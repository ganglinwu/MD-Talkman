# The Great GitHub Webhook Debugging Adventure

*A tale of microservices, containers, and the mysterious case of the missing headers*

## The Setup

I was working on **MD TalkMan**, a SwiftUI app for hands-free markdown reading with Claude.ai integration. The app has a sophisticated webhook system:

- **iOS App**: SwiftUI with GitHub Apps integration
- **Go Webhook Server**: Production-ready server deployed on EC2
- **GitHub App**: With JWT authentication and webhook subscriptions
- **Infrastructure**: Docker containers behind nginx, fronted by AWS CloudFront

The webhook flow should be simple:
```
GitHub Repository → Webhook → Go Server → APNs → iOS App
```

## The Mystery Begins

After pushing commits to my GitHub repository, I expected to see webhook logs in my Docker container. Instead: **complete silence**.

```bash
$ docker logs mdtalkman-webhook
# crickets... 🦗
```

## Investigation Phase 1: "Are Webhooks Even Enabled?"

**First suspect**: Maybe webhooks were disabled in the GitHub App settings.

Looking at my `WEBHOOK-CONFIG.md`, I found this smoking gun:
```markdown
## Current Status: Webhooks Disabled ✅
- ✅ **Webhook URL**: Empty (no URL configured)
- ❌ **Active**: Unchecked (webhooks disabled)
```

But wait! When I checked the actual GitHub App settings, webhooks WERE enabled with a proper URL. The documentation was outdated.

**Status**: False alarm, webhooks were properly configured.

## Investigation Phase 2: "The Container Mystery"

Next theory: Maybe the webhook container wasn't running or accessible.

```bash
$ docker ps | grep webhook
10ddbc7389ce   ganglinwu/mdtalkman-webhook:v1.2   Up 31 hours (healthy)   8081/tcp
```

Container was running and healthy. Let's check the logs:

```bash
$ docker logs mdtalkman-webhook
2025/08/22 00:35:16 🚀 Starting MD TalkMan Webhook Server...
2025/08/22 00:35:16 ✅ MD TalkMan Webhook Server is running!
2025/08/22 00:35:32 Received webhook: Event=ping, Delivery=
2025/08/22 00:35:32 Warning: No signature provided for delivery (testing mode)
```

**Plot twist**: The webhook server WAS receiving events! There was a ping event from my manual testing. But no logs from actual GitHub pushes.

**Status**: Container working, but GitHub pushes not reaching it.

## Investigation Phase 3: "The GitHub App Configuration Deep Dive"

Time to examine the GitHub App settings screenshots:

**Webhooks Configuration:**
- ✅ Active: Checked
- ✅ Webhook URL: `http://18.140.54.239/webhook/github` 
- ✅ Webhook Secret: Configured
- ✅ Push Events: Subscribed

**Repository Permissions:**
- ✅ Contents: Read and write
- ✅ Metadata: Read-only  
- ✅ Webhooks: Read and write

Everything looked correct! But then I checked GitHub's "Recent Deliveries" section...

**Eureka moment**: GitHub showed successful webhook deliveries with green checkmarks! 

```
✅ 1f397e2a-7ff6-11f0-83b9-a92ac28d548c push 2025-08-23 15:52:32
```

So GitHub WAS sending webhooks, and they were being delivered successfully. But my container logs showed nothing.

**Status**: GitHub delivering webhooks, but they're disappearing somewhere between GitHub and my container.

## Investigation Phase 4: "The Nginx Routing Mystery"

If GitHub is delivering but my container isn't logging, the issue must be in nginx routing.

Looking at the nginx configuration:
```nginx
upstream webhook_backend {
    server webhook-server:8080;  # 🚨 Suspicious port
}
```

But my container was running on port 8081:
```bash
0.0.0.0:8081->8081/tcp
```

**First red herring**: I thought this was the issue, but checking the actual nginx config showed it was already correct:
```nginx
upstream webhook_backend {
    server webhook-server:8081;  # Port was actually correct
}
```

Let me test nginx connectivity:
```bash
$ docker exec -it nginx curl http://webhook-server:8081/health
# No response... 🤔
```

But testing externally worked:
```bash
$ curl http://18.140.54.239:8081/health
{"status":"healthy"}  # ✅ Works
```

**The real issue**: Container name mismatch!

