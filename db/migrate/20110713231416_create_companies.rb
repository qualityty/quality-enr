class CreateCompanies < ActiveRecord::Migration
  def self.up
    create_table :companies do |t|
      t.string :name
      t.string :postal_code
      t.integer :serial_num
      t.string :address
      t.string :telephone
      t.timestamps
    end
  end

  def self.down
    drop_table :companies
  end
end
