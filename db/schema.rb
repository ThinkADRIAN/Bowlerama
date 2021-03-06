# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150226100343) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "frames", force: true do |t|
    t.string   "first_stroke"
    t.string   "second_stroke"
    t.string   "extra_stroke"
    t.integer  "frame_score"
    t.integer  "frame_number"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "game_id"
    t.integer  "bowled_pins"
    t.integer  "pins_left"
  end

  create_table "games", force: true do |t|
    t.integer  "current_frame"
    t.integer  "frame_stroke"
    t.integer  "total_score"
    t.integer  "rolls",         default: [], array: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "bowled_pins"
    t.integer  "pins_left"
  end

end
