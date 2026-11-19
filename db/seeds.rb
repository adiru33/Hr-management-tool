require_relative "demo_seed"

DemoSeed.run if Rails.env.development? || ENV["ACME_SEED_DEMO"] == "1"
