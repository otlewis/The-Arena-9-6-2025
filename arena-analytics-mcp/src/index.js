#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';

import { AppwriteClient } from './db/appwrite-client.js';
import { ArenaAnalytics } from './analytics/arena-analytics.js';
import { OpenDiscussionAnalytics } from './analytics/open-discussion-analytics.js';
import { DebatesDiscussionsAnalytics } from './analytics/debates-discussions-analytics.js';
import { UserJourneyAnalytics } from './analytics/user-journey-analytics.js';
import { PlatformHealthAnalytics } from './analytics/platform-health-analytics.js';
import { LaunchReadinessAnalytics } from './analytics/launch-readiness-analytics.js';
import { DateHelpers } from './utils/date-helpers.js';

class ArenaAnalyticsMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'arena-analytics',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.appwriteClient = new AppwriteClient();
    this.arenaAnalytics = new ArenaAnalytics(this.appwriteClient);
    this.openDiscussionAnalytics = new OpenDiscussionAnalytics(this.appwriteClient);
    this.debatesDiscussionsAnalytics = new DebatesDiscussionsAnalytics(this.appwriteClient);
    this.userJourneyAnalytics = new UserJourneyAnalytics(this.appwriteClient);
    this.platformHealthAnalytics = new PlatformHealthAnalytics(this.appwriteClient);
    this.launchReadinessAnalytics = new LaunchReadinessAnalytics(this.appwriteClient);

    this.setupToolHandlers();
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          // Arena Rooms Analytics
          {
            name: 'analyze_arena_rooms',
            description: 'Comprehensive analytics for Arena rooms (1v1 and 2v2 structured debates)',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for analysis'
                },
                focus: {
                  type: 'string',
                  enum: ['overview', 'judging', 'bias', 'timers', 'voice', 'completion', 'all'],
                  default: 'all',
                  description: 'Specific aspect to focus analysis on'
                }
              }
            }
          },

          // Open Discussions Analytics
          {
            name: 'analyze_open_discussions',
            description: 'Analytics for Open Discussion rooms focusing on engagement and longevity',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for analysis'
                },
                focus: {
                  type: 'string',
                  enum: ['engagement', 'dropoff', 'moderation', 'categories', 'all'],
                  default: 'all',
                  description: 'Specific aspect to focus analysis on'
                }
              }
            }
          },

          // Debates & Discussions Analytics
          {
            name: 'analyze_debates_discussions',
            description: 'Analytics for Debates & Discussions with 7-slot speaker panel system',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for analysis'
                },
                focus: {
                  type: 'string',
                  enum: ['speaker_panel', 'moderation', 'conversion', 'room_types', 'categories', 'all'],
                  default: 'all',
                  description: 'Specific aspect to focus analysis on'
                }
              }
            }
          },

          // Launch Readiness Assessment
          {
            name: 'assess_launch_readiness',
            description: 'Comprehensive launch readiness assessment for September 12 launch',
            inputSchema: {
              type: 'object',
              properties: {
                include_recommendations: {
                  type: 'boolean',
                  default: true,
                  description: 'Include specific recommendations for improvement'
                },
                critical_only: {
                  type: 'boolean',
                  default: false,
                  description: 'Focus only on critical launch blockers'
                }
              }
            }
          },

          // Cross-Room Comparison
          {
            name: 'compare_room_types',
            description: 'Compare performance metrics across all three room types',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for comparison'
                },
                metrics: {
                  type: 'array',
                  items: {
                    type: 'string',
                    enum: ['completion_rate', 'engagement', 'duration', 'participation', 'all']
                  },
                  default: ['all'],
                  description: 'Specific metrics to compare'
                }
              }
            }
          },

          // User Behavior Analysis
          {
            name: 'analyze_user_behavior',
            description: 'Cross-room user behavior patterns and preferences',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for analysis'
                },
                behavior_type: {
                  type: 'string',
                  enum: ['participation', 'preferences', 'retention', 'progression', 'all'],
                  default: 'all',
                  description: 'Type of behavior to analyze'
                }
              }
            }
          },

          // Performance Optimization Insights
          {
            name: 'get_optimization_insights',
            description: 'Specific insights for optimizing Arena for 10,000+ concurrent users',
            inputSchema: {
              type: 'object',
              properties: {
                focus_area: {
                  type: 'string',
                  enum: ['scalability', 'engagement', 'retention', 'moderation', 'technical', 'all'],
                  default: 'all',
                  description: 'Area to focus optimization insights on'
                },
                target_metrics: {
                  type: 'boolean',
                  default: true,
                  description: 'Include target metrics for scale'
                }
              }
            }
          },

          // Real-time Monitoring Data
          {
            name: 'get_realtime_metrics',
            description: 'Current real-time metrics across all room types',
            inputSchema: {
              type: 'object',
              properties: {
                include_alerts: {
                  type: 'boolean',
                  default: true,
                  description: 'Include any active alerts or issues'
                }
              }
            }
          },

          // User Journey Analytics
          {
            name: 'analyze_user_journeys',
            description: 'Track user movement and progression across all room types',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for analysis'
                },
                analysis_type: {
                  type: 'string',
                  enum: ['movement', 'preferences', 'role_progression', 'retention', 'segmentation', 'all'],
                  default: 'all',
                  description: 'Type of user journey analysis to perform'
                },
                user_segment: {
                  type: 'string',
                  enum: ['new_users', 'power_users', 'moderators', 'all'],
                  default: 'all',
                  description: 'User segment to analyze'
                }
              }
            }
          },

          // Platform Health Metrics
          {
            name: 'assess_platform_health',
            description: 'Comprehensive platform health assessment across all systems',
            inputSchema: {
              type: 'object',
              properties: {
                period: {
                  type: 'string',
                  enum: ['day', 'week', 'month', '3months', 'all'],
                  default: 'week',
                  description: 'Time period for health assessment'
                },
                health_aspect: {
                  type: 'string',
                  enum: ['engagement', 'retention', 'growth', 'stickiness', 'scalability', 'all'],
                  default: 'all',
                  description: 'Specific health aspect to focus on'
                },
                include_predictions: {
                  type: 'boolean',
                  default: true,
                  description: 'Include growth and trend predictions'
                }
              }
            }
          },

          // Launch Readiness Testing
          {
            name: 'test_launch_readiness',
            description: 'Execute comprehensive launch readiness tests and validations',
            inputSchema: {
              type: 'object',
              properties: {
                test_suite: {
                  type: 'string',
                  enum: ['critical_flows', 'performance_load', 'integration_validation', 'all'],
                  default: 'all',
                  description: 'Which test suite to run'
                },
                target_load: {
                  type: 'number',
                  default: 10000,
                  description: 'Target concurrent user load for performance testing'
                },
                include_simulation: {
                  type: 'boolean',
                  default: true,
                  description: 'Include load simulation results'
                }
              }
            }
          }
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'analyze_arena_rooms':
            return await this.analyzeArenaRooms(args);
            
          case 'analyze_open_discussions':
            return await this.analyzeOpenDiscussions(args);
            
          case 'analyze_debates_discussions':
            return await this.analyzeDebatesDiscussions(args);
            
          case 'assess_launch_readiness':
            return await this.assessLaunchReadiness(args);
            
          case 'compare_room_types':
            return await this.compareRoomTypes(args);
            
          case 'analyze_user_behavior':
            return await this.analyzeUserBehavior(args);
            
          case 'get_optimization_insights':
            return await this.getOptimizationInsights(args);
            
          case 'get_realtime_metrics':
            return await this.getRealtimeMetrics(args);
            
          case 'analyze_user_journeys':
            return await this.analyzeUserJourneys(args);
            
          case 'assess_platform_health':
            return await this.assessPlatformHealth(args);
            
          case 'test_launch_readiness':
            return await this.testLaunchReadiness(args);
            
          default:
            throw new McpError(ErrorCode.MethodNotFound, `Tool ${name} not found`);
        }
      } catch (error) {
        console.error(`Error executing tool ${name}:`, error);
        throw new McpError(ErrorCode.InternalError, `Failed to execute tool: ${error.message}`);
      }
    });
  }

  async analyzeArenaRooms(args) {
    const { period = 'week', focus = 'all' } = args;
    
    const analysis = await this.arenaAnalytics.analyzeArenaRooms(period);
    
    if (focus !== 'all') {
      return this.filterAnalysisSection(analysis, focus);
    }
    
    return {
      content: [
        {
          type: 'text',
          text: this.formatArenaAnalysis(analysis)
        }
      ]
    };
  }

  async analyzeOpenDiscussions(args) {
    const { period = 'week', focus = 'all' } = args;
    
    const analysis = await this.openDiscussionAnalytics.analyzeOpenDiscussions(period);
    
    if (focus !== 'all') {
      return this.filterAnalysisSection(analysis, focus);
    }
    
    return {
      content: [
        {
          type: 'text',
          text: this.formatOpenDiscussionAnalysis(analysis)
        }
      ]
    };
  }

  async analyzeDebatesDiscussions(args) {
    const { period = 'week', focus = 'all' } = args;
    
    const analysis = await this.debatesDiscussionsAnalytics.analyzeDebatesDiscussions(period);
    
    if (focus !== 'all') {
      return this.filterAnalysisSection(analysis, focus);
    }
    
    return {
      content: [
        {
          type: 'text',
          text: this.formatDebatesDiscussionsAnalysis(analysis)
        }
      ]
    };
  }

  async assessLaunchReadiness(args) {
    const { include_recommendations = true, critical_only = false } = args;
    
    // Get analysis from all room types
    const [arenaAnalysis, openAnalysis, debatesAnalysis] = await Promise.all([
      this.arenaAnalytics.analyzeArenaRooms('month'),
      this.openDiscussionAnalytics.analyzeOpenDiscussions('month'),
      this.debatesDiscussionsAnalytics.analyzeDebatesDiscussions('month')
    ]);

    const launchAssessment = this.compileLaunchReadiness(
      arenaAnalysis,
      openAnalysis,
      debatesAnalysis,
      include_recommendations,
      critical_only
    );

    return {
      content: [
        {
          type: 'text',
          text: this.formatLaunchReadiness(launchAssessment)
        }
      ]
    };
  }

  async compareRoomTypes(args) {
    const { period = 'week', metrics = ['all'] } = args;
    
    const [arenaAnalysis, openAnalysis, debatesAnalysis] = await Promise.all([
      this.arenaAnalytics.analyzeArenaRooms(period),
      this.openDiscussionAnalytics.analyzeOpenDiscussions(period),
      this.debatesDiscussionsAnalytics.analyzeDebatesDiscussions(period)
    ]);

    const comparison = this.compareAnalytics(arenaAnalysis, openAnalysis, debatesAnalysis, metrics);

    return {
      content: [
        {
          type: 'text',
          text: this.formatRoomTypeComparison(comparison)
        }
      ]
    };
  }

  async analyzeUserBehavior(args) {
    const { period = 'week', behavior_type = 'all' } = args;
    
    // Get user data across all room types
    const userBehavior = await this.analyzeUserBehaviorAcrossRooms(period, behavior_type);

    return {
      content: [
        {
          type: 'text',
          text: this.formatUserBehaviorAnalysis(userBehavior)
        }
      ]
    };
  }

  async getOptimizationInsights(args) {
    const { focus_area = 'all', target_metrics = true } = args;
    
    const insights = await this.generateOptimizationInsights(focus_area, target_metrics);

    return {
      content: [
        {
          type: 'text',
          text: this.formatOptimizationInsights(insights)
        }
      ]
    };
  }

  async getRealtimeMetrics(args) {
    const { include_alerts = true } = args;
    
    const metrics = await this.getCurrentMetrics(include_alerts);

    return {
      content: [
        {
          type: 'text',
          text: this.formatRealtimeMetrics(metrics)
        }
      ]
    };
  }

  // Helper methods for analysis compilation and formatting
  filterAnalysisSection(analysis, focus) {
    const sections = {
      'overview': ['overview'],
      'judging': ['judgingPatterns', 'biasDetection'],
      'bias': ['biasDetection'],
      'timers': ['timerAccuracy'],
      'voice': ['voiceQuality'],
      'completion': ['completionRates'],
      'engagement': ['participantEngagement'],
      'dropoff': ['dropoffPatterns'],
      'moderation': ['moderatorActivity', 'moderatorEffectiveness'],
      'categories': ['categoryPopularity'],
      'speaker_panel': ['speakerPanelAnalysis'],
      'conversion': ['audienceToSpeakerConversion'],
      'room_types': ['roomTypeDistribution']
    };

    const relevantSections = sections[focus] || [focus];
    const filtered = {};
    
    relevantSections.forEach(section => {
      if (analysis[section]) {
        filtered[section] = analysis[section];
      }
    });

    filtered.insights = analysis.insights?.filter(insight => 
      insight.category === focus || relevantSections.includes(insight.category)
    ) || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(filtered, null, 2)
        }
      ]
    };
  }

  compileLaunchReadiness(arenaAnalysis, openAnalysis, debatesAnalysis, includeRecommendations, criticalOnly) {
    const allInsights = [
      ...(arenaAnalysis.insights || []),
      ...(openAnalysis.insights || []),
      ...(debatesAnalysis.insights || [])
    ];

    const criticalIssues = allInsights.filter(i => i.priority === 'critical');
    const highIssues = allInsights.filter(i => i.priority === 'high');
    const mediumIssues = allInsights.filter(i => i.priority === 'medium');

    const overallReadinessScore = Math.round([
      arenaAnalysis.launchReadiness?.readinessScore || 50,
      openAnalysis.launchReadiness?.readinessScore || 50,
      debatesAnalysis.launchReadiness?.readinessScore || 50
    ].reduce((sum, score) => sum + score, 0) / 3);

    const daysUntilLaunch = DateHelpers.daysUntilLaunch();

    return {
      overallReadinessScore,
      daysUntilLaunch,
      criticalIssues: criticalOnly ? criticalIssues : [...criticalIssues, ...highIssues],
      mediumIssues: criticalOnly ? [] : mediumIssues,
      roomTypeReadiness: {
        arena: arenaAnalysis.launchReadiness?.readinessScore || 50,
        openDiscussion: openAnalysis.launchReadiness?.readinessScore || 50,
        debatesDiscussions: debatesAnalysis.launchReadiness?.readinessScore || 50
      },
      keyMetrics: {
        arenaCompletionRate: arenaAnalysis.completionRates?.overall || 0,
        openEngagementScore: openAnalysis.participantEngagement?.averageEngagementScore || 0,
        debatesConversionRate: debatesAnalysis.audienceToSpeakerConversion?.averageOverallConversion || 0
      },
      recommendations: includeRecommendations ? this.generateLaunchRecommendations(allInsights, daysUntilLaunch) : []
    };
  }

  generateLaunchRecommendations(insights, daysUntilLaunch) {
    const recommendations = [];
    const criticalIssues = insights.filter(i => i.priority === 'critical');
    const highIssues = insights.filter(i => i.priority === 'high');

    if (daysUntilLaunch <= 30) {
      recommendations.push({
        priority: 'critical',
        timeline: 'Next 7 days',
        action: 'Focus on critical stability and performance issues',
        details: `${criticalIssues.length} critical issues need immediate attention`
      });
    }

    if (criticalIssues.length > 0) {
      recommendations.push({
        priority: 'critical',
        timeline: 'Immediate',
        action: 'Resolve all critical issues before launch',
        details: criticalIssues.map(i => i.message).join('; ')
      });
    }

    if (highIssues.length > 0 && daysUntilLaunch > 14) {
      recommendations.push({
        priority: 'high',
        timeline: 'Next 2 weeks',
        action: 'Address high-priority user experience issues',
        details: `${highIssues.length} high-priority issues identified`
      });
    }

    return recommendations;
  }

  // Formatting methods (simplified for brevity)
  formatArenaAnalysis(analysis) {
    return `# Arena Rooms Analysis (${analysis.period.period})

## Overview
- Total Rooms: ${analysis.overview.totalRooms}
- Completion Rate: ${analysis.overview.completionRate}%
- 1v1 Rooms: ${analysis.overview.roomTypeDistribution['1v1']?.count || 0}
- 2v2 Rooms: ${analysis.overview.roomTypeDistribution['2v2']?.count || 0}

## Key Metrics
- Average Duration: ${DateHelpers.formatDuration(analysis.durationAnalysis.average)}
- Judge Participation: ${analysis.judgingPatterns.judgeParticipation?.totalJudges || 0} judges
- Timer Accuracy: ${Math.round(analysis.timerAccuracy.averageAccuracy)}%
- Voice Issues Rate: ${analysis.voiceQuality.voiceIssues?.rate || 0}%

## Insights & Recommendations
${analysis.insights.map(insight => `- **${insight.category.toUpperCase()}**: ${insight.message}`).join('\n')}

## Launch Readiness Score: ${analysis.launchReadiness?.readinessScore || 'N/A'}/100

${JSON.stringify(analysis, null, 2)}`;
  }

  formatOpenDiscussionAnalysis(analysis) {
    return `# Open Discussions Analysis (${analysis.period.period})

## Overview
- Total Rooms: ${analysis.overview.totalRooms}
- Completion Rate: ${analysis.overview.completionRate}%
- Average Engagement Score: ${Math.round(analysis.participantEngagement.averageEngagementScore)}

## Key Metrics
- Sustainability Score: ${analysis.roomLongevity.sustainabilityScore}%
- Dropoff Rate: ${Math.round(analysis.dropoffPatterns.overallDropoffRate)}%
- Hand-raise Approval Rate: ${analysis.handRaiseAnalysis.approvalRate}%

## Top Categories
${analysis.overview.topCategories.map(cat => `- ${cat.category}: ${cat.count} rooms (${cat.percentage}%)`).join('\n')}

## Insights & Recommendations
${analysis.insights.map(insight => `- **${insight.category.toUpperCase()}**: ${insight.message}`).join('\n')}

${JSON.stringify(analysis, null, 2)}`;
  }

  formatDebatesDiscussionsAnalysis(analysis) {
    return `# Debates & Discussions Analysis (${analysis.period.period})

## Overview
- Total Rooms: ${analysis.overview.totalRooms}
- Speaker Panel Utilization: ${Math.round(analysis.speakerPanelAnalysis.averageSpeakerUtilization)}%
- Audience-to-Speaker Conversion: ${Math.round(analysis.audienceToSpeakerConversion.averageOverallConversion)}%

## Room Types
${analysis.roomTypeDistribution.typeDistribution.map(type => 
  `- ${type.type}: ${type.count} rooms (${type.percentage}%)`
).join('\n')}

## Speaker Panel Usage
- Average Speakers per Room: ${Math.round(analysis.speakerPanelAnalysis.averageSpeakersPerRoom)}
- Full Panel Usage: ${analysis.speakerPanelAnalysis.panelFullnessDistribution.full} rooms

## Insights & Recommendations
${analysis.insights.map(insight => `- **${insight.category.toUpperCase()}**: ${insight.message}`).join('\n')}

${JSON.stringify(analysis, null, 2)}`;
  }

  formatLaunchReadiness(assessment) {
    const statusEmoji = assessment.overallReadinessScore >= 85 ? '🟢' : 
                       assessment.overallReadinessScore >= 70 ? '🟡' : '🔴';

    return `# Arena Launch Readiness Assessment ${statusEmoji}

## Overall Readiness: ${assessment.overallReadinessScore}/100
**Days until September 12 launch:** ${assessment.daysUntilLaunch}

## Room Type Readiness
- Arena Rooms: ${assessment.roomTypeReadiness.arena}/100
- Open Discussions: ${assessment.roomTypeReadiness.openDiscussion}/100  
- Debates & Discussions: ${assessment.roomTypeReadiness.debatesDiscussions}/100

## Critical Issues (${assessment.criticalIssues.length})
${assessment.criticalIssues.map(issue => `🚨 **${issue.category}**: ${issue.message}`).join('\n')}

## Key Performance Metrics
- Arena Completion Rate: ${assessment.keyMetrics.arenaCompletionRate}%
- Open Discussion Engagement: ${Math.round(assessment.keyMetrics.openEngagementScore)}
- Speaker Conversion Rate: ${Math.round(assessment.keyMetrics.debatesConversionRate)}%

## Priority Recommendations
${assessment.recommendations.map(rec => 
  `**${rec.priority.toUpperCase()}** (${rec.timeline}): ${rec.action}\n   ${rec.details}`
).join('\n\n')}

${JSON.stringify(assessment, null, 2)}`;
  }

  formatRoomTypeComparison(comparison) {
    return `# Room Type Performance Comparison

${JSON.stringify(comparison, null, 2)}`;
  }

  formatUserBehaviorAnalysis(behavior) {
    return `# User Behavior Analysis

${JSON.stringify(behavior, null, 2)}`;
  }

  formatOptimizationInsights(insights) {
    return `# Performance Optimization Insights

${JSON.stringify(insights, null, 2)}`;
  }

  formatRealtimeMetrics(metrics) {
    return `# Real-time Metrics Dashboard

${JSON.stringify(metrics, null, 2)}`;
  }

  formatUserJourneyAnalysis(analysis) {
    return `# User Journey Analysis (${analysis.period?.period || 'N/A'})

## Cross-Room Movement Patterns
- Users trying multiple room types: ${analysis.movementPatterns?.crossRoomUsers || 0}
- Most common journey: ${analysis.movementPatterns?.mostCommonJourney || 'N/A'}
- Room type retention: ${Math.round(analysis.movementPatterns?.roomTypeRetention || 0)}%

## Role Progression Analysis
- Audience → Speaker conversion: ${Math.round(analysis.roleProgression?.audienceToSpeaker || 0)}%
- Speaker → Moderator progression: ${Math.round(analysis.roleProgression?.speakerToModerator || 0)}%
- Average progression time: ${analysis.roleProgression?.averageProgressionTime || 'N/A'}

## User Segmentation
${analysis.userSegmentation?.segments?.map(segment => 
  `- ${segment.name}: ${segment.count} users (${segment.percentage}%)`
).join('\n') || 'No segmentation data'}

## Key Insights
${analysis.insights?.map(insight => `- **${insight.category}**: ${insight.message}`).join('\n') || 'No insights available'}

${JSON.stringify(analysis, null, 2)}`;
  }

  formatPlatformHealthAssessment(assessment) {
    const healthEmoji = assessment.overallHealthScore >= 85 ? '🟢' : 
                       assessment.overallHealthScore >= 70 ? '🟡' : '🔴';

    return `# Platform Health Assessment ${healthEmoji}

## Overall Health Score: ${assessment.overallHealthScore}/100

## Cross-Room Engagement Comparison
${assessment.crossRoomEngagement?.roomTypes?.map(room => 
  `- ${room.type}: ${Math.round(room.engagementRate)}% (${room.trend})`
).join('\n') || 'No engagement data'}

## Retention Metrics
- 1-day retention: ${Math.round(assessment.retentionAnalysis?.dayOne || 0)}%
- 7-day retention: ${Math.round(assessment.retentionAnalysis?.daySeven || 0)}%
- 30-day retention: ${Math.round(assessment.retentionAnalysis?.dayThirty || 0)}%

## Growth Analysis
- User growth rate: ${Math.round(assessment.growthMetrics?.userGrowthRate || 0)}%
- Room creation growth: ${Math.round(assessment.growthMetrics?.roomGrowthRate || 0)}%
- Predicted next month: ${assessment.growthMetrics?.predictions?.nextMonth || 'N/A'}

## User Stickiness
- Daily/Monthly Active: ${Math.round(assessment.stickinessMetrics?.dauMauRatio || 0)}%
- Session frequency: ${assessment.stickinessMetrics?.averageSessionsPerUser || 0} sessions/user

## Scalability Assessment
- Current load capacity: ${assessment.scalabilityMetrics?.currentCapacity || 'N/A'}
- Estimated max concurrent: ${assessment.scalabilityMetrics?.maxConcurrentUsers || 'N/A'}
- Infrastructure readiness: ${assessment.scalabilityMetrics?.infrastructureScore || 'N/A'}/100

## Key Recommendations
${assessment.recommendations?.map(rec => 
  `**${rec.priority.toUpperCase()}**: ${rec.action}`
).join('\n') || 'No recommendations'}

${JSON.stringify(assessment, null, 2)}`;
  }

  formatLaunchReadinessTests(testResults) {
    const statusEmoji = testResults.overallStatus === 'PASS' ? '✅' : 
                       testResults.overallStatus === 'WARNING' ? '⚠️' : '❌';

    return `# Launch Readiness Test Results ${statusEmoji}

## Overall Status: ${testResults.overallStatus}
**Readiness Score:** ${testResults.readinessScore}/100

## Critical Flow Tests
${testResults.criticalFlowTests?.map(test => 
  `- ${test.flowName}: ${test.status} (${test.successRate}%)`
).join('\n') || 'No critical flow tests'}

## Performance Under Load
- Target concurrent users: ${testResults.performanceTests?.targetLoad || 'N/A'}
- Achieved load: ${testResults.performanceTests?.achievedLoad || 'N/A'}
- Response time (95th percentile): ${testResults.performanceTests?.responseTime95th || 'N/A'}ms
- Error rate under load: ${testResults.performanceTests?.errorRate || 'N/A'}%

## System Integration Validation
${testResults.integrationTests?.map(test => 
  `- ${test.system}: ${test.status} (Latency: ${test.latency}ms)`
).join('\n') || 'No integration tests'}

## Go/No-Go Decision Framework
**Recommendation:** ${testResults.goNoGoDecision?.recommendation || 'PENDING'}
**Confidence Level:** ${testResults.goNoGoDecision?.confidence || 'N/A'}%

### Blocking Issues (${testResults.goNoGoDecision?.blockingIssues?.length || 0})
${testResults.goNoGoDecision?.blockingIssues?.map(issue => 
  `🚨 **${issue.severity}**: ${issue.description}`
).join('\n') || 'No blocking issues'}

### Pre-Launch Checklist
${testResults.prelaunchChecklist?.map(item => 
  `${item.status === 'COMPLETE' ? '✅' : '⏳'} ${item.task}`
).join('\n') || 'No checklist items'}

${JSON.stringify(testResults, null, 2)}`;
  }

  // Placeholder methods for complex analysis
  async analyzeUserBehaviorAcrossRooms(period, behaviorType) {
    return { message: 'User behavior analysis coming soon' };
  }

  async generateOptimizationInsights(focusArea, targetMetrics) {
    return { message: 'Optimization insights coming soon' };
  }

  async getCurrentMetrics(includeAlerts) {
    return { message: 'Real-time metrics coming soon' };
  }

  async analyzeUserJourneys(args) {
    const { period = 'week', analysis_type = 'all', user_segment = 'all' } = args;
    
    const analysis = await this.userJourneyAnalytics.analyzeUserJourneys(period, analysis_type, user_segment);
    
    return {
      content: [
        {
          type: 'text',
          text: this.formatUserJourneyAnalysis(analysis)
        }
      ]
    };
  }

  async assessPlatformHealth(args) {
    const { period = 'week', health_aspect = 'all', include_predictions = true } = args;
    
    const assessment = await this.platformHealthAnalytics.assessPlatformHealth(period, health_aspect, include_predictions);
    
    return {
      content: [
        {
          type: 'text',
          text: this.formatPlatformHealthAssessment(assessment)
        }
      ]
    };
  }

  async testLaunchReadiness(args) {
    const { test_suite = 'all', target_load = 10000, include_simulation = true } = args;
    
    const testResults = await this.launchReadinessAnalytics.runLaunchReadinessTests(test_suite, target_load, include_simulation);
    
    return {
      content: [
        {
          type: 'text',
          text: this.formatLaunchReadinessTests(testResults)
        }
      ]
    };
  }

  compareAnalytics(arenaAnalysis, openAnalysis, debatesAnalysis, metrics) {
    return {
      completionRates: {
        arena: arenaAnalysis.completionRates?.overall || 0,
        openDiscussion: openAnalysis.overview?.completionRate || 0,
        debatesDiscussions: debatesAnalysis.overview?.completionRate || 0
      },
      engagement: {
        arena: arenaAnalysis.participantBehavior?.averageParticipantsPerRoom || 0,
        openDiscussion: openAnalysis.participantEngagement?.averageEngagementScore || 0,
        debatesDiscussions: debatesAnalysis.participantEngagement?.averageEngagement || 0
      }
    };
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Arena Analytics MCP server running on stdio');
  }
}

// Environment validation
function validateEnvironment() {
  const required = [
    'APPWRITE_ENDPOINT',
    'APPWRITE_PROJECT_ID', 
    'APPWRITE_API_KEY',
    'APPWRITE_DATABASE_ID'
  ];

  const missing = required.filter(env => !process.env[env]);
  
  if (missing.length > 0) {
    console.error('Missing required environment variables:', missing.join(', '));
    process.exit(1);
  }
}

// Start server
if (import.meta.url === `file://${process.argv[1]}`) {
  validateEnvironment();
  const server = new ArenaAnalyticsMCPServer();
  server.start().catch(console.error);
}