defmodule CoinPaprika do
@moduledoc """
Conjunto de funciones como interfaz con la API de CoinPaprika.com para obtener precios históricos

"""
use Tesla

plug Tesla.Middleware.BaseUrl, "https://api.coinpaprika.com/v1"
plug Tesla.Middleware.JSON, engine_opts: [keys: :atoms]

@doc """
Obtiene el token_id que utiliza CoinPaprika a partir del simbolo del token.

El símbolo del token ha de estar en mayúsculas

body es una lista de datos relativos a los tokens con este formato
[%{id: _,is_active: _,is_new: _, name: _, rank: _, symbol: _, type: _},...]
"""

def get_token_id (token) do
  {:ok, %Tesla.Env{:body => body}} = get("/coins")
  token_data = Enum.find(body, fn x -> x[:symbol] == token end)
  token_data[:id]
end

@doc """
Obtiene el precio para un token y fecha determinada
El token ha de seguir la nomenclatura de CoinPaprika. Se obtiene con la función get_token_id/1
Ejemplo de salida del get:
[{"timestamp":"2021-02-14T00:00:00Z","price":1.67,"volume_24h":77673000,"market_cap":937904172}]

La hora está en UTC. Ojo al formato 2021-02-14T00:00:00Z
"""
def get_price(token, date) do
 token_id = CoinPaprika.get_token_id(token)
 {:ok, %Tesla.Env{:body => [body]}} = get("/tickers/#{token_id}/historical?start=#{date}&interval=1h&limit=1")
 body[:price]
end

def parse_date (date_time) do
  [date, time]=String.Break.split(date_time)
  date <> "T" <> time <> "Z"
end

end
