require "spec"
require "pg"
require "db"

TEST_DB = DB.open(ENV.fetch("DATABASE_URL", "postgres:///"))
