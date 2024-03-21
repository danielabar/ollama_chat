# Ollama Chat Rails

Rails project from following along with [Streaming LLM Responses ▶️](https://youtu.be/hSxmEZjCPP8?si=ps__eK0MbuSDFPXw) for building a streaming AI chatbot with Rails and Ollama.

## Differences in this project from tutorial

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

* Maybe related to marked plugin:
  * it removes line breaks, numbered and bullet lists, maybe need to explicitly style these somewhere
  * Also see advanced options: https://marked.js.org/using_advanced#options
  * Maybe need tailwind apply something like this but not exactly: https://dev.to/ewatch/styling-markdown-generated-html-with-tailwind-css-and-parsedown-328d
* Model URI should be config/env var rather than hard-coded
* Allow user to select from list of available models (how to handle if prompt format is different for each?)
* Also broadcast the question in a different styled div so it looks like a Q & A conversation
* Save chat history
* Ability to start a new chat
* Run the same prompt against 2 or more models at the same time for comparison
* Would the ChatJob http code be easier to read with Faraday? It does support [streaming responses](https://lostisland.github.io/faraday/#/adapters/custom/streaming)
* Mixing of logic and presentation concerns in `ChatJob#message_div` - could this be pulled out into a stream erb response that accepts the rand hex number as a local?
* Is Redis needed for ActionCable re: `Turbo::StreamsChannel.broadcast_append_to "welcome", target:, html: message` in `ChatJob`?
* If there are multiple clients (eg: open several browsers/tabs), it broadcasts to *all* of them
  * Use signed stream and detect signed in user? See https://www.hotrails.dev/turbo-rails/turbo-streams-security
  * This may require adding user sign in, devise (or can it just use a simple session id if want to allow anon usage?)
  * Will need "smarter" cache key for context per user, per chat
* If using a strict form of CSP, the injected inline script from ChatJob might get rejected?
* Why isn't code indented? Should the indents be coming from model response or is this considered client side formatting?
* Cancel response? (model could get stuck in a loop...)
