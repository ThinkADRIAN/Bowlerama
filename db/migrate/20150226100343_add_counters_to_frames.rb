class AddCountersToFrames < ActiveRecord::Migration
  def change
    add_column :frames, :bowled_pins, :integer
    add_column :frames, :pins_left, :integer
  end
end
