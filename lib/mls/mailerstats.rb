# frozen_string_literal: true

require "net/http"
require "json"

module MLS
  class MailerStats

    def initialize(options)
      @api_url = options[:api_url].dup
      @api_url << "/"  unless @api_url[-1] == "/"

      @api_key = options[:api_key]
    end

    def get
      stats = extract_stats

      "Sent emails today: %3d\n" % stats[:today]
    end

    private

    def extract_stats
      data = request_data

      stats = {}

      data_stats = data["Data"].first
      stats[:today] = data_stats["DeliveredCount"]  if data_stats

      stats
    end

    def request_data
      uri = URI.parse(@api_url)
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(*@api_key.split(":"))

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.ssl_version = :SSLv3
        http.request request
      end

      if res.is_a? Net::HTTPSuccess
        JSON.parse(res.body)
      else
        {}
      end
    end
  end
end
