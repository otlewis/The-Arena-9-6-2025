# Arena Launch Monitoring System

Real-time monitoring dashboard for Arena's September 12 launch with critical metric tracking and alerts.

## 🚀 Quick Start

### 1. Installation
```bash
cd arena-monitoring
npm install
```

### 2. Configuration
```bash
cp .env.example .env
# Edit .env with your Appwrite credentials
```

### 3. Start Monitoring
```bash
npm start
```

### 4. View Dashboard
Open: http://localhost:3001

## 📊 Monitored Metrics

### 🔥 Critical Launch Metrics

#### ⏱️ Timer Synchronization
- **Accuracy**: Percentage of timers syncing within 2 seconds
- **Active Timers**: Number of currently running timers
- **Sync Delay**: Average delay between timer updates
- **Alert Threshold**: <95% accuracy

#### 🏠 Room Creation Success
- **Success Rate**: Percentage of successful room creations
- **Creation Speed**: Average time to create rooms
- **Hourly Volume**: Rooms created in the last hour
- **Alert Threshold**: <90% success rate

#### 💾 Database Performance
- **Response Time**: Average query response time
- **Connection Health**: Database connection stability
- **Slow Queries**: Queries taking >1 second
- **Alert Threshold**: >1000ms response time

#### 🎤 Agora Connections
- **Voice Connections**: Active voice chat sessions
- **Chat Connections**: Active chat sessions  
- **Success Rate**: Connection establishment rate
- **Alert Threshold**: <90% success rate

## 🚨 Alert System

### Alert Levels
- **🔴 CRITICAL**: Immediate action required (email alerts)
- **🟡 WARNING**: Monitor closely (console alerts)
- **❌ ERROR**: System errors (logged)
- **ℹ️ INFO**: General information

### Email Alerts Setup
```bash
# Configure in .env
SMTP_HOST=smtp.gmail.com
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
ALERT_EMAIL=admin@arena.app
```

## 📈 Dashboard Features

### Real-time Metrics
- Live updating charts and gauges
- Color-coded status indicators
- Historical trend data
- System health scoring

### Performance Monitoring
- Response time tracking
- Error rate analysis
- Throughput measurement
- User load monitoring

## 🛠️ Commands

```bash
# Start monitoring
npm start

# Development mode (auto-restart)
npm run dev

# Dashboard only
npm run dashboard

# Stop monitoring
Ctrl+C
```

## 📋 Launch Day Checklist

### Pre-Launch (T-30 minutes)
- [ ] Start monitoring system
- [ ] Verify all metrics are green
- [ ] Test alert notifications
- [ ] Confirm dashboard accessibility
- [ ] Brief team on alert procedures

### Launch (T-0)
- [ ] Monitor timer synchronization accuracy
- [ ] Watch room creation success rates
- [ ] Track database performance
- [ ] Monitor Agora connection health
- [ ] Respond to critical alerts immediately

### Post-Launch (T+24 hours)
- [ ] Review monitoring data
- [ ] Identify performance bottlenecks
- [ ] Generate launch report
- [ ] Plan optimization improvements

## 🎯 Critical Thresholds

### 🟢 EXCELLENT (Launch Ready)
- Timer Sync: >95%
- Room Success: >95%
- DB Response: <200ms
- Agora Success: >95%

### 🟡 WARNING (Monitor Closely)
- Timer Sync: 90-95%
- Room Success: 85-95%
- DB Response: 200-1000ms
- Agora Success: 85-95%

### 🔴 CRITICAL (Immediate Action)
- Timer Sync: <90%
- Room Success: <85%
- DB Response: >1000ms
- Agora Success: <85%

## 🔧 Troubleshooting

### Common Issues

#### Dashboard Not Loading
```bash
# Check if port 3001 is available
lsof -i :3001

# Try different port
DASHBOARD_PORT=3002 npm start
```

#### Database Connection Errors
```bash
# Verify Appwrite credentials
curl -X GET https://cloud.appwrite.io/v1/health \
  -H "X-Appwrite-Project: your-project-id" \
  -H "X-Appwrite-Key: your-api-key"
```

#### No Timer Data
- Verify timer-controller and timer-ticker functions are deployed
- Check Appwrite function logs
- Confirm timers collection exists

#### Missing Alerts
- Check email configuration
- Verify SMTP credentials
- Check spam folder

## 📊 Performance Analysis

### Response Time Analysis
- Track average response times
- Identify slow operations
- Monitor performance trends
- Alert on degradation

### Error Rate Monitoring
- Track error frequencies
- Categorize error types
- Monitor error trends
- Alert on spikes

### Throughput Tracking
- Operations per second
- Peak load handling
- Capacity planning
- Bottleneck identification

## 🚀 Launch Success Criteria

### Minimum Viable Performance
- **System Uptime**: >99%
- **Timer Accuracy**: >90%
- **Room Creation**: >85%
- **User Experience**: Stable

### Optimal Performance
- **System Uptime**: >99.9%
- **Timer Accuracy**: >98%
- **Room Creation**: >95%
- **User Experience**: Excellent

## 📞 Emergency Contacts

### Launch Team
- **Tech Lead**: [Contact Info]
- **DevOps**: [Contact Info]
- **Product**: [Contact Info]

### Escalation Process
1. **Level 1**: Console alerts and dashboard monitoring
2. **Level 2**: Email alerts to team
3. **Level 3**: Emergency contact procedures
4. **Level 4**: Rollback decision

## 📝 Monitoring Logs

All monitoring data is logged with timestamps for post-launch analysis:
- Performance metrics
- Alert history
- System health scores
- User activity patterns

## 🎉 Launch Day Success

When all metrics are green and the system is stable:
- **Timer Sync**: >95% ✅
- **Room Creation**: >90% ✅  
- **Database**: <500ms ✅
- **Agora**: >90% ✅

**🚀 Arena is ready for successful launch!**