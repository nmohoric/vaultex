defmodule Vaultex.Write do
  def handle(key, value, state = %{token: token}) do
    request(:post, "#{state.url}#{key}", %{value: value}, [{"X-Vault-Token", token}])
    |> handle_response(state)
  end

  def handle(_key, _value, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end


  defp handle_response({:ok, _response}, state) do
    {:reply, {:ok, "Key saved"}, state}
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  defp request(method, url, params = %{}, headers) do
    Vaultex.RedirectableRequests.request(method, url, params, headers)
  end
end
