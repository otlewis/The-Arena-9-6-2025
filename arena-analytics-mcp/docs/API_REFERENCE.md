# Arena Analytics MCP Server API Reference

## Overview

The Arena Analytics MCP Server provides comprehensive analytics tools for all three Arena room types through a standardized Model Context Protocol interface.

## Tool Categories

### 🏟️ Arena Room Analytics
- `analyze_arena_rooms` - 1v1 and 2v2 structured debate analysis

### 💬 Open Discussion Analytics  
- `analyze_open_discussions` - Informal discussion room analysis

### 🎯 Debates & Discussions Analytics
- `analyze_debates_discussions` - 7-slot speaker panel system analysis

### 🚀 Launch Readiness Tools
- `assess_launch_readiness` - September 12 launch preparation
- `compare_room_types` - Cross-room performance comparison

### 📊 Advanced Analytics
- `analyze_user_behavior` - Cross-room user patterns
- `get_optimization_insights` - Scalability recommendations
- `get_realtime_metrics` - Current system status

---

## Tool Specifications

### analyze_arena_rooms

Comprehensive analytics for Arena rooms focusing on structured 1v1 and 2v2 debates.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "period": {
      "type": "string",
      "enum": ["day", "week", "month", "3months", "all"],
      "default": "week",
      "description": "Time period for analysis"
    },
    "focus": {
      "type": "string", 
      "enum": ["overview", "judging", "bias", "timers", "voice", "completion", "all"],
      "default": "all",
      "description": "Specific aspect to focus analysis on"
    }
  }
}
```

**Output Structure:**
```json
{
  "period": {
    "startDate": "2024-01-01T00:00:00.000Z",
    "endDate": "2024-01-07T23:59:59.999Z",
    "period": "week"
  },
  "overview": {
    "totalRooms": 150,
    "completedRooms": 128,
    "ongoingRooms": 5,
    "cancelledRooms": 17,
    "completionRate": 85,
    "roomTypeDistribution": {
      "1v1": { "count": 120, "percentage": 80 },
      "2v2": { "count": 30, "percentage": 20 }
    }
  },
  "completionRates": {
    "overall": 85,
    "byRoomType": {
      "1v1": { "total": 120, "completed": 105, "rate": 88 },
      "2v2": { "total": 30, "completed": 23, "rate": 77 }
    },
    "byTopic": {
      "Politics": { "total": 45, "completed": 38, "rate": 84 },
      "Sports": { "total": 32, "completed": 29, "rate": 91 }
    },
    "byTimeOfDay": {
      "14": { "total": 25, "completed": 22, "rate": 88 },
      "19": { "total": 35, "completed": 31, "rate": 89 }
    }
  },
  "judgingPatterns": {
    "totalJudgments": 340,
    "averageScore": 67.5,
    "scoreDistribution": {
      "0-20": 12,
      "21-40": 45,
      "41-60": 89,
      "61-80": 142,
      "81-100": 52
    },
    "judgeParticipation": {
      "totalJudges": 85,
      "averageJudgmentsPerJudge": 4,
      "topJudges": [
        {
          "judgeId": "user123",
          "totalJudgments": 15,
          "averageScore": 72,
          "completionRate": 93
        }
      ]
    }
  },
  "biasDetection": {
    "potentialBias": [
      {
        "judgeId": "user456",
        "type": "high_scoring",
        "severity": "medium", 
        "details": "85% of scores above 80",
        "totalJudgments": 12
      }
    ],
    "scoringConsistency": {
      "user123": {
        "mean": 68,
        "standardDeviation": 12.5,
        "consistency": "high"
      }
    },
    "recommendations": [
      "Consider implementing judge calibration sessions",
      "Review scoring guidelines with judges showing bias patterns"
    ]
  },
  "timerAccuracy": {
    "totalTimers": 128,
    "averageAccuracy": 94.2,
    "syncIssues": {
      "total": 8,
      "rate": 6.25
    },
    "accuracyDistribution": {
      "excellent": 98,
      "good": 22,
      "fair": 6,
      "poor": 2
    }
  },
  "voiceQuality": {
    "voiceEnabledRooms": 145,
    "voiceEnabledRate": 97,
    "voiceIssues": {
      "total": 12,
      "rate": 8,
      "commonIssues": {
        "connectionFailures": 5,
        "audioQuality": 4,
        "permissionIssues": 3
      }
    }
  },
  "insights": [
    {
      "type": "warning",
      "category": "judging",
      "message": "Potential judging bias detected in 3 judges",
      "priority": "medium",
      "suggestion": "Implement judge training and calibration programs"
    }
  ],
  "launchReadiness": {
    "daysRemaining": 25,
    "criticalIssues": [],
    "warningIssues": 1,
    "readinessScore": 87,
    "recommendations": [
      {
        "category": "ux",
        "action": "Optimize user onboarding and reduce friction points",
        "timeline": "Next 2 weeks"
      }
    ]
  }
}
```

**Focus Options:**
- `overview` - Basic metrics and completion rates
- `judging` - Judge scoring patterns and participation
- `bias` - Bias detection in judge scoring
- `timers` - Timer synchronization accuracy
- `voice` - Voice quality and connection issues
- `completion` - Detailed completion rate analysis
- `all` - Complete analysis (default)

**Example Usage:**
```javascript
// Get judging bias analysis for the past month
{
  "name": "analyze_arena_rooms",
  "arguments": {
    "period": "month",
    "focus": "bias"
  }
}
```

---

### analyze_open_discussions

Analytics for informal Open Discussion rooms focusing on engagement and sustainability.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "period": {
      "type": "string",
      "enum": ["day", "week", "month", "3months", "all"],
      "default": "week"
    },
    "focus": {
      "type": "string",
      "enum": ["engagement", "dropoff", "moderation", "categories", "all"],
      "default": "all"
    }
  }
}
```

