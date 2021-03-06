class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.integer :current_frame
      t.integer :frame_stroke
      t.integer :total_score
      t.integer :rolls, array: true, default: []

      t.timestamps
    end
  end
end
