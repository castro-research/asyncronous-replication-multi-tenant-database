class PublicData::TenantConsumer < PublicData::BaseConsumer
  EXCLUDED_PARAMS = [].freeze

  def self.base_klass
    Tenant
  end
end
