# Applies a replicated change to a public table on a replica. Called as
# `PublicDataService.call(subdomain, klass, action, attributes)`.
#
# `subdomain` IS the target shard: the write runs inside
# ConnectionSwitcher.switch_shard(subdomain), so it lands on that replica's
# connection. The active shard is then a replica (not :default), so the model's
# publish gate does not re-replicate — no echo, no loop.
#
# Writes go through raw SQL (upsert / delete), NOT `save`/`destroy`, on purpose:
#   * it bypasses the model's single-writer validation (which forbids writing a
#     public table on a non-:default connection) — applying replication is the
#     one legitimate way a replica row appears, so it must not trip that guard;
#   * `upsert` keys on the replicated `id`, so re-delivering the same Kafka
#     message (at-least-once delivery) converges instead of duplicating — this is
#     what makes weak/eventual consistency safe under retries.
class PublicDataService
  include Callable

  ACTIONS = PublicData::BaseProducer::ACTIONS

  Result = Struct.new(:record, :errors, keyword_init: true) do
    def success? = errors.empty?
    def failure? = !success?
  end

  def initialize(subdomain, klass, action, attributes)
    @subdomain  = subdomain
    @klass      = klass
    @action     = action.to_s
    @attributes = (attributes || {}).symbolize_keys
  end

  def call
    ConnectionSwitcher.switch_shard(@subdomain) do
      case @action
      when ACTIONS[:upsert] then upsert
      when ACTIONS[:delete] then delete
      else
        Result.new(record: nil, errors: ["Unknown action #{@action}"])
      end
    end
  rescue StandardError => e
    Result.new(record: nil, errors: [e.message])
  end

  private

  # ON CONFLICT (id) DO UPDATE keyed on the replicated id: idempotent under
  # redelivery. No callbacks/validations fire (raw SQL), so the single-writer
  # guard is not tripped on the replica.
  def upsert
    # @klass.upsert(@attributes, unique_by: :id)
    # `unique_by: :id` is the default, but i will let commented, because i want to simulate a problem we may have, or not... let's see.
    @klass.upsert(@attributes)
    Result.new(record: nil, errors: [])
  end

  # Deletion is the paper's open question: a replicated row (e.g. Manufacturer)
  # may be referenced by a tenant-owned row (Entry) on this replica. We adopt the
  # "prevent" strategy — the DB foreign key blocks the delete and we surface the
  # conflict (PG::ForeignKeyViolation) rather than orphaning tenant data.
  # Swapping this for tolerate-orphan or distributed-tx is the Future Work hook.
  def delete
    @klass.where(id: @attributes[:id]).delete_all # no-op if already gone -> idempotent
    Result.new(record: nil, errors: [])
  end
end
