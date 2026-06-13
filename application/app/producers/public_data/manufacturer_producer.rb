class PublicData::ManufacturerProducer < PublicData::BaseProducer
  KAFKA_TOPIC_SUFFIX = "manufacturer"

  def consumer_klass
    PublicData::ManufacturerConsumer
  end
end
