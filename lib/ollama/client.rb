require "net/http"

module Ollama
  class Client
    def initialize(model = nil)
      @uri = URI(Rails.application.config.chat["chat_api_url"])
      @model = model || Rails.application.config.chat["chat_model"]
    end

    def request(prompt, cached_context, &)
      request = build_request(prompt, cached_context)
      send_request(request, &)
    end

    private

    def build_request(prompt, cached_context)
      request = Net::HTTP::Post.new(@uri, "Content-Type" => "application/json")
      request.body = {
        model: @model,
        prompt: context(prompt),
        context: cached_context,
        temperature: 1,
        stream: true
      }.to_json
      request
    end

    def send_request(request)
      Net::HTTP.start(@uri.hostname, @uri.port) do |http|
        http.request(request) do |response|
          response.read_body do |chunk|
            encoded_chunk = chunk.force_encoding("UTF-8")
            Rails.logger.info("✅ #{encoded_chunk}")
            yield encoded_chunk if block_given?
          end
        end
      end
    end

    def context(prompt)
      "[INST]#{prompt}[/INST]"
    end
  end
end
