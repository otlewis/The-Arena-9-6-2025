import _ from 'lodash';
import { BaseAnalytics } from './base-analytics.js';
import { DateHelpers } from '../utils/date-helpers.js';
import { AppwriteClient } from '../db/appwrite-client.js';

export class ArenaAnalytics extends BaseAnalytics {
  constructor(appwriteClient) {
    super(appwriteClient);
  }

  /**
   * Comprehensive Arena analytics for 1v1 and 2v2 structured debates
   */
  async analyzeArenaRooms(period = 'week') {
    const { startDate, endDate } = DateHelpers.getDateRange(period);
    
    // Get all arena rooms in the period
    const rooms = await this.db.getArenaRooms(startDate, endDate);
    const roomIds = rooms.documents.map(room => room.$id);
    
    // Get related data
    const [participants, judgments, timers, timerEvents] = await Promise.all([
      this.db.getArenaParticipants(roomIds),
      this.db.getArenaJudgments(roomIds),
      this.db.getTimers(roomIds, 'arena'),
      this.getTimerEventsForRooms(roomIds)
    ]);

    const analysis = {
      period: { startDate, endDate, period },
      overview: this.calculateArenaOverview(rooms.documents),
      completionRates: this.analyzeCompletionRates(rooms.documents),
      judgingPatterns: this.analyzeJudgingPatterns(judgments.documents, rooms.documents),
      biasDetection: this.detectJudgingBias(judgments.documents, participants.documents),
      durationAnalysis: this.analyzeDurations(rooms.documents),
      voiceQuality: this.analyzeVoiceQuality(rooms.documents, participants.documents),
      timerAccuracy: this.analyzeTimerAccuracy(timers.documents, timerEvents),
      participantBehavior: this.analyzeParticipantBehavior(participants.documents, rooms.documents),
      roomTypeDistribution: this.analyzeRoomTypes(rooms.documents),
      peakUsageTimes: this.analyzePeakUsage(rooms.documents),
      trends: this.calculateTrend(rooms.documents)
    };

    // Generate insights and recommendations
    analysis.insights = this.generateArenaInsights(analysis);
    analysis.launchReadiness = this.prepareLaunchMetrics(analysis);

    return analysis;
  }

  /**
   * Calculate basic overview metrics
   */
  calculateArenaOverview(rooms) {
    const totalRooms = rooms.length;
    const completedRooms = rooms.filter(room => room.status === 'completed').length;
    const ongoingRooms = rooms.filter(room => room.status === 'active').length;
    const cancelledRooms = rooms.filter(room => room.status === 'cancelled').length;
    
    const roomTypes = _.groupBy(rooms, 'roomType');
    const oneVOneRooms = (roomTypes['1v1'] || []).length;
    const twoVTwoRooms = (roomTypes['2v2'] || []).length;

    return {
      totalRooms,
      completedRooms,
      ongoingRooms,
      cancelledRooms,
      completionRate: this.calculateCompletionRate(totalRooms, completedRooms),
      roomTypeDistribution: {
        '1v1': { count: oneVOneRooms, percentage: Math.round((oneVOneRooms / totalRooms) * 100) },
        '2v2': { count: twoVTwoRooms, percentage: Math.round((twoVTwoRooms / totalRooms) * 100) }
      }
    };
  }

