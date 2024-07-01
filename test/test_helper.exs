ExUnit.start()

# Ensure the Cachetastic.Behaviour module is loaded before defining mocks
Code.ensure_compiled!(Cachetastic.Behaviour)

Mox.defmock(Cachetastic.PrimaryMock, for: Cachetastic.Behaviour)
Mox.defmock(Cachetastic.BackupMock, for: Cachetastic.Behaviour)
