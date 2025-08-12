# Manual MediaSoup Deployment to Linode

Since we need SSH access to your Linode server, here are the manual steps to deploy:

## Step 1: Connect to Your Linode Server
```bash
ssh root@172.236.109.9
```
(Enter your password when prompted)

## Step 2: Install Node.js and PM2
```bash
# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install PM2 globally  
npm install -g pm2

# Verify installation
node --version
npm --version
pm2 --version
```

## Step 3: Create App Directory
```bash
mkdir -p /var/www/arena
cd /var/www/arena
```

## Step 4: Create package.json
```bash
cat > package.json << 'EOF'
{
  "name": "arena-mediasoup-single",
  "version": "1.0.0",
  "description": "Single MediaSoup server for Arena app",
  "main": "start-mediasoup-single.cjs",
  "scripts": {
    "start": "node start-mediasoup-single.cjs"
  },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.6.1",
    "mediasoup": "^3.13.0",
    "cors": "^2.8.5"
  }
}
EOF
```

## Step 5: Install Dependencies
```bash
npm install
```

## Step 6: Configure Firewall
```bash
# Allow required ports
ufw allow 3001
ufw allow 10000:10100/udp
ufw status
```

## Step 7: Create MediaSoup Server File

I'll provide the server code that you need to copy to your server. The complete file is in `start-mediasoup-single.cjs` in your local Arena project.

## Step 8: Start MediaSoup Server
```bash
pm2 start start-mediasoup-single.cjs --name arena-mediasoup
pm2 save
pm2 startup
```

## Step 9: Test Deployment
```bash
# Check status
pm2 status

# Check logs  
pm2 logs arena-mediasoup

# Test health endpoint
curl http://localhost:3001/health
```

## Step 10: Verify External Access
From your local machine:
```bash
curl http://172.236.109.9:3001/health
```

Would you like me to help you with any specific step, or do you have access to your Linode server to begin the deployment?