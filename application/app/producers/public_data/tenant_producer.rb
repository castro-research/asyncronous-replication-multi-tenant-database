class PublicData::TenantProducer < PublicData::BaseProducer
  KAFKA_TOPIC_SUFFIX = "tenant"

  def consumer_klass
    PublicData::TenantConsumer
  end
end
