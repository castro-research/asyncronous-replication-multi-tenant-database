# frozen_string_literal: true

require "rails_helper"

# Verifies the wire format a producer puts on Kafka: topic name, headers and
# payload. Uses karafka-testing's in-memory producer (no broker).
RSpec.describe PublicData::ManufacturerProducer do
  # Fixtures are built with the default (inline) path so they do not emit Kafka
  # messages; we only care about the message produced by the explicit
  # `described_class.call` under test.
  let(:tenant) { create(:tenant) }
  let(:manufacturer) { create(:manufacturer, tenant: tenant, name: "Sensus", country: "FR") }

  # Emit over Kafka and return the single message that call produced. Resetting
  # the buffer first isolates it from any incidental fixture activity.
  def emit(*args)
    manufacturer # ensure the row exists before we start capturing
    Karafka.producer.client.reset
    original = Rails.configuration.x.replication.perform_later
    Rails.configuration.x.replication.perform_later = true
    described_class.call(*args)
  ensure
    Rails.configuration.x.replication.perform_later = original
  end

  def message
    karafka.produced_messages.last
  end

  describe "#call (upsert)" do
    before { emit(:db1, "upsert", manufacturer) }

    it "targets the shard-scoped topic" do
      expect(message[:topic]).to eq("replicateable.public.db1.manufacturer")
    end

    it "sets subdomain and action headers" do
      expect(message[:headers]).to include("subdomain" => "db1", "action" => "upsert")
    end

    it "carries the persisted columns in the payload" do
      attributes = JSON.parse(message[:payload]).fetch("attributes")
      expect(attributes).to include(
        "id" => manufacturer.id,
        "name" => "Sensus",
        "country" => "FR",
        "tenant_id" => tenant.id
      )
    end

    it "partitions by record id to keep per-row ordering" do
      expect(message[:partition_key]).to eq(manufacturer.id.to_s)
    end
  end

  describe "#call (delete)" do
    before { emit(:db2, "delete", manufacturer) }

    it "sends only the id" do
      attributes = JSON.parse(message[:payload]).fetch("attributes")
      expect(attributes).to eq("id" => manufacturer.id)
    end

    it "marks the action as delete on the shard topic" do
      expect(message[:topic]).to eq("replicateable.public.db2.manufacturer")
      expect(message[:headers]).to include("action" => "delete")
    end
  end

  # db4 is a not-properly-configured node: it points at db3's instance but at a
  # schema (db4) that does not own the public tables, so the table is absent
  # there. The producer must skip it instead of emitting an event that would only
  # fail downstream.
  describe "a shard whose table is missing (db4)" do
    before do
      ApplicationRecord.connected_to(role: :writing, shard: :db4) do
        ApplicationRecord.connection.execute("CREATE SCHEMA IF NOT EXISTS db4")
      end
    end

    it "does not emit a Kafka message" do
      emit(:db4, "upsert", manufacturer)
      expect(karafka.produced_messages).to be_empty
    end

    it "returns true (treated as a successful no-op) on the inline path" do
      manufacturer # ensure the row exists
      expect(described_class.call(:db4, "upsert", manufacturer)).to be(true)
    end
  end
end
