defmodule FIX.Message do
  @moduledoc """
  A FIX message with promoted, canonical header fields.

  The header fields that every consumer touches are struct fields and are
  the source of truth:

   * `:begin_string` — BeginString(8), the protocol version
   * `:msg_type` — MsgType(35), the message discriminator
   * `:seq_num` — MsgSeqNum(34), as an integer
   * `:sender_comp_id` — SenderCompID(49)
   * `:target_comp_id` — TargetCompID(56)
   * `:sending_time` — SendingTime(52), as a UTCTimestamp binary
   * `:poss_dup_flag` — PossDupFlag(43), as a boolean
   * `:orig_sending_time` — OrigSendingTime(122), as a UTCTimestamp binary

  These are the fields the session layer reads or writes itself: it stamps
  SendingTime on every send, and rewrites PossDupFlag/OrigSendingTime when
  resending. Timestamps stay binaries because their precision varies and
  round-trip fidelity matters.

  The remaining fields keep the message's wire structure: `:header` holds
  the unpromoted header fields (sub and location IDs, OnBehalfOf/DeliverTo
  routing, ...) and `:body` holds the message body, each in wire order.
  `to_fix/1` encodes the promoted fields first, then `:header`, then
  `:body`. The derived fields BodyLength(9) and CheckSum(10) are never
  stored; `to_fix/1` computes them when encoding.

  `:raw` preserves the original wire bytes of a parsed message. FIX requires
  resending original messages on ResendRequest, and message stores and audit
  logs want exact bytes — re-encoding from fields cannot guarantee byte
  equality. It is `nil` for locally built messages.

  ## Example

      iex> message = %FIX.Message{
      ...>   begin_string: "FIX.4.4",
      ...>   msg_type: "0",
      ...>   seq_num: 3,
      ...>   sender_comp_id: "SENDER",
      ...>   target_comp_id: "TARGET",
      ...>   body: [{112, "TEST"}]
      ...> }
      iex> raw = FIX.Message.to_fix(message)
      iex> {:ok, parsed, ""} = FIX.Message.parse(raw)
      iex> {parsed.msg_type, parsed.seq_num, parsed.body}
      {"0", 3, [{112, "TEST"}]}
      iex> parsed.raw == raw
      true

  """

  @default_dictionary FIX.Dictionary.FIX44
  @soh <<0x01>>

  @type tag :: pos_integer()
  @type fields :: [{tag(), binary()}]

  @type t :: %__MODULE__{
          begin_string: binary() | nil,
          msg_type: binary() | nil,
          seq_num: pos_integer() | nil,
          sender_comp_id: binary() | nil,
          target_comp_id: binary() | nil,
          sending_time: binary() | nil,
          poss_dup_flag: boolean() | nil,
          orig_sending_time: binary() | nil,
          header: fields(),
          body: fields(),
          raw: binary() | nil
        }

  defstruct(
    begin_string: nil,
    msg_type: nil,
    seq_num: nil,
    sender_comp_id: nil,
    target_comp_id: nil,
    sending_time: nil,
    poss_dup_flag: nil,
    orig_sending_time: nil,
    header: [],
    body: [],
    raw: nil
  )

  @doc """
  Parses one complete FIX message off the front of `binary`.

  Frames and tokenizes via `FIX.Parser.parse_message/2`, then promotes the
  canonical header fields onto the struct. Promotion is positional: the
  parser splits the message into header, body, and trailer sections, and
  only fields in the header section are promoted — a header tag appearing
  after the body has started stays in `:body`. Unpromoted header fields
  land in `:header`. BodyLength(9) and the trailer (CheckSum(10)) are
  validated by the parser and then discarded. The consumed wire bytes are
  kept in `:raw`.

  Returns `{:ok, message, rest}` where `rest` is the remainder of the
  buffer, `:incomplete` when more bytes are needed, or `{:error, reason}`.
  A message whose MsgSeqNum(34) is not a positive integer, or whose
  PossDupFlag(43) is not `Y` or `N`, is `{:error, :garbled}`.
  """
  @spec parse(binary(), module()) ::
          {:ok, t(), rest :: binary()} | :incomplete | {:error, FIX.Parser.frame_error()}
  def parse(binary, dictionary \\ @default_dictionary) do
    with {:ok, sections, rest} <- FIX.Parser.parse_message(binary, dictionary),
         raw = binary_part(binary, 0, byte_size(binary) - byte_size(rest)),
         {:ok, message} <- build(sections, raw) do
      {:ok, message, rest}
    end
  end

  @doc """
  Encodes `message` as a FIX wire string.

  Assembles the header from the promoted struct fields — in the order
  BeginString(8), BodyLength(9), MsgType(35), SenderCompID(49),
  TargetCompID(56), MsgSeqNum(34), PossDupFlag(43), SendingTime(52),
  OrigSendingTime(122) — followed by `:header` and `:body` verbatim, and
  computes BodyLength(9) and CheckSum(10).

  `:begin_string` and `:msg_type` are required; `nil` promoted header
  fields are omitted. `:raw` is ignored — encoding always reflects the
  struct's current data.

  ## Example

      iex> message = %FIX.Message{
      ...>   begin_string: "FIX.4.4",
      ...>   msg_type: "0",
      ...>   seq_num: 3,
      ...>   sender_comp_id: "SENDER",
      ...>   target_comp_id: "TARGET",
      ...>   sending_time: "20260727-12:30:00",
      ...>   body: [{112, "TEST"}]
      ...> }
      iex> message |> FIX.Message.to_fix() |> String.replace(<<0x01>>, "|")
      "8=FIX.4.4|9=60|35=0|49=SENDER|56=TARGET|34=3|52=20260727-12:30:00|112=TEST|10=160|"

  """
  @spec to_fix(t()) :: binary()
  def to_fix(%__MODULE__{begin_string: begin_string, msg_type: msg_type} = message)
      when is_binary(begin_string) and is_binary(msg_type) do
    body =
      encode_fields([{35, msg_type} | header_fields(message)] ++ message.header ++ message.body)

    payload =
      "8=" <> begin_string <> @soh <> "9=" <> Integer.to_string(byte_size(body)) <> @soh <> body

    payload <> "10=" <> checksum(payload) <> @soh
  end

  def to_fix(%__MODULE__{} = message) do
    raise ArgumentError,
          "cannot encode a FIX.Message without :begin_string and :msg_type, got: " <>
            inspect(message)
  end

  @doc """
  Renders `message` as a human-readable string, for logs and debugging.

  Encodes via `to_fix/1`, then replaces the SOH field delimiters with `|`,
  the conventional display form for FIX messages. The result is not valid
  wire data — use `to_fix/1` for that — and is not reversible when a field
  value itself contains a `|`.

  This function backs the `String.Chars` implementation, so interpolating
  a message (`"got: \#{message}"`) produces the same display form.

  Unlike `to_fix/1`, never raises: a message missing `:begin_string` or
  `:msg_type` renders whatever fields are present, without the derived
  BodyLength(9) and CheckSum(10).

  ## Examples

      iex> message = %FIX.Message{
      ...>   begin_string: "FIX.4.4",
      ...>   msg_type: "0",
      ...>   seq_num: 3,
      ...>   sender_comp_id: "SENDER",
      ...>   target_comp_id: "TARGET",
      ...>   body: [{112, "TEST"}]
      ...> }
      iex> FIX.Message.to_string(message)
      "8=FIX.4.4|9=39|35=0|49=SENDER|56=TARGET|34=3|112=TEST|10=160|"

      iex> FIX.Message.to_string(%FIX.Message{msg_type: "0", seq_num: 1})
      "35=0|34=1|"

  """
  @spec to_string(t()) :: binary()
  def to_string(%__MODULE__{begin_string: begin_string, msg_type: msg_type} = message)
      when is_binary(begin_string) and is_binary(msg_type) do
    message |> to_fix() |> String.replace(@soh, "|")
  end

  def to_string(%__MODULE__{} = message) do
    fields =
      for {tag, value} <-
            [{8, message.begin_string}, {35, message.msg_type} | header_fields(message)] ++
              message.header ++ message.body,
          value != nil,
          do: {tag, value}

    fields |> encode_fields() |> String.replace(@soh, "|")
  end

  # ----------------------------------------------------------------------------
  # Parsing
  # ----------------------------------------------------------------------------

  # Promoted fields are taken from the header section only; the leftovers
  # (sub and location IDs, routing, ...) stay in :header. The trailer is
  # already validated by the parser and carries no data worth keeping, so
  # it is dropped.
  defp build({[{8, begin_string}, {9, _body_length} | header], body, _trailer}, raw) do
    {msg_type, header} = pop_field(header, 35)
    {seq_num, header} = pop_field(header, 34)
    {sender_comp_id, header} = pop_field(header, 49)
    {target_comp_id, header} = pop_field(header, 56)
    {sending_time, header} = pop_field(header, 52)
    {poss_dup_flag, header} = pop_field(header, 43)
    {orig_sending_time, header} = pop_field(header, 122)

    with {:ok, seq_num} <- parse_seq_num(seq_num),
         {:ok, poss_dup_flag} <- parse_boolean(poss_dup_flag) do
      {:ok,
       %__MODULE__{
         begin_string: begin_string,
         msg_type: msg_type,
         seq_num: seq_num,
         sender_comp_id: sender_comp_id,
         target_comp_id: target_comp_id,
         sending_time: sending_time,
         poss_dup_flag: poss_dup_flag,
         orig_sending_time: orig_sending_time,
         header: header,
         body: body,
         raw: raw
       }}
    end
  end

  # A dictionary that doesn't classify BeginString/BodyLength as header
  # tags (e.g. one built without extending a standard dictionary) can't
  # support header promotion.
  defp build(_sections, _raw), do: {:error, :garbled}

  # Promoted fields must be removed, not just read: whatever remains in the
  # header list is re-encoded verbatim by to_fix/1.
  defp pop_field(fields, tag) do
    case List.keytake(fields, tag, 0) do
      {{^tag, value}, rest} -> {value, rest}
      nil -> {nil, fields}
    end
  end

  defp parse_seq_num(nil), do: {:ok, nil}

  defp parse_seq_num(value) do
    case Integer.parse(value) do
      {seq_num, ""} when seq_num > 0 -> {:ok, seq_num}
      _ -> {:error, :garbled}
    end
  end

  defp parse_boolean(nil), do: {:ok, nil}
  defp parse_boolean("Y"), do: {:ok, true}
  defp parse_boolean("N"), do: {:ok, false}
  defp parse_boolean(_), do: {:error, :garbled}

  # ----------------------------------------------------------------------------
  # Encoding
  # ----------------------------------------------------------------------------

  defp header_fields(%__MODULE__{} = message) do
    for {tag, value} <- [
          {49, message.sender_comp_id},
          {56, message.target_comp_id},
          {34, message.seq_num && Integer.to_string(message.seq_num)},
          {43, encode_boolean(message.poss_dup_flag)},
          {52, message.sending_time},
          {122, message.orig_sending_time}
        ],
        value != nil,
        do: {tag, value}
  end

  defp encode_boolean(nil), do: nil
  defp encode_boolean(true), do: "Y"
  defp encode_boolean(false), do: "N"

  defp encode_fields(fields) do
    Enum.map_join(fields, fn {tag, value} ->
      Integer.to_string(tag) <> "=" <> value <> @soh
    end)
  end

  defp checksum(payload) do
    payload
    |> :binary.bin_to_list()
    |> Enum.sum()
    |> rem(256)
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end

  defimpl String.Chars do
    def to_string(message) do
      FIX.Message.to_string(message)
    end
  end
end
