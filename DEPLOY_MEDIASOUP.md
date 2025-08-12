# Deploy MediaSoup to Linode Server

## Step 1: Upload files to your server

You'll need to upload these files to your Linode server:
- `mediasoup-production-server.js` (the main server file)
- `mediasoup-server/package.json` (dependencies)

## Step 2: SSH into your Linode server

```bash
ssh root@172.236.109.9
```

## Step 3: Create MediaSoup directory

```bash
mkdir -p /opt/arena-mediasoup
cd /opt/arena-mediasoup
```

## Step 4: Create the MediaSoup server file

Copy and paste this content into `/opt/arena-mediasoup/server.js`:

```bash
cat > server.js << 'EOF'
EOF
```

Then copy the entire content of `mediasoup-production-server.js` between the EOF markers.

## Step 5: Create package.json

```bash
cat > package.json << 'EOF'
{
  "name": "arena-mediasoup-server",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.21.2",
    "socket.io": "^4.8.1",
    "mediasoup": "^3.16.7",
    "cors": "^2.8.5"
  }
}
EOF
```

## Step 6: Install dependencies

```bash
npm install
```

## Step 7: Configure firewall

```bash
ufw allow 3001
ufw allow 10000:10100/udp
ufw allow 10000:10100/tcp
```

## Step 8: Start MediaSoup server

```bash
PORT=3001 ANNOUNCED_IP=172.236.109.9 nohup node server.js > mediasoup.log 2>&1 &
```

## Step 9: Verify it's running

```bash
curl http://localhost:3001/
```

You should see:
```json
{
  "message": "Arena MediaSoup SFU Server",
  "status": "running",
  "workers": 4,
  "rooms": 0
}
```

## Step 10: Test from outside

From your local machine:
```bash
curl http://172.236.109.9:3001/
```

Should return the same JSON response.

## Troubleshooting

Check logs:
```bash
tail -f /opt/arena-mediasoup/mediasoup.log
```

Check if process is running:
```bash
ps aux | grep "node server.js"
```

Stop MediaSoup:
```bash
pkill -f "node server.js"
```