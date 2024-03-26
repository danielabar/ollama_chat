require "net/http"

class ChatJob < ApplicationJob
  queue_as :default

  def perform(prompt, chat_id)
    cached_context = Rails.cache.read("context_#{chat_id}")
    client = Ollama::Client.new
    rand = SecureRandom.hex(10)
    broadcast_response_container("messages", rand, chat_id)

    client.request(prompt, cached_context) do |chunk|
      process_chunk(chunk, rand, chat_id)
    end
  end

  private

  def broadcast_response_container(target, rand, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, partial: "chats/response",
                                                                    locals: { rand: }
  end

  def process_chunk(chunk, rand, chat_id)
    json = JSON.parse(chunk)
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

  # Find DOM element with `id` of `target` and append message (which is some html content) to it.
  # Uses ActionCable to broadcast the html message.
  # Any view that has subscribed to this channel `turbo_stream_from @chat_id, "welcome"`
  # will receive the message.
  def broadcast_message(target, message, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, html: message
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
