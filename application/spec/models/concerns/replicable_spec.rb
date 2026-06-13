# frozen_string_literal: true

require "rails_helper"

# The concern is the entry point of the whole replication flow: a committed
# change on a public table must hand off to that model's producer, once per shard.
RSpec.describe Replicable do
  let(:tenant) { create(:tenant) }

  describe "after_commit replication" do
    it "publishes an upsert to every shard on create" do
      expect(PublicData::ManufacturerProducer)
        .to receive(:call)
        .with(an_instance_of(Symbol), "upsert", an_instance_of(Manufacturer))
        .exactly(Replicable::SHARDS.size).times

      Manufacturer.create!(name: "Sensus", tenant: tenant)
    end

    it "fans out to db1, db2 and db3" do
      received = []
      allow(PublicData::ManufacturerProducer).to receive(:call) { |shard, *_| received << shard }

      Manufacturer.create!(name: "Sensus", tenant: tenant)

      expect(received).to match_array(Replicable::SHARDS)
    end

    it "publishes an upsert on update" do
      manufacturer = create(:manufacturer, tenant: tenant)

      expect(PublicData::ManufacturerProducer)
        .to receive(:call).with(anything, "upsert", manufacturer)
        .exactly(Replicable::SHARDS.size).times

      manufacturer.update!(country: "PT")
    end

    it "publishes a delete on destroy" do
      manufacturer = create(:manufacturer, tenant: tenant)

      expect(PublicData::ManufacturerProducer)
        .to receive(:call).with(anything, "delete", manufacturer)
        .exactly(Replicable::SHARDS.size).times

      manufacturer.destroy!
    end

    it "resolves the producer by model name" do
      expect(Tenant.replicateable_producer).to eq(PublicData::TenantProducer)
      expect(Manufacturer.replicateable_producer).to eq(PublicData::ManufacturerProducer)
    end
  end

  describe "single-writer gate (only :default originates replication)" do
    it "fans out when the active connection is the source (:default)" do
      expect(PublicData::ManufacturerProducer).to receive(:call).at_least(:once)

      # Specs run on :default by default — this is the source node.
      expect(ConnectionSwitcher.current_shard).to eq(:default)
      create(:manufacturer, tenant: tenant)
    end

    it "does NOT re-replicate a change applied on a replica shard" do
      expect(PublicData::ManufacturerProducer).not_to receive(:call)

      # The consumer applies via raw SQL on the shard connection; simulate that.
      PublicDataService.call(:db1, Manufacturer, "upsert",
                             id: SecureRandom.uuid, name: "Applied", tenant_id: tenant.id)
    end
  end

  describe "single-writer enforcement (public tables are read-only on replicas)" do
    it "fails validation on a direct save to a public table on a replica" do
      tenant_id = tenant.id # create the tenant on :default before switching
      manufacturer = nil
      saved = ConnectionSwitcher.switch_shard(:db1) do
        manufacturer = Manufacturer.new(name: "Forced", tenant_id: tenant_id)
        manufacturer.save
      end

      expect(saved).to be(false)
      expect(manufacturer.errors[:base].join).to match(/read-only/)
      expect(Manufacturer.where(name: "Forced")).to be_empty
    end

    it "aborts a direct destroy on a replica" do
      manufacturer = create(:manufacturer, tenant: tenant)

      destroyed = ConnectionSwitcher.switch_shard(:db1) { manufacturer.destroy }

      expect(destroyed).to be(false)
      expect(Manufacturer.exists?(manufacturer.id)).to be(true)
    end

    it "allows writes on the source (:default)" do
      expect { create(:manufacturer, tenant: tenant) }.not_to raise_error
    end

    it "lets the consumer apply on a replica via raw SQL (bypasses the guard)" do
      id = SecureRandom.uuid
      result = PublicDataService.call(:db1, Manufacturer, "upsert",
                                      id: id, name: "Applied", country: "FR", tenant_id: tenant.id)

      expect(result).to be_success
      expect(Manufacturer.find(id).name).to eq("Applied")
    end
  end

  describe "tenant-owned tables" do
    it "does not make Entry replicateable" do
      expect(Entry.included_modules).not_to include(described_class)
    end
  end
end
