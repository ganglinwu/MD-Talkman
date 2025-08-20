# MD TalkMan Webhook Server

A Go-based webhook server that receives GitHub webhook events and sends push notifications to the MD TalkMan iOS app for real-time repository synchronization.

## 🚀 Quick Start

### Prerequisites

- Go 1.21 or later
- GitHub App configured with webhook URL
- Apple Developer Account with APNs certificates/keys
- EC2 instance or server with public IP

### 1. Setup GitHub Webhook Secret

In your GitHub App settings:
1. Navigate to **Webhook** section
2. Set **Webhook URL**: `https://your-domain.com/webhook/github`
3. Generate a **Webhook secret** (save this for configuration)
4. Select events: `push`, `installation`, `installation_repositories`

### 2. Configure Environment Variables

```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. APNs Setup (Choose One)

#### Option A: Token-based Authentication (Recommended)
1. In Apple Developer Portal → Keys → Create new key
2. Enable Apple Push Notifications service
3. Download the `.p8` key file
4. Note the Key ID and Team ID

#### Option B: Certificate-based Authentication (Legacy)
1. Create APNs certificate in Apple Developer Portal
2. Export as `.p12` file
3. Configure `APNS_CERT_PATH`

### 4. Run the Server

```bash
# Install dependencies
go mod tidy

# Run in development
go run main.go

# Build for production
go build -o webhook-server main.go
./webhook-server
```

## 📡 API Endpoints

### Webhook Endpoints

- `POST /webhook/github` - Receives GitHub webhooks
- `POST /webhook/register` - Register iOS device for notifications  
- `POST /webhook/unregister` - Unregister iOS device
- `GET /webhook/status` - Get webhook handler status

### Health Endpoints

- `GET /health` - Health check with uptime
- `GET /ready` - Readiness check
- `GET /` - Service information

## 🔧 Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | Server port (default: 8080) |
| `GITHUB_WEBHOOK_SECRET` | Yes | GitHub webhook secret |
| `BUNDLE_ID` | Yes | iOS app bundle identifier |
| `APNS_DEVELOPMENT` | No | Use APNs sandbox (default: true) |
| `APNS_KEY_PATH` | * | Path to APNs .p8 key file |
| `APNS_KEY_ID` | * | APNs key ID |
| `APNS_TEAM_ID` | * | Apple Team ID |
| `APNS_CERT_PATH` | * | Path to APNs .p12 certificate |

*Either key-based OR certificate-based APNs auth required

### GitHub Webhook Events

The server listens for these GitHub events:

- **`push`**: Repository push events (only notifies for .md file changes)
- **`installation`**: App installation/removal events
- **`installation_repositories`**: Repository access changes

## 📱 iOS Integration

### Device Registration

iOS devices must register for push notifications:

```bash
curl -X POST https://your-domain.com/webhook/register \
  -H "Content-Type: application/json" \
  -d '{"device_token": "your_device_token_here"}'
```

### Push Notification Payload

```json
{
  "aps": {
    "alert": {
      "title": "Repository Updated",
      "body": "New changes in your-repo"
    },
    "badge": 1,
    "sound": "default"
  },
  "event_type": "push",
  "repository_name": "your-repo", 
  "installation_id": 12345,
  "action": "synchronize",
  "has_markdown_changes": true,
  "changed_files": ["README.md", "docs/guide.md"]
}
```

## 🏗️ Architecture

```
GitHub → Webhook → Go Server → APNs → iOS App
                     │
                     ├── Signature Verification
                     ├── Event Processing  
                     ├── Markdown File Detection
                     └── Push Notification
```

### Key Components

- **GitHub Service**: Webhook signature verification and event processing
- **APNs Service**: Apple Push Notification handling
- **Webhook Handler**: HTTP request routing and device management
- **Health Handler**: Service monitoring and status checks

## 🔒 Security Features

- **HMAC-SHA256 signature verification** for all GitHub webhooks
- **Device token masking** in logs for privacy
- **Secure APNs token/certificate handling**
- **Environment-based configuration** (no secrets in code)

## 🚀 Deployment

### EC2 Deployment

1. **Upload server files** to EC2 instance
2. **Configure environment variables** (use systemd environment files)
3. **Set up reverse proxy** (nginx/Apache) with SSL
4. **Configure systemd service** for auto-restart
5. **Update GitHub App webhook URL** to your domain

### Example systemd service

```ini
# /etc/systemd/system/mdtalkman-webhook.service
[Unit]
Description=MD TalkMan Webhook Server
After=network.target

[Service]
Type=simple
User=webapp
WorkingDirectory=/opt/mdtalkman-webhook
ExecStart=/opt/mdtalkman-webhook/webhook-server
EnvironmentFile=/etc/mdtalkman-webhook/config.env
Restart=always

[Install]
WantedBy=multi-user.target
```

## 📊 Monitoring

### Log Output
```
2024/08/20 10:30:00 🚀 Starting MD TalkMan Webhook Server...
2024/08/20 10:30:00 ✅ APNs service initialized (development: true)
2024/08/20 10:30:00 🌐 Server starting on port 8080
2024/08/20 10:30:15 Received webhook: Event=push, Delivery=abc-123
2024/08/20 10:30:15 Processed event: Type=push, Repo=my-repo, HasMarkdown=true
2024/08/20 10:30:15 Successfully sent push notifications to 3 devices
```

### Health Monitoring
```bash
# Check server health
curl https://your-domain.com/health

# Check webhook status  
curl https://your-domain.com/webhook/status
```

## 🐛 Troubleshooting

### Common Issues

1. **Invalid webhook signature**: Check `GITHUB_WEBHOOK_SECRET` matches GitHub App
2. **APNs authentication failed**: Verify certificate/key files and permissions
3. **Push notifications not received**: Check device token registration and APNs environment
4. **Server not receiving webhooks**: Verify GitHub App webhook URL and SSL certificate

### Debug Mode

Enable verbose logging:
```bash
export LOG_LEVEL=debug
go run main.go
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## 📄 License

This project is part of the MD TalkMan iOS app.