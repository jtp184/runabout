class CreateSecondScreen < ActiveRecord::Migration[8.1]
  def change
    create_table :series do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :theme, null: false, default: "classic"
      t.string :era
      t.integer :tmdb_id
      t.json :aliases, default: []
    end
    add_index :series, :code, unique: true
    create_table :ingests do |t|
      t.string :status, default: "building", null: false
      t.text :error
      t.timestamps
    end
    create_table :catalogs do |t|
      t.references :ingest, foreign_key: true
    end
    create_table :episodes do |t|
      t.references :ingest, null: false, foreign_key: true
      t.references :series, null: false, foreign_key: true
      t.integer :season
      t.integer :number
      t.string :title, null: false
      t.string :page, null: false
      t.string :stardate
      t.string :airdate
      t.string :director
      t.string :writers
      t.string :image
      t.text :blurb
      t.text :summary
      t.text :background
      t.string :photo_path
      t.binary :photo_data
    end
    add_index :episodes, [ :ingest_id, :page, :number ], unique: true
    add_index :episodes, [ :ingest_id, :series_id, :season, :number ]
    create_table :people do |t|
      t.references :ingest, null: false, foreign_key: true
      t.string :name, null: false
      t.string :page, null: false
      t.text :biography
      t.integer :tmdb_id
      t.string :photo_path
      t.binary :photo_data
    end
    add_index :people, [ :ingest_id, :page ], unique: true
    create_table :credits do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :character
      t.string :billing, default: "starring"
    end
    create_table :entities do |t|
      t.references :ingest, null: false, foreign_key: true
      t.string :name, null: false
      t.string :page, null: false
      t.text :gloss
      t.json :categories, default: []
      t.string :display_type, default: "Other"
    end
    add_index :entities, [ :ingest_id, :page ], unique: true
    create_table :entity_mentions do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :entity, null: false, foreign_key: true
      t.boolean :seen, default: true, null: false
      t.json :sources, default: []
    end
    add_index :entity_mentions, [ :episode_id, :entity_id, :seen ], unique: true
    create_table :quotes do |t|
      t.references :episode, null: false, foreign_key: true
      t.text :text
      t.string :speaker
      t.text :context
      t.integer :ordinal
    end
    create_table :classification_rules do |t|
      t.string :pattern, null: false
      t.string :display_type, null: false
      t.integer :priority, default: 0
    end
    create_table :media_files do |t|
      t.string :path, null: false
      t.json :episode_keys, default: []
      t.float :confidence, default: 0
      t.string :kind, default: "extra"
      t.datetime :scanned_at
    end
    add_index :media_files, :path, unique: true
    create_table :match_corrections do |t|
      t.string :path, null: false
      t.json :episode_keys, default: []
      t.timestamps
    end
    add_index :match_corrections, :path, unique: true
    create_table :viewings do |t|
      t.json :episode_keys, default: []
      t.string :path
      t.datetime :started_at
      t.datetime :ended_at
      t.float :furthest_position, default: 0
    end
    create_table :player_states do |t|
      t.string :bus_name
      t.string :status, default: "NO_PLAYER"
      t.string :playback_status, default: "Stopped"
      t.float :position, default: 0
      t.float :duration, default: 0
      t.float :rate, default: 1
      t.float :volume, default: 1
      t.datetime :captured_at
      t.string :track_id
      t.string :path
      t.json :episode_keys, default: []
      t.json :capabilities, default: {}
      t.float :confidence, default: 0
      t.text :diagnostic
      t.text :notice
      t.datetime :notice_at
      t.references :media_file, foreign_key: true
      t.references :viewing, foreign_key: true
      t.timestamps
    end
    create_table :player_commands do |t|
      t.string :action, null: false
      t.float :value
      t.string :bus_name
      t.string :track_id
      t.string :status, default: "pending"
      t.text :error
      t.timestamps
    end
    create_table :articles do |t|
      t.string :page, null: false
      t.text :html
      t.datetime :fetched_at
    end
    add_index :articles, :page, unique: true
  end
end
