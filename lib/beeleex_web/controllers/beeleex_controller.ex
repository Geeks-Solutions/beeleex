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
  action_fallback(BeeleexWeb.FallbackController)

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
        if Enum.all?(fields, &(Map.has_key?(returned_fields, &1))) do
          render(conn, "user_verified.json", res: res)
        else
          Logger.error("missing requested field(s): returned_fields are #{returned_fields}")
          render(conn |> put_status(500), "error.json", error: "missing requested field(s)")
        end
      _ ->
        render(conn |> put_status(400), "error.json", error: "Invalid token")
    end
  end
end
