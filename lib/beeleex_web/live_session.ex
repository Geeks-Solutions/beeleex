defmodule BeeleexWeb.LiveSession do
  @moduledoc """
  Helpers for reading the signed-in user's Beelee token out of the LiveView
  session, so the back-office pages can authenticate Beelee API calls as that
  user via the `bu-authorization` header.

  The host application is responsible for putting the token into the Plug
  session before the user reaches the billing pages (e.g. in its auth pipeline
  or `on_mount` hook). By default Beeleex reads it from the `"bu_token"` session
  key; override with:

      config :beeleex, :bu_token_session_key, "my_session_key"
  """

  @doc """
  Fetch the Beelee user token from a LiveView `session` map. Returns `nil` when
  the session is missing or does not carry the token.
  """
  @spec bu_token(map() | any()) :: String.t() | nil
  def bu_token(session) when is_map(session) do
    key = Application.get_env(:beeleex, :bu_token_session_key, "bu_token")
    session[key] || session[to_string(key)]
  end

  def bu_token(_), do: nil
end
