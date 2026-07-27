# FIX.Message

`FIX.Message` is an Elixir library for framing, parsing, inspecting, and encoding Financial Information eXchange (FIX) messages.

It provides:

- stream-safe framing using `BodyLength(9)`
- `CheckSum(10)` validation and generation
- ordered header, body, and trailer parsing
- byte-exact parsing of length-prefixed data fields, including values containing SOH
- a message struct with commonly used session fields promoted to named attributes
- preservation of the original wire bytes for message stores, audit logs, and resends
- built-in FIX 4.4 and FIX 5.0 SP2 dictionaries
- extensible dictionaries for counterparty-specific fields

## Installation

Add `fix_message` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fix_message, "~> 0.1.0"}
  ]
end
```

## Message API

`FIX.Message` is the primary high-level API. It promotes canonical session fields onto a struct while preserving all other fields as ordered `{tag, value}` tuples.

### Build and encode a message

```elixir
message = %FIX.Message{
  begin_string: "FIX.4.4",
  msg_type: "D",
  seq_num: 42,
  sender_comp_id: "SENDER",
  target_comp_id: "TARGET",
  sending_time: "20260727-12:30:00.000",
  header: [{115, "ON_BEHALF_OF"}],
  body: [
    {11, "ORDER-1"},
    {54, "1"},
    {38, "100"},
    {55, "AAPL"},
    {40, "1"}
  ]
}

wire_message = FIX.Message.to_fix(message)
```

`to_fix/1` computes `BodyLength(9)` and `CheckSum(10)`. `begin_string` and `msg_type` are required; optional promoted fields with `nil` values are omitted.

`FIX.Message` implements `String.Chars`, so `to_string(message)` produces the same wire representation.

### Parse a message

```elixir
case FIX.Message.parse(buffer) do
  {:ok, message, rest} ->
    IO.inspect(message.msg_type)
    IO.inspect(message.seq_num)
    IO.inspect(message.body)

    # Continue parsing any pipelined data in `rest`.

  :incomplete ->
    # Read more bytes and append them to the buffer.

  {:error, :checksum_mismatch} ->
    # The frame was complete, but CheckSum(10) was invalid.

  {:error, :garbled} ->
    # The buffer was not a valid FIX message.
end
```

A parsed message contains:

| Field               | FIX tag | Representation                         |
| ------------------- | ------: | -------------------------------------- |
| `begin_string`      |       8 | binary                                 |
| `msg_type`          |      35 | binary                                 |
| `seq_num`           |      34 | positive integer                       |
| `sender_comp_id`    |      49 | binary                                 |
| `target_comp_id`    |      56 | binary                                 |
| `sending_time`      |      52 | binary                                 |
| `poss_dup_flag`     |      43 | boolean                                |
| `orig_sending_time` |     122 | binary                                 |
| `header`            |       — | unpromoted header fields in wire order |
| `body`              |       — | body fields in wire order              |
| `raw`               |       — | exact bytes consumed from the input    |

`BodyLength(9)` and `CheckSum(10)` are validated but are not stored. Encoding always uses the current struct data and ignores `raw`.

Values remain binaries unless explicitly promoted to another type. This preserves formatting and precision, particularly for timestamps and numeric FIX values.

## Parsing byte streams

Both `FIX.Message.parse/1` and `FIX.Parser.parse_message/1` consume exactly one message from the front of a buffer and return the remaining bytes. This makes them suitable for TCP streams and pipelined messages:

```elixir
def parse_available(buffer, messages \\ []) do
  case FIX.Message.parse(buffer) do
    {:ok, message, rest} -> parse_available(rest, [message | messages])
    :incomplete -> {:ok, Enum.reverse(messages), buffer}
    {:error, reason} -> {:error, reason}
  end
end
```

The original bytes consumed for each high-level message are retained in `message.raw`.

## Low-level parser

Use `FIX.Parser` when you need framing or tokenized sections without constructing a `FIX.Message`.

### Frame one message

```elixir
FIX.Parser.frame(buffer)
# => {:ok, complete_wire_message, rest}
# => :incomplete
# => {:error, :garbled | :checksum_mismatch}
```

### Frame and tokenize

```elixir
FIX.Parser.parse_message(buffer)
# => {:ok, {header, body, trailer}, rest}
```

Each section is an ordered list of `{integer_tag, binary_value}` tuples. Section classification is positional: after the first body field, later header tags remain in the body; after the trailer begins, all remaining fields stay in the trailer.

### Tokenize fields only

```elixir
soh = <<1>>

FIX.Parser.parse("35=D" <> soh <> "11=ORDER-1" <> soh)
# => {:ok, {[{35, "D"}], [{11, "ORDER-1"}], []}}
```

`parse/2` tokenizes fields but does not validate `BodyLength(9)` or `CheckSum(10)`. Use `parse_message/2`, `frame/1`, or `FIX.Message.parse/2` when validating a complete wire message.

## Dictionaries

The parser uses dictionaries to identify:

- standard header and trailer tags
- companion length/data field pairs whose data may contain SOH

The default dictionary is `FIX.Dictionary.FIX44`. FIX 5.0 SP2 and FIXT 1.1 session fields are available through `FIX.Dictionary.FIX50SP2`:

```elixir
FIX.Message.parse(buffer, FIX.Dictionary.FIX50SP2)
FIX.Parser.parse_message(buffer, FIX.Dictionary.FIX50SP2)
FIX.Parser.parse(fields, FIX.Dictionary.FIX50SP2)
```

### Custom dictionaries

Extend a standard dictionary for bilateral or counterparty-defined fields:

```elixir
defmodule MyBroker.Dictionary do
  use FIX.Dictionary, extends: FIX.Dictionary.FIX44

  data_field 5001, 5002
  header_field 5003
  trailer_field 5004
end
```

Then pass the module to the parser:

```elixir
FIX.Message.parse(buffer, MyBroker.Dictionary)
```

`data_field length_tag, data_tag` declares that the data field must immediately follow its length field and contain exactly the declared number of bytes. Local declarations take precedence over the extended dictionary.

## Length-prefixed data

FIX data fields such as `RawData(96)` may contain arbitrary bytes, including SOH. The parser uses the preceding companion length field—`RawDataLength(95)` in this case—to extract the value byte-exactly:

```elixir
soh = <<1>>
data = "left" <> soh <> "right"
fields = "95=#{byte_size(data)}" <> soh <> "96=" <> data <> soh

FIX.Parser.parse(fields)
# => {:ok, {[], [{95, "10"}, {96, data}], []}}
```

When constructing messages, include both the length field and data field in the correct order; the encoder only derives `BodyLength(9)` and `CheckSum(10)`.

## Supported errors

Complete-message parsing returns two error reasons:

- `:garbled` — invalid framing, malformed fields, invalid declared data length, invalid promoted values, or otherwise unparseable input
- `:checksum_mismatch` — a complete frame whose checksum does not match

A valid prefix of a message returns `:incomplete`, allowing the caller to read and append more bytes.

## Development

Run the test suite with:

```sh
mix test
```

## License

Licensed under the Apache License 2.0. See [`LICENSE`](LICENSE).
