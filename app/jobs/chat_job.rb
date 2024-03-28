require "net/http"

class ChatJob < ApplicationJob
  queue_as :default

  def perform(prompt, chat_id)
    rand = SecureRandom.hex(10)
    prompt_id = "prompt_#{rand}"
    response_id = "response_#{rand}"
    broadcast_response_container("messages", prompt, prompt_id, response_id, chat_id)

    cached_context = Rails.cache.read(context_cache_key(chat_id))
    client = Ollama::Client.new
    client.request(prompt, cached_context) do |chunk|
      process_chunk(chunk, response_id, chat_id)
    end
  end

  private

  def context_cache_key(chat_id)
    "context_#{chat_id}"
  end

  def process_chunk(chunk, response_id, chat_id)
    json = JSON.parse(chunk)
    done = json["done"]
    if done
      Rails.logger.info("🎉 Done streaming response for chat_id #{chat_id}.")

      context = json["context"]
      Rails.cache.write(context_cache_key(chat_id), context)
      broadcast_markdown_updater(response_id, chat_id)
    else
      message = json["response"].to_s.strip.empty? ? "<br/>" : json["response"]
      broadcast_response_chunk(response_id, message, chat_id)
    end
  end

  def broadcast_response_container(target, prompt, prompt_id, response_id, chat_id)
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, partial: "chats/response",
                                                                    locals: { prompt_id:, prompt:, response_id: }
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
