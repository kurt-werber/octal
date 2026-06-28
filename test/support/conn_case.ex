defmodule OctalWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use OctalWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import OctalWeb.ConnCase

      @endpoint OctalWeb.Endpoint
    end
  end

  setup tags do
    Octal.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
