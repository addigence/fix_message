defmodule FIX.ParserTest do
  use ExUnit.Case, async: true

  alias FIX.Parser

  @soh <<0x01>>

  # Builds a complete FIX message from body fields, computing BodyLength(9)
  # and CheckSum(10).
  defp build_message(body_fields, begin_string \\ "FIX.4.4") do
    body =
      Enum.map_join(body_fields, fn {tag, value} -> "#{tag}=#{value}" <> @soh end)

    payload = "8=#{begin_string}" <> @soh <> "9=#{byte_size(body)}" <> @soh <> body
    payload <> "10=" <> checksum(payload) <> @soh
  end

  defp checksum(payload) do
    payload
    |> :binary.bin_to_list()
    |> Enum.sum()
    |> rem(256)
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end

  describe "parse/1 single fields" do
    test "parses a single field" do
      assert Parser.parse("35=D" <> @soh) == {:ok, [{35, "D"}]}
    end

    test "parses a field with a multi-digit tag" do
      assert Parser.parse("10114=Y" <> @soh) == {:ok, [{10114, "Y"}]}
    end

    test "parses a field with an empty value" do
      assert Parser.parse("58=" <> @soh) == {:ok, [{58, ""}]}
    end

    test "parses a value containing an equals sign" do
      assert Parser.parse("58=a=b=c" <> @soh) == {:ok, [{58, "a=b=c"}]}
    end

    test "parses a value containing spaces and punctuation" do
      value = "Order rejected: insufficient funds!"

      assert Parser.parse("58=#{value}" <> @soh) == {:ok, [{58, value}]}
    end

    test "parses a UTF-8 value" do
      assert Parser.parse("58=héllo wörld 日本" <> @soh) == {:ok, [{58, "héllo wörld 日本"}]}
    end

    test "parses a decimal price value as a string" do
      assert Parser.parse("44=150.25" <> @soh) == {:ok, [{44, "150.25"}]}
    end
  end

  describe "parse/1 multiple fields" do
    test "parses two fields in order" do
      input = "8=FIX.4.2" <> @soh <> "35=D" <> @soh

      assert Parser.parse(input) == {:ok, [{8, "FIX.4.2"}, {35, "D"}]}
    end

    test "parses a complete NewOrderSingle message" do
      input =
        Enum.join(
          [
            "8=FIX.4.2",
            "9=145",
            "35=D",
            "34=4",
            "49=ABC_DEFG01",
            "52=20090323-15:40:29",
            "56=CCG",
            "115=XYZ",
            "11=NF 0542/03232009",
            "54=1",
            "38=100",
            "55=CVS",
            "40=1",
            "59=0",
            "47=A",
            "60=20090323-15:40:29",
            "21=1",
            "207=N",
            "10=139"
          ],
          @soh
        ) <> @soh

      assert {:ok, fields} = Parser.parse(input)

      assert fields == [
               {8, "FIX.4.2"},
               {9, "145"},
               {35, "D"},
               {34, "4"},
               {49, "ABC_DEFG01"},
               {52, "20090323-15:40:29"},
               {56, "CCG"},
               {115, "XYZ"},
               {11, "NF 0542/03232009"},
               {54, "1"},
               {38, "100"},
               {55, "CVS"},
               {40, "1"},
               {59, "0"},
               {47, "A"},
               {60, "20090323-15:40:29"},
               {21, "1"},
               {207, "N"},
               {10, "139"}
             ]
    end

    test "preserves duplicate tags in order" do
      input = "58=first" <> @soh <> "58=second" <> @soh

      assert Parser.parse(input) == {:ok, [{58, "first"}, {58, "second"}]}
    end
  end

  describe "parse/1 data fields" do
    test "parses RawData(96) containing SOH using RawDataLength(95)" do
      raw = "abc" <> @soh <> "def=" <> @soh <> "ghi"
      input = "95=#{byte_size(raw)}" <> @soh <> "96=#{raw}" <> @soh <> "35=D" <> @soh

      assert Parser.parse(input) ==
               {:ok, [{95, "#{byte_size(raw)}"}, {96, raw}, {35, "D"}]}
    end

    test "parses EncodedText(355) containing SOH using EncodedTextLen(354)" do
      encoded = <<1, 2, 3, 1>>
      input = "354=4" <> @soh <> "355=#{encoded}" <> @soh

      assert Parser.parse(input) == {:ok, [{354, "4"}, {355, encoded}]}
    end

    test "parses XmlData(213) with XmlDataLen(212)" do
      xml = "<a b=\"c\">" <> @soh <> "</a>"
      input = "212=#{byte_size(xml)}" <> @soh <> "213=#{xml}" <> @soh

      assert Parser.parse(input) == {:ok, [{212, "14"}, {213, xml}]}
    end

    test "parses the non-adjacent EncodedListStatusText(446) pair with EncodedListStatusTextLen(445)" do
      text = "status" <> @soh <> "text"
      input = "445=#{byte_size(text)}" <> @soh <> "446=#{text}" <> @soh

      assert Parser.parse(input) == {:ok, [{445, "11"}, {446, text}]}
    end

    test "parses EncryptedPassword(1402) with EncryptedPasswordLen(1401)" do
      password = <<0, 1, 2, 255, 1, 42>>
      input = "1401=#{byte_size(password)}" <> @soh <> "1402=#{password}" <> @soh

      assert Parser.parse(input) == {:ok, [{1401, "6"}, {1402, password}]}
    end

    test "parses SecurityXML(1185) with SecurityXMLLen(1184)" do
      xml = "<Instrmt>" <> @soh <> "</Instrmt>"
      input = "1184=#{byte_size(xml)}" <> @soh <> "1185=#{xml}" <> @soh

      assert Parser.parse(input) == {:ok, [{1184, "20"}, {1185, xml}]}
    end

    test "parses a zero-length data field" do
      input = "95=0" <> @soh <> "96=" <> @soh

      assert Parser.parse(input) == {:ok, [{95, "0"}, {96, ""}]}
    end

    test "is garbled when the data field is missing after the length field" do
      input = "35=D" <> @soh <> "95=5" <> @soh <> "58=text" <> @soh

      assert Parser.parse(input) == {:error, :garbled}
    end

    test "is garbled when the declared length is too long" do
      input = "95=100" <> @soh <> "96=short" <> @soh

      assert Parser.parse(input) == {:error, :garbled}
    end

    test "is garbled when the length is not an integer" do
      input = "95=abc" <> @soh <> "96=data" <> @soh

      assert Parser.parse(input) == {:error, :garbled}
    end

    test "is garbled without SOH immediately after the declared data bytes" do
      # declared length cuts the value short: byte after slice is not SOH
      input = "95=2" <> @soh <> "96=abcd" <> @soh

      assert Parser.parse(input) == {:error, :garbled}
    end
  end

  describe "parse/1 malformed input" do
    test "returns empty field list for an empty string" do
      assert Parser.parse("") == {:ok, []}
    end

    test "is garbled when the last field has no trailing SOH" do
      input = "8=FIX.4.2" <> @soh <> "35=D"

      assert Parser.parse(input) == {:error, :garbled}
    end

    test "is garbled when input does not start with a numeric tag" do
      input = "abc=1" <> @soh

      assert Parser.parse(input) == {:error, :garbled}
    end

    test "is garbled when a tag is missing the equals sign" do
      input = "35=D" <> @soh <> "49" <> @soh

      assert Parser.parse(input) == {:error, :garbled}
    end

    test "is garbled with malformed trailing data after valid fields" do
      input = "8=FIX.4.2" <> @soh <> "35=D" <> @soh <> "garbage"

      assert Parser.parse(input) == {:error, :garbled}
    end
  end

  describe "frame/1" do
    test "frames a complete message with a valid checksum" do
      msg = build_message([{35, "0"}, {34, "3"}, {49, "SENDER"}, {56, "TARGET"}])

      assert Parser.frame(msg) == {:ok, msg, ""}
    end

    test "returns the remaining buffer after the framed message" do
      msg1 = build_message([{35, "0"}, {34, "1"}])
      msg2 = build_message([{35, "0"}, {34, "2"}])

      assert Parser.frame(msg1 <> msg2) == {:ok, msg1, msg2}
    end

    test "accepts any BeginString version" do
      msg = build_message([{35, "0"}], "FIXT.1.1")

      assert Parser.frame(msg) == {:ok, msg, ""}
    end

    test "returns :incomplete for an empty buffer" do
      assert Parser.frame("") == :incomplete
    end

    test "returns :incomplete for every proper prefix of a message" do
      msg = build_message([{35, "D"}, {58, "hello"}])

      for len <- 0..(byte_size(msg) - 1) do
        prefix = binary_part(msg, 0, len)
        assert Parser.frame(prefix) == :incomplete, "failed at prefix length #{len}"
      end
    end

    test "returns :checksum_mismatch for a corrupted body" do
      msg = build_message([{35, "0"}, {58, "hello"}])
      corrupted = String.replace(msg, "hello", "jello")

      assert Parser.frame(corrupted) == {:error, :checksum_mismatch}
    end

    test "returns :garbled when the buffer does not start with 8=" do
      assert Parser.frame("35=D" <> @soh) == {:error, :garbled}
      assert Parser.frame("garbage") == {:error, :garbled}
    end

    test "returns :garbled when BodyLength does not follow BeginString" do
      assert Parser.frame("8=FIX.4.4" <> @soh <> "35=D" <> @soh) == {:error, :garbled}
    end

    test "returns :garbled when BodyLength is not numeric" do
      assert Parser.frame("8=FIX.4.4" <> @soh <> "9=abc" <> @soh) == {:error, :garbled}
    end

    test "returns :garbled when BodyLength does not point at the trailer" do
      body = "35=0" <> @soh
      # declared length one byte short, so "10=" is not where it should be
      payload = "8=FIX.4.4" <> @soh <> "9=#{byte_size(body) - 1}" <> @soh <> body
      msg = payload <> "10=000" <> @soh

      assert Parser.frame(msg) == {:error, :garbled}
    end

    test "returns :garbled when checksum digits are malformed" do
      msg = build_message([{35, "0"}])
      base = binary_part(msg, 0, byte_size(msg) - 7)

      assert Parser.frame(base <> "10=1x3" <> @soh) == {:error, :garbled}
    end
  end

  describe "parse_message/1" do
    test "frames and parses a complete message" do
      msg = build_message([{35, "0"}, {34, "3"}, {49, "SENDER"}, {56, "TARGET"}])

      body_len =
        Integer.to_string(
          byte_size(
            "35=0" <> @soh <> "34=3" <> @soh <> "49=SENDER" <> @soh <> "56=TARGET" <> @soh
          )
        )

      assert {:ok, fields, ""} = Parser.parse_message(msg)

      assert [
               {8, "FIX.4.4"},
               {9, ^body_len},
               {35, "0"},
               {34, "3"},
               {49, "SENDER"},
               {56, "TARGET"},
               {10, _checksum}
             ] = fields
    end

    test "parses a message with a data field containing SOH" do
      raw = "bin" <> @soh <> "data"
      msg = build_message([{35, "D"}, {95, byte_size(raw)}, {96, raw}, {58, "note"}])

      assert {:ok, fields, ""} = Parser.parse_message(msg)
      assert {96, raw} in fields
      assert {58, "note"} in fields
    end

    test "returns the rest of the buffer for pipelined messages" do
      msg1 = build_message([{35, "0"}, {34, "1"}])
      msg2 = build_message([{35, "0"}, {34, "2"}])

      assert {:ok, fields1, rest} = Parser.parse_message(msg1 <> msg2)
      assert {34, "1"} in fields1

      assert {:ok, fields2, ""} = Parser.parse_message(rest)
      assert {34, "2"} in fields2
    end

    test "returns :incomplete for a partial message" do
      msg = build_message([{35, "0"}])
      partial = binary_part(msg, 0, byte_size(msg) - 1)

      assert Parser.parse_message(partial) == :incomplete
    end

    test "propagates framing errors" do
      msg = build_message([{35, "0"}, {58, "hello"}])
      corrupted = String.replace(msg, "hello", "jello")

      assert Parser.parse_message(corrupted) == {:error, :checksum_mismatch}
      assert Parser.parse_message("garbage") == {:error, :garbled}
    end
  end
end
