# Mixin for the public/configuration tables that must be copied to every
# regional replica (DB1, DB2, DB3). Including it turns a model into a replication
# *source*: every committed create/update/destroy on DB0 is published to Kafka,
# one message per shard, via the model's dedicated producer.
#
#   class Manufacturer < ApplicationRecord
#     include Replicable
#   end
#
# By convention the producer is `PublicData::<Model>Producer` (one producer class
# per public table); this concern wires the callbacks to that class so the models
# stay declarative.
#
# NB: named `Replicable` (not `Replicateable`) because the Rails application
# module is itself `Replicateable` — reusing that name would collide with the
# app's root namespace under Zeitwerk.
module Replicable
  extend ActiveSupport::Concern

  # The shards a change must be fanned out to (the regional replicas). The
  # canonical value lives in config/initializers/replication.rb so karafka.rb can
  # use it at boot, before Zeitwerk autoloading is available.
  SHARDS = REPLICATION_SHARDS

  included do
    # Single-writer guard: a public table is writable only on the source
    # connection (:default). Any save through ActiveRecord on a replica fails
    # validation. Replicas receive rows only via PublicDataService, which applies
    # them with raw SQL (no callbacks/validations), so this never blocks a
    # legitimate apply — it only stops a stray `Model.save` on a replica.
    validate :writable_on_source
    # destroy skips validations, so guard it with a callback that aborts on a
    # replica connection.
    before_destroy :writable_on_source!

    # after_commit (not after_save) so we only replicate durable changes and
    # never publish a row that was rolled back.
    after_commit :replicate_upsert, on: %i[create update]
    after_commit :replicate_delete, on: :destroy
  end

  private

  def source_connection?
    ConnectionSwitcher.current_shard == :default
  end

  def writable_on_source
    return if source_connection?

    errors.add(:base, "public tables are read-only on #{ConnectionSwitcher.current_shard}; " \
                      "only the source (:default) may write them")
  end

  # before_destroy variant: abort the destroy on a replica connection.
  def writable_on_source!
    throw :abort unless source_connection?
  end

  def replicate_upsert
    publish(REPLICATION_ACTIONS[:upsert])
  end

  def replicate_delete
    publish(REPLICATION_ACTIONS[:delete])
  end

  # One message per shard, using per-subdomain topic naming
  # (`replicateable.public.<shard>.<suffix>`).
  #
  # Only the source originates replication: a write is a source write exactly
  # when the active connection is :default. When a consumer applies a change it
  # does so inside ConnectionSwitcher.switch_shard(<subdomain>), so current_shard
  # is a replica — this returns and the replica never echoes the row back. This
  # connection gate is what makes a separate "applying" flag unnecessary.
  def publish(action)
    return unless ConnectionSwitcher.current_shard == :default

    SHARDS.each do |shard|
      replicateable_producer.call(shard, action, self)
    end
  end

  def replicateable_producer
    self.class.replicateable_producer
  end

  class_methods do
    # Resolves `PublicData::<Model>Producer` (e.g. ManufacturerProducer) lazily so
    # the producer file is only required when replication actually fires.
    def replicateable_producer
      @replicateable_producer ||= "PublicData::#{model_name.name}Producer".constantize
    end
  end
end
