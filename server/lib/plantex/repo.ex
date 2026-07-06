defmodule Plantex.Repo do
  use Ecto.Repo,
    otp_app: :plantex,
    adapter: Ecto.Adapters.Postgres
end
