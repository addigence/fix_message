defmodule FIX.DictionaryTest do
  use ExUnit.Case, async: true

  alias FIX.Parser

  @soh <<0x01>>

  defmodule EmptyDictionary do
    use FIX.Dictionary
  end

  defmodule CustomDictionary do
    use FIX.Dictionary, extends: FIX.Dictionary.FIX44

    # Bilaterally-agreed custom data fields
    data_field(5001, 5002)
    data_field(20117, 20118)
  end

  defmodule OverridingDictionary do
    use FIX.Dictionary, extends: FIX.Dictionary.FIX44

    # Nonstandard counterparty: repurposes RawDataLength(95) to prefix a
    # custom data tag instead of RawData(96).
    data_field(95, 7096)
  end

  describe "FIX.Dictionary.FIX44" do
    test "maps standard length tags to their companion data tags" do
      assert FIX.Dictionary.FIX44.companion_data_tag(95) == 96
      assert FIX.Dictionary.FIX44.companion_data_tag(93) == 89
      assert FIX.Dictionary.FIX44.companion_data_tag(354) == 355
      # non-adjacent pair
      assert FIX.Dictionary.FIX44.companion_data_tag(445) == 446
    end

    test "returns nil for ordinary tags" do
      assert FIX.Dictionary.FIX44.companion_data_tag(35) == nil
      # BodyLength and MaxMessageSize are LENGTH-typed but not data companions
      assert FIX.Dictionary.FIX44.companion_data_tag(9) == nil
      assert FIX.Dictionary.FIX44.companion_data_tag(383) == nil
    end
  end

  describe "FIX.Dictionary.FIX50SP2" do
    test "is a superset of FIX44" do
      for tag <- [
            90,
            93,
            95,
            212,
            348,
            350,
            352,
            354,
            356,
            358,
            360,
            362,
            364,
            445,
            618,
            621,
            1184,
            1282,
            1401,
            1403,
            1871,
            1874
          ] do
        assert FIX.Dictionary.FIX50SP2.companion_data_tag(tag) ==
                 FIX.Dictionary.FIX44.companion_data_tag(tag),
               "FIX50SP2 disagrees with FIX44 for tag #{tag}"
      end
    end

    test "maps SP2 pairs with adjacent tags" do
      # EncodedRejectTextLen -> EncodedRejectText
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(1664) == 1665
    end

    test "maps SP2 pairs with gaps" do
      # EncodedDocumentationTextLen -> EncodedDocumentationText
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(1525) == 1527
      # EncodedOptionExpirationDescLen -> EncodedOptionExpirationDesc
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(1678) == 1697
    end

    test "maps reverse-ordered SP2 pairs" do
      # EncodedTradeContinuationTextLen -> EncodedTradeContinuationText
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(2372) == 2371
      # EncodedReplaceTextLen -> EncodedReplaceText
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(2802) == 2801
    end

    test "maps the distant PaymentStreamFormula XMLDATA pairs" do
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(43109) == 42684
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(43110) == 42486
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(43111) == 42982
    end

    test "returns nil for ordinary tags and non-companion LENGTH fields" do
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(35) == nil
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(9) == nil
      assert FIX.Dictionary.FIX50SP2.companion_data_tag(383) == nil
    end

    test "parses an SP2 data field containing SOH" do
      reject_text = "bad" <> @soh <> "field"
      input = "1664=#{byte_size(reject_text)}" <> @soh <> "1665=#{reject_text}" <> @soh

      assert Parser.parse(input, FIX.Dictionary.FIX50SP2) ==
               {:ok, [{1664, "9"}, {1665, reject_text}]}

      # the FIX44 dictionary doesn't know this pair
      assert Parser.parse(input, FIX.Dictionary.FIX44) == {:error, :garbled}
    end
  end

  describe "use FIX.Dictionary" do
    test "an empty dictionary maps every tag to nil" do
      assert EmptyDictionary.companion_data_tag(95) == nil
      assert EmptyDictionary.companion_data_tag(5001) == nil
    end

    test "declared pairs are looked up locally" do
      assert CustomDictionary.companion_data_tag(5001) == 5002
      assert CustomDictionary.companion_data_tag(20117) == 20118
    end

    test "unknown tags defer to the extended dictionary" do
      assert CustomDictionary.companion_data_tag(95) == 96
      assert CustomDictionary.companion_data_tag(445) == 446
      assert CustomDictionary.companion_data_tag(35) == nil
    end

    test "local declarations override the extended dictionary" do
      assert OverridingDictionary.companion_data_tag(95) == 7096
    end
  end

  describe "FIX.Parser integration" do
    test "parses custom data fields containing SOH with a custom dictionary" do
      raw = "custom" <> @soh <> "bytes"
      input = "5001=#{byte_size(raw)}" <> @soh <> "5002=#{raw}" <> @soh

      assert Parser.parse(input, CustomDictionary) ==
               {:ok, [{5001, "12"}, {5002, raw}]}
    end

    test "the default dictionary treats custom tags as ordinary fields" do
      input = "5001=4" <> @soh <> "5002=text" <> @soh

      assert Parser.parse(input) == {:ok, [{5001, "4"}, {5002, "text"}]}
    end

    test "still handles standard data fields via the extended dictionary" do
      raw = "bin" <> @soh <> "data"
      input = "95=#{byte_size(raw)}" <> @soh <> "96=#{raw}" <> @soh

      assert Parser.parse(input, CustomDictionary) == {:ok, [{95, "8"}, {96, raw}]}
    end

    test "parse_message/2 threads the dictionary through" do
      raw = "a" <> @soh <> "b"
      body = "35=D" <> @soh <> "5001=#{byte_size(raw)}" <> @soh <> "5002=#{raw}" <> @soh
      payload = "8=FIX.4.4" <> @soh <> "9=#{byte_size(body)}" <> @soh <> body
      msg = payload <> "10=" <> checksum(payload) <> @soh

      assert {:ok, fields, ""} = Parser.parse_message(msg, CustomDictionary)
      assert {5002, raw} in fields

      # ...while the default dictionary can't parse the embedded SOH
      assert Parser.parse_message(msg) == {:error, :garbled}
    end
  end

  defp checksum(payload) do
    payload
    |> :binary.bin_to_list()
    |> Enum.sum()
    |> rem(256)
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end
end
