ExUnit.start()

Code.require_file("support/test_schema.ex", __DIR__)
Code.require_file("support/test_repo.ex", __DIR__)

# Create the database, run migrations, and start the sandbox
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))

Cachetastic.TestRepo.start_link()

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Cachetastic.TestRepo)
Ecto.Adapters.SQL.Sandbox.mode(Cachetastic.TestRepo, {:shared, self()})

# Check out a connection before each test
ExUnit.configure(exclude: [skip: true])
