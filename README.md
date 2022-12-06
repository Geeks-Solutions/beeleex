# Beeleex

Beeleex is a helper library that allows you to quickly setup the connections between your business unit and BeeLee.
## Installation

  In your mix.exs add this to your list of dependencies:

  ```elixir
  {:beeleex, "~> 0.1.0"}
  ```
## Configuration
#### Common Configuration
To setup Beeleex, all you need to do is the following:

  - In your `router.ex`, add this line:
  ```elixir
  use Beeleex.Routes, scope: "/beeleex"
  ```

  - In your `config.ex`, add the following: 
  ```elixir
  config :beeleex,
  verify_token_action: %{module: YourModule, function: :function_name}
  ```