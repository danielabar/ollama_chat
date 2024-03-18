# Ollama Chat Rails

Tutorial from (insert link tbd) for building a streaming ai chatbot with Rails and Ollama.

https://youtu.be/hSxmEZjCPP8?si=ps__eK0MbuSDFPXw

Left at 14:01

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
* Save chat history
* Ability to start a new chat
* Run the same prompt against 2 or more models at the same time for comparison
* Would the ChatJob http code be easier to read with Faraday? It does support [streaming responses](https://lostisland.github.io/faraday/#/adapters/custom/streaming)
* Mixing of logic and presentation concerns in `ChatJob#message_div` - could this be pulled out into a stream erb response that accepts the rand hex number as a local?
* Is Redis needed for ActionCable re: `Turbo::StreamsChannel.broadcast_append_to "welcome", target:, html: message` in `ChatJob`?
