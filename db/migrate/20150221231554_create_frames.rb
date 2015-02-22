class CreateFrames < ActiveRecord::Migration
  def change
    create_table :frames do |t|
      t.string :first_stroke
      t.string :second_stroke
      t.string :extra_stroke
      t.integer :frame_score
      t.integer :frame_number

      t.timestamps
    end
  end
end
