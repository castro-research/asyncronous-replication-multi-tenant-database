class PublicData::ManufacturerConsumer < PublicData::BaseConsumer
  EXCLUDED_PARAMS = [].freeze

  def self.base_klass
    Manufacturer
  end
end
