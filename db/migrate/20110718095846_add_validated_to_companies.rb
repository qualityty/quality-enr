class AddValidatedToCompanies < ActiveRecord::Migration
#  def change
#    add_column :companies, :validated, :boolean, :default => false
#  end
  def self.up
    add_column :companies, :validated, :boolean, :default => false
  end

  def self.down
    remove_column :companies, :validated, :boolean
  end
end
