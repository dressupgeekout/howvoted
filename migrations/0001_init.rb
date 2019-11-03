Sequel.migration do
  change do
    create_table(:legislators) do
      primary_key :id
      String :name_id, :text => true, :null => false
      Integer :year, :null => false
      String :sort_field, :text => true
      String :unaccented_name, :text => true
      String :party, :text => true
      String :state, :text => true
      String :role, :text => true
      String :name, :text => true
    end

    create_table(:roll_calls) do
      primary_key :id
      Integer :year, :null => false
      String :date, :text => true
      Integer :number
      String :legisnum, :text => true
      String :question, :text => true
      String :descr, :text => true
    end

    create_table(:votes) do
      primary_key :id
      foreign_key :roll_call_id, :roll_calls
      foreign_key :legislator_id, :legislators
      String :vote, :text => true
    end
  end
end
