# Arena Analytics MCP Server - Environment Setup Guide

## Overview
The Arena Analytics MCP Server provides comprehensive launch readiness assessment across all three room types (Arena Rooms, Open Discussions, and Debates & Discussions). This guide covers setup requirements and usage.

## Prerequisites

### System Requirements
- Node.js v18+ (tested with v23.11.0)
- npm package manager
- Access to Arena's Appwrite database

### Environment Variables
Create a `.env` file in the config directory with the following variables:

```bash
# Appwrite Configuration (Required)
APPWRITE_ENDPOINT=https://your-appwrite-endpoint.com/v1
APPWRITE_PROJECT_ID=your-project-id
APPWRITE_API_KEY=your-api-key
APPWRITE_DATABASE_ID=your-database-id

# Optional: Redis for caching (future enhancement)
# REDIS_URL=redis://localhost:6379

# Optional: Monitoring
# SENTRY_DSN=your-sentry-dsn
# LOG_LEVEL=info
```

## Installation

1. Navigate to the arena-analytics-mcp directory:
```bash
cd /Users/otislewis/arena2/arena-analytics-mcp
```

2. Install dependencies:
```bash
npm install
```

3. Configure environment variables (copy from `.env.example`):
```bash
cp config/.env.example .env
# Edit .env with your actual Appwrite credentials
```

## Usage

### Starting the MCP Server
```bash
npm start
```

### Available Tools

The MCP server provides the following analytics tools:

#### Core Analytics Tools
1. **`assess_launch_readiness`** - Primary tool for September 12 launch assessment
2. **`analyze_arena_rooms`** - Arena rooms (1v1/2v2 debates) analytics
3. **`analyze_open_discussions`** - Open discussion rooms analytics
4. **`analyze_debates_discussions`** - Debates & discussions (7-slot panel) analytics

#### Comparison and Insights
5. **`compare_room_types`** - Cross-room performance comparison
6. **`analyze_user_behavior`** - User behavior patterns across room types
7. **`analyze_user_journeys`** - User movement and progression tracking
8. **`assess_platform_health`** - Overall platform health metrics

#### Performance and Monitoring
9. **`get_optimization_insights`** - Performance optimization recommendations
10. **`get_realtime_metrics`** - Current real-time system metrics
11. **`test_launch_readiness`** - Execute comprehensive readiness tests

### Testing Without Database Connection

For testing purposes, you can run the assessment tool with mock data:

```bash
node test-launch-readiness.js
```

This will simulate the launch readiness assessment without requiring database credentials.

## Architecture

### Database Collections
The system analyzes data from these Appwrite collections:
- `users` - User profiles and registration data
- `arena_rooms` - Arena room sessions and outcomes
- `arena_participants` - Arena participation records
- `arena_judgments` - Judging data and scores
- `debate_discussion_rooms` - Discussion room sessions
- `debate_discussion_participants` - Discussion participation with roles
- `room_hand_raises` - Hand-raise requests and responses
- `timers` - Timer system data
- `timer_events` - Timer synchronization events

### Key Metrics Analyzed

#### Critical Flows (35% weight)
- User onboarding success rate
- Arena room creation and completion
- Discussion room functionality
- Cross-room navigation
- Moderation tools effectiveness
- Voice and chat reliability
- Timer synchronization accuracy
- Notification delivery

#### Performance (25% weight)
- Concurrent user capacity
- Room creation performance
- Timer sync under load
- Voice quality under load
- Database performance
- Real-time update delivery

#### System Integration (25% weight)
- Appwrite database integration
- Agora Voice SDK integration
- Agora Chat SDK integration
- Timer system integration
- Notification system integration
- Cross-service communication
- Data consistency validation
- Failover mechanisms

#### User Experience (15% weight)
- Onboarding experience
- Room discovery and joining
- Participation experience
- Moderation experience
- Cross-room navigation
- Mobile experience
- Accessibility compliance
- Error handling
- Perceived performance

## Launch Readiness Scoring

### Overall Score Calculation
- **95-100**: Launch Ready (GO)
- **85-94**: Launch with Monitoring (GO_WITH_MONITORING)
- **75-84**: Launch with Fixes Required (GO_WITH_FIXES)
- **60-74**: Delay Recommended (NO_GO)
- **0-59**: Not Ready (NO_GO)

### Critical Thresholds
- Critical flows must achieve 95%+ success rate
- Performance must support target concurrent users
- All integrations must maintain 95%+ health
- No critical launch blockers allowed

## Current Assessment Results (Mock Data)

Based on the test run with simulated data:

```
🎯 Overall Readiness Score: 86/100
📅 Days until launch (Sept 12): 0
📈 Readiness Level: launch_with_monitoring
🔥 Launch Recommendation: NO_GO (due to timeline)

📊 Component Scores:
   Critical Flows: 75% ⚠️
   Performance: 92% ✅
   Integration: 97% ✅
   User Experience: 85% ✅

🚨 Critical Issues:
   ❌ Arena flows failure (critical)
   ❌ Timer synchronization failure (critical)
```

## Production Deployment Considerations

### Required Before Launch
1. **Environment Setup**: Configure all required environment variables
2. **Database Access**: Ensure MCP server has read access to Appwrite collections
3. **Monitoring**: Set up real-time monitoring dashboards
4. **Alerting**: Configure alerts for critical threshold breaches
5. **Rollback Plan**: Prepare rapid rollback procedures

### Performance Optimization
- Implement connection pooling for database queries
- Add Redis caching for frequently accessed data
- Set up horizontal scaling for high concurrent loads
- Monitor and optimize slow database queries

### Security
- Use read-only database credentials for analytics
- Implement rate limiting for MCP endpoints
- Secure environment variable storage
- Regular security audits of dependencies

## Troubleshooting

### Common Issues
1. **"Missing required environment variables"**: Check `.env` file configuration
2. **Database connection failures**: Verify Appwrite credentials and network access
3. **"Collection not found"**: Ensure all required collections exist in Appwrite
4. **Performance timeouts**: Increase query timeouts for large datasets

### Development Testing
Use the test script to validate functionality without production data:
```bash
export APPWRITE_ENDPOINT="mock" && node test-launch-readiness.js
```

## Future Enhancements
- Redis caching integration
- Advanced predictive analytics
- Real-time monitoring dashboard
- Automated alert system
- Performance benchmarking suite
- A/B testing analytics integration