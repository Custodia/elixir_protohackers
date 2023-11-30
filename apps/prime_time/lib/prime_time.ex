defmodule PrimeTime do
  @moduledoc """
  Documentation for `PrimeTime`.
  """

  @doc """
  Given a number checks wether the number is a prime number or not.

  ## Examples

  iex> PrimeTime.is_prime?(1.0)
  false

  iex> PrimeTime.is_prime?(-3)
  false

  iex> PrimeTime.is_prime?(1)
  false

  iex> PrimeTime.is_prime?(2)
  true

  iex> PrimeTime.is_prime?(3)
  true
  """
  def is_prime?(number) when is_float(number), do: false
  def is_prime?(number) when is_integer(number) and number < 2, do: false
  def is_prime?(2), do: true
  def is_prime?(3), do: true
  def is_prime?(number) when is_integer(number) do
    Stream.iterate(2, fn n -> if n == 2, do: 3, else: n + 2 end)
    |> Stream.take_while(fn n -> n * n <= number end)
    |> Enum.all?(fn divider -> rem(number, divider) != 0 end)
  end
end
