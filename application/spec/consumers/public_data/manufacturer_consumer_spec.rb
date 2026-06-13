# frozen_string_literal: true

require "rails_helper"

# Verifies the replica side: a consumer applies upsert/delete to the local DB and
# ignores messages for shards it does not own. Uses karafka-testing's consumer
# harness (no broker).
RSpec.describe PublicData::ManufacturerConsumer do
  subject(:consumer) { karafka.consumer_for("replicateable.public.db1.manufacturer") }

  let(:tenant) { create(:tenant) }

  def payload_for(attrs)
    Jbuilder.new { |json| json.attributes(attrs) }.target!
  end

  def deliver(attrs, action:, subdomain: "db1")
    karafka.produce(payload_for(attrs), headers: { "subdomain" => subdomain, "action" => action })
  end

  # Public tables use DB0-generated UUIDs as their replicated identity.
  let(:source_id) { SecureRandom.uuid }

  describe "upsert" do
    let(:attributes) { { id: source_id, name: "Sensus", country: "FR", tenant_id: tenant.id } }

    it "creates the replicated row keyed by the source id" do
      deliver(attributes, action: "upsert")

      expect { consumer.consume }.to change(Manufacturer, :count).by(1)
      expect(Manufacturer.find(source_id)).to have_attributes(name: "Sensus", country: "FR")
    end

    it "is idempotent on redelivery" do
      deliver(attributes, action: "upsert")
      deliver(attributes, action: "upsert")

      expect { consumer.consume }.to change(Manufacturer, :count).by(1)
    end

    it "applies updates to an existing row" do
      create(:manufacturer, id: source_id, tenant: tenant, name: "Old", country: "FR")
      deliver(attributes.merge(country: "PT"), action: "upsert")

      consumer.consume

      expect(Manufacturer.find(source_id).country).to eq("PT")
    end
  end

  describe "delete" do
    it "removes the replicated row" do
      manufacturer = create(:manufacturer, tenant: tenant)
      deliver({ id: manufacturer.id }, action: "delete")

      expect { consumer.consume }.to change(Manufacturer, :count).by(-1)
    end

    it "is a no-op when the row is already gone (idempotent)" do
      deliver({ id: SecureRandom.uuid }, action: "delete")

      expect { consumer.consume }.not_to raise_error
    end
  end

  describe "shard filtering" do
    it "skips messages whose subdomain is not one of our shards" do
      deliver({ id: SecureRandom.uuid, name: "X", tenant_id: tenant.id }, action: "upsert", subdomain: "unknown")

      expect { consumer.consume }.not_to change(Manufacturer, :count)
    end
  end
end
