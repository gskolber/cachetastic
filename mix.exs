defmodule Cachetastic.MixProject do
  use Mix.Project

  def project do
    [
      app: :cachetastic,
      version: "0.1.3",
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
      {:jason, "~> 1.2"},
      {:ecto, "~> 3.6", only: :test, runtime: false},
      {:ecto_sql, "~> 3.6", only: :test, runtime: false},
      {:postgrex, ">= 0.0.0", only: :test, runtime: false},
      {:patch, "~> 0.12.0", only: :test, runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
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
