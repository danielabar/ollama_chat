<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Ollama Chat Rails](#ollama-chat-rails)
  - [Differences in this project from tutorial](#differences-in-this-project-from-tutorial)
    - [JavaScript and CSS Handling](#javascript-and-css-handling)
    - [Encoding](#encoding)
    - [Context](#context)
    - [Separate Sessions](#separate-sessions)
  - [Project Setup](#project-setup)
  - [Future Features](#future-features)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Ollama Chat Rails

Rails project from following along with [Streaming LLM Responses ▶️](https://youtu.be/hSxmEZjCPP8?si=ps__eK0MbuSDFPXw) for building a streaming AI chatbot with Rails and Ollama.

## Differences in this project from tutorial

### JavaScript and CSS Handling

Original tutorial uses [esbuild](https://github.com/rails/jsbundling-rails) for JavaScript and [Bootstrap](https://getbootstrap.com/) for styles. This project uses [importmaps](https://github.com/rails/importmap-rails) for JavaScript and [TailwindCSS](https://tailwindcss.com/docs/installation) for styles.

Since `ChatJob` generates an html string for the message chunks, need to configure this as a content source for Tailwind, otherwise, the referenced Tailwind classes will not get included in the Tailwind build/generated css:

```javascript
// config/tailwind.config.js
module.exports = {
  content: [
    ...
    './app/jobs/**/*.rb',
  ],
  ...
}
```

The original tutorial uses `yarn add` to add the [marked](https://github.com/markedjs/marked) and [highlight.js](https://github.com/markedjs/marked) JavaScript dependencies. But this project uses importmaps so the process to add JS libs is different:

```bash
bin/importmap pin marked
# Pinning "marked" to vendor/javascript/marked.js via download from https://ga.jspm.io/npm:marked@12.0.1/lib/marked.esm.js

bin/importmap pin highlight.js
#Pinning "highlight.js" to vendor/javascript/highlight.js.js via download from https://ga.jspm.io/npm:highlight.js@11.9.0/es/index.js
```

The above commands add new `pin` entries to `config/importmap.rb`.

But actually for highlight, the above didn't work, instead I had to write the pin as:

```ruby
# config/importmap.rb

# other pins...

# Ref: https://stackoverflow.com/questions/77539248/adding-highlightjs-to-rails-7-1-with-importmaps
pin "highlight.js", to: "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/es/highlight.min.js"
```

Also need CSS for highlight.js theme, added to `app/views/layouts/application.html.erb`:

```erb
<head>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github-dark.min.css">
</head>
```

### Encoding

Was getting encoding errors from some response chunks from model, fix by specifying UTF-8 encoding:

```ruby
json = JSON.parse(chunk.force_encoding("UTF-8"))
```

### Context

The original tutorial does not include context for conversational history. To have the model remember the past conversations you've been having with it, need to save the `context` from the Ollama [REST API](https://github.com/ollama/ollama/blob/main/docs/api.md) response (for eg: in Rails cache), then include this context in the next Ollama REST API request.

For example:

```ruby
# When making a request
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

# Later when received response with done: true
Net::HTTP.start(uri.hostname, uri.port) do |http|
  http.request(request) do |response|
    response.read_body do |chunk|
      # chunks are json, eg:
      # {"model":"mistral:latest","created_at":"2024-03-18T12:48:19.494759Z","response":" need","done":false}
      # When done is true, we get an empty response, but with `context` populated
      Rails.logger.info("✅ #{chunk.force_encoding('UTF-8')}")
      process_chunk(chunk, rand, chat_id)
    end
  end
end

def process_chunk(chunk, rand, chat_id)
  json = JSON.parse(chunk.force_encoding("UTF-8"))
  done = json["done"]
  if done
    Rails.logger.info("🎉 Done streaming response for chat_id #{chat_id}.")

    # cache context for next inference
    context = json["context"]
    cache_key = "context_#{chat_id}"
    Rails.cache.write(cache_key, context)
    # ...
end
```

### Separate Sessions

With the original tutorial, every connected client subscribes to the same `"welcome"` stream in the welcome index view:

```erb
<%# app/views/welcome/index.html.erb %>
<%= turbo_stream_from "welcome" %>
```

This means if you open multiple browsers (and/or incognito sessions) at `http://localhost:3000`, and type in a question into *any* of them, the model response will be broadcast to *all* browser windows.

To fix this so that each "user", or connected client can have their own unique stream, we need to assign a unique identifier to each chat session. Start in the `WelcomeController` by creating a unique `chat_id` instance variable:

```ruby
# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
  def index
    @chat_id = SecureRandom.hex(20)
    Rails.logger.info("🗞️ Generated chat id: #{@chat_id}")
  end
end
```

Then in the index view, pass the `chat_id` to the `turbo_stream_from` helper. This will ensure a unique `signed_stream_name` is generated. Also, pass the `chat_id` as a local variable to the form partial:

```erb
<!-- app/views/welcome/index.html.erb -->
<div class="w-full">
  <h1>Welcome#index</h1>

  <%# Subscribe to welcome channel for real-time updates via ActionCable %>
  <%# Use chat_id so that each connected client will have a unique chat session %>
  <%= turbo_stream_from @chat_id, "welcome" %>

  <%# Here is where we will stream the responses from the llm %>
  <div id="messages"></div>

  <%# The user types in their prompt here %>
  <%= render "form", chat_id: @chat_id %>
</div>
```

Update the form partial so that the chat_id gets submitted in the POST as a hidden field:

```erb
<!-- app/views/welcome/_form.html.erb -->
<%= form_with url: chats_path, html: { id: "chat_form" } do |f| %>
  <%= f.hidden_field :chat_id, value: chat_id %>
  <div>
    <div>
      <%= f.text_area :message, placeholder: "Your message", autofocus: true %>
    </div>
    <div>
      <%= f.submit "Send" %>
    </div>
  </div>
<% end %>
```

Update the `ChatController` that handles this form POST to pass on the `chat_id` to the `ChatJob`, and also to pass `chat_id` back to the form as a local because it renders a turbo stream response to clear out the form (without refreshing the page, hurray for Turbo!):

```ruby
# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  def create
    # Interaction with LLM can be slow - execute in the background
    ChatJob.perform_later(params[:message], params[:chat_id])

    # In the meantime, clear out the form text area that user just typed
    # render turbo_stream: turbo_stream.replace("chat_form", partial: "welcome/form")
    render turbo_stream: turbo_stream.replace("chat_form", partial: "welcome/form",
                                                           locals: { chat_id: params[:chat_id] })
  end
end
```

Then use `chat_id` in `ChatJob` to distinguish the `context` cache key (as shown earlier in the context section of this document).

Also, use `chat_id` when broadcasting the model response so that it will go to the correct stream. Notice if you pass an array as the first argument to `broadcast_append_to`, it generates a signed stream name from all the array elements:

```ruby
# app/jobs/chat_job.rb
class ChatJob < ApplicationJob
  queue_as :default

  def perform(prompt, chat_id)
    # ...
  end

  # ...

  def broadcast_message(target, message, chat_id)
    # This uses ActionCable to broadcast the html message to the welcome channel.
    # Any view that has subscribed to this channel `turbo_stream_from "welcome"`
    # and the given chat_id will receive the message.
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, html: message
  end
end
```

## Project Setup

Install:
* Ruby version as specified in `.ruby-version` in project root
* [Docker](https://docs.docker.com/get-docker/)
* [Ollama](https://github.com/ollama/ollama)

In one terminal (db unused for now but could be for future)

```bash
docker-compose up
```

In another terminal:

```bash
# Fetch the LLM (Ref: https://ollama.com/library)
ollama pull mistral:latest

# Install projects dependencies and setup database
bin/setup

# Enable dev caching (required for context)
bin/rails dev:cache

# Start Rails server and TailwindCSS build in watch mode
bin/dev
```

Navigate to `http://localhost:3000`

Type in your message/question in the text area and click Send.

## Future Features

* WIP: If there are multiple clients (eg: open several browsers/tabs), it broadcasts to *all* of them
  * Verify by checking `/cable` WS request in dev tools, command/subscribe - signed_stream_name (see if its the same for all)
  * Find which gem `broadcast_append_to` is a part of, its not in official rails docs?
  * Use signed stream and detect signed in user? See https://www.hotrails.dev/turbo-rails/turbo-streams-security
  * This may require adding user sign in, devise (or can it just use a simple session id if want to allow anon usage?)
  * Will need "smarter" cache key for context per user, per chat
  * Consider `session[:session_id]` OR some other kind of unique ID such as `session[:chat_id]`, generating a unique chat id at first POST of chat controller

* ChatJob Refactor
  * Extract interaction with Ollama REST API to `OllamaClient`, something like this: https://github.com/danielabar/echo-weather-rails/blob/main/lib/weather/client.rb
  * Would the ChatJob http code be easier to read with Faraday? It does support [streaming responses](https://lostisland.github.io/faraday/#/adapters/custom/streaming)
  * Model URI should be config/env var rather than hard-coded
  * Mixing of logic and presentation concerns in `ChatJob#message_div` - could this be pulled out into a stream erb response that accepts the rand hex number as a local?
  * Is Redis needed for ActionCable re: `Turbo::StreamsChannel.broadcast_append_to "welcome", target:, html: message` in `ChatJob`?
  * If using a strict form of CSP, the injected inline script from ChatJob might get rejected?

* Maybe related to marked plugin:
  * it removes line breaks, numbered and bullet lists, maybe need to explicitly style these somewhere
  * Also see advanced options: https://marked.js.org/using_advanced#options
  * Maybe need tailwind apply something like this but not exactly: https://dev.to/ewatch/styling-markdown-generated-html-with-tailwind-css-and-parsedown-328d
  * Why aren't code responses from model indented? Should the indents be coming from model response or is this considered client side formatting?

* Also broadcast the question in a different styled div so it looks like a Q & A conversation
* Allow user to select from list of available models (how to handle if prompt format is different for each?)
* Save chat history
* Ability to start a new chat
* Run the same prompt against 2 or more models at the same time for comparison
* Cancel response? (model could get stuck in a loop...)
* Auto scroll as conversation exceeds length of viewport
