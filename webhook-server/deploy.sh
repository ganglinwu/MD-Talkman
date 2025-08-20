#!/bin/bash

# MD TalkMan Webhook Server Deployment Script

set -e  # Exit on any error

echo "🚀 Deploying MD TalkMan Webhook Server..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo "Please copy .env.docker to .env and configure your settings."
    exit 1
fi

# Check if certificates directory exists
if [ ! -d "certs" ]; then
    echo -e "${YELLOW}⚠️  Creating certs directory...${NC}"
    mkdir -p certs
    echo "Please add your APNs certificate/key files to the certs/ directory"
fi

# Function to check if required environment variables are set
check_env() {
    local var_name=$1
    local var_value=$(grep "^$var_name=" .env | cut -d '=' -f2)
    
    if [ -z "$var_value" ] || [ "$var_value" = "your_${var_name,,}_here" ]; then
        echo -e "${RED}❌ $var_name not configured in .env file${NC}"
        return 1
    fi
    return 0
}

# Check required environment variables
echo "🔍 Checking configuration..."

if ! check_env "GITHUB_WEBHOOK_SECRET"; then
    echo "Please set GITHUB_WEBHOOK_SECRET in your .env file"
    exit 1
fi

if ! check_env "APNS_KEY_ID" && ! check_env "APNS_CERT_PATH"; then
    echo "Please configure either APNS_KEY_ID or APNS_CERT_PATH in your .env file"
    exit 1
fi

echo -e "${GREEN}✅ Configuration looks good!${NC}"

# Build and start the containers
echo "🔨 Building Docker image..."
docker-compose build

echo "🚀 Starting webhook server..."
docker-compose up -d

# Wait for health check
echo "⏳ Waiting for server to be healthy..."
sleep 10

# Check if server is running
if docker-compose ps | grep -q "Up (healthy)"; then
    echo -e "${GREEN}✅ Webhook server is running and healthy!${NC}"
    echo
    echo "🌐 Service URLs:"
    echo "   Health check: http://localhost:8080/health"
    echo "   Webhook endpoint: http://localhost:8080/webhook/github" 
    echo "   Status: http://localhost:8080/webhook/status"
    echo
    echo "📱 To register an iOS device:"
    echo "   curl -X POST http://localhost:8080/webhook/register \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"device_token\": \"your_device_token\"}'"
    echo
    echo "🔧 Next steps:"
    echo "   1. Update GitHub App webhook URL to your domain"
    echo "   2. Test webhook delivery from GitHub"
    echo "   3. Register iOS devices for push notifications"
else
    echo -e "${RED}❌ Server failed to start or is unhealthy${NC}"
    echo "Check logs with: docker-compose logs webhook-server"
    exit 1
fi

echo -e "${GREEN}🎉 Deployment complete!${NC}"