**Key Output Sections:**
- `participantEngagement` - Engagement scores and participation metrics
- `roomLongevity` - Duration analysis and sustainability scores
- `dropoffPatterns` - When and why participants leave
- `handRaiseAnalysis` - Request patterns and approval rates
- `moderatorActivity` - Moderator effectiveness metrics
- `categoryPopularity` - Topic trending and performance

**Example Response:**
```json
{
  "participantEngagement": {
    "totalParticipants": 450,
    "uniqueUsers": 280,
    "averageEngagementScore": 62,
    "averageParticipantsPerRoom": 8.5,
    "engagementDistribution": {
      "high": 25,
      "medium": 35,
      "low": 18
    }
  },
  "roomLongevity": {
    "averageDuration": 85,
    "sustainabilityScore": 72,
    "durationDistribution": {
      "very_short": 8,
      "short": 22,
      "medium": 28,
      "long": 15,
      "very_long": 5
    }
  },
  "dropoffPatterns": {
    "overallDropoffRate": 35,
    "dropoffPatterns": {
      "early": 45,
      "mid": 28,
      "late": 15
    }
  }
}
```

---

### analyze_debates_discussions

Analytics for the structured Debates & Discussions system with 7-slot speaker panels.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "period": {
      "type": "string",
      "enum": ["day", "week", "month", "3months", "all"],
      "default": "week"
    },
    "focus": {
      "type": "string",
      "enum": ["speaker_panel", "moderation", "conversion", "room_types", "categories", "all"],
      "default": "all"
    }
  }
}
```

**Key Metrics:**
- **Speaker Panel Utilization** - 7-slot panel usage and efficiency
- **Audience-to-Speaker Conversion** - Hand-raise success rates
- **Room Type Performance** - Discussion vs Debate vs Take rooms
- **Moderator Effectiveness** - Control usage and responsiveness

**Example Response:**
```json
{
  "speakerPanelAnalysis": {
    "averageSpeakerUtilization": 67,
    "averageSpeakersPerRoom": 4.2,
    "panelFullnessDistribution": {
      "empty": 2,
      "low": 15,
      "medium": 35,
      "high": 28,
      "full": 8
    }
  },
  "audienceToSpeakerConversion": {
    "averageRaiseRate": 25,
    "averageConversionRate": 68,
    "averageOverallConversion": 17,
    "conversionTiers": {
      "excellent": 12,
      "good": 28,
      "average": 35,
      "poor": 13
    }
  },
  "roomTypeDistribution": {
    "typeDistribution": [
      { "type": "discussion", "count": 45, "percentage": 60, "completionRate": 88 },
      { "type": "debate", "count": 22, "percentage": 29, "completionRate": 82 },
      { "type": "take", "count": 8, "percentage": 11, "completionRate": 75 }
    ],
    "mostPopularType": "discussion",
    "bestPerformingType": "discussion"
  }
}
```

---

### assess_launch_readiness

Comprehensive launch readiness assessment for September 12 launch target.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "include_recommendations": {
      "type": "boolean",
      "default": true,
      "description": "Include specific recommendations for improvement"
    },
    "critical_only": {
      "type": "boolean", 
      "default": false,
      "description": "Focus only on critical launch blockers"
    }
  }
}
```

**Output Structure:**
```json
{
  "overallReadinessScore": 78,
  "daysUntilLaunch": 25,
  "criticalIssues": [
    {
      "type": "critical",
      "category": "timing",
      "message": "Timer accuracy (87%) needs improvement",
      "priority": "critical",
      "suggestion": "Investigate timer synchronization issues before launch"
    }
  ],
  "roomTypeReadiness": {
    "arena": 82,
    "openDiscussion": 75,
    "debatesDiscussions": 77
  },
  "keyMetrics": {
    "arenaCompletionRate": 85,
    "openEngagementScore": 62,
    "debatesConversionRate": 17
  },
  "recommendations": [
    {
      "priority": "critical",
      "timeline": "Next 7 days", 
      "action": "Focus on critical stability and performance issues",
      "details": "1 critical issues need immediate attention"
    }
  ]
}
```

