import _ from 'lodash';
import { BaseAnalytics } from './base-analytics.js';
import { DateHelpers } from '../utils/date-helpers.js';
import { AppwriteClient } from '../db/appwrite-client.js';

export class OpenDiscussionAnalytics extends BaseAnalytics {
  constructor(appwriteClient) {
    super(appwriteClient);
  }

  /**
   * Comprehensive Open Discussion analytics
   * Note: Open discussions are more informal, single-moderator rooms
   */
  async analyzeOpenDiscussions(period = 'week') {
    const { startDate, endDate } = DateHelpers.getDateRange(period);
    
    // Get open discussion rooms (filter by roomType if needed)
    const rooms = await this.db.getDiscussionRooms(startDate, endDate, 'open_discussion');
    const roomIds = rooms.documents.map(room => room.$id);
    
    // Get related data
    const [participants, handRaises, timers] = await Promise.all([
      this.db.getDiscussionParticipants(roomIds),
      this.db.getHandRaises(roomIds),
      this.db.getTimers(roomIds, 'open_discussion')
    ]);

    const analysis = {
      period: { startDate, endDate, period },
      overview: this.calculateOpenDiscussionOverview(rooms.documents),
      participantEngagement: this.analyzeParticipantEngagement(participants.documents, rooms.documents),
      roomLongevity: this.analyzeRoomLongevity(rooms.documents),
      dropoffPatterns: this.analyzeDropoffPatterns(participants.documents, rooms.documents),
      handRaiseAnalysis: this.analyzeHandRaises(handRaises.documents, participants.documents),
      moderatorActivity: this.analyzeModeratorActivity(participants.documents, rooms.documents),
      speakingTimeDistribution: this.analyzeSpeakingTime(participants.documents),
      categoryPopularity: this.analyzeCategoryPopularity(rooms.documents),
      peakUsageTimes: this.analyzePeakUsage(rooms.documents),
      roomEffectiveness: this.analyzeRoomEffectiveness(rooms.documents, participants.documents),
      trends: this.calculateTrend(rooms.documents)
    };

    // Generate insights and recommendations
    analysis.insights = this.generateOpenDiscussionInsights(analysis);
    analysis.launchReadiness = this.prepareLaunchMetrics(analysis);

    return analysis;
  }

  /**
   * Calculate basic overview metrics for open discussions
   */
  calculateOpenDiscussionOverview(rooms) {
    const totalRooms = rooms.length;
    const activeRooms = rooms.filter(room => room.status === 'active').length;
    const completedRooms = rooms.filter(room => room.status === 'completed').length;
    const cancelledRooms = rooms.filter(room => room.status === 'cancelled').length;

    const categories = _.groupBy(rooms, 'category');
    const categoryDistribution = Object.keys(categories).map(category => ({
      category,
      count: categories[category].length,
      percentage: Math.round((categories[category].length / totalRooms) * 100)
    })).sort((a, b) => b.count - a.count);

    return {
      totalRooms,
      activeRooms,
      completedRooms,
      cancelledRooms,
      completionRate: this.calculateCompletionRate(totalRooms, completedRooms),
      averageRoomsPerDay: totalRooms / 7, // Assuming weekly analysis
      categoryDistribution: categoryDistribution.slice(0, 10), // Top 10 categories
      topCategories: categoryDistribution.slice(0, 5).map(c => c.category)
    };
  }

