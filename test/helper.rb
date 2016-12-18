require "minitest/autorun"

ENV["DATABASE_URL"] = "sqlite::memory:"

require_relative "../app"


def setup_database
end

def teardown_database
  Log.destroy  if DB
  DailyStats.destroy  if DB
end


def silence_warnings
  original_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = original_verbose
end
