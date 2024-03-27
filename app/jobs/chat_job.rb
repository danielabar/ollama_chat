require "net/http"

class ChatJob < ApplicationJob
  queue_as :default

  def perform(prompt, chat_id)
    rand = SecureRandom.hex(10)
    response_id = "response_#{rand}"
    broadcast_response_container("messages", response_id, chat_id)

    cached_context = Rails.cache.read("context_#{chat_id}")
    client = Ollama::Client.new
    client.request(prompt, cached_context) do |chunk|
      process_chunk(chunk, response_id, chat_id)
    end
  end

  private

  def process_chunk(chunk, response_id, chat_id)
    json = JSON.parse(chunk)
    done = json["done"]
    if done
      Rails.logger.info("🎉 Done streaming response for chat_id #{chat_id}.")

      # cache context for next inference
      context = json["context"]
      cache_key = "context_#{chat_id}"
      Rails.cache.write(cache_key, context)
      broadcast_markdown_updater(response_id, chat_id)
    else
      message = json["response"].to_s.strip.empty? ? "<br/>" : json["response"]
      broadcast_response_chunk(response_id, message, chat_id)
    end
  end

  def broadcast_response_container(target, response_id, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, partial: "chats/response",
                                                                    locals: { response_id: }
  end

  def broadcast_response_chunk(response_id, message, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target: response_id, html: message
  end

  def broadcast_markdown_updater(response_id, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target: response_id,
                                                                    partial: "chats/markdown_updater",
                                                                    locals: {
                                                                      response_id:,
                                                                      cur_time: Time.current.to_f
                                                                    }
  end
end
