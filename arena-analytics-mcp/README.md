# Arena Analytics MCP Server

A comprehensive Model Context Protocol (MCP) server providing deep analytics for the Arena debate platform across all three room types: Arena Rooms (1v1/2v2 debates), Open Discussions, and Debates & Discussions.

## Features

### 🏟️ Arena Rooms Analytics
- **Judge Scoring Patterns** - Analyze scoring trends and potential bias detection
- **Debate Completion Rates** - Track completion rates by room type, topic, and time
- **Voice Quality Metrics** - Monitor audio issues and connection reliability
- **Timer Synchronization** - Verify timer accuracy across devices and rooms
- **Participant Behavior** - Role transitions, engagement patterns, and repeat participation

### 💬 Open Discussions Analytics  
- **Participant Engagement** - Speaking time distribution and retention metrics
- **Room Longevity** - Sustainability scores and duration analysis
- **Drop-off Patterns** - Identify when and why users leave discussions
- **Hand-raise Analysis** - Request-to-approval rates and moderator responsiveness
- **Moderator Effectiveness** - Room management and participant guidance metrics

### 🎯 Debates & Discussions Analytics
- **7-Slot Speaker Panel** - Utilization rates and panel fullness analysis
- **Moderator Controls** - Usage patterns of mute, speaker management, and room settings
- **Room Type Distribution** - Performance comparison between Discussion, Debate, and Take rooms
- **Category Popularity** - Trending topics and engagement by category (Religion, Sports, Science, Politics)
- **Audience-to-Speaker Conversion** - Hand-raise success rates and participation flow

## Installation

1. **Clone and install dependencies**
   ```bash
   cd arena-analytics-mcp
   npm install
   ```

2. **Configure environment**
   ```bash
   cp config/.env.example .env
   # Edit .env with your Appwrite credentials
   ```

3. **Run the server**
   ```bash
   npm start
   ```

## Configuration

### Required Environment Variables

```env
APPWRITE_ENDPOINT=https://your-appwrite-endpoint.com/v1
APPWRITE_PROJECT_ID=your-project-id
APPWRITE_API_KEY=your-api-key
APPWRITE_DATABASE_ID=your-database-id
```

### Appwrite Collections Required

The server expects these collections in your Appwrite database:

- `users` - User profiles with social links
- `arena_rooms` - Challenge-based debate rooms  
- `arena_participants` - Arena participant tracking
- `arena_judgments` - Judge scoring for arena debates
- `debate_discussion_rooms` - Open discussion rooms
- `debate_discussion_participants` - Participant tracking with roles
- `room_hand_raises` - Hand-raise requests in discussion rooms
- `timers` - Server-controlled timer states
- `timer_events` - Timer action audit trail
- `challenges` - Debate challenges between users

## Available Tools

### Core Analytics Tools

#### `analyze_arena_rooms`
Comprehensive analytics for Arena rooms (1v1 and 2v2 structured debates)

**Parameters:**
- `period` (string): `day`, `week`, `month`, `3months`, `all` (default: `week`)
- `focus` (string): `overview`, `judging`, `bias`, `timers`, `voice`, `completion`, `all` (default: `all`)

**Example:**
```javascript
{
  "name": "analyze_arena_rooms",
  "arguments": {
    "period": "week",
    "focus": "judging"
  }
}
```

#### `analyze_open_discussions`
Analytics for Open Discussion rooms focusing on engagement and longevity

**Parameters:**
- `period` (string): Time period for analysis
- `focus` (string): `engagement`, `dropoff`, `moderation`, `categories`, `all`

#### `analyze_debates_discussions`
Analytics for Debates & Discussions with 7-slot speaker panel system

**Parameters:**
- `period` (string): Time period for analysis  
- `focus` (string): `speaker_panel`, `moderation`, `conversion`, `room_types`, `categories`, `all`

### Launch Readiness Tools

