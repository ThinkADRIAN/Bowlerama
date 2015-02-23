class AddGameIdToFrame < ActiveRecord::Migration
  def change
    add_column :frames, :game_id, :integer
  end
end
