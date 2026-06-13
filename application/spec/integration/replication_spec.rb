# frozen_string_literal: true

require "rails_helper"

# End-to-end across the seam: a change on DB0 produces Kafka messages, and feeding
# those exact messages to the replica's consumer reproduces the row. In a single
# test process the "source" and "replica" share one database, so we delete the
# source row before consuming to prove the consumer (not the original write)
# recreated it.
RSpec.describe "Replication flow", type: :model do
  let(:tenant) { create(:tenant) }

  around do |example|
    original = Rails.configuration.x.replication.perform_later
    Rails.configuration.x.replication.perform_later = true
    example.run
    Rails.configuration.x.replication.perform_later = original
  end

  it "propagates a manufacturer created on DB0 to a replica consumer" do
    # 1. Write on the source (DB0). The concern publishes one message per shard.
    manufacturer = Manufacturer.create!(name: "Sensus", tenant: tenant, country: "FR")

    db1_message = karafka.produced_messages
                         .find { |m| m[:topic] == "replicateable.public.db1.manufacturer" }
    expect(db1_message).to be_present

    # 2. Simulate the replica starting empty.
    captured_id = manufacturer.id
    manufacturer.destroy!
    expect(Manufacturer.exists?(captured_id)).to be(false)

    # 3. The replica's consumer applies the captured event.
    consumer = karafka.consumer_for("replicateable.public.db1.manufacturer")
    karafka.produce(db1_message[:payload], headers: db1_message[:headers])
    consumer.consume

    # 4. The row now exists on the replica with the source's id (convergence).
    expect(Manufacturer.find(captured_id)).to have_attributes(name: "Sensus", country: "FR")
  end
end
