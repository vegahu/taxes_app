defmodule Nexo do
@moduledoc """
Tratamiento de las transacciones extraidas de nexo.io
"""
  NimbleCSV.define(NexoParser, separator: ",", escape: "\"")

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
  @doc """
  add a tuple for the field type to differenciate if it's an input or output.
  Used to fill value and currency of the respective input or output transaction
  """
  def parse_type(type) do
    case type do
      "Interest" -> {:in, "Interest Income" }
      "Deposit"  -> {:in, type }
      "Withdrawal" -> {:out, type}
      "DepositToExchange" -> {:in, "Deposit"}
      "ExchangeDepositedOn" -> {:in, "Deposit"}
      "ExchangeSell" -> {:in, "Trade"}
      "WithdrawExchanged" -> {:out, "Withdrawal"}
      "ExchangeToWithdraw" -> {:in, "Trade"}
    end
  end

  @doc """
  The sells are represented in nexo.io file as negative values, so this functions change
  the sign to them.
  """
  def parse_trade(oper, type, value_b) do
    case oper do
      :buy when (elem(type,0)== :in) and (value_b > 0) -> value_b
      :sell when (elem(type, 0) == :out) -> String.trim(value_b, "-")
      _ -> ""
    end
  end

  @doc """
  Nexo.io use internal names for the currencies, this normalize them.
  It's possible that more are needed, here are the ones that I know at the momment.
  """
  def parse_currency(:buy,{:in, _},"NEXONEXO"), do: "NEXO"
  def parse_currency(:sell,{:out, _},"NEXONEXO"), do: "NEXO"
  def parse_currency(:buy,{:in, _},"EURX"), do: "EUR"
  def parse_currency(:sell,{:out, _},"EURX"), do: "EUR"
  def parse_currency(:buy,{:in, _},"BNBN"), do: "EUR"
  def parse_currency(:sell,{:out, _},"BNBN"), do: "EUR"
  def parse_currency(:buy,{:in, _},"NEXOBEP2"), do: "NEXO"
  def parse_currency(:sell,{:out, _},"NEXOBEP2"), do: "NEXO"
  def parse_currency(:buy, {:in, _}, currency), do: currency
  def parse_currency(:sell, {:out, _}, currency), do: currency
  def parse_currency(_, _, _), do: ""



  @doc """
  Receive a list [NX32DSAFSE, "Deposit", NEXONEXO, 0.2342355, "Comentario", "0", "2021-02-12T12:23Z"]
  and creates a new one with the normalized fields (currently CoinTracking format)
  """
  def parse_transac([tx, type, currency_b, value_b, comment, _loan, date]) do
    type = parse_type(type) # Lo convierte en una tupla {:in, type} or {:out, type}
    []
    |> Keyword.put(:type, type)
    |> Keyword.put(:buy, parse_trade(:buy, type, value_b))
    |> Keyword.put(:buy_currency, parse_currency(:buy, type, currency_b))
    |> Keyword.put(:sell, parse_trade(:sell, type, value_b))
    |> Keyword.put(:sell_currency, parse_currency(:sell, type, currency_b))
    |> Keyword.put(:fees, "")
    |> Keyword.put(:fees_currency, "")
    |> Keyword.put(:service, "Nexo.io")
    |> Keyword.put(:Group, "")
    |> Keyword.put(:commment, tx <> ": " <> comment)
    |> Keyword.put(:date, parse_date(date))
    |> Enum.reverse()
    #loan: loan,

  end

  @doc """
  Recibe una transacción ya normalizada y evalua si es de cobro de intereses en NEXO
  """
  def interest_in_NEXO?(transac) do
    (elem(Keyword.get(transac, :type), 1) == "Interest Income") and (Keyword.get(transac, :buy_currency) == "NEXO")
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


  def chunk_fun transac, acc do
    if (acc != []) do     # Si no es la primera transacción
      transac = parse_transac(transac)
      if interest_in_NEXO?(transac) and (Keyword.get(transac, :date) == Keyword.get(acc, :date)) do
        acc = Keyword.replace( acc, :buy ,to_string(String.to_float(Keyword.get(acc, :buy)) + String.to_float(Keyword.get(transac, :buy))))
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
  Formatea el csv de transacciones descargado de nexo.io y lo mete en una Keyword List.
  Agrupa los intereses diarios cobrados en NEXO de varias monedas en una sola entrada.

  ## Ejemplos

    iex> TaxesApp.nexo_trans(nexo_transactions.csv)
   [
  [
    type: {:in, "Interest"},
    buy: "0.03016009",
    buy_currency: "NEXO",
    sell: "",
    sell_currency: "",
    fees: "",
    fees_currency: "",
    service: "Nexo.io",
    commment: "NXT7B0uhAp897: approved / 0.0000263 ETH",
    date: "2021-02-28T01:00:02Z"
  ],
  [
    type: {:in, "Interest"},
    buy: "0.03024641",
    buy_currency: "NEXO",
    sell: "",
    sell_currency: "",
    fees: "",
    fees_currency: "",
    service: "Nexo.io",
    commment: "NXT2gz6NetHg1: approved / 0.0000263 ETH",
    date: "2021-02-27T01:00:02Z"
  ],.......
  ]

  """



  def parse_nexo_csv(transactions) do
    File.read!(transactions)
    |>  CSV.parse_string
    # Enum recibe lista de listas [NX32DSAFSE, "Deposit", NEXONEXO, 0.2342355, "Comentario", "0", "2021-02-12T12:23Z"]
    |>  Enum.chunk_while([], &Nexo.chunk_fun/2, &Nexo.after_fun/1)
  end

  @doc """
  Replace de type from a tuple to a single element removing the atom to create de csv output only with values
  Ej.
    {:in, "Interest"} to "Interest"
  """
  def type_for_csv transaction do
    Keyword.replace(transaction, :type, elem(Keyword.get(transaction, :type), 1))
  end

  @doc """
  Add the header to the final csv (cointracking format)
  """
  def add_header(transactions) do
    [["Type", "Buy", "Buy Currency", "sell", "Sell Currency", "Fees", "Fees currency", "Exchange", "Group", "Comments", "Date"] | transactions]
  end

  @doc """
  Convert the keyword list to a csv and store it in nexo_result.csv
  """
  def to_csv(transactions) do
    data = transactions
    |>  Enum.map(&type_for_csv/1)
    |>  Enum.map(&Keyword.values/1) # Remove de key of pairs key: value, return a list
    |>  add_header
    |>  CSV.dump_to_iodata

    File.write("../nexo_result.csv", data)
  end

end
