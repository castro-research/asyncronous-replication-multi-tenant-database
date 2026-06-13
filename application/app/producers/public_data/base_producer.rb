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
    service_result = PublicDataService.call(@subdomain, consumer_klass.base_klass, @action, build_attributes)

    if service_result.failure?
      raise ReplicationError, "Failed to produce public data for #{topic_name}: #{service_result.errors.join(', ')}"
    end

    true
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
