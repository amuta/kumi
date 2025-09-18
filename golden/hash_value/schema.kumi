schema do
  input do
    array :users do
      string :name
      string :state
    end
  end

  value :users, {
    name: input.users.name,
    state: input.users.state
  }

  trait :is_john, input.users.name == "John"

  value :john_user, select(is_john, users, "NOT_JOHN")
end
