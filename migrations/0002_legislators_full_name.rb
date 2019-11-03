Sequel.migration do
  change do
    alter_table(:legislators) do
      add_column :full_name, String, :text => true
    end
  end
end
