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
      # broadcast initial empty message
      broadcast_message("messages", message_div(rand))
      http.request(request) do |response|
        response.read_body do |chunk|
          # chunks are json, eg:
          # {"model":"mistral:latest","created_at":"2024-03-18T12:48:19.494759Z","response":" need","done":false}
          # When done is true, we get an empty response
          Rails.logger.info("✅ #{chunk}")
          process_chunk(chunk, rand)
        end
      end
    end
  end

  private

  def context(prompt)
    "[INST]#{prompt}[/INST]"
  end

  def message_div(rand)
    "<div id='#{rand}' class='border border-blue-500 bg-blue-50 text-blue-500 p-2 rounded-xl mb-2'></div>"
  end

  # Find DOM element with `id` of `target` and append message (which is some html content) to it.
  def broadcast_message(target, message)
    # This uses ActionCable to broadcast the html message to the welcome channel
    # Any view that has subscribed to this channel `turbo_stream_from "welcome"` will receive the message
    Turbo::StreamsChannel.broadcast_append_to "welcome", target:, html: message
  end

  # If response attribute is an empty string, generate html line break
  def process_chunk(chunk, rand)
    json = JSON.parse(chunk)
    done = json["done"]
    message = json["response"].to_s.strip.empty? ? "<br/>" : json["response"]
    if done
      Rails.logger.info("🎉 Done streaming response.")
    else
      broadcast_message(rand, message)
    end
  end
end
