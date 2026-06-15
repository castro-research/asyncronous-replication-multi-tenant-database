# Publishes a public-table change to Kafka, one message per shard:
#
#   topic   replicateable.public.<subdomain>.<KAFKA_TOPIC_SUFFIX>
#   headers { subdomain:, action: }   (upsert | delete)
#   payload { "attributes": { ...persisted columns... } }
#
# Subclasses define KAFKA_TOPIC_SUFFIX and #consumer_klass.
class PublicData::BaseProducer < ApplicationProducer
  ACTIONS = REPLICATION_ACTIONS

  class ReplicationError < StandardError; end

  def initialize(subdomain, action, record = {})
    super(record)
    @subdomain = subdomain
    @action = action
  end

  private

  # Real path: hand the event to Kafka and let the consumer on the shard apply it.
  def produce
    return true unless table_on_shard?

    logger.debug { "Producing public data for #{topic_name}" }

    Karafka.producer.produce_sync(
      topic: topic_name,
      payload: build_json,
      partition_key: partition_key,
      headers: build_headers
    )

    true
  end

  # Inline path: apply straight to the shard's database without a broker. Returns
  # the service result so callers can detect failures, exactly like the reference.
  def produce_now
    return true unless table_on_shard?

    service_result = PublicDataService.call(@subdomain, consumer_klass.base_klass, @action, build_attributes)

    if service_result.failure?
      raise ReplicationError, "Failed to produce public data for #{topic_name}: #{service_result.errors.join(', ')}"
    end

    true
  end

  # A replica is only a valid target if it actually owns the public table. A
  # not-properly-configured node (e.g. db4: shares db3's instance but points at a
  # schema without the public tables) is missing it — producing there would just
  # fail downstream, so we skip it instead. Schema cache is reset per check so a
  # node provisioned after boot is picked up without a restart.
  def table_on_shard?
    klass = consumer_klass.base_klass

    ConnectionSwitcher.switch_shard(@subdomain) do
      klass.connection.schema_cache.clear!
      klass.connection.table_exists?(klass.table_name)
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished => e
    logger.warn { "Skipping replication to #{@subdomain}: #{e.class} #{e.message}" }
    false
  end

  def topic_name
    "replicateable.public.#{@subdomain}.#{self.class::KAFKA_TOPIC_SUFFIX}"
  end

  # Keeps all events for one row on the same partition, so upsert/delete stay
  # ordered per record (paper §ordering: at-least-once + per-key ordering).
  def partition_key
    @resource.id.to_s
  end

  def build_attributes
    data =
      case @action
      when ACTIONS[:upsert]
        # Slice by column_names so virtual attributes never reach upsert.
        @resource.attributes.slice(*@resource.class.column_names)
      when ACTIONS[:delete]
        { "id" => @resource.id }
      else
        {}
      end

    data.symbolize_keys.except(*consumer_klass::EXCLUDED_PARAMS)
  end

  def build_headers
    { subdomain: @subdomain, action: @action }
      .deep_stringify_keys
      .deep_transform_values(&:to_s)
  end

  def build_json
    Jbuilder.new { |json| json.attributes(build_attributes) }.target!
  end
end
