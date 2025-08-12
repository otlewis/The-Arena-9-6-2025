import _ from 'lodash';
import { BaseAnalytics } from './base-analytics.js';
import { DateHelpers } from '../utils/date-helpers.js';
import { AppwriteClient } from '../db/appwrite-client.js';

export class DebatesDiscussionsAnalytics extends BaseAnalytics {
  constructor(appwriteClient) {
    super(appwriteClient);
  }

  /**
   * Comprehensive Debates & Discussions analytics
   * Focus on the 7-slot floating speaker panel system
   */
  async analyzeDebatesDiscussions(period = 'week') {
    const { startDate, endDate } = DateHelpers.getDateRange(period);
    
    // Get debates & discussions rooms (filter by room types)
    const rooms = await this.db.getDiscussionRooms(startDate, endDate, null); // Get all types
    const roomIds = rooms.documents.map(room => room.$id);
    
    // Get related data
    const [participants, handRaises, timers] = await Promise.all([
      this.db.getDiscussionParticipants(roomIds),
      this.db.getHandRaises(roomIds),
      this.db.getTimers(roomIds, 'debate_discussion')
    ]);

    const analysis = {
      period: { startDate, endDate, period },
      overview: this.calculateDebatesDiscussionsOverview(rooms.documents),
      speakerPanelAnalysis: this.analyzeSpeakerPanelUtilization(participants.documents, rooms.documents),
      moderatorControlsUsage: this.analyzeModeratorControlsUsage(participants.documents, rooms.documents),
      roomTypeDistribution: this.analyzeRoomTypeDistribution(rooms.documents),
      categoryPopularity: this.analyzeCategoryPopularity(rooms.documents),
      audienceToSpeakerConversion: this.analyzeAudienceToSpeakerConversion(participants.documents, handRaises.documents),
      handRaiseEffectiveness: this.analyzeHandRaiseEffectiveness(handRaises.documents),
      roleTransitionPatterns: this.analyzeRoleTransitionPatterns(participants.documents),
      moderatorEffectiveness: this.analyzeModeratorEffectiveness(participants.documents, rooms.documents, handRaises.documents),
      participantEngagement: this.analyzeParticipantEngagement(participants.documents, rooms.documents),
      roomQualityMetrics: this.analyzeRoomQuality(rooms.documents, participants.documents),
      peakUsageTimes: this.analyzePeakUsage(rooms.documents),
      trends: this.calculateTrend(rooms.documents)
    };

    // Generate insights and recommendations
    analysis.insights = this.generateDebatesDiscussionsInsights(analysis);
    analysis.launchReadiness = this.prepareLaunchMetrics(analysis);

    return analysis;
  }

