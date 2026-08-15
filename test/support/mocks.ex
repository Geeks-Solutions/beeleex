# Defines the Mox mock at compile time (test/support is on the test elixirc
# path) so the bundled test router can inject it into the LiveView session.
# Defining it here instead of in test_helper.exs (runtime) avoids "module is not
# available" compile/Dialyzer warnings.
Mox.defmock(Beeleex.ApiMock, for: Beeleex.ApiBehaviour)
