class AddRequiredRoleIdToEvent < ActiveRecord::Migration
  def change
    add_column :events, :required_role_id, :integer, :null => false, :default => 1
  end
end
