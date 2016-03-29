class AddFingerprintIndex < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    args = [:keys, :fingerprint]

    if Gitlab::Database.postgresql?
      args << { algorithm: :concurrently }
    end

    add_index(*args)
  end
end
