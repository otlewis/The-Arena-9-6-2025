import express from 'express';
import { createServer } from 'http';
import { Server as SocketServer } from 'socket.io';
import { format } from 'date-fns';

/**
 * Real-time Dashboard Server for Arena Launch Monitoring
 * 
 * Provides a web-based dashboard with live metrics and alerts
 */

export class DashboardServer {
  constructor() {
    this.app = express();
    this.server = createServer(this.app);
    this.io = new SocketServer(this.server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      }
    });
    
    this.port = process.env.DASHBOARD_PORT || 3001;
    this.metrics = null;
    this.setupRoutes();
    this.setupSocketHandlers();
  }

  setupRoutes() {
    // Serve static dashboard HTML
    this.app.get('/', (req, res) => {
      res.send(this.getDashboardHTML());
    });

    // API endpoints
    this.app.get('/api/metrics', (req, res) => {
      res.json({
        metrics: this.metrics,
        timestamp: new Date().toISOString(),
        status: 'active'
      });
    });

    this.app.get('/api/health', (req, res) => {
      const healthScore = this.calculateOverallHealth();
      res.json({
        health: healthScore,
        status: healthScore >= 90 ? 'excellent' : 
               healthScore >= 70 ? 'good' : 
               healthScore >= 50 ? 'warning' : 'critical',
        timestamp: new Date().toISOString()
      });
    });
  }

  setupSocketHandlers() {
    this.io.on('connection', (socket) => {
      console.log('📊 Dashboard client connected');
      
      // Send current metrics on connection
      if (this.metrics) {
        socket.emit('metrics', this.metrics);
      }
      
      socket.on('disconnect', () => {
        console.log('📊 Dashboard client disconnected');
      });
    });
  }

  async start(metrics) {
    this.metrics = metrics;
    
    return new Promise((resolve) => {
      this.server.listen(this.port, () => {
        console.log(`📊 Dashboard running at http://localhost:${this.port}`);
        resolve();
      });
    });
  }

  async stop() {
    return new Promise((resolve) => {
      this.server.close(() => {
        console.log('📊 Dashboard server stopped');
        resolve();
      });
    });
  }

  updateMetrics(metrics) {
    this.metrics = metrics;
    
    // Broadcast to all connected clients
    this.io.emit('metrics', metrics);
  }

  calculateOverallHealth() {
    if (!this.metrics) return 100;
    
    const weights = {
      timers: 0.3,    // 30% weight - most critical
      rooms: 0.25,    // 25% weight
      database: 0.25, // 25% weight
      agora: 0.2      // 20% weight
    };
    
    const scores = {
      timers: this.metrics.timers.syncAccuracy,
      rooms: this.metrics.rooms.successRate,
      database: this.metrics.database.connectionHealth,
      agora: this.metrics.agora.connectionSuccessRate
    };
    
    return Math.round(
      (scores.timers * weights.timers) +
      (scores.rooms * weights.rooms) +
      (scores.database * weights.database) +
      (scores.agora * weights.agora)
    );
  }

  getDashboardHTML() {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Arena Launch Monitor</title>
    <script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #0a0f1b;
            color: #ffffff;
            line-height: 1.6;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 1rem 2rem;
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 2rem; }
        .header .status { margin-top: 0.5rem; font-size: 1.1rem; opacity: 0.9; }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        .metric-card {
            background: #1e2a3a;
            border-radius: 12px;
            padding: 1.5rem;
            border: 1px solid #2d3748;
            transition: transform 0.2s;
        }
        .metric-card:hover { transform: translateY(-2px); }
        .metric-header {
            display: flex;
            justify-content: between;
            align-items: center;
            margin-bottom: 1rem;
        }
        .metric-title {
            font-size: 1.1rem;
            font-weight: 600;
            color: #a0aec0;
        }
        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }
        .metric-subtitle {
            color: #718096;
            font-size: 0.9rem;
        }
        .status-excellent { color: #48bb78; }
        .status-good { color: #38b2ac; }
        .status-warning { color: #ed8936; }
        .status-critical { color: #f56565; }
        .alert-section {
            background: #1e2a3a;
            border-radius: 12px;
            padding: 1.5rem;
            border: 1px solid #2d3748;
        }
        .alert-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem;
            margin: 0.5rem 0;
            background: #2d3748;
            border-radius: 8px;
        }
        .timestamp { color: #718096; font-size: 0.8rem; }
        .refresh-indicator {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #48bb78;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-size: 0.9rem;
            opacity: 0;
            transition: opacity 0.3s;
        }
        .refresh-indicator.show { opacity: 1; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Arena Launch Monitor</h1>
        <div class="status" id="system-status">System Status: Initializing...</div>
    </div>

    <div class="container">
        <div class="metrics-grid">
            <!-- Timer Sync Metrics -->
            <div class="metric-card">
                <div class="metric-header">
                    <div class="metric-title">⏱️ Timer Synchronization</div>
                </div>
                <div class="metric-value" id="timer-accuracy">--</div>
                <div class="metric-subtitle" id="timer-details">Loading...</div>
            </div>

            <!-- Room Creation Metrics -->
            <div class="metric-card">
                <div class="metric-header">
                    <div class="metric-title">🏠 Room Creation</div>
                </div>
                <div class="metric-value" id="room-success">--</div>
                <div class="metric-subtitle" id="room-details">Loading...</div>
            </div>

            <!-- Database Performance -->
            <div class="metric-card">
                <div class="metric-header">
                    <div class="metric-title">💾 Database Performance</div>
                </div>
                <div class="metric-value" id="db-response">--</div>
                <div class="metric-subtitle" id="db-details">Loading...</div>
            </div>

            <!-- Agora Connections -->
            <div class="metric-card">
                <div class="metric-header">
                    <div class="metric-title">🎤 Agora Connections</div>
                </div>
                <div class="metric-value" id="agora-connections">--</div>
                <div class="metric-subtitle" id="agora-details">Loading...</div>
            </div>
        </div>

        <!-- Overall Health -->
        <div class="metric-card" style="text-align: center; margin-bottom: 2rem;">
            <div class="metric-title">📊 Overall System Health</div>
            <div class="metric-value" id="overall-health" style="font-size: 3rem;">--</div>
            <div class="metric-subtitle" id="health-status">Calculating...</div>
        </div>

        <!-- Recent Activity -->
        <div class="alert-section">
            <h3 style="margin-bottom: 1rem; color: #a0aec0;">📋 Recent Activity</h3>
            <div id="recent-activity">
                <div class="alert-item">
                    <span>Monitoring system started</span>
                    <span class="timestamp" id="start-time">--</span>
                </div>
            </div>
        </div>
    </div>

    <div class="refresh-indicator" id="refresh-indicator">
        📡 Data Updated
    </div>

    <script>
        const socket = io();
        let lastUpdate = Date.now();

        // Format numbers with appropriate suffixes
        function formatValue(value, type) {
            if (type === 'percentage') return value + '%';
            if (type === 'time') return value + 'ms';
            if (type === 'count') return value.toLocaleString();
            return value;
        }

        // Get status class based on value and thresholds
        function getStatusClass(value, thresholds) {
            if (value >= thresholds.excellent) return 'status-excellent';
            if (value >= thresholds.good) return 'status-good';
            if (value >= thresholds.warning) return 'status-warning';
            return 'status-critical';
        }

        // Update metrics display
        function updateMetrics(metrics) {
            // Timer Sync
            const timerAccuracy = metrics.timers.syncAccuracy;
            document.getElementById('timer-accuracy').textContent = formatValue(timerAccuracy, 'percentage');
            document.getElementById('timer-accuracy').className = 'metric-value ' + 
                getStatusClass(timerAccuracy, {excellent: 95, good: 90, warning: 80});
            document.getElementById('timer-details').textContent = 
                \`\${metrics.timers.totalActive} active timers, \${metrics.timers.avgSyncDelay}ms avg delay\`;

            // Room Creation
            const roomSuccess = metrics.rooms.successRate;
            document.getElementById('room-success').textContent = formatValue(roomSuccess, 'percentage');
            document.getElementById('room-success').className = 'metric-value ' + 
                getStatusClass(roomSuccess, {excellent: 95, good: 90, warning: 80});
            document.getElementById('room-details').textContent = 
                \`\${metrics.rooms.lastHourCreations} rooms created in last hour\`;

            // Database
            const dbResponse = metrics.database.avgResponseTime;
            document.getElementById('db-response').textContent = formatValue(dbResponse, 'time');
            document.getElementById('db-response').className = 'metric-value ' + 
                getStatusClass(1000-dbResponse, {excellent: 800, good: 500, warning: 200}); // Inverted for response time
            document.getElementById('db-details').textContent = 
                \`\${metrics.database.connectionHealth}% connection health\`;

            // Agora
            const agoraConnections = metrics.agora.voiceConnections;
            document.getElementById('agora-connections').textContent = formatValue(agoraConnections, 'count');
            document.getElementById('agora-details').textContent = 
                \`\${metrics.agora.connectionSuccessRate}% success rate\`;

            // Overall Health
            const overallHealth = calculateOverallHealth(metrics);
            document.getElementById('overall-health').textContent = formatValue(overallHealth, 'percentage');
            document.getElementById('overall-health').className = 'metric-value ' + 
                getStatusClass(overallHealth, {excellent: 90, good: 70, warning: 50});
            
            const healthStatus = overallHealth >= 90 ? 'Excellent' :
                               overallHealth >= 70 ? 'Good' :
                               overallHealth >= 50 ? 'Warning' : 'Critical';
            document.getElementById('health-status').textContent = healthStatus;
            document.getElementById('system-status').textContent = \`System Status: \${healthStatus}\`;

            // Show refresh indicator
            showRefreshIndicator();
        }

        function calculateOverallHealth(metrics) {
            const weights = { timers: 0.3, rooms: 0.25, database: 0.25, agora: 0.2 };
            const scores = {
                timers: metrics.timers.syncAccuracy,
                rooms: metrics.rooms.successRate,
                database: metrics.database.connectionHealth,
                agora: metrics.agora.connectionSuccessRate
            };
            
            return Math.round(
                (scores.timers * weights.timers) +
                (scores.rooms * weights.rooms) +
                (scores.database * weights.database) +
                (scores.agora * weights.agora)
            );
        }

        function showRefreshIndicator() {
            const indicator = document.getElementById('refresh-indicator');
            indicator.classList.add('show');
            setTimeout(() => indicator.classList.remove('show'), 2000);
        }

        // Socket event handlers
        socket.on('metrics', (data) => {
            updateMetrics(data);
            lastUpdate = Date.now();
        });

        socket.on('connect', () => {
            console.log('Connected to monitoring server');
            document.getElementById('start-time').textContent = new Date().toLocaleTimeString();
        });

        socket.on('disconnect', () => {
            console.log('Disconnected from monitoring server');
            document.getElementById('system-status').textContent = 'System Status: Disconnected';
        });

        // Update timestamps periodically
        setInterval(() => {
            const timeSinceUpdate = Math.round((Date.now() - lastUpdate) / 1000);
            if (timeSinceUpdate > 30) {
                document.getElementById('system-status').textContent = 
                    \`System Status: Last update \${timeSinceUpdate}s ago\`;
            }
        }, 1000);
    </script>
</body>
</html>`;
  }
}