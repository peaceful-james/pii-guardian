# PII Guardian

PII Guardian monitors Slack channels and Notion databases, detecting personally identifiable information (PII) in messages and tickets. When PII is found, it removes the content and notifies the author to recreate it without the sensitive information.

## Installation

1. Clone the repository
2. Configure environment variables (see `.env.example`)
3. Install dependencies with `mix deps.get`
4. Start the application with `mix run --no-halt`

## Configuration

PII Guardian requires the following configuration:

### Slack Configuration
- `SLACK_BOT_TOKEN` - Bot token with permissions to read messages, delete messages, and send DMs
- `SLACK_SIGNING_SECRET` - Signing secret for verifying requests from Slack
- `SLACK_WATCHED_CHANNELS` - Comma-separated list of channel IDs to monitor

### Notion Configuration
- `NOTION_API_KEY` - API key with access to read and delete pages in the watched databases
- `NOTION_WATCHED_DATABASES` - Comma-separated list of database IDs to monitor

### AI Service Configuration
- `AI_SERVICE` - Type of AI service to use ("openai", "azure", etc.)
- `AI_SERVICE_API_KEY` - API key for the selected AI service
- `AI_SERVICE_ENDPOINT` - Endpoint URL for the selected AI service (if applicable)

## Development

```bash
mix deps.get
mix test
mix run --no-halt
```

## Testing

```bash
mix test
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
