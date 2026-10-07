require "spec"
require "pg"
require "db"
require "../src/postgis"

TEST_DB = DB.open(ENV.fetch("DATABASE_URL", "postgres:///"))
