ExUnit.start()

Code.require_file("support/test_schema.ex", __DIR__)

# Create the database, run migrations, and start the sandbox
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))

# Check out a connection before each test
ExUnit.configure(exclude: [skip: true])
