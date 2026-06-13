# Applies a replicated public-table change on a replica. Faithfully follows the
# reference `PublicData::BaseConsumer`:
#
#   * skips messages whose subdomain is not one of our shards,
#   * validates the action (upsert | delete),
#   * delegates the actual write to PublicDataService.
#
# Subclasses define EXCLUDED_PARAMS and `self.base_klass`.
class PublicData::BaseConsumer < ApplicationConsumer
  private

  def execute(message)
    data      = message.payload.deep_symbolize_keys
    subdomain = message.headers["subdomain"]
    action    = message.headers["action"]

    unless Replicable::SHARDS.include?(subdomain.to_sym)
      logger.info("#{self.class.name} received message for subdomain #{subdomain}: NOT A SHARD. Skipping.")
      return true
    end

    raise "Subdomain is missing" if subdomain.blank?
    raise "Action #{action} is not valid" if PublicData::BaseProducer::ACTIONS.values.exclude?(action.to_s)

    logger.info("#{self.class.name} received #{data.inspect}")

    attributes = data[:attributes].except(*self.class::EXCLUDED_PARAMS)
    service_result = PublicDataService.call(subdomain, self.class.base_klass, action, attributes)

    if service_result.failure?
      logger.error("[#{self.class.name}] subdomain: #{subdomain} action: #{action}")
      raise StandardError, "Errors: #{service_result.errors.join(', ')}"
    end

    true
  end

  def self.base_klass
    raise NotImplementedError, "Subclasses must implement the base_klass method"
  end
end