#### `assess_launch_readiness`
Comprehensive launch readiness assessment for September 12 launch

**Parameters:**
- `include_recommendations` (boolean): Include specific recommendations (default: `true`)
- `critical_only` (boolean): Focus only on critical launch blockers (default: `false`)

#### `compare_room_types`
Compare performance metrics across all three room types

**Parameters:**
- `period` (string): Time period for comparison
- `metrics` (array): `completion_rate`, `engagement`, `duration`, `participation`, `all`

### Advanced Analytics

#### `analyze_user_behavior`
Cross-room user behavior patterns and preferences

**Parameters:**
- `period` (string): Time period for analysis
- `behavior_type` (string): `participation`, `preferences`, `retention`, `progression`, `all`

#### `get_optimization_insights`
Specific insights for optimizing Arena for 10,000+ concurrent users

**Parameters:**
- `focus_area` (string): `scalability`, `engagement`, `retention`, `moderation`, `technical`, `all`
- `target_metrics` (boolean): Include target metrics for scale

#### `get_realtime_metrics`
Current real-time metrics across all room types

**Parameters:**
- `include_alerts` (boolean): Include any active alerts or issues

### Cross-Room Analytics Tools

#### `analyze_user_journeys`
Track user movement and progression across all room types

**Parameters:**
- `period` (string): `day`, `week`, `month`, `3months`, `all` (default: `week`)
- `analysis_type` (string): `movement`, `preferences`, `role_progression`, `retention`, `segmentation`, `all` (default: `all`)
- `user_segment` (string): `new_users`, `power_users`, `moderators`, `all` (default: `all`)

**Key Insights:**
- Cross-room user movement patterns
- Role progression (audience → speaker → moderator)
- User preference identification and segmentation
- Retention analysis by user segment
- User lifecycle and journey mapping

#### `assess_platform_health`
Comprehensive platform health assessment across all systems

**Parameters:**
- `period` (string): Time period for health assessment
- `health_aspect` (string): `engagement`, `retention`, `growth`, `stickiness`, `scalability`, `all` (default: `all`)
- `include_predictions` (boolean): Include growth and trend predictions (default: `true`)

**Health Metrics:**
- Overall platform health score (0-100)
- Cross-room engagement comparison
- User retention analysis (1-day, 7-day, 30-day)
- Growth rate tracking and predictions
- User stickiness (DAU/MAU ratios)
- Scalability assessment for 10,000+ concurrent users

#### `test_launch_readiness`
Execute comprehensive launch readiness tests and validations

**Parameters:**
- `test_suite` (string): `critical_flows`, `performance_load`, `integration_validation`, `all` (default: `all`)
- `target_load` (number): Target concurrent user load for performance testing (default: `10000`)
- `include_simulation` (boolean): Include load simulation results (default: `true`)

**Testing Framework:**
- Critical user flow validation across all room types
- Performance under load testing (10,000+ concurrent users)
- System integration validation (Appwrite, Agora, Firebase)
- Go/No-Go decision framework with confidence scoring
- Pre-launch checklist tracking and validation

## Key Metrics Tracked

### Arena Rooms
- Completion rates by room type (1v1 vs 2v2)
- Judge scoring patterns and bias detection
- Average debate duration and optimal timing
- Voice quality issues and connection rates
- Timer synchronization accuracy across devices

### Open Discussions
- Participant engagement scores and retention
- Room longevity and sustainability metrics
- Drop-off patterns and critical exit points
- Moderator responsiveness to hand-raise requests
- Category popularity and trending topics

### Debates & Discussions
- Speaker panel utilization (7-slot system)
- Audience-to-speaker conversion rates
- Moderator control usage patterns
- Room type performance (Discussion/Debate/Take)
- Hand-raise approval and response times

