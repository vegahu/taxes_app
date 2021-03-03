defmodule TaxesApp do
  @moduledoc """
  Documentation for `TaxesApp`.
  """

NimbleCSV.define(MyParser, separator: ",", escape: "\n")

alias NimbleCSV.RFC4180, as: CSV

@doc """
Convierte al fecha del fichero de nexo a ISO8610
  Formato nexo.io: YYYY-MM-DD HH:MM:SS
  Salida: YYYY-MM-DDTHH:MM:SSZ
  Ej:
    >CoinPaprika.parse_date("2020-02-14 09:32:23")
    "2020-02-14T09:32:23Z"


"""
  def parse_date (date_time) do
    [date, time]=String.Break.split(date_time)
    date <> "T" <> time <> "Z"
  end

  @doc """
  Formatea el csv de transacciones descargado de nexo.io y lo mete en un mapa.

  ## Examples

    iex> TaxesApp.nexo_trans(nexo_transactions.csv)
      %{
    comment: "approved / 0.00003531 ETH",
    currency_b: "NEXONEXO",
    date: "2021-02-14 01:00:02",
    loan: "$0.00",
    tx: "NXTGOXGlZ6uKm",
    type: "Interest",
    value_b: "0.03807562"
    },
    %{
     comment: "approved / 0.11847263 EURx",
     currency_b: "NEXONEXO",
     date: "2021-02-14 01:00:02",
     loan: "$0.00",
     tx: "NXTJqkpkTntLM",
     type: "Interest",
     value_b: "0.08522719"
    },.......

  """
def nexo_trans(transacciones) do
  File.read!(transacciones)
  |> CSV.parse_string
  |> Enum.map(fn [tx, type, currency_b, value_b, comment, loan, date] ->
    %{tx: :binary.copy(tx), type: :binary.copy(type), currency_b: :binary.copy(currency_b), value_b: :binary.copy(value_b), comment: :binary.copy(comment), loan: :binary.copy(loan), date: :binary.copy(parse_date(date))}
    end)
    # En este punto las trasacciones están en una lista de mapas

end




end

