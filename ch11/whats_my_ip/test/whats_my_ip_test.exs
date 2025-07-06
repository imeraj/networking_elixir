defmodule WhatsMyIPTest do
  use ExUnit.Case, async: true
  import Plug.Test

  describe "GET /myip" do
    test "returns the client's IP address" do
      assert {200, _headers, resp_body} =
               conn(:get, "/myip")
               |> Plug.run([{WhatsMyIP.Router, []}])
               |> sent_resp()

      assert :json.decode(resp_body) == %{"ip" => "127.0.0.1"}
    end
  end
end
