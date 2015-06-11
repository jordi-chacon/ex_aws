defmodule ExAws.SNS.Request do
  @moduledoc false
  # SNS specific request logic.

  def request(client, action, params) do
    {_, http_method} = ExAws.SNS.Impl |> ExAws.Actions.get(action)

    query = params
    |> Map.put("Action", Mix.Utils.camelize(Atom.to_string(action)))
    |> URI.encode_query

    headers = [
      {"x-amz-content-sha256", AWSAuth.Utils.hash_sha256("")}
    ]

    ExAws.Request.request(http_method, client.config |> url(query), "", headers, client)
  end

  defp url(%{scheme: scheme, host: host}, query) do
    [scheme, host, "/?", query]
    |> IO.iodata_to_binary
  end
end
