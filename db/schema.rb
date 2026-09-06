# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_05_000000) do
  create_table "articles", force: :cascade do |t|
    t.datetime "fetched_at"
    t.text "html"
    t.string "page", null: false
    t.index ["page"], name: "index_articles_on_page", unique: true
  end

  create_table "catalogs", force: :cascade do |t|
    t.integer "ingest_id"
    t.index ["ingest_id"], name: "index_catalogs_on_ingest_id"
  end

  create_table "classification_rules", force: :cascade do |t|
    t.string "display_type", null: false
    t.string "pattern", null: false
    t.integer "priority", default: 0
  end

  create_table "credits", force: :cascade do |t|
    t.string "billing", default: "starring"
    t.string "character"
    t.integer "episode_id", null: false
    t.integer "person_id", null: false
    t.index ["episode_id"], name: "index_credits_on_episode_id"
    t.index ["person_id"], name: "index_credits_on_person_id"
  end

  create_table "entities", force: :cascade do |t|
    t.json "categories", default: []
    t.string "display_type", default: "Other"
    t.text "gloss"
    t.integer "ingest_id", null: false
    t.string "name", null: false
    t.string "page", null: false
    t.index ["ingest_id", "page"], name: "index_entities_on_ingest_id_and_page", unique: true
    t.index ["ingest_id"], name: "index_entities_on_ingest_id"
  end

  create_table "entity_mentions", force: :cascade do |t|
    t.integer "entity_id", null: false
    t.integer "episode_id", null: false
    t.boolean "seen", default: true, null: false
    t.json "sources", default: []
    t.index ["entity_id"], name: "index_entity_mentions_on_entity_id"
    t.index ["episode_id", "entity_id", "seen"], name: "index_entity_mentions_on_episode_id_and_entity_id_and_seen", unique: true
    t.index ["episode_id"], name: "index_entity_mentions_on_episode_id"
  end

  create_table "episodes", force: :cascade do |t|
    t.string "airdate"
    t.text "background"
    t.text "blurb"
    t.string "director"
    t.string "image"
    t.integer "ingest_id", null: false
    t.integer "number"
    t.string "page", null: false
    t.binary "photo_data"
    t.string "photo_path"
    t.integer "season"
    t.integer "series_id", null: false
    t.string "stardate"
    t.text "summary"
    t.string "title", null: false
    t.string "writers"
    t.index ["ingest_id", "page", "number"], name: "index_episodes_on_ingest_id_and_page_and_number", unique: true
    t.index ["ingest_id", "series_id", "season", "number"], name: "idx_on_ingest_id_series_id_season_number_4d14e9275f"
    t.index ["ingest_id"], name: "index_episodes_on_ingest_id"
    t.index ["series_id"], name: "index_episodes_on_series_id"
  end

  create_table "ingests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.string "status", default: "building", null: false
    t.datetime "updated_at", null: false
  end

  create_table "match_corrections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "episode_keys", default: []
    t.string "path", null: false
    t.datetime "updated_at", null: false
    t.index ["path"], name: "index_match_corrections_on_path", unique: true
  end

  create_table "media_files", force: :cascade do |t|
    t.float "confidence", default: 0.0
    t.json "episode_keys", default: []
    t.string "kind", default: "extra"
    t.string "path", null: false
    t.datetime "scanned_at"
    t.index ["path"], name: "index_media_files_on_path", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.text "biography"
    t.integer "ingest_id", null: false
    t.string "name", null: false
    t.string "page", null: false
    t.binary "photo_data"
    t.string "photo_path"
    t.integer "tmdb_id"
    t.index ["ingest_id", "page"], name: "index_people_on_ingest_id_and_page", unique: true
    t.index ["ingest_id"], name: "index_people_on_ingest_id"
  end

  create_table "player_commands", force: :cascade do |t|
    t.string "action", null: false
    t.string "bus_name"
    t.datetime "created_at", null: false
    t.text "error"
    t.string "status", default: "pending"
    t.string "track_id"
    t.datetime "updated_at", null: false
    t.float "value"
  end

  create_table "player_states", force: :cascade do |t|
    t.string "bus_name"
    t.json "capabilities", default: {}
    t.datetime "captured_at"
    t.float "confidence", default: 0.0
    t.datetime "created_at", null: false
    t.text "diagnostic"
    t.float "duration", default: 0.0
    t.json "episode_keys", default: []
    t.integer "media_file_id"
    t.text "notice"
    t.datetime "notice_at"
    t.string "path"
    t.string "playback_status", default: "Stopped"
    t.float "position", default: 0.0
    t.float "rate", default: 1.0
    t.string "status", default: "NO_PLAYER"
    t.string "track_id"
    t.datetime "updated_at", null: false
    t.integer "viewing_id"
    t.float "volume", default: 1.0
    t.index ["media_file_id"], name: "index_player_states_on_media_file_id"
    t.index ["viewing_id"], name: "index_player_states_on_viewing_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.text "context"
    t.integer "episode_id", null: false
    t.integer "ordinal"
    t.string "speaker"
    t.text "text"
    t.index ["episode_id"], name: "index_quotes_on_episode_id"
  end

  create_table "series", force: :cascade do |t|
    t.json "aliases", default: []
    t.string "code", null: false
    t.string "era"
    t.string "name", null: false
    t.string "theme", default: "classic", null: false
    t.integer "tmdb_id"
    t.index ["code"], name: "index_series_on_code", unique: true
  end

  create_table "viewings", force: :cascade do |t|
    t.datetime "ended_at"
    t.json "episode_keys", default: []
    t.float "furthest_position", default: 0.0
    t.string "path"
    t.datetime "started_at"
  end

  add_foreign_key "catalogs", "ingests"
  add_foreign_key "credits", "episodes"
  add_foreign_key "credits", "people"
  add_foreign_key "entities", "ingests"
  add_foreign_key "entity_mentions", "entities"
  add_foreign_key "entity_mentions", "episodes"
  add_foreign_key "episodes", "ingests"
  add_foreign_key "episodes", "series"
  add_foreign_key "people", "ingests"
  add_foreign_key "player_states", "media_files"
  add_foreign_key "player_states", "viewings"
  add_foreign_key "quotes", "episodes"
end
