# PiiGuardian

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Considerations

- The Slack events come via a webhook. If app goes down, we lose events.
- I am verifying the Notion events with the verification token. This is good.
- We should batch updates to the same notion "page" together. `:flow` could be good for this.
- test new slack msg
- test edited slack msg
- test new slack comment
- test edited slack comment
- test new slack attachment
- test edited slack attachment
- use CloudCIX for chatbot with corpus

## For dev

Get notion webhooks by using `ngrok http 4000` and update the URL at Notions "My Creator Profile" in "Integrations".

Source the env vars with `source .env`.