  /**
   * Analyze participant engagement patterns
   */
  analyzeParticipantEngagement(participants, rooms) {
    if (participants.length === 0) {
      return { totalParticipants: 0, engagementScore: 0 };
    }

    // Group participants by room
    const roomParticipants = _.groupBy(participants, 'roomId');
    
    // Calculate participation metrics per room
    const roomMetrics = Object.keys(roomParticipants).map(roomId => {
      const roomUsers = roomParticipants[roomId];
      const room = rooms.find(r => r.$id === roomId);
      
      if (!room) return null;

      const duration = room.endedAt ? 
        DateHelpers.calculateDuration(room.createdAt, room.endedAt).minutes : 
        DateHelpers.calculateDuration(room.createdAt, new Date()).minutes;

      // Calculate speaking time distribution
      const speakingUsers = roomUsers.filter(p => p.role === 'speaker');
      const audienceUsers = roomUsers.filter(p => p.role === 'audience');
      
      // Estimate engagement based on role transitions and time spent
      const engagementScore = this.calculateRoomEngagementScore(roomUsers, duration);

      return {
        roomId,
        totalParticipants: roomUsers.length,
        speakingParticipants: speakingUsers.length,
        audienceParticipants: audienceUsers.length,
        duration,
        engagementScore,
        participantTurnover: this.calculateParticipantTurnover(roomUsers),
        averageParticipationTime: this.calculateAverageParticipationTime(roomUsers, room)
      };
    }).filter(Boolean);

    const engagementScores = roomMetrics.map(m => m.engagementScore);
    const participantCounts = roomMetrics.map(m => m.totalParticipants);
    const speakerCounts = roomMetrics.map(m => m.speakingParticipants);

    return {
      totalParticipants: participants.length,
      uniqueUsers: new Set(participants.map(p => p.userId)).size,
      averageEngagementScore: _.mean(engagementScores),
      averageParticipantsPerRoom: _.mean(participantCounts),
      averageSpeakersPerRoom: _.mean(speakerCounts),
      engagementDistribution: {
        high: engagementScores.filter(s => s >= 70).length,
        medium: engagementScores.filter(s => s >= 40 && s < 70).length,
        low: engagementScores.filter(s => s < 40).length
      },
      participantStats: this.calculateStats(participantCounts, 'participants_per_room'),
      roomMetrics: roomMetrics.sort((a, b) => b.engagementScore - a.engagementScore).slice(0, 10)
    };
  }

  /**
   * Analyze room longevity and sustainability
   */
  analyzeRoomLongevity(rooms) {
    const completedRooms = rooms.filter(room => room.status === 'completed' && room.endedAt);
    
    if (completedRooms.length === 0) {
      return { count: 0, averageDuration: 0 };
    }

    const durations = completedRooms.map(room => {
      return DateHelpers.calculateDuration(room.createdAt, room.endedAt).minutes;
    });

    // Categorize by duration
    const durationCategories = {
      'very_short': durations.filter(d => d < 15).length,      // Under 15 minutes
      'short': durations.filter(d => d >= 15 && d < 60).length, // 15-60 minutes
      'medium': durations.filter(d => d >= 60 && d < 180).length, // 1-3 hours
      'long': durations.filter(d => d >= 180 && d < 360).length,  // 3-6 hours
      'very_long': durations.filter(d => d >= 360).length        // Over 6 hours
    };

    const sustainabilityScore = this.calculateSustainabilityScore(durations);

    return {
      count: completedRooms.length,
      averageDuration: this.calculateAverageDuration(durations),
      medianDuration: durations.sort((a, b) => a - b)[Math.floor(durations.length / 2)],
      durationDistribution: durationCategories,
      sustainabilityScore,
      stats: this.calculateStats(durations, 'room_duration_minutes'),
      longevityInsights: this.generateLongevityInsights(durations, durationCategories)
    };
  }

