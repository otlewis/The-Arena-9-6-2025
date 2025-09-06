# Arena Webhook Deployment Guide 🚀

## Option 1: Deploy to Cloud Run (Recommended for Production)

### Prerequisites
- Google Cloud account with billing enabled
- `gcloud` CLI installed and configured

### Step 1: Create Dockerfile
```dockerfile
# server/Dockerfile
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe webhook_handler.dart -o webhook_handler

FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/webhook_handler /app/webhook_handler

ENV PORT=8080
EXPOSE 8080
CMD ["/app/webhook_handler"]
```

### Step 2: Create pubspec.yaml
```yaml
# server/pubspec.yaml
name: arena_webhook_server
version: 1.0.0

environment:
  sdk: '>=2.17.0 <3.0.0'

dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  appwrite: ^11.0.0
```

### Step 3: Deploy to Cloud Run
```bash
# Build and deploy
gcloud run deploy arena-webhook \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars APPWRITE_ENDPOINT="https://cloud.appwrite.io/v1" \
  --set-env-vars APPWRITE_PROJECT_ID="YOUR_PROJECT_ID" \
  --set-env-vars APPWRITE_API_KEY="YOUR_API_KEY" \
  --set-env-vars WEBHOOK_SECRET="YOUR_WEBHOOK_SECRET"

# Get the webhook URL
gcloud run services describe arena-webhook --region us-central1 --format 'value(status.url)'
```

Your webhook URL will be: `https://arena-webhook-xxxxx-uc.a.run.app/webhooks/revenuecat`

## Option 2: Deploy to Vercel (Serverless)

### Step 1: Create Vercel Function
```javascript
// api/webhooks/revenuecat.js
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { Client, Databases, ID } = require('node-appwrite');
  
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
    
  const databases = new Databases(client);
  
  try {
    const payload = req.body;
    // Process webhook (implement logic from webhook_handler.dart)
    
    res.status(200).json({ status: 'success' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}
```

### Step 2: Deploy to Vercel
```bash
vercel --prod
```

Your webhook URL will be: `https://your-app.vercel.app/api/webhooks/revenuecat`

## Option 3: Deploy to Your Own Server (VPS)

### Prerequisites
- Ubuntu 20.04+ server with public IP
- Domain name pointed to server
- SSL certificate (use Let's Encrypt)

### Step 1: Install Dart on Server
```bash
# SSH into your server
ssh root@your-server-ip

# Install Dart
sudo apt update
sudo apt install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt update
sudo apt install dart
```

### Step 2: Setup the Webhook Server
```bash
# Create app directory
mkdir -p /opt/arena-webhook
cd /opt/arena-webhook

# Copy files (from local)
scp server/* root@your-server-ip:/opt/arena-webhook/

# Install dependencies
dart pub get

# Compile the app
dart compile exe webhook_handler.dart -o webhook_handler

# Create systemd service
cat > /etc/systemd/system/arena-webhook.service << EOF
[Unit]
Description=Arena Webhook Handler
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/arena-webhook
Environment="APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1"
Environment="APPWRITE_PROJECT_ID=YOUR_PROJECT_ID"
Environment="APPWRITE_API_KEY=YOUR_API_KEY"
Environment="WEBHOOK_SECRET=YOUR_WEBHOOK_SECRET"
Environment="PORT=8080"
ExecStart=/opt/arena-webhook/webhook_handler
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl enable arena-webhook
systemctl start arena-webhook
```

### Step 3: Setup Nginx Reverse Proxy
```nginx
# /etc/nginx/sites-available/webhook
server {
    listen 80;
    server_name webhook.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name webhook.your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/webhook.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webhook.your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Enable site and restart nginx
ln -s /etc/nginx/sites-available/webhook /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

Your webhook URL will be: `https://webhook.your-domain.com/webhooks/revenuecat`

## Configure RevenueCat Webhook

1. Go to RevenueCat Dashboard → Project Settings → Integrations → Webhooks
2. Click "Add Webhook"
3. Enter your webhook URL
4. Select events to receive (recommend all events)
5. Add authorization header if using webhook secret: `Bearer YOUR_WEBHOOK_SECRET`
6. Save and test the webhook

## Testing the Webhook

### 1. Test Endpoint
```bash
curl https://your-webhook-url/health
# Should return: {"status":"healthy","service":"arena-webhook-handler"}
```

### 2. Send Test Webhook
```bash
curl -X POST https://your-webhook-url/webhooks/revenuecat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_WEBHOOK_SECRET" \
  -d '{
    "event": {
      "type": "TEST",
      "app_user_id": "test_user",
      "product_id": "arena_pro_monthly",
      "event_timestamp_ms": 1234567890000,
      "environment": "SANDBOX"
    }
  }'
```

### 3. Monitor Logs
```bash
# Cloud Run
gcloud run logs read arena-webhook --region us-central1

# VPS with systemd
journalctl -u arena-webhook -f

# Vercel
vercel logs
```

## Security Checklist

- [ ] **HTTPS Only**: Webhook endpoint uses SSL/TLS
- [ ] **Secret Token**: Webhook secret configured in RevenueCat and server
- [ ] **IP Whitelist**: (Optional) Restrict to RevenueCat IPs
- [ ] **Rate Limiting**: Implement rate limiting on webhook endpoint
- [ ] **Error Handling**: Proper error responses without exposing sensitive data
- [ ] **Monitoring**: Set up alerts for webhook failures
- [ ] **Backup**: Have fallback webhook endpoint ready

## RevenueCat Webhook IPs (for whitelisting)
```
3.15.188.115
3.133.157.47
3.21.150.131
```

## Troubleshooting

### Webhook not receiving events
1. Check RevenueCat webhook logs in dashboard
2. Verify URL is correct and publicly accessible
3. Check authorization header matches
4. Review server logs for errors

### Database write failures
1. Verify Appwrite API key has write permissions
2. Check collection names match exactly
3. Ensure all required fields are present

### SSL/TLS errors
1. Ensure valid SSL certificate
2. Check certificate hasn't expired
3. Verify full certificate chain is installed

---

## Next Steps

1. Deploy webhook handler using one of the methods above
2. Configure webhook URL in RevenueCat dashboard
3. Make a sandbox purchase to test the flow
4. Monitor Appwrite collections for webhook events
5. Enable production payments when ready!