defmodule FIX.MessageTest do
  use ExUnit.Case, async: true
  doctest FIX.Message, import: true

  alias FIX.Message

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

  describe "parse/1" do
    test "promotes canonical header fields" do
      raw =
        build_message([
          {35, "0"},
          {34, "3"},
          {49, "SENDER"},
          {56, "TARGET"},
          {112, "TEST"}
        ])

      assert {:ok, message, ""} = Message.parse(raw)

      assert %Message{
               begin_string: "FIX.4.4",
               msg_type: "0",
               seq_num: 3,
               sender_comp_id: "SENDER",
               target_comp_id: "TARGET"
             } = message
    end

    test "keeps unpromoted header fields in :header and the body in :body, in wire order" do
      raw =
        build_message([
          {35, "D"},
          {34, "7"},
          {49, "S"},
          {52, "20090323-15:40:29"},
          {56, "T"},
          {115, "XYZ"},
          {116, "SUB"},
          {11, "ORDER-1"},
          {54, "1"}
        ])

      assert {:ok, message, ""} = Message.parse(raw)
      assert message.sending_time == "20090323-15:40:29"
      assert message.header == [{115, "XYZ"}, {116, "SUB"}]
      assert message.body == [{11, "ORDER-1"}, {54, "1"}]
    end

    test "does not promote header tags that appear after the body has started" do
      raw = build_message([{35, "D"}, {34, "7"}, {11, "ORDER-1"}, {49, "SNEAKY"}])

      assert {:ok, message, ""} = Message.parse(raw)
      assert message.sender_comp_id == nil
      assert message.header == []
      assert message.body == [{11, "ORDER-1"}, {49, "SNEAKY"}]
    end

    test "does not store BodyLength(9) or CheckSum(10)" do
      raw = build_message([{35, "0"}, {34, "1"}])

      assert {:ok, message, ""} = Message.parse(raw)

      refute Enum.any?(message.header ++ message.body, fn {tag, _} ->
               tag in [8, 9, 10, 35, 34]
             end)
    end

    test "keeps the original wire bytes in :raw" do
      raw = build_message([{35, "0"}, {34, "1"}])

      assert {:ok, message, ""} = Message.parse(raw)
      assert message.raw == raw
    end

    test ":raw covers exactly one message for pipelined input" do
      msg1 = build_message([{35, "0"}, {34, "1"}])
      msg2 = build_message([{35, "0"}, {34, "2"}])

      assert {:ok, message1, rest} = Message.parse(msg1 <> msg2)
      assert message1.raw == msg1
      assert rest == msg2

      assert {:ok, message2, ""} = Message.parse(rest)
      assert message2.raw == msg2
      assert message2.seq_num == 2
    end

    test "promotes header fields regardless of their order within the header" do
      raw = build_message([{49, "S"}, {56, "T"}, {35, "0"}, {34, "9"}])

      assert {:ok, message, ""} = Message.parse(raw)
      assert message.msg_type == "0"
      assert message.seq_num == 9
      assert message.header == []
      assert message.body == []
    end

    test "leaves missing header fields as nil" do
      raw = build_message([{35, "0"}])

      assert {:ok, message, ""} = Message.parse(raw)
      assert message.seq_num == nil
      assert message.sender_comp_id == nil
      assert message.target_comp_id == nil
    end

    test "parses data fields containing SOH" do
      data = "bin" <> @soh <> "data"
      raw = build_message([{35, "D"}, {34, "2"}, {95, byte_size(data)}, {96, data}])

      assert {:ok, message, ""} = Message.parse(raw)
      assert message.body == [{95, "8"}, {96, data}]
    end

    test "is garbled when MsgSeqNum(34) is not a positive integer" do
      assert Message.parse(build_message([{35, "0"}, {34, "abc"}])) == {:error, :garbled}
      assert Message.parse(build_message([{35, "0"}, {34, "0"}])) == {:error, :garbled}
      assert Message.parse(build_message([{35, "0"}, {34, "-1"}])) == {:error, :garbled}
    end

    test "returns :incomplete for a partial message" do
      raw = build_message([{35, "0"}, {34, "1"}])
      partial = binary_part(raw, 0, byte_size(raw) - 1)

      assert Message.parse(partial) == :incomplete
    end

    test "propagates framing errors" do
      raw = build_message([{35, "0"}, {58, "hello"}])
      corrupted = String.replace(raw, "hello", "jello")

      assert Message.parse(corrupted) == {:error, :checksum_mismatch}
      assert Message.parse("garbage") == {:error, :garbled}
    end
  end

  describe "to_fix/1" do
    test "encodes header, body, and trailer with computed BodyLength and CheckSum" do
      message = %Message{
        begin_string: "FIX.4.4",
        msg_type: "0",
        seq_num: 3,
        sender_comp_id: "SENDER",
        target_comp_id: "TARGET",
        body: [{112, "TEST"}]
      }

      expected =
        build_message([{35, "0"}, {49, "SENDER"}, {56, "TARGET"}, {34, "3"}, {112, "TEST"}])

      assert Message.to_fix(message) == expected
    end

    test "encodes :header fields between the promoted header and the body" do
      message = %Message{
        begin_string: "FIX.4.4",
        msg_type: "0",
        seq_num: 3,
        header: [{115, "XYZ"}],
        body: [{112, "TEST"}]
      }

      expected = build_message([{35, "0"}, {34, "3"}, {115, "XYZ"}, {112, "TEST"}])

      assert Message.to_fix(message) == expected
    end

    test "omits nil promoted header fields" do
      message = %Message{begin_string: "FIX.4.4", msg_type: "0"}

      assert Message.to_fix(message) == build_message([{35, "0"}])
    end

    test "round-trips through parse/1" do
      message = %Message{
        begin_string: "FIX.4.4",
        msg_type: "D",
        seq_num: 42,
        sender_comp_id: "SENDER",
        target_comp_id: "TARGET",
        header: [{115, "XYZ"}],
        body: [{11, "ORDER-1"}, {54, "1"}, {38, "100"}, {55, "CVS"}]
      }

      raw = Message.to_fix(message)

      assert {:ok, parsed, ""} = Message.parse(raw)
      assert %{message | raw: raw} == parsed
    end

    test "encodes from struct data, ignoring :raw" do
      raw = build_message([{35, "0"}, {34, "1"}])
      assert {:ok, message, ""} = Message.parse(raw)

      resent = Message.to_fix(%{message | seq_num: 2})

      assert {:ok, reparsed, ""} = Message.parse(resent)
      assert reparsed.seq_num == 2
    end

    test "raises without :begin_string and :msg_type" do
      assert_raise ArgumentError, fn -> Message.to_fix(%Message{}) end
      assert_raise ArgumentError, fn -> Message.to_fix(%Message{begin_string: "FIX.4.4"}) end
      assert_raise ArgumentError, fn -> Message.to_fix(%Message{msg_type: "0"}) end
    end
  end

  describe "String.Chars" do
    test "to_string/1 encodes the message" do
      message = %Message{begin_string: "FIX.4.4", msg_type: "0", seq_num: 1}

      assert to_string(message) == Message.to_fix(message)
    end
  end
end