  /**
   * Analyze participant drop-off patterns
   */
  analyzeDropoffPatterns(participants, rooms) {
    const roomAnalysis = _.groupBy(participants, 'roomId');
    
    const dropoffData = Object.keys(roomAnalysis).map(roomId => {
      const roomParticipants = roomAnalysis[roomId];
      const room = rooms.find(r => r.$id === roomId);
      
      if (!room || !room.endedAt) return null;

      const roomDuration = DateHelpers.calculateDuration(room.createdAt, room.endedAt).minutes;
      
      // Calculate when participants left relative to room duration
      const dropoffTimes = roomParticipants
        .filter(p => p.leftAt)
        .map(p => {
          const timeInRoom = DateHelpers.calculateDuration(p.joinedAt, p.leftAt).minutes;
          return (timeInRoom / roomDuration) * 100; // Percentage of room duration
        });

      const earlyDropoffs = dropoffTimes.filter(t => t < 25).length; // Left in first quarter
      const midDropoffs = dropoffTimes.filter(t => t >= 25 && t < 75).length;
      const lateDropoffs = dropoffTimes.filter(t => t >= 75).length;

      return {
        roomId,
        totalParticipants: roomParticipants.length,
        dropoffCount: dropoffTimes.length,
        dropoffRate: this.calculateCompletionRate(roomParticipants.length, dropoffTimes.length),
        earlyDropoffs,
        midDropoffs,
        lateDropoffs,
        averageDropoffTime: _.mean(dropoffTimes) || 0
      };
    }).filter(Boolean);

    const overallDropoffRate = dropoffData.length > 0 ? 
      _.mean(dropoffData.map(d => d.dropoffRate)) : 0;

    return {
      overallDropoffRate,
      dropoffPatterns: {
        early: _.sumBy(dropoffData, 'earlyDropoffs'),
        mid: _.sumBy(dropoffData, 'midDropoffs'),
        late: _.sumBy(dropoffData, 'lateDropoffs')
      },
      roomsAnalyzed: dropoffData.length,
      highDropoffRooms: dropoffData.filter(d => d.dropoffRate > 50).length,
      dropoffTrends: this.calculateDropoffTrends(dropoffData)
    };
  }

  /**
   * Analyze hand-raise requests and approval patterns
   */
  analyzeHandRaises(handRaises, participants) {
    if (handRaises.length === 0) {
      return { totalRequests: 0, approvalRate: 0 };
    }

    const approvedRaises = handRaises.filter(hr => hr.status === 'approved');
    const deniedRaises = handRaises.filter(hr => hr.status === 'denied');
    const pendingRaises = handRaises.filter(hr => hr.status === 'pending');

    // Group by room to analyze moderator responsiveness
    const roomGroups = _.groupBy(handRaises, 'roomId');
    const moderatorResponsiveness = Object.keys(roomGroups).map(roomId => {
      const roomRaises = roomGroups[roomId];
      const avgResponseTime = this.calculateAverageResponseTime(roomRaises);
      const approvalRate = this.calculateCompletionRate(
        roomRaises.length,
        roomRaises.filter(hr => hr.status === 'approved').length
      );

      return {
        roomId,
        totalRequests: roomRaises.length,
        approvalRate,
        avgResponseTime
      };
    });

    // Analyze request patterns by time of day
    const hourlyRequests = _.groupBy(handRaises, hr => new Date(hr.raisedAt).getHours());

    return {
      totalRequests: handRaises.length,
      approvalRate: this.calculateCompletionRate(handRaises.length, approvedRaises.length),
      denialRate: this.calculateCompletionRate(handRaises.length, deniedRaises.length),
      pendingRate: this.calculateCompletionRate(handRaises.length, pendingRaises.length),
      averageResponseTime: _.mean(moderatorResponsiveness.map(m => m.avgResponseTime)),
      requestPatterns: {
        hourlyDistribution: hourlyRequests,
        peakRequestHour: Object.keys(hourlyRequests).reduce((a, b) => 
          hourlyRequests[a].length > hourlyRequests[b].length ? a : b
        )
      },
      moderatorPerformance: {
        responsive: moderatorResponsiveness.filter(m => m.avgResponseTime < 5).length,
        average: moderatorResponsiveness.filter(m => m.avgResponseTime >= 5 && m.avgResponseTime < 15).length,
        slow: moderatorResponsiveness.filter(m => m.avgResponseTime >= 15).length
      }
    };
  }

