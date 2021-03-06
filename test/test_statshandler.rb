# frozen_string_literal: true

require_relative "helper"


describe MLS::StatsHandler do

  before do
    setup_database
    @stats = MLS::StatsHandler.new
  end

  after do
    teardown_database
  end

  it "can increment an existing entry (1)" do
    create_dailystats(date: Date.new(2000, 1, 2), talk_subsc: 4)

    @stats.increment("ruby-talk", "subscribe", timestamp: Time.utc(2000, 1, 2))

    stats = DailyStats.first(date: Date.new(2000, 1, 2)).to_s
    _(stats).must_match "2000-01-02,5"
  end

  it "can increment an existing entry (2)" do
    create_dailystats(date: Date.new(2000, 1, 2), talk_subsc: 4)

    @stats.increment("ruby-core", "unsubscribe", timestamp: Time.utc(2000, 1, 2))

    stats = DailyStats.first(date: Date.new(2000, 1, 2)).to_s
    _(stats).must_match "2000-01-02,4,0,0,1"
  end

  it "can increment a non-existing entry" do
    @stats.increment("ruby-talk", "subscribe", timestamp: Time.utc(2010, 1, 1))

    stats = DailyStats.first(date: Date.new(2010, 1, 1)).to_s
    _(stats).must_match "2010-01-01,1"
  end

  it "can increment a non-existing entry for today" do
    now = Time.utc(2010, 1, 1)
    Time.stub(:now, now) do
      @stats.increment("ruby-talk", "unsubscribe")
    end

    stats = DailyStats.first(date: Date.new(2010, 1, 1)).to_s
    _(stats).must_match "2010-01-01,0,1"
  end
end
