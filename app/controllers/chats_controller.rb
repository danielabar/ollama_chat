class ChatsController < ApplicationController
  def create
    # Interaction with LLM can be slow - execute in the background
    ChatJob.perform_later(params[:message], params[:chat_id])

    # In the meantime, clear out the form text area that user just typed
    # The turbo stream response here is being returned over regular http request/response, NOT websocket
    render turbo_stream: turbo_stream.replace("chat_form", partial: "welcome/form",
                                                           locals: { chat_id: params[:chat_id] })
  end
end