  /**
   * Analyze moderator activity and effectiveness
   */
  analyzeModeratorActivity(participants, rooms) {
    const moderators = participants.filter(p => p.role === 'moderator');
    const moderatorRooms = _.groupBy(moderators, 'userId');

    const moderatorStats = Object.keys(moderatorRooms).map(userId => {
      const userRooms = moderatorRooms[userId];
      const roomIds = userRooms.map(ur => ur.roomId);
      const associatedRooms = rooms.filter(r => roomIds.includes(r.$id));

      const completedRooms = associatedRooms.filter(r => r.status === 'completed').length;
      const averageDuration = this.calculateAverageRoomDuration(associatedRooms);
      const totalParticipantsManaged = participants.filter(p => roomIds.includes(p.roomId)).length;

      return {
        userId,
        roomsModerated: userRooms.length,
        completionRate: this.calculateCompletionRate(userRooms.length, completedRooms),
        averageRoomDuration: averageDuration,
        totalParticipantsManaged,
        averageParticipantsPerRoom: totalParticipantsManaged / userRooms.length,
        effectivenessScore: this.calculateModeratorEffectiveness(userRooms, associatedRooms, participants)
      };
    });

    return {
      totalModerators: Object.keys(moderatorRooms).length,
      averageRoomsPerModerator: moderators.length / Object.keys(moderatorRooms).length,
      topModerators: moderatorStats.sort((a, b) => b.effectivenessScore - a.effectivenessScore).slice(0, 5),
      moderatorEffectiveness: {
        excellent: moderatorStats.filter(m => m.effectivenessScore >= 80).length,
        good: moderatorStats.filter(m => m.effectivenessScore >= 60 && m.effectivenessScore < 80).length,
        average: moderatorStats.filter(m => m.effectivenessScore >= 40 && m.effectivenessScore < 60).length,
        poor: moderatorStats.filter(m => m.effectivenessScore < 40).length
      }
    };
  }

  /**
   * Analyze speaking time distribution
   */
  analyzeSpeakingTime(participants) {
    const speakers = participants.filter(p => p.role === 'speaker' && p.speakingTimeMinutes);
    
    if (speakers.length === 0) {
      return { totalSpeakers: 0, averageSpeakingTime: 0 };
    }

    const speakingTimes = speakers.map(s => s.speakingTimeMinutes);
    const roomGroups = _.groupBy(speakers, 'roomId');

    // Analyze distribution fairness per room
    const roomFairness = Object.keys(roomGroups).map(roomId => {
      const roomSpeakers = roomGroups[roomId];
      const times = roomSpeakers.map(s => s.speakingTimeMinutes);
      
      if (times.length <= 1) return 100; // Single speaker = perfectly fair
      
      const mean = _.mean(times);
      const stdDev = Math.sqrt(times.reduce((sum, time) => sum + Math.pow(time - mean, 2), 0) / times.length);
      
      // Lower standard deviation = more fair distribution
      const fairnessScore = Math.max(0, 100 - (stdDev / mean) * 100);
      
      return {
        roomId,
        speakerCount: roomSpeakers.length,
        fairnessScore,
        speakingTimeRange: { min: _.min(times), max: _.max(times) }
      };
    });

    return {
      totalSpeakers: speakers.length,
      averageSpeakingTime: _.mean(speakingTimes),
      speakingTimeDistribution: {
        under_5min: speakingTimes.filter(t => t < 5).length,
        '5_15min': speakingTimes.filter(t => t >= 5 && t < 15).length,
        '15_30min': speakingTimes.filter(t => t >= 15 && t < 30).length,
        over_30min: speakingTimes.filter(t => t >= 30).length
      },
      fairnessAnalysis: {
        averageFairness: _.mean(roomFairness.map(rf => rf.fairnessScore)),
        veryFairRooms: roomFairness.filter(rf => rf.fairnessScore >= 80).length,
        fairRooms: roomFairness.filter(rf => rf.fairnessScore >= 60 && rf.fairnessScore < 80).length,
        unfairRooms: roomFairness.filter(rf => rf.fairnessScore < 60).length
      },
      stats: this.calculateStats(speakingTimes, 'speaking_time_minutes')
    };
  }

  /**
   * Helper methods for calculations
   */
  calculateRoomEngagementScore(participants, duration) {
    // Factors: participant retention, role diversity, speaking participation
    let score = 0;
    
    // Base score from participant count (more participants = higher engagement potential)
    score += Math.min(30, participants.length * 3);
    
    // Speaker participation score
    const speakers = participants.filter(p => p.role === 'speaker');
    score += Math.min(40, speakers.length * 8);
    
    // Duration bonus (longer rooms = more engagement, up to a point)
    if (duration > 15 && duration < 180) {
      score += Math.min(30, duration / 6);
    } else if (duration >= 180) {
      score += 30; // Cap at 30 points for very long rooms
    }
    
    return Math.min(100, score);
  }

