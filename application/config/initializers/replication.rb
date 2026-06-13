# Shards a public-table change is fanned out to (the regional replicas). The
# source is the :default connection (DB0); these are the replica connections (see
# ApplicationRecord.connects_to). Defined here, not in the autoloaded concern,
# because karafka.rb references it at boot before Zeitwerk is ready.
REPLICATION_SHARDS = %i[db1 db2 db3].freeze

# The two replication actions carried in the Kafka `action` header. Defined here
# (not on a class) so both the producer and the model concern can reference them
# without creating an autoload-ordering dependency between them.
REPLICATION_ACTIONS = { upsert: "upsert", delete: "delete" }.freeze

# Replication switch read by ApplicationProducer#call.
#
#   perform_later == true   -> publish over Kafka (real distributed path)
#   perform_later == false  -> apply inline via PublicDataService (single process)
#
# Default: async everywhere except tests, where specs drive producers/consumers
# explicitly through karafka-testing rather than a live broker.
Rails.application.configure do
  config.x.replication.perform_later = !Rails.env.test?
end
