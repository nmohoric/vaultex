defmodule Vaultex.Auth do
  def handle(:app_id, {app_id, user_id}, state) do
    request(:post, "#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:userpass, {username, password}, state) do
    request(:post, "#{state.url}auth/userpass/login/#{username}", %{password: password}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:github, {token}, state) do
    request(:post, "#{state.url}auth/github/login", %{token: token}, [{"Content-Type", "application/json"}])
    |> handle_response(state)
  end

  def handle(:vault_token, {token}, state) do
    {:reply, {:ok, :authenticated}, Map.merge(state, %{token: token})}
  end

  defp handle_response({:ok, response}, state) do
    case response.body |> Poison.Parser.parse! do
      %{"errors" => messages} -> {:reply, {:error, messages}, state}
      %{"auth" => properties} -> {:reply, {:ok, :authenticated}, Map.merge(state, %{token: properties["client_token"]})}
    end
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  defp request(method, url, params = %{}, headers) do
    Vaultex.RedirectableRequests.request(method, url, params, headers)
  end

end
