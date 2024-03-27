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

  def process_chunk(chunk, rand, chat_id)
    json = JSON.parse(chunk)
    done = json["done"]
    # If response attribute is an empty string, generate html line break
    # Maybe not needed given use of marked js library?
    message = json["response"].to_s.strip.empty? ? "<br/>" : json["response"]
    if done
      Rails.logger.info("🎉 Done streaming response for chat_id #{chat_id}.")

      # cache context for next inference
      context = json["context"]
      cache_key = "context_#{chat_id}"
      Rails.cache.write(cache_key, context)
      broadcast_markdown_updater(rand, chat_id)
    else
      broadcast_response_chunk(rand, message, chat_id)
    end
  end

  def broadcast_response_container(target, rand, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, partial: "chats/response",
                                                                    locals: { rand: }
  end

  def broadcast_response_chunk(target, message, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, html: message
  end

  def broadcast_markdown_updater(target, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, partial: "chats/markdown_updater",
                                                                    locals: {
                                                                      rand: target,
                                                                      cur_time: Time.current.to_f
                                                                    }
  end
end