Looking at the Docker network:
```bash
$ docker network inspect todoapp
"Containers": {
    "mdtalkman-webhook": {...},  # ← Actual container name
    "nginx": {...},
    "backend": {...}
}
```

The nginx config referenced `webhook-server:8081`, but the actual container name was `mdtalkman-webhook`!

**Status**: Found the routing issue - container name mismatch.

## The Fix (Attempt 1)

Updated nginx config:
```nginx
upstream webhook_backend {
    server mdtalkman-webhook:8081;  # Fixed container name
}
```

Restarted nginx and tested:
```bash
$ docker exec -it nginx curl http://mdtalkman-webhook:8081/health
{"status":"healthy"}  # ✅ Now working!
```

Pushed another commit and checked logs... **Still nothing!** 😫

## Investigation Phase 5: "The Case of the Missing Headers"

The routing was fixed, but something was still wrong. Let me test the full nginx proxy path:

```bash
$ docker exec -it nginx curl -X POST http://localhost/webhook/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{"test": "proxy_test"}'
```

Checking webhook container logs:
```
2025/08/23 08:42:37 Received webhook: Event=push, Delivery=
2025/08/23 08:42:37 Processed event: Type=push, Repo=, Action=, HasMarkdown=false
```

**Success!** The routing was working. But wait - let me check what happens with real GitHub webhooks:

```
2025/08/23 08:37:33 Received webhook: Event=, Delivery=
2025/08/23 08:37:33 Warning: No signature provided for delivery (testing mode)
```

**The smoking gun**: GitHub webhooks were arriving with **empty headers**!
- `Event=` (should be `Event=push`)  
- `Delivery=` (should have a UUID)
- No signature (hence "testing mode")

But my test curl from inside nginx showed `Event=push` working. This meant nginx header forwarding worked, but something was stripping the headers from GitHub's requests.

**Status**: Headers being stripped somewhere between GitHub and nginx.

## Investigation Phase 6: "The AWS CloudFront Culprit"

Looking at the nginx access logs:
```
3.172.32.142 - - [23/Aug/2025:08:37:33 +0000] "POST /webhook/github HTTP/1.1" 200 53 "-" "Amazon CloudFront"
```

**The smoking gun**: `"Amazon CloudFront"`! 

The webhook URL was `http://18.140.54.239/webhook/github`, but it was actually routed through `guenyanghae.com`, which uses AWS CloudFront as a CDN.

**The issue**: CloudFront was stripping the GitHub webhook headers!

By default, CloudFront doesn't forward custom headers like:
- `X-GitHub-Event`
- `X-GitHub-Delivery` 
- `X-Hub-Signature-256`

So GitHub was sending the headers, CloudFront was discarding them, and nginx was receiving requests with no GitHub-specific headers.

## The Final Fix

**Solution**: Bypass CloudFront for webhooks by using the direct EC2 IP address.

Changed GitHub App webhook URL from:
```
https://guenyanghae.com/webhook/github  # ❌ Goes through CloudFront
```

To:
```
http://18.140.54.239/webhook/github     # ✅ Direct to EC2
```

Pushed another commit and finally saw the magic:

```
2025/08/23 09:07:57 Received webhook: Event=push, Delivery=a8e40a3c-8000-11f0-8af7-cceab2d4d761
2025/08/23 09:07:57 Processed event: Type=push, Repo=MD-Talkman, Action=, HasMarkdown=true
2025/08/23 09:07:57 Skipping notification: ShouldNotify=true, DeviceTokens=0
```

**Success!** 🎉
- ✅ Event type: `push`
- ✅ Delivery ID: Present and valid
- ✅ Repository: `MD-Talkman` 
- ✅ Markdown detection: `HasMarkdown=true`
- ✅ Notification logic: `ShouldNotify=true`

## Lessons Learned

### 1. **CDNs and Webhooks Don't Mix**
CloudFront (and most CDNs) strip custom headers by default. For webhooks, you need either:
- Direct server access (bypass CDN)
- Explicit header whitelisting in CDN config
- API Gateway with proper header forwarding

### 2. **Container Networking is Tricky**
Docker Compose creates containers with specific names, not the service names you expect. Always check:
```bash
docker network inspect <network-name>
```

### 3. **Debug Layer by Layer** 
The debugging process was:
1. ✅ GitHub App configuration
2. ✅ Container health and logs  
3. ✅ Network connectivity
4. ✅ Nginx routing
5. ❌ **Header preservation** ← The real issue

