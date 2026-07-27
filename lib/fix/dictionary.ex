defmodule FIX.Dictionary do
  @moduledoc """
  Behaviour and builder for FIX data dictionaries.

  A dictionary gives the parser the version-specific tag knowledge it needs:

  * `companion_data_tag/1` — which tags are length fields, and which data
    field tag must immediately follow each one. FIX data-type fields
    (RawData, EncodedText, ...) hold arbitrary bytes — including the SOH
    delimiter — so the parser slices them by the byte count declared in the
    companion length field instead of scanning for SOH.

  * `header_tag?/1` and `trailer_tag?/1` — which tags belong to the standard
    message header and trailer. The parser uses these to split the token
    stream into `{header, body, trailer}` sections: fields accumulate into
    the header until the first non-header tag, then into the body until the
    first trailer tag.

  `FIX.Dictionary.FIX44` covers the standard fields and is the parser's
  default. Counterparties that define custom data fields need their own
  dictionary:

      defmodule MyBroker.Dictionary do
        use FIX.Dictionary, extends: FIX.Dictionary.FIX44

        # Bilaterally-agreed custom data fields
        data_field 5001, 5002
      end

      FIX.Parser.parse_message(buffer, MyBroker.Dictionary)

  Declarations compile to literal function clauses (a jump table), so
  lookups stay constant-time regardless of dictionary size. Locally declared
  tags take precedence over the `:extends` base; tags unknown to both return
  `nil` from `companion_data_tag/1` and `false` from the predicates.
  """

  @callback companion_data_tag(FIX.Parser.tag()) :: FIX.Parser.tag() | nil
  @callback header_tag?(FIX.Parser.tag()) :: boolean()
  @callback trailer_tag?(FIX.Parser.tag()) :: boolean()

  defmacro __using__(opts) do
    quote do
      @behaviour FIX.Dictionary
      @before_compile FIX.Dictionary
      @fix_dictionary_extends unquote(opts[:extends])

      Module.register_attribute(__MODULE__, :fix_data_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :fix_header_tags, accumulate: true)
      Module.register_attribute(__MODULE__, :fix_trailer_tags, accumulate: true)
      import FIX.Dictionary, only: [data_field: 2, header_field: 1, trailer_field: 1]
    end
  end

  @doc """
  Declares a `length_tag => data_tag` companion pair.

  The data field's value is exactly the number of bytes declared by the
  length field, and may contain SOH.
  """
  defmacro data_field(length_tag, data_tag)
           when is_integer(length_tag) and length_tag > 0 and
                  is_integer(data_tag) and data_tag > 0 do
    quote do
      @fix_data_fields {unquote(length_tag), unquote(data_tag)}
    end
  end

  @doc """
  Declares a standard-header tag.

  The parser accumulates fields into the header section while tags satisfy
  `header_tag?/1`; the first tag that doesn't starts the body.
  """
  defmacro header_field(tag) when is_integer(tag) and tag > 0 do
    quote do
      @fix_header_tags unquote(tag)
    end
  end

  @doc """
  Declares a standard-trailer tag.

  The first tag satisfying `trailer_tag?/1` starts the trailer section, which
  runs to the end of the message.
  """
  defmacro trailer_field(tag) when is_integer(tag) and tag > 0 do
    quote do
      @fix_trailer_tags unquote(tag)
    end
  end

  defmacro __before_compile__(env) do
    pairs = Module.get_attribute(env.module, :fix_data_fields)
    header_tags = Module.get_attribute(env.module, :fix_header_tags)
    trailer_tags = Module.get_attribute(env.module, :fix_trailer_tags)
    extends = Module.get_attribute(env.module, :fix_dictionary_extends)

    data_clauses =
      for {length_tag, data_tag} <- Enum.reverse(pairs) do
        quote do
          def companion_data_tag(unquote(length_tag)), do: unquote(data_tag)
        end
      end

    header_clauses =
      for tag <- Enum.reverse(header_tags) do
        quote do
          def header_tag?(unquote(tag)), do: true
        end
      end

    trailer_clauses =
      for tag <- Enum.reverse(trailer_tags) do
        quote do
          def trailer_tag?(unquote(tag)), do: true
        end
      end

    fallbacks =
      if extends do
        # Tags not declared locally defer to the base dictionary.
        quote do
          def companion_data_tag(tag), do: unquote(extends).companion_data_tag(tag)
          def header_tag?(tag), do: unquote(extends).header_tag?(tag)
          def trailer_tag?(tag), do: unquote(extends).trailer_tag?(tag)
        end
      else
        quote do
          def companion_data_tag(_tag), do: nil
          def header_tag?(_tag), do: false
          def trailer_tag?(_tag), do: false
        end
      end

    [data_clauses, header_clauses, trailer_clauses, fallbacks]
  end
end
