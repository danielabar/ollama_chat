class ChatsController < ApplicationController
  def create
    # Interaction with LLM can be slow - execute in the background
    ChatJob.perform_later(params[:message])

    # In the meantime, clear out the form text area that user just typed
    render turbo_stream: turbo_stream.replace("chat_form", partial: "welcome/form")
  end
end
