class CreateNewClustersArchitectures < ActiveRecord::Migration
  DOWNTIME = false

  def change
    create_table :clusters do |t|
      t.references :user, foreign_key: { on_delete: :nullify }

      t.boolean :enabled, default: true
      t.string :name, null: false # If manual, read-write. If gcp, read-only.

      t.integer :provider_type, null: false
      t.integer :platform_type, null: false

      t.datetime_with_timezone :created_at, null: false
      t.datetime_with_timezone :updated_at, null: false
    end

    create_table :cluster_projects do |t|
      t.references :project, null: false, index: true, foreign_key: { on_delete: :cascade }
      t.references :cluster, null: false, index: true, foreign_key: { on_delete: :cascade }

      t.datetime_with_timezone :created_at, null: false
      t.datetime_with_timezone :updated_at, null: false
    end

    create_table :cluster_platforms_kubernetes do |t|
      t.references :cluster, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }

      t.string :api_url
      t.text :ca_cert

      t.string :namespace

      t.string :username
      t.text :encrypted_password
      t.string :encrypted_password_iv

      t.text :encrypted_token
      t.string :encrypted_token_iv

      t.datetime_with_timezone :created_at, null: false
      t.datetime_with_timezone :updated_at, null: false
    end

    create_table :cluster_providers_gcp do |t|
      t.references :cluster, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }

      t.integer :status
      t.text :status_reason

      t.string :gcp_project_id, null: false
      t.string :zone, null: false
      t.integer :num_nodes, null: false
      t.string :machine_type
      t.string :operation_id

      t.string :endpoint

      t.text :encrypted_access_token
      t.string :encrypted_access_token_iv

      t.datetime_with_timezone :created_at, null: false
      t.datetime_with_timezone :updated_at, null: false
    end
  end
end
