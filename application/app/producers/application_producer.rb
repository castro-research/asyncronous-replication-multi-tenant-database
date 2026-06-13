# Base producer. Decides whether a replication change goes out asynchronously
# over Kafka (the real path) or is applied inline (`produce_now`, handy for
# single-process tests and demos).
class ApplicationProducer
  include Callable

  def initialize(record = nil)
    @resource = record
  end

  def call
    Rails.configuration.x.replication.perform_later ? produce : produce_now
  end

  private

  def produce
    raise NotImplementedError, "#{self.class} must implement #produce"
  end

  def produce_now
    raise NotImplementedError, "#{self.class} must implement #produce_now"
  end

  def logger
    Rails.logger
  end
end
