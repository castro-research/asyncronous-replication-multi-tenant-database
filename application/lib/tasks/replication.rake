namespace :replication do
  desc "Full demo: set up the 4 databases, seed the source, replicate over Kafka, and verify"
  task demo: :environment do
    Rake::Task["replication:setup"].invoke
    Rake::Task["replication:replicate"].invoke
    Rake::Task["replication:verify"].invoke
  end

  desc "Drop, recreate and migrate every node (db0..db3)"
  task setup: :environment do
    # The development env declares all four connections, so a single drop/create
    # acts on every node — no per-NODE loop needed.
    system("bin/rails", "db:create", "db:migrate", exception: true)
  end

  desc "Seed the source (db0); changes are produced to Kafka for the consumer to apply"
  task replicate: :environment do
    Rails.configuration.x.replication.perform_later = true

    clear = lambda do
      Entry.delete_all
      Manufacturer.delete_all
      Tenant.delete_all
    end

    REPLICATION_SHARDS.each { |shard| ConnectionSwitcher.switch_shard(shard) { clear.call } }
    clear.call

    france = Tenant.create!(name: "France HQ", subdomain: "france")
    sensus = Manufacturer.create!(name: "Sensus", country: "FR", tenant: france)
    Manufacturer.create!(name: "Itron", country: "US", tenant: france)
    Manufacturer.create!(name: "Diehl", country: "DE", tenant: france)
    Entry.create!(description: "Meter batch #1", manufacturer: sensus)

    puts "==> source (db0): produced #{Manufacturer.count} manufacturer(s) to Kafka"
  end

  desc "Poll the replicas until they converge with the source (or time out)"
  task verify: :environment do
    expected = Manufacturer.order(:id).pluck(:id).sort
    deadline = monotonic + Integer(ENV.fetch("TIMEOUT", "30"))

    REPLICATION_SHARDS.each do |shard|
      loop do
        ids, names = ConnectionSwitcher.switch_shard(shard) do
          [Manufacturer.order(:id).pluck(:id).sort, Manufacturer.order(:name).pluck(:name)]
        end

        if ids == expected
          puts "==> #{shard}: converged (#{names.join(', ')})"
          break
        end

        if monotonic > deadline
          puts "==> #{shard}: TIMEOUT (#{ids.size}/#{expected.size} rows)"
          break
        end

        sleep 1
      end
    end
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