  /**
   * Calculate basic overview metrics
   */
  calculateDebatesDiscussionsOverview(rooms) {
    const totalRooms = rooms.length;
    const activeRooms = rooms.filter(room => room.status === 'active').length;
    const completedRooms = rooms.filter(room => room.status === 'completed').length;
    const scheduledRooms = rooms.filter(room => room.status === 'scheduled').length;

    const roomTypes = _.groupBy(rooms, 'roomType');
    const typeDistribution = Object.keys(roomTypes).map(type => ({
      type,
      count: roomTypes[type].length,
      percentage: Math.round((roomTypes[type].length / totalRooms) * 100)
    }));

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
      scheduledRooms,
      completionRate: this.calculateCompletionRate(totalRooms, completedRooms),
      roomTypeDistribution: typeDistribution,
      topCategories: categoryDistribution.slice(0, 5),
      averageRoomsPerDay: totalRooms / 7 // Assuming weekly analysis
    };
  }

  /**
   * Analyze 7-slot floating speaker panel utilization
   */
  analyzeSpeakerPanelUtilization(participants, rooms) {
    const roomAnalysis = _.groupBy(participants, 'roomId');
    
    const panelUtilization = Object.keys(roomAnalysis).map(roomId => {
      const roomParticipants = roomAnalysis[roomId];
      const room = rooms.find(r => r.$id === roomId);
      
      if (!room) return null;

      // Count roles (1 moderator + up to 6 speakers)
      const moderators = roomParticipants.filter(p => p.role === 'moderator');
      const speakers = roomParticipants.filter(p => p.role === 'speaker');
      const audience = roomParticipants.filter(p => p.role === 'audience');
      const pending = roomParticipants.filter(p => p.role === 'pending');

      // Calculate panel usage over time
      const maxSpeakers = 6; // 7-slot panel minus 1 moderator
      const speakerUtilizationRate = (speakers.length / maxSpeakers) * 100;
      
      // Analyze speaker turnover during room lifetime
      const speakerTurnover = this.calculateSpeakerTurnover(roomParticipants, room);
      
      return {
        roomId,
        roomType: room.roomType,
        moderatorCount: moderators.length,
        speakerCount: speakers.length,
        audienceCount: audience.length,
        pendingCount: pending.length,
        speakerUtilizationRate,
        speakerTurnover,
        panelFullness: this.categorizePanelFullness(speakers.length),
        totalParticipants: roomParticipants.length
      };
    }).filter(Boolean);

    const utilizationRates = panelUtilization.map(p => p.speakerUtilizationRate);
    const speakerCounts = panelUtilization.map(p => p.speakerCount);

    return {
      totalRoomsAnalyzed: panelUtilization.length,
      averageSpeakerUtilization: _.mean(utilizationRates),
      averageSpeakersPerRoom: _.mean(speakerCounts),
      panelFullnessDistribution: {
        empty: panelUtilization.filter(p => p.speakerCount === 0).length,
        low: panelUtilization.filter(p => p.speakerCount >= 1 && p.speakerCount <= 2).length,
        medium: panelUtilization.filter(p => p.speakerCount >= 3 && p.speakerCount <= 4).length,
        high: panelUtilization.filter(p => p.speakerCount >= 5 && p.speakerCount <= 6).length,
        full: panelUtilization.filter(p => p.speakerCount === 6).length
      },
      speakerTurnoverAnalysis: {
        low: panelUtilization.filter(p => p.speakerTurnover < 20).length,
        medium: panelUtilization.filter(p => p.speakerTurnover >= 20 && p.speakerTurnover < 50).length,
        high: panelUtilization.filter(p => p.speakerTurnover >= 50).length
      },
      roomTypeComparison: this.comparePanelUtilizationByType(panelUtilization),
      utilizationStats: this.calculateStats(utilizationRates, 'speaker_utilization_rate')
    };
  }

  /**
   * Analyze moderator controls usage patterns
   */
  analyzeModeratorControlsUsage(participants, rooms) {
    const moderatorActions = participants.filter(p => p.role === 'moderator');
    const roomsByModerator = _.groupBy(moderatorActions, 'userId');

    const moderatorStats = Object.keys(roomsByModerator).map(userId => {
      const userRooms = roomsByModerator[userId];
      const roomIds = userRooms.map(ur => ur.roomId);
      const associatedRooms = rooms.filter(r => roomIds.includes(r.$id));
      
      // Analyze moderator actions based on room data
      const roomControls = associatedRooms.map(room => {
        const roomParticipants = participants.filter(p => p.roomId === room.$id);
        
        return {
          roomId: room.$id,
          roomType: room.roomType,
          endedByModerator: room.endedBy === userId,
          participantCount: roomParticipants.length,
          speakerChanges: this.countSpeakerChanges(roomParticipants),
          muteActions: room.muteActions || 0,
          roomSettings: room.settingsChanges || 0
        };
      });

      return {
        userId,
        roomsModerated: userRooms.length,
        averageParticipantsManaged: _.mean(roomControls.map(rc => rc.participantCount)),
        roomEndingRate: this.calculateCompletionRate(
          roomControls.length,
          roomControls.filter(rc => rc.endedByModerator).length
        ),
        averageSpeakerChanges: _.mean(roomControls.map(rc => rc.speakerChanges)),
        totalMuteActions: _.sumBy(roomControls, 'muteActions'),
        totalSettingsChanges: _.sumBy(roomControls, 'roomSettings'),
        moderationStyle: this.determineModerationStyle(roomControls)
      };
    });

    return {
      totalModerators: Object.keys(roomsByModerator).length,
      averageRoomsPerModerator: moderatorActions.length / Object.keys(roomsByModerator).length,
      moderatorControlsUsage: {
        activeControlUsers: moderatorStats.filter(m => m.averageSpeakerChanges > 2).length,
        passiveControlUsers: moderatorStats.filter(m => m.averageSpeakerChanges <= 2).length,
        highMuteUsers: moderatorStats.filter(m => m.totalMuteActions > 5).length
      },
      moderationStyles: _.countBy(moderatorStats, 'moderationStyle'),
      topModerators: moderatorStats.sort((a, b) => b.roomsModerated - a.roomsModerated).slice(0, 5)
    };
  }

  /**
   * Analyze room type distribution and performance
   */
  analyzeRoomTypeDistribution(rooms) {
    const roomTypes = _.groupBy(rooms, 'roomType');
    
    const typeAnalysis = Object.keys(roomTypes).map(type => {
      const typeRooms = roomTypes[type];
      const completedRooms = typeRooms.filter(r => r.status === 'completed');
      
      const durations = completedRooms
        .filter(r => r.endedAt)
        .map(r => DateHelpers.calculateDuration(r.createdAt, r.endedAt).minutes);

      return {
        type,
        count: typeRooms.length,
        percentage: Math.round((typeRooms.length / rooms.length) * 100),
        completionRate: this.calculateCompletionRate(typeRooms.length, completedRooms.length),
        averageDuration: durations.length > 0 ? _.mean(durations) : 0,
        popularity: typeRooms.length,
        performance: this.calculateRoomTypePerformance(typeRooms)
      };
    }).sort((a, b) => b.count - a.count);

    return {
      totalTypes: Object.keys(roomTypes).length,
      typeDistribution: typeAnalysis,
      mostPopularType: typeAnalysis[0]?.type,
      bestPerformingType: typeAnalysis.sort((a, b) => b.performance - a.performance)[0]?.type,
      typeComparison: this.compareRoomTypes(typeAnalysis)
    };
  }

  /**
   * Analyze category popularity across room types
   */
  analyzeCategoryPopularity(rooms) {
    const categories = _.groupBy(rooms, 'category');
    const roomTypesByCategory = {};

    // Analyze each category's room type distribution
    Object.keys(categories).forEach(category => {
      const categoryRooms = categories[category];
      roomTypesByCategory[category] = _.countBy(categoryRooms, 'roomType');
    });

    const categoryAnalysis = Object.keys(categories).map(category => {
      const categoryRooms = categories[category];
      const completedRooms = categoryRooms.filter(r => r.status === 'completed');
      
      const durations = completedRooms
        .filter(r => r.endedAt)
        .map(r => DateHelpers.calculateDuration(r.createdAt, r.endedAt).minutes);

      return {
        category,
        count: categoryRooms.length,
        percentage: Math.round((categoryRooms.length / rooms.length) * 100),
        completionRate: this.calculateCompletionRate(categoryRooms.length, completedRooms.length),
        averageDuration: durations.length > 0 ? _.mean(durations) : 0,
        roomTypeDistribution: roomTypesByCategory[category],
        popularityTrend: this.calculateCategoryTrend(categoryRooms)
      };
    }).sort((a, b) => b.count - a.count);

    return {
      totalCategories: Object.keys(categories).length,
      topCategories: categoryAnalysis.slice(0, 10),
      categoryPerformance: categoryAnalysis.sort((a, b) => b.completionRate - a.completionRate).slice(0, 5),
      emergingCategories: this.identifyEmergingCategories(categoryAnalysis),
      categoryInsights: this.generateCategoryInsights(categoryAnalysis)
    };
  }

  /**
   * Analyze audience to speaker conversion rates
   */
  analyzeAudienceToSpeakerConversion(participants, handRaises) {
    const roomGroups = _.groupBy(participants, 'roomId');
    
    const conversionAnalysis = Object.keys(roomGroups).map(roomId => {
      const roomParticipants = roomGroups[roomId];
      const roomHandRaises = handRaises.filter(hr => hr.roomId === roomId);
      
      const audienceMembers = roomParticipants.filter(p => p.role === 'audience');
      const speakers = roomParticipants.filter(p => p.role === 'speaker');
      const handRaiseRequests = roomHandRaises.length;
      const approvedRaises = roomHandRaises.filter(hr => hr.status === 'approved').length;
      
      // Calculate conversion metrics
      const raiseRate = audienceMembers.length > 0 ? 
        (handRaiseRequests / audienceMembers.length) * 100 : 0;
      
      const conversionRate = handRaiseRequests > 0 ? 
        (approvedRaises / handRaiseRequests) * 100 : 0;
      
      const overallConversion = audienceMembers.length > 0 ? 
        (approvedRaises / audienceMembers.length) * 100 : 0;

      return {
        roomId,
        audienceCount: audienceMembers.length,
        speakerCount: speakers.length,
        handRaiseRequests,
        approvedRaises,
        raiseRate,
        conversionRate,
        overallConversion,
        engagementLevel: this.categorizeEngagementLevel(raiseRate, conversionRate)
      };
    });

    const raiseRates = conversionAnalysis.map(ca => ca.raiseRate);
    const conversionRates = conversionAnalysis.map(ca => ca.conversionRate);
    const overallConversions = conversionAnalysis.map(ca => ca.overallConversion);

    return {
      totalRoomsAnalyzed: conversionAnalysis.length,
      averageRaiseRate: _.mean(raiseRates),
      averageConversionRate: _.mean(conversionRates),
      averageOverallConversion: _.mean(overallConversions),
      engagementDistribution: _.countBy(conversionAnalysis, 'engagementLevel'),
      conversionTiers: {
        excellent: conversionAnalysis.filter(ca => ca.overallConversion >= 30).length,
        good: conversionAnalysis.filter(ca => ca.overallConversion >= 15 && ca.overallConversion < 30).length,
        average: conversionAnalysis.filter(ca => ca.overallConversion >= 5 && ca.overallConversion < 15).length,
        poor: conversionAnalysis.filter(ca => ca.overallConversion < 5).length
      },
      topPerformingRooms: conversionAnalysis.sort((a, b) => b.overallConversion - a.overallConversion).slice(0, 5)
    };
  }

  /**
   * Analyze hand-raise effectiveness and response patterns
   */
  analyzeHandRaiseEffectiveness(handRaises) {
    if (handRaises.length === 0) {
      return { totalHandRaises: 0, effectiveness: 0 };
    }

    const statusDistribution = _.countBy(handRaises, 'status');
    const responseTimeAnalysis = this.analyzeHandRaiseResponseTimes(handRaises);
    const hourlyPatterns = this.analyzeHandRaisePatterns(handRaises);

    return {
      totalHandRaises: handRaises.length,
      statusDistribution,
      approvalRate: this.calculateCompletionRate(handRaises.length, statusDistribution.approved || 0),
      responseTimeAnalysis,
      hourlyPatterns,
      effectiveness: this.calculateHandRaiseEffectiveness(handRaises),
      recommendations: this.generateHandRaiseRecommendations(handRaises, responseTimeAnalysis)
    };
  }

  /**
   * Helper methods for complex calculations
   */
  calculateSpeakerTurnover(participants, room) {
    // Calculate how often speaker slots change during room lifetime
    const speakers = participants.filter(p => p.role === 'speaker');
    const speakerChanges = participants.filter(p => 
      p.previousRole && p.previousRole !== p.role
    ).length;
    
    if (speakers.length === 0) return 0;
    return (speakerChanges / speakers.length) * 100;
  }

  categorizePanelFullness(speakerCount) {
    if (speakerCount === 0) return 'empty';
    if (speakerCount <= 2) return 'low';
    if (speakerCount <= 4) return 'medium';
    if (speakerCount <= 5) return 'high';
    return 'full';
  }

  comparePanelUtilizationByType(panelUtilization) {
    const byType = _.groupBy(panelUtilization, 'roomType');
    
    return Object.keys(byType).map(type => {
      const typeData = byType[type];
      const utilizationRates = typeData.map(td => td.speakerUtilizationRate);
      
      return {
        type,
        count: typeData.length,
        averageUtilization: _.mean(utilizationRates),
        averageSpeakers: _.mean(typeData.map(td => td.speakerCount))
      };
    });
  }

  countSpeakerChanges(participants) {
    // Count role transitions that involve speaker role
    return participants.filter(p => 
      p.roleHistory && p.roleHistory.includes('speaker')
    ).length;
  }

  determineModerationStyle(roomControls) {
    const avgSpeakerChanges = _.mean(roomControls.map(rc => rc.speakerChanges));
    const avgMuteActions = _.mean(roomControls.map(rc => rc.muteActions));
    
    if (avgSpeakerChanges > 5 || avgMuteActions > 3) return 'active';
    if (avgSpeakerChanges > 2 || avgMuteActions > 1) return 'moderate';
    return 'passive';
  }

  calculateRoomTypePerformance(rooms) {
    const completed = rooms.filter(r => r.status === 'completed').length;
    const completionRate = this.calculateCompletionRate(rooms.length, completed);
    
    // Factor in average duration and participant satisfaction (if available)
    let performance = completionRate;
    
    // Bonus for optimal duration ranges
    const durations = rooms
      .filter(r => r.endedAt)
      .map(r => DateHelpers.calculateDuration(r.createdAt, r.endedAt).minutes);
    
    if (durations.length > 0) {
      const avgDuration = _.mean(durations);
      if (avgDuration >= 30 && avgDuration <= 120) {
        performance += 10; // Bonus for optimal duration
      }
    }
    
    return Math.min(100, performance);
  }

  compareRoomTypes(typeAnalysis) {
    return {
      bestCompletion: typeAnalysis.sort((a, b) => b.completionRate - a.completionRate)[0],
      longestDuration: typeAnalysis.sort((a, b) => b.averageDuration - a.averageDuration)[0],
      mostPopular: typeAnalysis.sort((a, b) => b.count - a.count)[0]
    };
  }

  calculateCategoryTrend(categoryRooms) {
    // Simple trend based on recent vs older rooms
    const sortedRooms = categoryRooms.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const recentHalf = sortedRooms.slice(0, Math.ceil(sortedRooms.length / 2));
    const olderHalf = sortedRooms.slice(Math.ceil(sortedRooms.length / 2));
    
    if (recentHalf.length > olderHalf.length) return 'growing';
    if (recentHalf.length < olderHalf.length) return 'declining';
    return 'stable';
  }

  identifyEmergingCategories(categoryAnalysis) {
    // Categories with growth trends and reasonable volume
    return categoryAnalysis
      .filter(ca => ca.popularityTrend === 'growing' && ca.count >= 5)
      .slice(0, 3);
  }

  generateCategoryInsights(categoryAnalysis) {
    const insights = [];
    
    const topCategory = categoryAnalysis[0];
    if (topCategory && topCategory.percentage > 30) {
      insights.push(`${topCategory.category} dominates with ${topCategory.percentage}% of all rooms`);
    }
    
    const lowCompletion = categoryAnalysis.filter(ca => ca.completionRate < 60);
    if (lowCompletion.length > 0) {
      insights.push(`${lowCompletion.length} categories have completion rates below 60%`);
    }
    
    return insights;
  }

  categorizeEngagementLevel(raiseRate, conversionRate) {
    const combined = (raiseRate + conversionRate) / 2;
    
    if (combined >= 40) return 'high';
    if (combined >= 20) return 'medium';
    return 'low';
  }

  analyzeHandRaiseResponseTimes(handRaises) {
    const responseTimes = handRaises
      .filter(hr => hr.respondedAt && hr.raisedAt)
      .map(hr => DateHelpers.calculateDuration(hr.raisedAt, hr.respondedAt).minutes);
    
    if (responseTimes.length === 0) return { count: 0, average: 0 };

    return {
      count: responseTimes.length,
      average: _.mean(responseTimes),
      median: responseTimes.sort((a, b) => a - b)[Math.floor(responseTimes.length / 2)],
      distribution: {
        immediate: responseTimes.filter(rt => rt < 1).length,     // Under 1 minute
        fast: responseTimes.filter(rt => rt >= 1 && rt < 5).length, // 1-5 minutes
        moderate: responseTimes.filter(rt => rt >= 5 && rt < 15).length, // 5-15 minutes
        slow: responseTimes.filter(rt => rt >= 15).length        // Over 15 minutes
      }
    };
  }

  analyzeHandRaisePatterns(handRaises) {
    const hourlyDistribution = _.countBy(handRaises, hr => new Date(hr.raisedAt).getHours());
    const peakHour = Object.keys(hourlyDistribution).reduce((a, b) => 
      (hourlyDistribution[a] || 0) > (hourlyDistribution[b] || 0) ? a : b
    );

    return {
      hourlyDistribution,
      peakHour,
      totalRequests: handRaises.length,
      busyHours: Object.keys(hourlyDistribution).filter(hour => 
        hourlyDistribution[hour] > _.mean(Object.values(hourlyDistribution))
      )
    };
  }

  calculateHandRaiseEffectiveness(handRaises) {
    const approved = handRaises.filter(hr => hr.status === 'approved').length;
    const responded = handRaises.filter(hr => hr.respondedAt).length;
    
    const approvalRate = this.calculateCompletionRate(handRaises.length, approved);
    const responseRate = this.calculateCompletionRate(handRaises.length, responded);
    
    return Math.round((approvalRate + responseRate) / 2);
  }

  generateHandRaiseRecommendations(handRaises, responseTimeAnalysis) {
    const recommendations = [];
    
    if (responseTimeAnalysis.average > 10) {
      recommendations.push('Improve moderator response times - currently averaging ' + 
        DateHelpers.formatDuration(responseTimeAnalysis.average));
    }
    
    const approvalRate = this.calculateCompletionRate(
      handRaises.length,
      handRaises.filter(hr => hr.status === 'approved').length
    );
    
    if (approvalRate < 60) {
      recommendations.push('Consider increasing hand-raise approval rates to boost engagement');
    }
    
    return recommendations;
  }

  analyzeRoleTransitionPatterns(participants) {
    // Analyze how users move between audience -> pending -> speaker roles
    const transitions = participants
      .filter(p => p.roleHistory && p.roleHistory.length > 1)
      .map(p => ({
        userId: p.userId,
        roomId: p.roomId,
        transitions: p.roleHistory,
        finalRole: p.role
      }));

    const transitionTypes = {
      'audience_to_pending': 0,
      'pending_to_speaker': 0,
      'speaker_to_audience': 0,
      'audience_to_speaker': 0 // Direct promotion
    };

    transitions.forEach(t => {
      const history = t.transitions;
      for (let i = 1; i < history.length; i++) {
        const from = history[i-1];
        const to = history[i];
        const key = `${from}_to_${to}`;
        if (transitionTypes.hasOwnProperty(key)) {
          transitionTypes[key]++;
        }
      }
    });

    return {
      totalTransitions: transitions.length,
      transitionTypes,
      mostCommonTransition: Object.keys(transitionTypes).reduce((a, b) => 
        transitionTypes[a] > transitionTypes[b] ? a : b
      ),
      transitionSuccess: this.calculateTransitionSuccess(transitions)
    };
  }

  calculateTransitionSuccess(transitions) {
    const successful = transitions.filter(t => 
      t.finalRole === 'speaker' && t.transitions.includes('audience')
    ).length;
    
    return this.calculateCompletionRate(transitions.length, successful);
  }

  analyzeModeratorEffectiveness(participants, rooms, handRaises) {
    const moderators = participants.filter(p => p.role === 'moderator');
    const moderatorGroups = _.groupBy(moderators, 'userId');

    return Object.keys(moderatorGroups).map(userId => {
      const userRooms = moderatorGroups[userId];
      const roomIds = userRooms.map(ur => ur.roomId);
      const associatedRooms = rooms.filter(r => roomIds.includes(r.$id));
      const roomHandRaises = handRaises.filter(hr => roomIds.includes(hr.roomId));

      const effectiveness = this.calculateModeratorEffectivenessScore(
        associatedRooms,
        roomHandRaises,
        participants.filter(p => roomIds.includes(p.roomId))
      );

      return {
        userId,
        roomsModerated: userRooms.length,
        effectiveness,
        handRaisesHandled: roomHandRaises.length,
        averageResponseTime: this.calculateAverageResponseTime(roomHandRaises)
      };
    }).sort((a, b) => b.effectiveness - a.effectiveness);
  }

  calculateModeratorEffectivenessScore(rooms, handRaises, allParticipants) {
    let score = 0;

    // Room completion rate (40% weight)
    const completed = rooms.filter(r => r.status === 'completed').length;
    const completionRate = this.calculateCompletionRate(rooms.length, completed);
    score += completionRate * 0.4;

    // Hand-raise response rate (30% weight)
    const responded = handRaises.filter(hr => hr.respondedAt).length;
    const responseRate = this.calculateCompletionRate(handRaises.length, responded);
    score += responseRate * 0.3;

    // Participant engagement (30% weight)
    const avgParticipants = allParticipants.length / rooms.length;
    const engagementScore = Math.min(100, avgParticipants * 10); // Cap at 100
    score += engagementScore * 0.3;

    return Math.round(score);
  }

  calculateAverageResponseTime(handRaises) {
    const responseTimes = handRaises
      .filter(hr => hr.respondedAt && hr.raisedAt)
      .map(hr => DateHelpers.calculateDuration(hr.raisedAt, hr.respondedAt).minutes);
    
    return responseTimes.length > 0 ? _.mean(responseTimes) : 0;
  }

  analyzeParticipantEngagement(participants, rooms) {
    // Similar to other analytics but focused on role diversity and transitions
    const roomEngagement = _.groupBy(participants, 'roomId');
    
    const engagementScores = Object.keys(roomEngagement).map(roomId => {
      const roomParticipants = roomEngagement[roomId];
      const room = rooms.find(r => r.$id === roomId);
      
      if (!room) return 0;

      const speakers = roomParticipants.filter(p => p.role === 'speaker').length;
      const audience = roomParticipants.filter(p => p.role === 'audience').length;
      const totalParticipants = roomParticipants.length;
      
      // Engagement based on speaker diversity and total participation
      let engagement = 0;
      engagement += Math.min(50, speakers * 8); // Up to 50 points for speakers
      engagement += Math.min(30, totalParticipants * 2); // Up to 30 points for total participants
      engagement += Math.min(20, (speakers / Math.max(1, totalParticipants)) * 100); // Speaker ratio bonus
      
      return Math.min(100, engagement);
    });

    return {
      averageEngagement: _.mean(engagementScores),
      engagementDistribution: {
        high: engagementScores.filter(e => e >= 70).length,
        medium: engagementScores.filter(e => e >= 40 && e < 70).length,
        low: engagementScores.filter(e => e < 40).length
      }
    };
  }

  analyzeRoomQuality(rooms, participants) {
    // Assess overall room quality based on multiple factors
    return rooms.map(room => {
      const roomParticipants = participants.filter(p => p.roomId === room.$id);
      
      let quality = 0;
      
      // Completion factor
      if (room.status === 'completed') quality += 30;
      
      // Duration factor (optimal: 30-120 minutes)
      if (room.endedAt) {
        const duration = DateHelpers.calculateDuration(room.createdAt, room.endedAt).minutes;
        if (duration >= 30 && duration <= 120) quality += 25;
        else if (duration >= 15 && duration <= 180) quality += 15;
      }
      
      // Participation factor
      const participants_count = roomParticipants.length;
      quality += Math.min(25, participants_count * 2);
      
      // Speaker diversity factor
      const speakers = roomParticipants.filter(p => p.role === 'speaker').length;
      quality += Math.min(20, speakers * 4);
      
      return {
        roomId: room.$id,
        quality: Math.min(100, quality),
        category: room.category,
        roomType: room.roomType
      };
    }).sort((a, b) => b.quality - a.quality);
  }

  analyzePeakUsage(rooms) {
    const hourlyDistribution = _.countBy(rooms, room => new Date(room.createdAt).getHours());
    const dailyDistribution = _.countBy(rooms, room => new Date(room.createdAt).getDay());
    const roomTypeHourly = {};
    
    // Analyze peak usage by room type
    ['discussion', 'debate', 'take'].forEach(type => {
      const typeRooms = rooms.filter(r => r.roomType === type);
      roomTypeHourly[type] = _.countBy(typeRooms, room => new Date(room.createdAt).getHours());
    });
    
    return {
      hourly: hourlyDistribution,
      daily: dailyDistribution,
      byRoomType: roomTypeHourly,
      peakHour: Object.keys(hourlyDistribution).reduce((a, b) => 
        (hourlyDistribution[a] || 0) > (hourlyDistribution[b] || 0) ? a : b
      ),
      peakDay: Object.keys(dailyDistribution).reduce((a, b) => 
        (dailyDistribution[a] || 0) > (dailyDistribution[b] || 0) ? a : b
      )
    };
  }

  /**
   * Generate Debates & Discussions specific insights
   */
  generateDebatesDiscussionsInsights(analysis) {
    const insights = [];

    // Speaker panel utilization insights
    if (analysis.speakerPanelAnalysis.averageSpeakerUtilization < 50) {
      insights.push({
        type: 'warning',
        category: 'utilization',
        message: `Low speaker panel utilization (${Math.round(analysis.speakerPanelAnalysis.averageSpeakerUtilization)}%)`,
        priority: 'medium',
        suggestion: 'Encourage more audience participation and hand-raising'
      });
    }

    // Conversion rate insights
    if (analysis.audienceToSpeakerConversion.averageOverallConversion < 15) {
      insights.push({
        type: 'warning',
        category: 'conversion',
        message: `Low audience-to-speaker conversion rate (${Math.round(analysis.audienceToSpeakerConversion.averageOverallConversion)}%)`,
        priority: 'high',
        suggestion: 'Improve moderation techniques and encourage participation'
      });
    }

    // Hand-raise effectiveness insights
    if (analysis.handRaiseEffectiveness.effectiveness < 60) {
      insights.push({
        type: 'warning',
        category: 'moderation',
        message: `Hand-raise system effectiveness below target (${analysis.handRaiseEffectiveness.effectiveness}%)`,
        priority: 'high',
        suggestion: 'Train moderators on timely response and approval strategies'
      });
    }

    // Room type performance insights
    const roomTypes = analysis.roomTypeDistribution.typeDistribution;
    const poorPerformingTypes = roomTypes.filter(rt => rt.completionRate < 60);
    
    if (poorPerformingTypes.length > 0) {
      insights.push({
        type: 'warning',
        category: 'room_types',
        message: `Poor completion rates in ${poorPerformingTypes.map(pt => pt.type).join(', ')} rooms`,
        priority: 'medium',
        suggestion: 'Review and optimize underperforming room type formats'
      });
    }

    // Category distribution insights
    const topCategory = analysis.categoryPopularity.topCategories[0];
    if (topCategory && topCategory.percentage > 40) {
      insights.push({
        type: 'info',
        category: 'categories',
        message: `${topCategory.category} category dominates discussions (${topCategory.percentage}%)`,
        priority: 'low',
        suggestion: 'Consider promoting other categories for diversity'
      });
    }

    return insights;
  }
}