require "net/http"

class ChatJob < ApplicationJob
  queue_as :default

  # prompt is passed in from the form text area that user typed in
  def perform(prompt)
    # Setup http request to Ollama
    # Setting stream to true means as we start inference on model,
    # will send back a bunch of chunks
    # Note that prompt from user must be formatted before we can pass it to the model
    uri = URI("http://localhost:11434/api/generate")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = {
      model: "mistral:latest",
      prompt: context(prompt),
      temperature: 1,
      stream: true
    }.to_json

    # Now make the http request
    # Need rand number assigned to each frame
    # "messages" is the id of a div in the welcome index view
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      rand = SecureRandom.hex(10)
      # broadcast initial message (nothing here yet?)
      broadcast_message("messages", message_div(rand))
      http.request(request) do |response|
        response.read_body do |chunk|
          Rails.logger.info("✅ #{chunk}")
        end
      end
    end
  end

  private

  def context(prompt)
    "[INST]#{prompt}[/INST]"
  end

  def message_div(rand)
    "<div id='#{rand}' class='border border-blue-500 text-blue-500 p-2 rounded-lg mb-2'></div>"
  end

  def broadcast_message(target, message)
    # This uses ActionCable to broadcast the html message to the welcome channel
    # Any view that has subscribed to this channel `turbo_stream_from "welcome"` will receive the message
    Turbo::StreamsChannel.broadcast_append_to "welcome", target:, html: message
  end
end
