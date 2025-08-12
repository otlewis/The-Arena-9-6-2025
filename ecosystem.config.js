module.exports = {
  apps: [
    {
      name: 'arena-mediasoup',
      script: './mediasoup-scalable-server.js',
      instances: 1, // Single instance for 2-CPU server
      exec_mode: 'cluster',
      watch: false,
      max_memory_restart: '1G',
      
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
        SERVER_ID: 'server-1',
        ANNOUNCED_IP: process.env.PUBLIC_IP || '172.236.109.9',
        REDIS_HOST: 'localhost',
        REDIS_PORT: 6379,
        MEDIASOUP_WORKERS: 2,
      },
      
      // Auto-restart settings
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      
      // Logging
      error_file: './logs/mediasoup-error.log',
      out_file: './logs/mediasoup-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      
      // Monitoring
      instance_var: 'INSTANCE_ID',
      
      // Graceful shutdown
      kill_timeout: 5000,
      listen_timeout: 3000,
      
      // Performance optimized for 4GB RAM
      node_args: '--max-old-space-size=2048',
    },
    
    // Load balancer
    {
      name: 'arena-load-balancer',
      script: './load-balancer.js',
      instances: 1,
      watch: false,
      
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
        REDIS_HOST: 'localhost',
        REDIS_PORT: 6379,
      },
    },
    
    // Metrics collector
    {
      name: 'arena-metrics',
      script: './metrics-collector.js',
      instances: 1,
      watch: false,
      
      env: {
        NODE_ENV: 'production',
        REDIS_HOST: 'localhost',
        REDIS_PORT: 6379,
        METRICS_PORT: 9090,
      },
    },
  ],
  
  deploy: {
    production: {
      user: 'root',
      host: ['server1.arena.com', 'server2.arena.com', 'server3.arena.com'],
      ref: 'origin/main',
      repo: 'git@github.com:yourusername/arena.git',
      path: '/var/www/arena',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
    },
  },
};