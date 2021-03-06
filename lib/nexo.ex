defmodule Nexo do
@moduledoc """
Tratamiento de las transacciones extraidas de nexo.io
"""
  NimbleCSV.define(NexoParser, separator: ",", escape: "\n")

  alias NimbleCSV.RFC4180, as: CSV

  @doc """
  Convierte al fecha del fichero de nexo a ISO8610
    Formato nexo.io: YYYY-MM-DD HH:MM:SS
    Salida: YYYY-MM-DDTHH:MM:SSZ
    Ej:
      >CoinPaprika.parse_date("2020-02-14 09:32:23")
      "2020-02-14T09:32:23Z"


  """
  def parse_date(date_time) do
    [date, time] = String.Break.split(date_time)
    date <> "T" <> time <> "Z"
  end

  def parse_type(type) do
    case type do
      "Interest" -> {:in, type }
      "Deposit"  -> {:in, type }
      "Withdrawal" -> {:out, type}
      "DepositToExchange" -> {:in, "Deposit"}
      "ExchangeDepositedOn" -> {:in, "Deposit"}
      "ExchangeSell" -> {:in, "Trade"}
    end
  end


  def parse_trade(oper, type, value_b) do
    case oper do
      :buy when (elem(type,0)== :in) and (value_b > 0) -> value_b
      :sell when (elem(type, 0) == :out) -> String.trim(value_b, "-")
      _ -> ""
    end
  end

  def parse_currency(:buy,{:in, _},"NEXONEXO"), do: "NEXO"
  def parse_currency(:sell,{:out, _},"NEXONEXO"), do: "NEXO"
  def parse_currency(:buy,{:in, _},"EURX"), do: "EUR"
  def parse_currency(:sell,{:out, _},"EURX"), do: "EUR"
  def parse_currency(:buy,{:in, _},"BNBN"), do: "EUR"
  def parse_currency(:sell,{:out, _},"BNBN"), do: "EUR"
  def parse_currency(:buy, {:in, _}, currency), do: currency
  def parse_currency(:sell, {:out, _}, currency), do: currency
  def parse_currency(_, _, _), do: ""



  @doc """
  Recibe un lista [NX32DSAFSE, "Deposit", NEXONEXO, 0.2342355, "Comentario", "0", "2021-02-12T12:23Z"]
  """
  def parse_transac([tx, type, currency_b, value_b, comment, _loan, date]) do
    type = parse_type(type)
    %{}
    |> Map.put(:type, type)
    |> Map.put(:buy, parse_trade(:buy, type, value_b))
    |> Map.put(:buy_currency, parse_currency(:buy, type, currency_b))
    |> Map.put(:sell, parse_trade(:sell, type, value_b))
    |> Map.put(:sell_currency, parse_currency(:sell, type, currency_b))
    |> Map.put(:fees, "")
    |> Map.put(:service, "Nexo.io")
    |> Map.put(:fees_currency, "")
    |> Map.put(:commment, tx <> ": " <> comment)
    |> Map.put(:date, parse_date(date))
    #loan: loan,

  end

  @doc """
    Funciones auxiliares para Enum.chunk_while(enumerable, acc, chunk_fun, after_fun)
    que agrupa las entradas de intereses en NEXO de un mismo día sumando los valores
    correspondientes.

    En nexo.io, si se tiene más de una moneda en depósito y se elige obtener los intereses en NEXO
    se genera una entrada de intereses por cada moneda. Esta función las agrupa todas en
    una para reducir la cantidad de transacciones, pensando sobre todo en el caso de
    usarlo en páginas donde el número de transacciones gratuitas es limitado.

  """
  def interest_in_NEXO?(transac) do
    (elem(transac[:type], 1) == "Interest") and (transac[:buy_currency] == "NEXO")
  end

  def chunk_fun transac, acc do
    if (acc != []) do     # Si no es la primera transacción
      transac = parse_transac(transac)
      if interest_in_NEXO?(transac) and (transac[:date] == acc[:date]) do
        acc = Map.put( acc, :buy ,to_string(String.to_float(acc[:buy]) + String.to_float(transac[:buy])))
        {:cont, acc}
      else
        {:cont, acc , transac}
      end
    else
      {:cont, parse_transac(transac)}  # Primera iteración con acc = [], se inicializa acc con la primera transacción
    end
  end

  def after_fun acc do
    {:cont, acc, []}    # Se añade la última transacción
  end

  @doc """
  Formatea el csv de transacciones descargado de nexo.io y lo mete en un mapa.
  Agrupa los intereses diarios cobrados en NEXO de varias monedas en una sola entrada.

  ## Ejemplos

    iex> TaxesApp.nexo_trans(nexo_transactions.csv)
    [
  %{
    comentario: "approved / 0.0000263 ETH",
    moneda_c: "NEXONEXO",
    fecha: "2021-02-28T01:00:02Z",
    loan: "$0.00",
    tx: "NXT7B0uhAp897",
    tipo: "Interest",
    value_b: "0.03016009"
  },
  %{
    comentario: "approved / 0.0000263 ETH",
    moneda_c: "NEXONEXO",
    fecha: "2021-02-27T01:00:02Z",
    loan: "$0.00",
    tx: "NXT2gz6NetHg1",
    tipo: "Interest",
    value_b: "0.03024641"
  },.......
  ]

  """



  def parse_nexo_csv(transacciones) do
    File.read!(transacciones)
    |> CSV.parse_string()
    # Enum recibe lista de listas [NX32DSAFSE, "Deposit", NEXONEXO, 0.2342355, "Comentario", "0", "2021-02-12T12:23Z"]
    |> Enum.chunk_while([], &Nexo.chunk_fun/2, &Nexo.after_fun/1)
  end
end
