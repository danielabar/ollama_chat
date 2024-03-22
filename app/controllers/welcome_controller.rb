class WelcomeController < ApplicationController
  def index
    @chat_id = SecureRandom.hex(20)
    Rails.logger.info("🗞️ Generated chat id: #{@chat_id}")
  end
end
