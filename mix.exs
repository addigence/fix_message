defmodule FIX.Message.MixProject do
  use Mix.Project

  def project do
    [
      app: :fix_message,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description:
        "Elixir library for framing, parsing, inspecting, and encoding Financial Information eXchange (FIX) messages.",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/addigence/fix_message"
      },
      source_url: "https://github.com/addigence/fix_message",
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end
end
