defmodule Vaultex.Client do
  @moduledoc """
  Provides a functionality to authenticate and read from a vault endpoint.
  """

  use GenServer
  alias Vaultex.Auth, as: Auth
  alias Vaultex.Read, as: Read
  alias Vaultex.Write, as: Write
  @version "v1"

  def start_link() do
    GenServer.start_link(__MODULE__, %{progress: "starting"}, name: :vaultex)
  end

  def init(state) do
    {:ok, Map.merge(state, %{url: url()})}
  end

  @doc """
  Authenticates with vault using a tuple. This can be executed before attempting to read secrets from vault.

  ## Parameters

    - method: Auth backend to use for authenticating, can be one of `:app_id, :userpass, :github`
    - credentials: A tuple used for authentication depending on the method, `{app_id, user_id}` for `:app_id`, `{username, password}` for `:userpass`, `{github_token}` for `:github`

  ## Examples

    ```
    iex> Vaultex.Client.auth(:app_id, {app_id, user_id})
    {:ok, :authenticated}

    iex> Vaultex.Client.auth(:userpass, {username, password})
    {:error, ["Something didn't work"]}

    iex> Vaultex.Client.auth(:github, {github_token})
    {:ok, :authenticated}

    iex> Vaultex.Client.auth(:vault_token, {})
    {:ok, :authenticated}

    ```
  """
  def auth(:vault_token, {}) do
    auth(:vault_token, {vault_token()})
  end

  def auth(method, credentials) do
    GenServer.call(:vaultex, {:auth, method, credentials})
  end

  @doc """
  Reads a secret from vault given a path.

  ## Parameters

    - key: A String path to be used for querying vault.
    - auth_method and credentials: See Vaultex.Client.auth

  ## Examples

    ```
    iex> Vaultex.Client.read "secret/foo", :app_id, {app_id, user_id}
    {:ok, %{"value" => "bar"}}

    iex> Vaultex.Client.read "secret/baz", :userpass, {username, password}
    {:error, ["Key not found"]}

    iex> Vaultex.Client.read "secret/bar", :github, {github_token}
    {:ok, %{"value" => "bar"}}
    ```

  """
  def read(key, :vault_token, credentials) do
    token = case credentials do
              {}   -> vault_token()
              {vt} -> vt
            end
    state = %{url: url(), token: token}
    {:reply, res, _} = Read.handle(key, state)
    res
  end
  def read(key, auth_method, credentials) do
    response = read(key)
    case response do
      {:ok, _} -> response
      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
          do: read(key)
    end
  end

  def list(key, :vault_token, credentials) do
    token = case credentials do
              {}   -> vault_token()
              {vt} -> vt
            end
    state = %{url: url(), token: token}
    {:reply, res, _} = Read.handle(key <> "?list=true", state)
    res
  end
  def list(key, auth_method, credentials) do
    read(key <> "?list=true", auth_method, credentials)
  end

  def write(key, value, :vault_token, credentials) do
    token = case credentials do
              {}   -> vault_token()
              {vt} -> vt
            end
    state = %{url: url(), token: token}
    {:reply, res, _} = Write.handle(key, value, state)
    res
  end
  def write(key, value, auth_method, credentials) do
    response = write(key, value)
    case response do
      {:ok, _} -> response
      {:error, _} ->
        with {:ok, _} <- auth(auth_method, credentials),
          do: write(key, value)
    end
  end

  defp read(key) do
    GenServer.call(:vaultex, {:read, key})
  end

  defp write(key, value) do
    GenServer.call(:vaultex, {:write, key, value})
  end

  def handle_call({:read, key}, _from, state) do
    Read.handle(key, state)
  end

  def handle_call({:write, key, value}, _from, state) do
    Write.handle(key, value, state)
  end

  def handle_call({:auth, method, credentials}, _from, state) do
    Auth.handle(method, credentials, state)
  end

  defp url do
    "#{scheme()}://#{host()}:#{port()}/#{@version}/"
  end

  defp host do
    parsed_vault_addr().host || get_env(:host)
  end

  defp port do
    parsed_vault_addr().port || get_env(:port)
  end

  defp scheme do
    parsed_vault_addr().scheme || get_env(:scheme)
  end

  defp vault_token do
    get_env(:vault_token)
  end

  defp parsed_vault_addr do
    get_env(:vault_addr) |> to_string |> URI.parse
  end

  defp get_env(:host) do
    System.get_env("VAULT_HOST") || Application.get_env(:vaultex, :host) || "localhost"
  end

  defp get_env(:port) do
      System.get_env("VAULT_PORT") || Application.get_env(:vaultex, :port) || 8200
  end

  defp get_env(:scheme) do
      System.get_env("VAULT_SCHEME") || Application.get_env(:vaultex, :scheme) || "http"
  end

  defp get_env(:vault_addr) do
    System.get_env("VAULT_ADDR") || Application.get_env(:vaultex, :vault_addr)
  end

  defp get_env(:vault_token) do
    System.get_env("VAULT_TOKEN") || Application.get_env(:vaultex, :vault_token)
  end
end