  calculateParticipantTurnover(participants) {
    // Measure how much participants change during room lifetime
    const withLeaveTime = participants.filter(p => p.leftAt);
    return this.calculateCompletionRate(participants.length, withLeaveTime.length);
  }

  calculateAverageParticipationTime(participants, room) {
    const participationTimes = participants
      .filter(p => p.joinedAt)
      .map(p => {
        const endTime = p.leftAt || room.endedAt || new Date();
        return DateHelpers.calculateDuration(p.joinedAt, endTime).minutes;
      });
    
    return participationTimes.length > 0 ? _.mean(participationTimes) : 0;
  }

  calculateSustainabilityScore(durations) {
    // Rooms that last 30+ minutes are considered sustainable
    const sustainableRooms = durations.filter(d => d >= 30).length;
    return this.calculateCompletionRate(durations.length, sustainableRooms);
  }

  generateLongevityInsights(durations, categories) {
    const insights = [];
    
    if (categories.very_short > categories.medium + categories.long) {
      insights.push('High percentage of very short rooms suggests engagement issues');
    }
    
    if (categories.very_long > durations.length * 0.1) {
      insights.push('Some rooms running very long - check for moderation effectiveness');
    }
    
    return insights;
  }

  calculateDropoffTrends(dropoffData) {
    const earlyDropoffRate = _.mean(dropoffData.map(d => d.earlyDropoffs / d.totalParticipants * 100));
    
    return {
      earlyDropoffTrend: earlyDropoffRate > 30 ? 'concerning' : earlyDropoffRate > 15 ? 'moderate' : 'good',
      recommendation: earlyDropoffRate > 30 ? 'Improve room onboarding and early engagement' : 'Monitor and maintain current patterns'
    };
  }

  calculateAverageResponseTime(handRaises) {
    const responseTimes = handRaises
      .filter(hr => hr.respondedAt && hr.raisedAt)
      .map(hr => DateHelpers.calculateDuration(hr.raisedAt, hr.respondedAt).minutes);
    
    return responseTimes.length > 0 ? _.mean(responseTimes) : 0;
  }

  calculateAverageRoomDuration(rooms) {
    const durations = rooms
      .filter(r => r.endedAt)
      .map(r => DateHelpers.calculateDuration(r.createdAt, r.endedAt).minutes);
    
    return durations.length > 0 ? _.mean(durations) : 0;
  }

  calculateModeratorEffectiveness(moderatorParticipations, rooms, allParticipants) {
    // Factors: completion rate, participant retention, response time, room duration
    let score = 0;
    
    const completedRooms = rooms.filter(r => r.status === 'completed').length;
    const completionRate = this.calculateCompletionRate(rooms.length, completedRooms);
    score += completionRate * 0.4; // 40% weight
    
    // Average room duration (optimal range: 30-120 minutes)
    const avgDuration = this.calculateAverageRoomDuration(rooms);
    if (avgDuration >= 30 && avgDuration <= 120) {
      score += 30;
    } else if (avgDuration > 15 && avgDuration < 180) {
      score += 20;
    } else {
      score += 10;
    }
    
    // Participant engagement in their rooms
    const roomIds = rooms.map(r => r.$id);
    const roomParticipants = allParticipants.filter(p => roomIds.includes(p.roomId));
    const avgParticipants = roomParticipants.length / rooms.length;
    score += Math.min(30, avgParticipants * 3);
    
    return Math.min(100, score);
  }

  analyzeCategoryPopularity(rooms) {
    const categories = _.groupBy(rooms, 'category');
    return Object.keys(categories)
      .map(category => ({
        category,
        count: categories[category].length,
        percentage: Math.round((categories[category].length / rooms.length) * 100),
        avgDuration: this.calculateAverageRoomDuration(categories[category])
      }))
      .sort((a, b) => b.count - a.count);
  }

