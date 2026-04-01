ExUnit.start()

# Create the database, run migrations, and start the sandbox
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))

Cachetastic.TestRepo.start_link()

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Cachetastic.TestRepo)
Ecto.Adapters.SQL.Sandbox.mode(Cachetastic.TestRepo, {:shared, self()})

ExUnit.configure(exclude: [skip: true])