  /**
   * Analyze completion rates by various factors
   */
  analyzeCompletionRates(rooms) {
    const byRoomType = _.groupBy(rooms, 'roomType');
    const byTopic = _.groupBy(rooms, 'topic');
    const byTimeOfDay = _.groupBy(rooms, room => new Date(room.createdAt).getHours());

    const analysis = {
      overall: this.calculateCompletionRate(rooms.length, rooms.filter(r => r.status === 'completed').length),
      byRoomType: {},
      byTopic: {},
      byTimeOfDay: {}
    };

    // Completion rates by room type
    Object.keys(byRoomType).forEach(type => {
      const typeRooms = byRoomType[type];
      const completed = typeRooms.filter(r => r.status === 'completed').length;
      analysis.byRoomType[type] = {
        total: typeRooms.length,
        completed,
        rate: this.calculateCompletionRate(typeRooms.length, completed)
      };
    });

    // Completion rates by topic (top 10)
    const topTopics = Object.keys(byTopic)
      .map(topic => ({
        topic,
        rooms: byTopic[topic],
        total: byTopic[topic].length
      }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 10);

    topTopics.forEach(({ topic, rooms }) => {
      const completed = rooms.filter(r => r.status === 'completed').length;
      analysis.byTopic[topic] = {
        total: rooms.length,
        completed,
        rate: this.calculateCompletionRate(rooms.length, completed)
      };
    });

    // Completion rates by hour of day
    Object.keys(byTimeOfDay).forEach(hour => {
      const hourRooms = byTimeOfDay[hour];
      const completed = hourRooms.filter(r => r.status === 'completed').length;
      analysis.byTimeOfDay[hour] = {
        total: hourRooms.length,
        completed,
        rate: this.calculateCompletionRate(hourRooms.length, completed)
      };
    });

    return analysis;
  }

  /**
   * Analyze judging patterns and scoring behavior
   */
  analyzeJudgingPatterns(judgments, rooms) {
    if (judgments.length === 0) {
      return { totalJudgments: 0, averageScore: 0, distribution: {} };
    }

    const scores = judgments.map(j => j.totalScore || 0).filter(s => s > 0);
    const judgeActivity = _.groupBy(judgments, 'judgeId');
    
    // Score distribution
    const scoreRanges = {
      '0-20': scores.filter(s => s <= 20).length,
      '21-40': scores.filter(s => s > 20 && s <= 40).length,
      '41-60': scores.filter(s => s > 40 && s <= 60).length,
      '61-80': scores.filter(s => s > 60 && s <= 80).length,
      '81-100': scores.filter(s => s > 80).length
    };

    // Judge participation analysis
    const judgeStats = Object.keys(judgeActivity).map(judgeId => {
      const judgeJudgments = judgeActivity[judgeId];
      const judgeScores = judgeJudgments.map(j => j.totalScore || 0).filter(s => s > 0);
      
      return {
        judgeId,
        totalJudgments: judgeJudgments.length,
        averageScore: judgeScores.length > 0 ? _.mean(judgeScores) : 0,
        scoreVariation: judgeScores.length > 0 ? _.max(judgeScores) - _.min(judgeScores) : 0,
        completionRate: this.calculateCompletionRate(
          judgeJudgments.length,
          judgeJudgments.filter(j => j.status === 'completed').length
        )
      };
    });

    return {
      totalJudgments: judgments.length,
      averageScore: scores.length > 0 ? _.mean(scores) : 0,
      scoreDistribution: scoreRanges,
      judgeParticipation: {
        totalJudges: Object.keys(judgeActivity).length,
        averageJudgmentsPerJudge: judgments.length / Object.keys(judgeActivity).length,
        topJudges: judgeStats.sort((a, b) => b.totalJudgments - a.totalJudgments).slice(0, 5)
      },
      scoring: this.calculateStats(scores, 'judgment_scores')
    };
  }

  /**
   * Detect potential judging bias
   */
  detectJudgingBias(judgments, participants) {
    const biasAnalysis = {
      potentialBias: [],
      scoringConsistency: {},
      recommendations: []
    };

    if (judgments.length === 0) return biasAnalysis;

    // Group judgments by judge
    const judgeGroups = _.groupBy(judgments, 'judgeId');
    
    Object.keys(judgeGroups).forEach(judgeId => {
      const judgeJudgments = judgeGroups[judgeId];
      const scores = judgeJudgments.map(j => j.totalScore || 0).filter(s => s > 0);
      
      if (scores.length < 3) return; // Need at least 3 judgments for bias detection
      
      const mean = _.mean(scores);
      const stdDev = Math.sqrt(scores.reduce((sum, score) => sum + Math.pow(score - mean, 2), 0) / scores.length);
      
      // Check for consistently high or low scoring
      const highScoreBias = scores.filter(s => s > 80).length / scores.length;
      const lowScoreBias = scores.filter(s => s < 40).length / scores.length;
      
      if (highScoreBias > 0.7) {
        biasAnalysis.potentialBias.push({
          judgeId,
          type: 'high_scoring',
          severity: 'medium',
          details: `${Math.round(highScoreBias * 100)}% of scores above 80`,
          totalJudgments: scores.length
        });
      }
      
      if (lowScoreBias > 0.7) {
        biasAnalysis.potentialBias.push({
          judgeId,
          type: 'low_scoring',
          severity: 'medium',
          details: `${Math.round(lowScoreBias * 100)}% of scores below 40`,
          totalJudgments: scores.length
        });
      }
      
      // Check for low variation (potential non-engagement)
      if (stdDev < 10 && scores.length > 5) {
        biasAnalysis.potentialBias.push({
          judgeId,
          type: 'low_variation',
          severity: 'low',
          details: `Very consistent scoring pattern (std dev: ${stdDev.toFixed(1)})`,
          totalJudgments: scores.length
        });
      }
      
      biasAnalysis.scoringConsistency[judgeId] = {
        mean: Math.round(mean),
        standardDeviation: Math.round(stdDev * 100) / 100,
        consistency: stdDev < 15 ? 'high' : stdDev < 25 ? 'medium' : 'low'
      };
    });

    // Generate recommendations
    if (biasAnalysis.potentialBias.length > 0) {
      biasAnalysis.recommendations.push(
        'Consider implementing judge calibration sessions',
        'Review scoring guidelines with judges showing bias patterns',
        'Implement peer review for judges with concerning patterns'
      );
    }

    return biasAnalysis;
  }

  /**
   * Analyze debate durations
   */
  analyzeDurations(rooms) {
    const completedRooms = rooms.filter(room => room.status === 'completed' && room.endedAt);
    
    if (completedRooms.length === 0) {
      return { count: 0, average: 0, distribution: {} };
    }

    const durations = completedRooms.map(room => {
      const duration = DateHelpers.calculateDuration(room.createdAt, room.endedAt);
      return duration.minutes;
    });

    const durationRanges = {
      'under_15min': durations.filter(d => d < 15).length,
      '15_30min': durations.filter(d => d >= 15 && d < 30).length,
      '30_60min': durations.filter(d => d >= 30 && d < 60).length,
      '1_2hours': durations.filter(d => d >= 60 && d < 120).length,
      'over_2hours': durations.filter(d => d >= 120).length
    };

    return {
      count: durations.length,
      average: this.calculateAverageDuration(durations),
      median: durations.sort((a, b) => a - b)[Math.floor(durations.length / 2)],
      distribution: durationRanges,
      stats: this.calculateStats(durations, 'duration_minutes'),
      outliers: this.detectOutliers(durations)
    };
  }

  /**
   * Analyze voice quality metrics
   */
  analyzeVoiceQuality(rooms, participants) {
    // Note: This would integrate with Agora analytics in a real implementation
    // For now, we'll analyze based on available data patterns
    
    const roomsWithVoice = rooms.filter(room => room.voiceEnabled !== false);
    const voiceIssues = rooms.filter(room => 
      room.issues && room.issues.includes('audio') || 
      room.status === 'cancelled' && room.cancelReason?.includes('audio')
    );

    const participantVoiceData = participants.filter(p => p.voiceConnected !== false);
    
    return {
      voiceEnabledRooms: roomsWithVoice.length,
      voiceEnabledRate: this.calculateCompletionRate(rooms.length, roomsWithVoice.length),
      voiceIssues: {
        total: voiceIssues.length,
        rate: this.calculateCompletionRate(rooms.length, voiceIssues.length),
        commonIssues: this.extractCommonVoiceIssues(voiceIssues)
      },
      participantConnection: {
        connectedRate: this.calculateCompletionRate(participants.length, participantVoiceData.length),
        avgConnectionTime: this.calculateAverageConnectionTime(participantVoiceData)
      }
    };
  }

  /**
   * Analyze timer synchronization accuracy
   */
  analyzeTimerAccuracy(timers, timerEvents) {
    if (timers.length === 0) return { totalTimers: 0, accuracy: 100 };

    const timerAnalysis = timers.map(timer => {
      const events = timerEvents.filter(event => event.timerId === timer.$id);
      
      // Calculate accuracy based on expected vs actual durations
      const startEvent = events.find(e => e.eventType === 'started');
      const endEvent = events.find(e => e.eventType === 'completed' || e.eventType === 'stopped');
      
      if (!startEvent || !endEvent) return null;
      
      const actualDuration = DateHelpers.calculateDuration(startEvent.createdAt, endEvent.createdAt).minutes;
      const expectedDuration = timer.durationSeconds / 60;
      const accuracy = Math.max(0, 100 - Math.abs(actualDuration - expectedDuration) / expectedDuration * 100);
      
      return {
        timerId: timer.$id,
        roomId: timer.roomId,
        expectedDuration,
        actualDuration,
        accuracy,
        syncIssues: events.filter(e => e.eventType === 'sync_error').length
      };
    }).filter(Boolean);

    const accuracyScores = timerAnalysis.map(t => t.accuracy);
    const syncIssues = timerAnalysis.reduce((sum, t) => sum + t.syncIssues, 0);

    return {
      totalTimers: timers.length,
      averageAccuracy: accuracyScores.length > 0 ? _.mean(accuracyScores) : 100,
      syncIssues: {
        total: syncIssues,
        rate: this.calculateCompletionRate(timers.length, syncIssues)
      },
      accuracyDistribution: {
        excellent: accuracyScores.filter(a => a >= 95).length,
        good: accuracyScores.filter(a => a >= 90 && a < 95).length,
        fair: accuracyScores.filter(a => a >= 80 && a < 90).length,
        poor: accuracyScores.filter(a => a < 80).length
      }
    };
  }

  /**
   * Analyze participant behavior patterns
   */
  analyzeParticipantBehavior(participants, rooms) {
    const behavior = {
      totalParticipants: participants.length,
      uniqueUsers: new Set(participants.map(p => p.userId)).size,
      roleDistribution: _.countBy(participants, 'role'),
      averageParticipantsPerRoom: participants.length / rooms.length,
      participationPatterns: this.analyzeParticipationPatterns(participants)
    };

    return behavior;
  }

  /**
   * Helper methods
   */
  async getTimerEventsForRooms(roomIds) {
    const timers = await this.db.getTimers(roomIds);
    const timerIds = timers.documents.map(t => t.$id);
    return this.db.getTimerEvents(timerIds);
  }

  extractCommonVoiceIssues(voiceIssues) {
    // Extract and categorize voice issues from room data
    return {
      connectionFailures: voiceIssues.filter(r => r.cancelReason?.includes('connection')).length,
      audioQuality: voiceIssues.filter(r => r.cancelReason?.includes('quality')).length,
      permissionIssues: voiceIssues.filter(r => r.cancelReason?.includes('permission')).length
    };
  }

  calculateAverageConnectionTime(participants) {
    // Calculate average time to connect to voice
    const connectionTimes = participants
      .filter(p => p.voiceConnectedAt && p.joinedAt)
      .map(p => DateHelpers.calculateDuration(p.joinedAt, p.voiceConnectedAt).minutes);
    
    return connectionTimes.length > 0 ? _.mean(connectionTimes) : 0;
  }

  analyzeParticipationPatterns(participants) {
    const userParticipation = _.groupBy(participants, 'userId');
    const participationCounts = Object.values(userParticipation).map(userRooms => userRooms.length);
    
    return {
      oneTimeParticipants: participationCounts.filter(count => count === 1).length,
      repeatParticipants: participationCounts.filter(count => count > 1).length,
      superUsers: participationCounts.filter(count => count >= 5).length,
      averageParticipationsPerUser: _.mean(participationCounts)
    };
  }

  analyzeRoomTypes(rooms) {
    return _.countBy(rooms, 'roomType');
  }

  analyzePeakUsage(rooms) {
    const hourlyDistribution = _.countBy(rooms, room => new Date(room.createdAt).getHours());
    const dailyDistribution = _.countBy(rooms, room => new Date(room.createdAt).getDay());
    
    return {
      hourly: hourlyDistribution,
      daily: dailyDistribution,
      peakHour: Object.keys(hourlyDistribution).reduce((a, b) => hourlyDistribution[a] > hourlyDistribution[b] ? a : b),
      peakDay: Object.keys(dailyDistribution).reduce((a, b) => dailyDistribution[a] > dailyDistribution[b] ? a : b)
    };
  }

  /**
   * Generate Arena-specific insights
   */
  generateArenaInsights(analysis) {
    const insights = [];

    // Completion rate insights
    if (analysis.completionRates.overall < 70) {
      insights.push({
        type: 'warning',
        category: 'completion',
        message: `Arena completion rate (${analysis.completionRates.overall}%) is below target`,
        priority: 'high',
        suggestion: 'Investigate common dropout points and improve user experience'
      });
    }

    // Judging bias insights
    if (analysis.biasDetection.potentialBias.length > 0) {
      insights.push({
        type: 'warning',
        category: 'judging',
        message: `Potential judging bias detected in ${analysis.biasDetection.potentialBias.length} judges`,
        priority: 'medium',
        suggestion: 'Implement judge training and calibration programs'
      });
    }

    // Timer accuracy insights
    if (analysis.timerAccuracy.averageAccuracy < 90) {
      insights.push({
        type: 'critical',
        category: 'timing',
        message: `Timer accuracy (${Math.round(analysis.timerAccuracy.averageAccuracy)}%) needs improvement`,
        priority: 'critical',
        suggestion: 'Investigate timer synchronization issues before launch'
      });
    }

    // Voice quality insights
    if (analysis.voiceQuality.voiceIssues.rate > 10) {
      insights.push({
        type: 'warning',
        category: 'voice',
        message: `Voice issues in ${analysis.voiceQuality.voiceIssues.rate}% of rooms`,
        priority: 'high',
        suggestion: 'Improve voice connection reliability and user guidance'
      });
    }

    return insights;
  }
}