### Cross-Room Analytics
- **User Journey Tracking** - Movement patterns between room types
- **Role Progression Analysis** - Audience → Speaker → Moderator transitions
- **Platform Health Scoring** - Overall system health across all features
- **Retention Analysis** - User retention by room type and user segment
- **Growth Predictions** - Trend analysis and future projections
- **Launch Readiness Testing** - Comprehensive validation for September 12 launch

## Launch Readiness Insights

The server provides comprehensive launch readiness assessment with:

- **Overall Readiness Score** (0-100) based on all room types
- **Critical Issue Detection** with priority levels
- **Days Until Launch Countdown** (September 12 target)
- **Room-Specific Readiness** scores for each system
- **Actionable Recommendations** with timelines

### Readiness Scoring Factors

- **Completion Rates** - Target: 80%+ across all room types
- **Engagement Metrics** - Sustained participation and interaction
- **Technical Stability** - Timer sync, voice quality, system uptime
- **User Experience** - Low drop-off rates, high conversion rates
- **Moderation Effectiveness** - Response times, approval rates

## Integration with Claude Code

Add this server to your Claude Code MCP configuration:

```json
{
  "mcpServers": {
    "arena-analytics": {
      "command": "node",
      "args": ["/path/to/arena-analytics-mcp/src/index.js"],
      "env": {
        "APPWRITE_ENDPOINT": "your-endpoint",
        "APPWRITE_PROJECT_ID": "your-project-id",
        "APPWRITE_API_KEY": "your-api-key",
        "APPWRITE_DATABASE_ID": "your-database-id"
      }
    }
  }
}
```

## Common Usage Patterns

### Pre-Launch Quality Assurance
```
"Analyze Arena's current state and identify any launch blockers"
```

### Performance Optimization
```
"Optimize Arena for 10,000+ concurrent users"
```

### Bug Triage and Fixing
```
"Fix the most critical Arena bugs blocking launch"
```

### Weekly Health Check
```
"Compare this week's performance across all Arena room types"
```

## Development

### Project Structure
```
src/
├── analytics/          # Analytics engines for each room type
│   ├── base-analytics.js              # Base analytics class with common methods
│   ├── arena-analytics.js             # Arena rooms (1v1/2v2 debates)
│   ├── open-discussion-analytics.js   # Open discussion rooms
│   ├── debates-discussions-analytics.js # Debates & discussions (7-slot panel)
│   ├── user-journey-analytics.js      # Cross-room user behavior tracking
│   ├── platform-health-analytics.js   # Overall platform health assessment
│   └── launch-readiness-analytics.js  # Launch readiness testing framework
├── db/                 # Database integration
│   └── appwrite-client.js             # Appwrite database client and queries
├── utils/              # Utility functions
│   └── date-helpers.js                # Date calculations and formatting
└── index.js           # Main MCP server entry point
```

### Adding New Analytics

1. Extend the appropriate analytics class
2. Add new methods following the existing patterns
3. Update the MCP server tool definitions
4. Add comprehensive JSDoc documentation

### Testing

```bash
# Run tests (when implemented)
npm test

# Development mode with auto-reload
npm run dev
```

## Troubleshooting

### Common Issues

1. **Connection Errors**
   - Verify Appwrite endpoint and credentials
   - Check network connectivity and firewall settings

2. **Missing Data**
   - Ensure all required collections exist in Appwrite
   - Verify API key has read permissions for all collections

3. **Performance Issues**
   - Consider adding database indexes for large datasets
   - Implement caching for frequently accessed data

### Debug Mode

Set `LOG_LEVEL=debug` in your environment for detailed logging:

```bash
LOG_LEVEL=debug npm start
```

## Roadmap

- [ ] Real-time alerts and monitoring
- [ ] Predictive analytics for user behavior
- [ ] A/B testing framework integration
- [ ] Performance optimization recommendations
- [ ] Automated report generation
- [ ] Dashboard web interface

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

For issues and feature requests, please use the GitHub issues tracker or contact the Arena development team.