require "net/http"

class ChatJob < ApplicationJob
  queue_as :default

  # prompt is passed in from the form text area that user typed in
  def perform(prompt, chat_id)
    # Setup http request to Ollama
    # Setting stream to true means as we start inference on model,
    # will send back a bunch of chunks
    # Note that prompt from user must be formatted before we can pass it to the model
    cache_key = "context_#{chat_id}"
    cached_context = Rails.cache.read(cache_key)

    uri = URI("http://localhost:11434/api/generate")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = {
      model: "mistral:latest",
      prompt: context(prompt),
      context: cached_context,
      temperature: 1,
      stream: true
    }.to_json

    # Now make the http request
    # Need rand number assigned to each frame
    # "messages" is the id of a div in the welcome index view
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      rand = SecureRandom.hex(10)
      # broadcast initial empty message
      broadcast_message("messages", message_div(rand), chat_id)
      http.request(request) do |response|
        response.read_body do |chunk|
          # chunks are json, eg:
          # {"model":"mistral:latest","created_at":"2024-03-18T12:48:19.494759Z","response":" need","done":false}
          # When done is true, we get an empty response
          Rails.logger.info("✅ #{chunk.force_encoding('UTF-8')}")
          process_chunk(chunk, rand, chat_id)
        end
      end
    end
  end

  private

  def context(prompt)
    "[INST]#{prompt}[/INST]"
  end

  # Use heredoc because it supports multi-line html for legibility
  def message_div(rand)
    <<~HTML
      <div id='#{rand}'
           data-controller='markdown-text'
           data-markdown-text-updated-value=''
           class='border border-blue-500 bg-blue-100 text-blue-800 p-2 rounded-xl mb-2'>
      </div>
    HTML
  end

  # Find DOM element with `id` of `target` and append message (which is some html content) to it.
  def broadcast_message(target, message, chat_id)
    # This uses ActionCable to broadcast the html message to the welcome channel.
    # Any view that has subscribed to this channel `turbo_stream_from @chat_id, "welcome"`
    # will receive the message.
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, html: message
  end

  def process_chunk(chunk, rand, chat_id)
    json = JSON.parse(chunk.force_encoding("UTF-8"))
    done = json["done"]
    # If response attribute is an empty string, generate html line break
    message = json["response"].to_s.strip.empty? ? "<br/>" : json["response"]
    if done
      Rails.logger.info("🎉 Done streaming response for chat_id #{chat_id}.")

      # cache context for next inference
      context = json["context"]
      cache_key = "context_#{chat_id}"
      Rails.cache.write(cache_key, context)

      message = build_markdown_updater(rand)
      broadcast_message(rand, message, chat_id)
    else
      broadcast_message(rand, message, chat_id)
    end
  end

  # The stimulus controller will perform some action anytime the markdown-text-update-value is updated
  # So basically, this is the back end streaming triggerring the stimulus controller to do something
  def build_markdown_updater(rand)
    <<~HTML
      <script>
        document.getElementById('#{rand}').dataset.markdownTextUpdatedValue = '#{Time.current.to_f}'
      </script>
    HTML
  end
end
