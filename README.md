<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Ollama Chat Rails](#ollama-chat-rails)
  - [Differences in this project from tutorial](#differences-in-this-project-from-tutorial)
    - [JavaScript and CSS Handling](#javascript-and-css-handling)
    - [Encoding](#encoding)
    - [Context](#context)
    - [Separate Sessions](#separate-sessions)
    - [Split up ChatJob Responsibilities](#split-up-chatjob-responsibilities)
    - [Configurable model and API endpoint](#configurable-model-and-api-endpoint)
  - [Project Setup](#project-setup)
  - [Future Features](#future-features)
  - [Deployment](#deployment)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Ollama Chat Rails

Rails project from following along with [Streaming LLM Responses  ▶️](https://youtu.be/hSxmEZjCPP8?si=ps__eK0MbuSDFPXw) for building a streaming AI chatbot with Rails and Ollama.

This project uses Hotwire for SPA like interactivity features including:

* [Turbo Streams](https://github.com/hotwired/turbo-rails?tab=readme-ov-file#come-alive-with-turbo-streams) over websockets (via ActionCable) to stream the response from the LLM to the UI.
* Turbo Stream as regular HTTP response to clear our the chat form without requiring a full page refresh
* [Stimulus](https://github.com/hotwired/stimulus) for some lightweight JS to augment the model responses by converting to markdown and syntax highlighting code blocks (together with the marked and highlight.js libraries).

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

Check dev tools -> Network -> WS -> `/cable` -> Messages -> Filter: `signed_stream_name`

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
    # Any view that has subscribed to this channel `turbo_stream_from @chat_id, "welcome"`
    # will receive the message.
    Turbo::StreamsChannel.broadcast_append_to [chat_id, "welcome"], target:, html: message
  end
end
```

### Split up ChatJob Responsibilities

In the original tutorial, the ChatJob is also responsible for all the stream http request/response with the Ollama REST API.

In this project, that responsibility has been split out to `Ollama::Client` to handle the request, and stream the response back to the client by yielding to a given block.

### Configurable model and API endpoint

In the original tutorial, the model `mistral:latest` and API url `http://localhost:11434/api/generate` are hard-coded in the `ChatJob`. In this version, they're set as environment variables, for example in `.env`:

```bash
CHAT_API_URL=http://localhost:11434/api/generate

# See other values at: https://ollama.com/library
CHAT_MODEL=mistral:latest
```

These are read from a new configuration file:

```yml
# config/chat.yml
default: &default
  chat_api_url: <%= ENV.fetch("CHAT_API_URL") { "http://localhost:11434/api/generate" } %>
  chat_model: <%= ENV.fetch("CHAT_MODEL") { "mistral:latest" } %>

development:
  <<: *default

test:
  <<: *default

production:
  chat_api_url: <%= ENV["CHAT_API_URL"] %>
  chat_model: <%= ENV["CHAT_MODEL"] %>
```

This config is loaded in the application:

```ruby
# config/application.rb
module OllamaChat
  class Application < Rails::Application
    # ...

    # Load custom config
    config.chat = config_for(:chat)
  end
end
```

Then it can be used by `Ollama::Client`:

```ruby
# lib/ollama/client.rb
module Ollama
  class Client
    def initialize(model = nil)
      @uri = URI(Rails.application.config.chat["chat_api_url"])
      @model = model || Rails.application.config.chat["chat_model"]
    end

    # ...
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

* WIP ChatJob Refactor
  * Mixing of logic and presentation concerns in `ChatJob#message_div` - could this be pulled out into a stream erb response that accepts the rand hex number as a local?
  * If using a strict form of CSP, the injected inline script from ChatJob might get rejected?

* Maybe related to marked plugin:
  * it removes line breaks, numbered and bullet lists, maybe need to explicitly style these somewhere
  * Also see advanced options: https://marked.js.org/using_advanced#options
  * Maybe need tailwind apply something like this but not exactly: https://dev.to/ewatch/styling-markdown-generated-html-with-tailwind-css-and-parsedown-328d
  * Why aren't code responses from model indented? Should the indents be coming from model response or is this considered client side formatting?

* Broadcast the question in a different styled div so it looks like a Q & A conversation
* Allow user to select from list of available models (how to handle if prompt format is different for each?)
* Save chat history
* Ability to start a new chat
* Run the same prompt against 2 or more models at the same time for comparison
* Cancel response? (model could get stuck in a loop...)

* Auto scroll as conversation exceeds length of viewport
  * Probably a StimulusJS controller with somewhere this logic: `window.scrollTo(0, document.documentElement.scrollHeight);

## Deployment

For the tutorial, this only runs locally on a laptop. What would it take to deploy this?

* Ollama server running/deployed somewhere accessible to Puma/Rails - auth???
* Sidekiq or some other production quality [backend for ActiveJob](https://guides.rubyonrails.org/active_job_basics.html#backends)
* Redis configured with persistent storage if using Sidekiq as ActiveJob queue adapter
* Redis configured for ActionCable, see `config/cable.yml` (possibly a different Redis instance than that used for Sidekiq/ActiveJob?)