### 4. **GitHub's Delivery Dashboard is Gold**
The GitHub App's "Recent Deliveries" section shows exactly what GitHub attempted to deliver and the response codes. This was crucial for understanding that GitHub was successfully sending webhooks.

### 5. **Test Each Layer Independently**
- Manual curl to container: ✅ Container works
- Curl through nginx: ✅ Routing works  
- Curl with headers through nginx: ✅ Header forwarding works
- GitHub webhooks: ❌ Headers stripped by CloudFront

## The Architecture That Finally Worked

```
GitHub Repository
    ↓ webhook (with headers)
Direct HTTP to EC2 IP (bypass CloudFront)
    ↓ 
nginx (proxy with header forwarding)
    ↓
Docker container network
    ↓
Go webhook server (mdtalkman-webhook:8081)
    ↓ 
Webhook processing with full GitHub headers
```

## Final Status

✅ **Webhooks**: Fully functional  
✅ **Header Preservation**: GitHub headers intact  
✅ **Signature Verification**: Working (when secret provided)  
✅ **Markdown Detection**: Filtering works  
✅ **Repository Parsing**: Correct repo identification

The only missing piece is `DeviceTokens=0` - no iOS devices registered for push notifications yet. But that's Phase 3 of the project!

**Total debugging time**: ~3 hours  
**Root cause**: AWS CloudFront stripping GitHub webhook headers  
**Solution**: Bypass CDN for webhook endpoints  
**Coffee consumed**: Too much ☕

## The AWS Lambda Question: Are Others Affected Too?

After solving this, I wondered: **"What about all those AWS Lambda webhook tutorials? Wouldn't they hit the same CloudFront header stripping issue?"**

The answer is nuanced and reveals why this problem isn't more widely known:

### Scenario 1: Lambda Behind CloudFront (Problematic) 
If you put Lambda behind CloudFront:
```
GitHub → CloudFront → Lambda Function URL/API Gateway → Lambda
```
**Yes, you'd face the exact same header stripping issue** we just solved.

### Scenario 2: Direct Lambda Invocation (Safe)
Most webhook tutorials recommend:
```
GitHub → API Gateway (direct) → Lambda
GitHub → Lambda Function URL (direct) → Lambda  
```
This bypasses CloudFront entirely, preserving all headers.

### Scenario 3: CloudFront with Proper Configuration (Complex)
You *can* use CloudFront with webhooks, but you must explicitly whitelist headers:
```javascript
// CloudFront behavior settings
"AllowedMethods": ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"],
"ForwardedValues": {
  "Headers": [
    "X-GitHub-Event",
    "X-GitHub-Delivery", 
    "X-Hub-Signature-256",
    "X-Hub-Signature"  // Legacy webhook signature
  ]
}
```

### Why Most People Don't Hit This Issue

1. **AWS Tutorials**: Most Lambda webhook examples use direct API Gateway endpoints, not CloudFront
2. **No Caching Need**: Webhooks don't benefit from CDN caching - they're one-time POST requests  
3. **Latency Irrelevant**: Webhook delivery speed isn't user-facing
4. **Separate Domains**: Many use separate subdomains for APIs (api.example.com) vs web (www.example.com)

### The Trap We Fell Into

Our architecture:
```
GitHub → guenyanghae.com (CloudFront) → EC2 nginx → Docker container
```

Typical Lambda setup:
```  
GitHub → Direct API Gateway → Lambda
```

### Real-World Impact

This likely affects developers who:
- Use custom domains with CloudFront for their entire infrastructure
- Route webhook endpoints through the same domain as their web app
- Don't realize CloudFront is intercepting webhook requests
- Assume their CDN will "just work" with webhooks

**The broader lesson**: **Webhooks should typically bypass CDNs entirely** since they don't benefit from caching and CDNs often interfere with custom headers. This CloudFront header issue is probably a silent problem for many webhook implementations that happen to go through CDNs!

---

*Sometimes the simplest solutions are the hardest to find. In this case, the entire webhook infrastructure was perfect - it just needed to avoid a well-meaning CDN that was "helping" by discarding headers it didn't recognize. The real lesson? When building webhook endpoints, always ask: "Is there a CDN between GitHub and my server?" If yes, either bypass it or configure it properly.*