defmodule FIX.Dictionary do
  @moduledoc """
  Behaviour and builder for FIX data dictionaries.

  A dictionary tells the parser which tags are length fields, and which data
  field tag must immediately follow each one. FIX data-type fields (RawData,
  EncodedText, ...) hold arbitrary bytes — including the SOH delimiter — so
  the parser slices them by the byte count declared in the companion length
  field instead of scanning for SOH.

  `FIX.Dictionary.FIX44` covers the standard fields and is the parser's
  default. Counterparties that define custom data fields need their own
  dictionary:

      defmodule MyBroker.Dictionary do
        use FIX.Dictionary, extends: FIX.Dictionary.FIX44

        # Bilaterally-agreed custom data fields
        data_field 5001, 5002
      end

      FIX.Parser.parse_message(buffer, MyBroker.Dictionary)

  Declared pairs compile to literal function clauses (a jump table), so
  lookups stay constant-time regardless of dictionary size. Locally declared
  pairs take precedence over the `:extends` base, and tags unknown to both
  return `nil`.
  """

  @callback companion_data_tag(FIX.Parser.tag()) :: FIX.Parser.tag() | nil

  defmacro __using__(opts) do
    quote do
      @behaviour FIX.Dictionary
      @before_compile FIX.Dictionary
      @fix_dictionary_extends unquote(opts[:extends])

      Module.register_attribute(__MODULE__, :fix_data_fields, accumulate: true)
      import FIX.Dictionary, only: [data_field: 2]
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

  defmacro __before_compile__(env) do
    pairs = Module.get_attribute(env.module, :fix_data_fields)
    extends = Module.get_attribute(env.module, :fix_dictionary_extends)

    clauses =
      for {length_tag, data_tag} <- Enum.reverse(pairs) do
        quote do
          def companion_data_tag(unquote(length_tag)), do: unquote(data_tag)
        end
      end

    fallback =
      if extends do
        # Tags not declared locally defer to the base dictionary.
        quote do
          def companion_data_tag(tag), do: unquote(extends).companion_data_tag(tag)
        end
      else
        quote do
          def companion_data_tag(_tag), do: nil
        end
      end

    [clauses, fallback]
  end
end
