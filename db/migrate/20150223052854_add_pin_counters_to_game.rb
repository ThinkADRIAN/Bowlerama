class AddPinCountersToGame < ActiveRecord::Migration
  def change
    add_column :games, :bowled_pins, :integer
    add_column :games, :pins_left, :integer
  end
end
