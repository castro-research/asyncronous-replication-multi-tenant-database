# frozen_string_literal: true

# Karafka boots the Rails app so consumers can use the models/services.
ENV["RAILS_ENV"] ||= "development"
require_relative "config/environment"

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092") }
    config.client_id = "replicateable"
    # Consumers are idempotent (upsert by id), so at-least-once is fine.
    config.max_messages = 100
    # Topic names mix dots and underscores
    # (replicateable.public.<shard>.<suffix>); allow it.
    config.strict_topics_namespacing = false
  end

  routes.draw do
    # One consumer group per shard, with a topic per public table.
    #
    # In practice a replica process runs with NODE=<shard> and consumes only its
    # own group; running every group in one process is fine for a local demo.
    REPLICATION_SHARDS.each do |shard|
      consumer_group :"replicateable_#{shard}_public_data" do
        topic "replicateable.public.#{shard}.tenant" do
          consumer PublicData::TenantConsumer
        end

        topic "replicateable.public.#{shard}.manufacturer" do
          consumer PublicData::ManufacturerConsumer
        end
      end
    end
  end
end
