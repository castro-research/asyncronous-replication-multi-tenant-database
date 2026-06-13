# Manufacturer name is globally unique. The DB constraint is the real guarantee;
# the model validation just turns a would-be PG::UniqueViolation into a friendly
# error and lets PublicDataService report it instead of crashing the consumer.
class AddUniqueIndexToManufacturersName < ActiveRecord::Migration[8.1]
  def change
    add_index :manufacturers, :name, unique: true
  end
end
