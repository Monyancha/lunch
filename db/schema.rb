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

ActiveRecord::Schema.define(version: 20150128002218) do

  create_table "corporate_communications", force: true do |t|
    t.string   "email_id"
    t.string   "title"
    t.datetime "date_sent"
    t.string   "category"
    t.text     "body"
  end

  add_index "corporate_communications", ["category"], name: "i_cor_com_cat"

  create_table "users", force: true do |t|
    t.string   "username",                                        default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer  "sign_in_count",          precision: 38, scale: 0, default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["reset_password_token"], name: "i_users_reset_password_token", unique: true
  add_index "users", ["username"], name: "index_users_on_username", unique: true

end
