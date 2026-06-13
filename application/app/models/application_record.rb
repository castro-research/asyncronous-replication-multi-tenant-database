class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # One process connects to the source (default = DB0) and to every replica, so
  # the consumer can apply a change on the right node via
  # ConnectionSwitcher.switch_shard(<subdomain>). The shard names match the
  # connections declared in config/database.yml.
  connects_to shards: {
    default: { writing: :primary },
    db1: { writing: :db1 },
    db2: { writing: :db2 },
    db3: { writing: :db3 }
  }
end
