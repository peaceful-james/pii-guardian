# PII Guardian - Elixir Application Architecture

## Overview
PII Guardian monitors Slack channels and Notion databases, detecting personally identifiable information (PII) in messages and tickets. When PII is found, it removes the content and notifies the author to recreate it without the sensitive information.

## System Components

### Core Application
- `PiiGuardian.Application` - Main application supervisor
- `PiiGuardian.PubSub` - Internal event pub/sub system

### Slack Integration
- `PiiGuardian.Slack.Supervisor` - Manages Slack-related processes
- `PiiGuardian.Slack.Connector` - Handles Slack API authentication and real-time messaging
- `PiiGuardian.Slack.EventHandler` - Processes incoming Slack events
- `PiiGuardian.Slack.MessageProcessor` - Extracts message content for analysis
- `PiiGuardian.Slack.Actions` - Functions for message deletion and user notifications

### Notion Integration
- `PiiGuardian.Notion.Supervisor` - Manages Notion-related processes
- `PiiGuardian.Notion.Connector` - Handles Notion API authentication
- `PiiGuardian.Notion.Poller` - Periodically checks for new/updated database entries
- `PiiGuardian.Notion.PageProcessor` - Extracts content from Notion pages
- `PiiGuardian.Notion.Actions` - Functions for page deletion and author identification

### PII Detection
- `PiiGuardian.PII.Analyzer` - Coordinates PII analysis using multiple detectors
- `PiiGuardian.PII.TextDetector` - Analyzes text content for PII
- `PiiGuardian.PII.ImageDetector` - Extracts and analyzes text from images
- `PiiGuardian.PII.PDFDetector` - Extracts and analyzes text from PDFs
- `PiiGuardian.PII.AIService` - Integration with AI services for PII detection

### User Management
- `PiiGuardian.Users.Resolver` - Maps between Notion and Slack users

### Configuration
- `PiiGuardian.Config` - Application configuration management
- `PiiGuardian.Config.SlackChannels` - Maintains list of watched Slack channels
- `PiiGuardian.Config.NotionDatabases` - Maintains list of watched Notion databases

## Data Flow

1. **Slack Message Flow**:
   - Real-time event received from Slack API
   - Event filtered for messages in watched channels
   - Message content extracted (text, images, files)
   - Content analyzed for PII
   - If PII found:
     - Message deleted via Slack API
     - Original author notified via DM

2. **Notion Page Flow**:
   - Poller retrieves recent database entries
   - New/modified pages identified
   - Page content extracted (text, images, PDFs, fields)
   - Content analyzed for PII
   - If PII found:
     - Page deleted via Notion API
     - Author's email retrieved
     - Slack user found by matching email
     - Author notified via Slack DM

## Technical Specifications

### Elixir/OTP Details
- Use of GenServers for stateful processes
- Supervision trees for fault tolerance
- Use of Tasks for concurrent processing
- Oban for background job processing

### External Dependencies
- `slack` for Slack RTM and Web API integration
- `notion` for Notion API integration
- AI service for PII detection (OpenAI API, Azure AI, etc.)
- `jason` for JSON handling
- `finch` for HTTP requests
- `oban` for background jobs
- `tesla` for API client functionality
- `ex_aws` for document/image processing (optional)
- `pdf_text` or similar for PDF text extraction

### Deployment Considerations
- Kubernetes or similar container orchestration
- Monitoring with Prometheus/Grafana
- Secret management for API keys
- Rate limiting strategies for API calls
- Circuit breakers for external service calls

### Database/Storage
- PostgreSQL for storing configuration and operational data
- Redis for rate limiting and temporary state

### Testing Strategy
- Unit tests for core logic
- Integration tests with mock API responses
- Property-based testing for PII detection
- End-to-end testing with actual API connections (for CI environments)

## Project Structure
```
pii_guardian/
├── .formatter.exs
├── .gitignore
├── README.md
├── mix.exs
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── test.exs
├── lib/
│   ├── pii_guardian/
│   │   ├── application.ex
│   │   ├── pub_sub.ex
│   │   ├── slack/
│   │   │   ├── supervisor.ex
│   │   │   ├── connector.ex
│   │   │   ├── event_handler.ex
│   │   │   ├── message_processor.ex
│   │   │   └── actions.ex
│   │   ├── notion/
│   │   │   ├── supervisor.ex
│   │   │   ├── connector.ex
│   │   │   ├── poller.ex
│   │   │   ├── page_processor.ex
│   │   │   └── actions.ex
│   │   ├── pii/
│   │   │   ├── analyzer.ex
│   │   │   ├── text_detector.ex
│   │   │   ├── image_detector.ex
│   │   │   ├── pdf_detector.ex
│   │   │   └── ai_service.ex
│   │   ├── users/
│   │   │   └── resolver.ex
│   │   └── config/
│   │       ├── slack_channels.ex
│   │       └── notion_databases.ex
│   └── pii_guardian.ex
└── test/
    ├── pii_guardian/
    │   ├── slack_test.exs
    │   ├── notion_test.exs
    │   ├── pii_test.exs
    │   └── users_test.exs
    └── test_helper.exs
```

## Implementation Strategy

### Phase 1: Core Infrastructure
- Project setup and dependencies
- Configuration system
- PubSub mechanism
- Basic supervision tree

### Phase 2: Slack Integration
- Authentication with Slack API
- Real-time messaging connection
- Message event filtering
- Basic message processing

### Phase 3: Notion Integration
- Authentication with Notion API
- Database polling system
- Page content extraction
- Basic page processing

### Phase 4: PII Detection
- AI service integration
- Text-based PII detection
- Image-based PII detection (OCR + analysis)
- PDF-based PII detection

### Phase 5: User Resolution and Notifications
- User mapping between systems
- Notification system for authors
- Content deletion implementation

### Phase 6: Testing and Hardening
- Comprehensive test suite
- Error handling improvements
- Rate limiting and backoff strategies
- Monitoring and logging

### Phase 7: Deployment
- Containerization
- CI/CD pipeline setup
- Production environment configuration
- Documentation
