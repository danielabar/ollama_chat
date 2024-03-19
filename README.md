# Ollama Chat Rails

Tutorial from (insert link tbd) for building a streaming ai chatbot with Rails and Ollama.

https://youtu.be/hSxmEZjCPP8?si=ps__eK0MbuSDFPXw

Left at 24:00

## Notes

Since `ChatJob` generates an html string for the message chunks, need to configure this as a content source for Tailwind, otherwise, the referenced Tailwind classes will not get included in the Tailwind build and generated css:

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

## TBD

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...


## Nice to Have

* Model URI should be config/env var rather than hard-coded
* Allow user to select from list of available models (how to handle if prompt format is different for each?)
* Also broadcast the question in a different styled div so it looks like a Q&A conversation
* Save chat history
* Ability to start a new chat
* Run the same prompt against 2 or more models at the same time for comparison
* Would the ChatJob http code be easier to read with Faraday? It does support [streaming responses](https://lostisland.github.io/faraday/#/adapters/custom/streaming)
* Mixing of logic and presentation concerns in `ChatJob#message_div` - could this be pulled out into a stream erb response that accepts the rand hex number as a local?
* Is Redis needed for ActionCable re: `Turbo::StreamsChannel.broadcast_append_to "welcome", target:, html: message` in `ChatJob`?
* If there are multiple clients (eg: open several browsers/tabs), it broadcasts to *all* of them - use signed stream and detect signed in user? See https://www.hotrails.dev/turbo-rails/turbo-streams-security
