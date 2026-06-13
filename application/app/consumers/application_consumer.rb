# Base Karafka consumer. Iterates the batch and applies each message.
class ApplicationConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| execute(message) }
  end

  private

  def logger
    Rails.logger
  end
end
