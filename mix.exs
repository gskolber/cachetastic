defmodule Cachetastic.MixProject do
  use Mix.Project

  def project do
    [
      app: :cachetastic,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "A unified caching library for Elixir with support for ETS and Redis backends.",
      package: package(),
      name: "Cachetastic",
      source_url: "https://github.com/gskolber/cachetastic",
      homepage_url: "https://github.com/gskolber/cachetastic",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:redix, "~> 1.0"},
      # Patch is used only for tests, not needed at runtime
      {:patch, "~> 0.12.0", only: :test, runtime: false},
      # ExDoc is used only for documentation generation
      {:ex_doc, "~> 0.23", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Gabriel Kolber"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/gskolber/cachetastic"}
    ]
  end
end
