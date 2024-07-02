defmodule Cachetastic.MixProject do
  use Mix.Project

  def project do
    [
      app: :cachetastic,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Cachetastic",
      source_url: "https://github.com/gskolber/cachetastic",
      homepage_url: "https://github.com/gskolber/cachetastic",
      docs: [
        # Specify the main page in the docs
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :patch]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 1.0"},
      {:patch, "~> 0.12.0", only: :test},
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
