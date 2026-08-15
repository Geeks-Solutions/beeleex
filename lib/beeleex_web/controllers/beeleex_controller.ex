defmodule BeeleexWeb.BeeleexController do
  @moduledoc """
  The beeleex Controller handles the beeleex endpoints.

  Check the routes for mapping to the right controller function.

  Note:

  As Beeleex will have to handle with file submission, thus the user will need supply form-data body in the request. In order to see an example you can check the Postman collection shared at the root of the project. Import the Postman collection to Postman. Add the environment variable `url` that point to your project in `environment` section inside Postman.
  That's it your postman collection is ready to be used to interact with Beeleex. The body is setup only needs the values to be filled.
  """
  use BeeleexWeb, :controller
  require Logger
  alias Beeleex.Helpers

  @doc """
  Verifies a user token

  #### Request Format:

  In the body we expect the following format:

  ```json
    {
      "token": "the token",
      "fields": {
        "field_1": "value_1",
        "field_2": "value_2"
      }
    }
  ```

  - Status 400:
  ```json
  {"error": "Invalid token"}
  ```

  - Status 200:
   {"user_id": "the user id,
    "fields": {
      "field_1": "value_1",
      "field_2": "value_2"
    }
  }
  ```
  """

  def verify_token(conn, %{"token" => _token, "fields" => fields} = payload) do
    action = Helpers.env(:verify_token_action, %{raise: true})

    case apply(action[:module], action[:function], [payload]) do
      {:ok, %{user_id: _user_id, fields: returned_fields} = res} ->
        # `fields` from the request may arrive as a list of names
        # (`["name", "email"]`) or as a map keyed by name
        # (`%{"name" => _, ...}`). Normalize to the set of requested names and
        # compare against the returned keys as strings so the presence check
        # holds regardless of either side's shape or key type.
        requested = request_field_names(fields)
        returned = MapSet.new(returned_fields, fn {k, _v} -> to_string(k) end)

        if Enum.all?(requested, &MapSet.member?(returned, &1)) do
          render(conn, "user_verified.json", res: res)
        else
          missing = Enum.reject(requested, &MapSet.member?(returned, &1))
          Logger.error("missing requested field(s): #{inspect(missing)}")
          render(conn |> put_status(500), "error.json", error: "missing requested field(s)")
        end
      _ ->
        render(conn |> put_status(400), "error.json", error: "Invalid token")
    end
  end

  # The requested `fields` may be a list of names or a map keyed by name; return
  # the requested names as strings either way.
  defp request_field_names(fields) when is_list(fields), do: Enum.map(fields, &to_string/1)
  defp request_field_names(fields) when is_map(fields), do: Enum.map(Map.keys(fields), &to_string/1)
  defp request_field_names(_), do: []
end