  analyzeRoomEffectiveness(rooms, participants) {
    // Measure how effective rooms are at maintaining engagement
    const roomMetrics = rooms.map(room => {
      const roomParticipants = participants.filter(p => p.roomId === room.$id);
      const speakers = roomParticipants.filter(p => p.role === 'speaker');
      
      let effectiveness = 0;
      
      // Factor 1: Speaker diversity (more speakers = more effective)
      effectiveness += Math.min(40, speakers.length * 8);
      
      // Factor 2: Completion status
      if (room.status === 'completed') effectiveness += 30;
      else if (room.status === 'active') effectiveness += 15;
      
      // Factor 3: Duration appropriateness
      if (room.endedAt) {
        const duration = DateHelpers.calculateDuration(room.createdAt, room.endedAt).minutes;
        if (duration >= 30 && duration <= 180) effectiveness += 30;
        else if (duration >= 15 && duration <= 240) effectiveness += 15;
      }
      
      return {
        roomId: room.$id,
        effectiveness: Math.min(100, effectiveness),
        participantCount: roomParticipants.length,
        speakerCount: speakers.length
      };
    });

    return {
      averageEffectiveness: _.mean(roomMetrics.map(rm => rm.effectiveness)),
      effectivenessDistribution: {
        excellent: roomMetrics.filter(rm => rm.effectiveness >= 80).length,
        good: roomMetrics.filter(rm => rm.effectiveness >= 60 && rm.effectiveness < 80).length,
        average: roomMetrics.filter(rm => rm.effectiveness >= 40 && rm.effectiveness < 60).length,
        poor: roomMetrics.filter(rm => rm.effectiveness < 40).length
      },
      topPerformingRooms: roomMetrics.sort((a, b) => b.effectiveness - a.effectiveness).slice(0, 5)
    };
  }

  analyzePeakUsage(rooms) {
    const hourlyDistribution = _.countBy(rooms, room => new Date(room.createdAt).getHours());
    const dailyDistribution = _.countBy(rooms, room => new Date(room.createdAt).getDay());
    
    return {
      hourly: hourlyDistribution,
      daily: dailyDistribution,
      peakHour: Object.keys(hourlyDistribution).reduce((a, b) => 
        (hourlyDistribution[a] || 0) > (hourlyDistribution[b] || 0) ? a : b
      ),
      peakDay: Object.keys(dailyDistribution).reduce((a, b) => 
        (dailyDistribution[a] || 0) > (dailyDistribution[b] || 0) ? a : b
      )
    };
  }

  /**
   * Generate Open Discussion specific insights
   */
  generateOpenDiscussionInsights(analysis) {
    const insights = [];

    // Engagement insights
    if (analysis.participantEngagement.averageEngagementScore < 50) {
      insights.push({
        type: 'warning',
        category: 'engagement',
        message: `Low average engagement score (${Math.round(analysis.participantEngagement.averageEngagementScore)})`,
        priority: 'high',
        suggestion: 'Focus on improving room onboarding and encouraging participation'
      });
    }

    // Dropoff insights
    if (analysis.dropoffPatterns.overallDropoffRate > 40) {
      insights.push({
        type: 'critical',
        category: 'retention',
        message: `High participant dropoff rate (${Math.round(analysis.dropoffPatterns.overallDropoffRate)}%)`,
        priority: 'critical',
        suggestion: 'Investigate early engagement strategies and room structure'
      });
    }

    // Hand-raise insights
    if (analysis.handRaiseAnalysis.approvalRate < 70) {
      insights.push({
        type: 'warning',
        category: 'moderation',
        message: `Low hand-raise approval rate (${analysis.handRaiseAnalysis.approvalRate}%)`,
        priority: 'medium',
        suggestion: 'Provide moderator training on encouraging participation'
      });
    }

    // Speaking time fairness
    if (analysis.speakingTimeDistribution.fairnessAnalysis.averageFairness < 60) {
      insights.push({
        type: 'warning',
        category: 'fairness',
        message: `Uneven speaking time distribution detected`,
        priority: 'medium',
        suggestion: 'Implement speaking time guidelines and moderator tools'
      });
    }

    // Room longevity insights
    if (analysis.roomLongevity.sustainabilityScore < 50) {
      insights.push({
        type: 'warning',
        category: 'sustainability',
        message: `Many rooms ending too quickly (${analysis.roomLongevity.sustainabilityScore}% sustainable)`,
        priority: 'high',
        suggestion: 'Improve content structure and engagement techniques'
      });
    }

    return insights;
  }
}