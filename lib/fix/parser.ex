defmodule FIX.Parser do
  @moduledoc """
  A recursive binary-matching FIX parser.

  Provides two layers:

  * `frame/1` and `parse_message/2` — message framing for a byte stream:
     validates the BeginString(8)/BodyLength(9) structure and the
     CheckSum(10) trailer, and splits complete messages off the buffer.

  * `parse/2` — tokenizes a complete message of `tag=value<SOH>` fields.
     Length-prefixed data fields (RawData, EncodedText, ...) are sliced
     byte-exactly, so their values may contain the SOH delimiter.

  Which tags are length-prefixed data fields is determined by a
  `FIX.Dictionary`, defaulting to `FIX.Dictionary.FIX44`. Pass a custom
  dictionary to handle counterparty-defined data fields.
  """

  @default_dictionary FIX.Dictionary.FIX44

  @type fields :: FIX.Message.fields()
  @type frame_error :: :garbled | :checksum_mismatch

  @doc """
  Frames and tokenizes one complete FIX message off the front of `buffer`.

  Combines `frame/1` and `parse/1`: returns `{:ok, fields, rest}` for a
  complete, checksum-valid message whose fields all parsed, where `rest` is
  the remainder of the buffer (any pipelined messages after this one).

  Returns `:incomplete` when more bytes are needed, and `{:error, reason}`
  otherwise. A message that frames correctly but contains unparseable fields
  is `{:error, :garbled}`.
  """
  @spec parse_message(binary(), module()) ::
          {:ok, fields(), rest :: binary()} | :incomplete | {:error, frame_error()}
  def parse_message(buffer, dictionary \\ @default_dictionary) do
    with {:ok, message, rest} <- frame(buffer),
         {:ok, fields} <- parse(message, dictionary) do
      {:ok, fields, rest}
    end
  end

  @doc """
  Splits one complete FIX message off the front of `buffer`.

  Validates that the message starts with BeginString(8) followed by
  BodyLength(9), that the full body and trailer are present, and that
  CheckSum(10) matches. The BeginString value itself is not restricted to a
  particular FIX version.

  Returns:

   * `{:ok, message, rest}` — `message` is the complete framed message
      (a sub-binary of `buffer`) and `rest` is whatever follows it.
   * `:incomplete` — `buffer` is a valid prefix of a message; read more bytes.
   * `{:error, :garbled}` — `buffer` cannot be the start of a valid message.
   * `{:error, :checksum_mismatch}` — well-framed, but CheckSum(10) is wrong.

  """
  @spec frame(binary()) ::
          {:ok, message :: binary(), rest :: binary()} | :incomplete | {:error, frame_error()}
  def frame(<<"8=", rest::binary>> = buffer) do
    with {:ok, rest} <- begin_string(rest),
         {:ok, body_len, rest} <- body_length(rest) do
      # BodyLength counts the bytes between the SOH after tag 9 and the "10=".
      payload_len = byte_size(buffer) - byte_size(rest) + body_len
      # payload <> "10=" <> 3 checksum digits <> SOH
      total_len = payload_len + 7

      case buffer do
        <<payload::binary-size(payload_len), "10=", cs::binary-size(3), 0x01, rest::binary>> ->
          verify_checksum(buffer, payload, cs, total_len, rest)

        _ when byte_size(buffer) < total_len ->
          :incomplete

        _ ->
          {:error, :garbled}
      end
    end
  end

  def frame(buffer) when buffer in [<<>>, <<"8">>], do: :incomplete
  def frame(_buffer), do: {:error, :garbled}

  @doc """
  Tokenizes FIX fields from `binary`.

  Returns `{:ok, fields}` when the entire input parses, where tags are
  integers and values are binaries, or `{:error, :garbled}` if any part of the
  input cannot be consumed.

  Data fields are length-prefixed by their companion field (e.g.
  RawDataLength(95) precedes RawData(96)) and are sliced by the declared byte
  count, so their values may contain SOH. A length field not followed by its
  companion data field with exactly the declared number of bytes is garbled.
  The companion pairs are defined by `dictionary` (see `FIX.Dictionary`).
  """
  @spec parse(binary(), module()) :: {:ok, fields()} | {:error, :garbled}
  def parse(binary, dictionary \\ @default_dictionary) do
    case parse(binary, dictionary, []) do
      {fields, ""} -> {:ok, fields}
      {_fields, _rest} -> {:error, :garbled}
    end
  end

  # ----------------------------------------------------------------------------
  # Field tokenizer
  # ----------------------------------------------------------------------------

  defp parse(binary, dict, acc) do
    with {:tag, tag, rest} <- tag(binary, 0, 0),
         {:value, value, rest} <- value(rest, rest, 0) do
      case dict.companion_data_tag(tag) do
        nil ->
          parse(rest, dict, [{tag, value} | acc])

        data_tag ->
          case data_field(rest, data_tag, value) do
            {:data, data, rest} -> parse(rest, dict, [{data_tag, data}, {tag, value} | acc])
            :error -> {:lists.reverse(acc), binary}
          end
      end
    else
      _ -> {:lists.reverse(acc), binary}
    end
  end

  defp tag(<<digit, rest::binary>>, n, count) when digit in ?0..?9,
    do: tag(rest, n * 10 + (digit - ?0), count + 1)

  defp tag(<<?=, rest::binary>>, n, count) when count > 0,
    do: {:tag, n, rest}

  defp tag(_, _, _), do: :error

  defp value(<<0x01, rest::binary>>, start, len),
    do: {:value, binary_part(start, 0, len), rest}

  defp value(<<_, rest::binary>>, start, len),
    do: value(rest, start, len + 1)

  defp value(<<>>, _, _), do: :error

  # ----------------------------------------------------------------------------
  # Data fields
  # ----------------------------------------------------------------------------
  # FIX data-type fields hold arbitrary bytes, so their values may contain
  # the SOH delimiter and cannot be tokenized by scanning for SOH. The
  # protocol requires each one to be immediately preceded by a companion
  # length field declaring the value's exact byte size. The dictionary's
  # `companion_data_tag/1` identifies length fields (see `FIX.Dictionary`);
  # `data_field/3` then slices the companion's value by byte count.

  defp data_field(binary, data_tag, len_value) do
    with {:len, len} <- data_length(len_value),
         {:tag, ^data_tag, rest} <- tag(binary, 0, 0),
         <<data::binary-size(len), 0x01, rest::binary>> <- rest do
      {:data, data, rest}
    else
      _ -> :error
    end
  end

  defp data_length(value) do
    case Integer.parse(value) do
      {len, ""} when len >= 0 -> {:len, len}
      _ -> :error
    end
  end

  # ----------------------------------------------------------------------------
  # Framing
  # ----------------------------------------------------------------------------

  # BeginString's value must not contain SOH. An unterminated value at the end
  # of the buffer just means we need more bytes.
  defp begin_string(rest) do
    case value(rest, rest, 0) do
      {:value, _begin_string, rest} -> {:ok, rest}
      :error -> :incomplete
    end
  end

  defp body_length(<<"9=", rest::binary>>), do: body_length(rest, 0, 0)
  defp body_length(rest) when rest in [<<>>, <<"9">>], do: :incomplete
  defp body_length(_), do: {:error, :garbled}

  defp body_length(<<digit, rest::binary>>, n, count) when digit in ?0..?9,
    do: body_length(rest, n * 10 + (digit - ?0), count + 1)

  defp body_length(<<0x01, rest::binary>>, n, count) when count > 0,
    do: {:ok, n, rest}

  defp body_length(<<>>, _, _), do: :incomplete
  defp body_length(_, _, _), do: {:error, :garbled}

  defp verify_checksum(buffer, payload, cs, total_len, rest) do
    case checksum_digits(cs) do
      {:ok, expected} ->
        if checksum(payload, 0) == expected do
          {:ok, binary_part(buffer, 0, total_len), rest}
        else
          {:error, :checksum_mismatch}
        end

      :error ->
        {:error, :garbled}
    end
  end

  defp checksum_digits(<<a, b, c>>) when a in ?0..?9 and b in ?0..?9 and c in ?0..?9,
    do: {:ok, (a - ?0) * 100 + (b - ?0) * 10 + (c - ?0)}

  defp checksum_digits(_), do: :error

  defp checksum(<<byte, rest::binary>>, acc), do: checksum(rest, acc + byte)
  defp checksum(<<>>, acc), do: rem(acc, 256)
end
