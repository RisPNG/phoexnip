defmodule PhoexnipWeb.ConnCase do

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PhoexnipWeb.Endpoint

      use PhoexnipWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import PhoexnipWeb.ConnCase
    end
  end

  setup tags do
    Phoexnip.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def register_and_log_in_user(%{conn: conn}) do
    user = Phoexnip.UsersFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  def log_in_user(conn, user) do
    token = Phoexnip.Users.UserService.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
