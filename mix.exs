defmodule Iter.MixProject do
  use Mix.Project

  @version "0.1.3"
  @github_url "https://github.com/sabiwara/iter"

  def project do
    [
      app: :iter,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [flags: [:missing_return, :extra_return]],
      aliases: aliases(),

      # hex
      description:
        "A blazing fast compile-time optimized alternative to the `Enum` and `Stream` modules",
      package: package(),
      name: "Iter",
      docs: docs(),
      test_ignore_filters: [~r|^test\/fixtures\/|]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      # doc, benchs
      {:ex_doc, "~> 0.28", only: :docs, runtime: false},
      {:benchee, "~> 1.1", only: :bench, runtime: false},
      # CI
      {:dialyxir, "~> 1.0", only: :test, runtime: false},
      {:stream_data, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["sabiwara"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url},
      files: ~w(lib mix.exs README.md enum.cheatmd LICENSE.md CHANGELOG.md)
    ]
  end

  defp aliases do
    [
      docs: ["compile --force", "docs"],
      "test.unit": ["test --exclude property:true"],
      "test.prop": ["test --only property:true"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        docs: :docs,
        "hex.publish": :docs,
        dialyzer: :test,
        "test.unit": :test,
        "test.prop": :test
      ]
    ]
  end

  defp docs do
    [
      main: "Iter",
      source_ref: "v#{@version}",
      source_url: @github_url,
      homepage_url: @github_url,
      extras: ["README.md", "enum.cheatmd", "CHANGELOG.md", "LICENSE.md"]
    ]
  end
end