**Readiness Score Calculation:**
- **100 points** baseline score
- **-25 points** per critical issue
- **-10 points** per high priority issue  
- **-5 points** per medium priority issue
- **-15 points** if completion rate < 70%
- **-20 points** if completion rate < 50%

---

### compare_room_types

Cross-room type performance comparison across key metrics.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "period": {
      "type": "string",
      "enum": ["day", "week", "month", "3months", "all"],
      "default": "week"
    },
    "metrics": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["completion_rate", "engagement", "duration", "participation", "all"]
      },
      "default": ["all"]
    }
  }
}
```

**Example Response:**
```json
{
  "completionRates": {
    "arena": 85,
    "openDiscussion": 72,
    "debatesDiscussions": 77
  },
  "engagement": {
    "arena": 4.2,
    "openDiscussion": 62,
    "debatesDiscussions": 65
  },
  "averageDuration": {
    "arena": 45,
    "openDiscussion": 85,
    "debatesDiscussions": 92
  },
  "participationMetrics": {
    "arena": {
      "averageParticipants": 4.2,
      "uniqueUsers": 180
    },
    "openDiscussion": {
      "averageParticipants": 8.5,
      "uniqueUsers": 280
    },
    "debatesDiscussions": {
      "averageParticipants": 12.3,
      "uniqueUsers": 320
    }
  }
}
```

---

### analyze_user_behavior

Cross-room user behavior patterns and preferences analysis.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "period": {
      "type": "string",
      "enum": ["day", "week", "month", "3months", "all"],
      "default": "week"
    },
    "behavior_type": {
      "type": "string",
      "enum": ["participation", "preferences", "retention", "progression", "all"],
      "default": "all"
    }
  }
}
```

**Analysis Types:**
- `participation` - Cross-room participation patterns
- `preferences` - Room type and category preferences
- `retention` - User retention across room types
- `progression` - User journey and role advancement
- `all` - Comprehensive behavior analysis

---

### get_optimization_insights

Performance optimization recommendations for scaling to 10,000+ concurrent users.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "focus_area": {
      "type": "string",
      "enum": ["scalability", "engagement", "retention", "moderation", "technical", "all"],
      "default": "all"
    },
    "target_metrics": {
      "type": "boolean",
      "default": true,
      "description": "Include target metrics for scale"
    }
  }
}
```

**Optimization Areas:**
- `scalability` - Database, caching, and infrastructure recommendations
- `engagement` - User engagement optimization strategies
- `retention` - User retention improvement tactics
- `moderation` - Moderator tools and automation recommendations
- `technical` - Performance and reliability improvements
- `all` - Comprehensive optimization strategy

---

### get_realtime_metrics

Current real-time system metrics and alerts.

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "include_alerts": {
      "type": "boolean",
      "default": true,
      "description": "Include any active alerts or issues"
    }
  }
}
```

**Real-time Data:**
- Active room counts by type
- Current user counts and concurrent sessions
- System performance metrics
- Active alerts and issues
- Recent error rates and patterns

---

## Error Handling

### Standard Error Response
```json
{
  "error": {
    "code": "ErrorCode",
    "message": "Human readable error message",
    "details": {
      "collection": "collection_name",
      "operation": "operation_attempted"
    }
  }
}
```

### Common Error Codes
- `MethodNotFound` - Tool name not recognized
- `InternalError` - Server-side processing error
- `InvalidParams` - Invalid input parameters
- `DatabaseError` - Appwrite connection/query error
- `PermissionError` - Insufficient API key permissions

### Debugging Errors

1. **Check Appwrite Connection**
```bash
# Test basic connectivity
curl -X GET \
  'https://your-endpoint/v1/health' \
  -H 'X-Appwrite-Project: your-project-id'
```

2. **Verify API Key Permissions**
```bash
# Test API key access
curl -X GET \
  'https://your-endpoint/v1/databases/your-db-id/collections' \
  -H 'X-Appwrite-Project: your-project-id' \
  -H 'X-Appwrite-Key: your-api-key'
```

3. **Enable Debug Logging**
```bash
LOG_LEVEL=debug npm start
```

## Rate Limits

### Default Limits
- **100 requests/minute** per MCP session
- **Maximum 30 second** timeout per request
- **5MB maximum** response size

### Optimization Tips
- Use focused analysis (`focus` parameter) for faster responses
- Batch multiple metrics in single requests when possible
- Cache results for repeated queries
- Use appropriate time periods (avoid `all` for large datasets)

## Data Privacy

### Personal Information Handling
- User IDs are anonymized in analytics output
- No personal information (names, emails) included in responses
- Aggregate data only, no individual user tracking
- GDPR and privacy-compliant data processing

### Data Retention
- Analytics use read-only access to live data
- No data storage or caching of personal information
- Real-time analysis without data persistence
- Audit logs for analytics requests (optional)