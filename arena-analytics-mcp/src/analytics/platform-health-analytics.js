import _ from 'lodash';
import { BaseAnalytics } from './base-analytics.js';
import { DateHelpers } from '../utils/date-helpers.js';
import { AppwriteClient } from '../db/appwrite-client.js';

export class PlatformHealthAnalytics extends BaseAnalytics {
  constructor(appwriteClient) {
    super(appwriteClient);
  }

  /**
   * Comprehensive platform health analysis across all room types
   */
  async analyzePlatformHealth(period = 'week') {
    const { startDate, endDate } = DateHelpers.getDateRange(period);
    
    // Get data from all room types
    const [arenaData, discussionData, userData, timerData] = await Promise.all([
      this.getArenaHealthData(startDate, endDate),
      this.getDiscussionHealthData(startDate, endDate),
      this.getUserHealthData(startDate, endDate),
      this.getTimerHealthData(startDate, endDate)
    ]);

    const analysis = {
      period: { startDate, endDate, period },
      overallHealth: this.calculateOverallHealth(arenaData, discussionData, userData),
      crossRoomEngagement: this.analyzeCrossRoomEngagement(arenaData, discussionData),
      retentionComparison: this.compareRetentionAcrossRoomTypes(arenaData, discussionData),
      platformGrowth: this.analyzePlatformGrowth(userData, arenaData, discussionData),
      userStickiness: this.analyzeUserStickiness(arenaData, discussionData, userData),
      systemReliability: this.analyzeSystemReliability(timerData, arenaData, discussionData),
      engagementQuality: this.analyzeEngagementQuality(arenaData, discussionData),
      contentHealth: this.analyzeContentHealth(arenaData, discussionData),
      communityHealth: this.analyzeCommunityHealth(arenaData, discussionData, userData),
      scalabilityMetrics: this.analyzeScalabilityMetrics(arenaData, discussionData, timerData),
      competitivePositioning: this.analyzeCompetitivePositioning(arenaData, discussionData),
      healthTrends: this.analyzeHealthTrends(period)
    };

    // Generate insights and recommendations
    analysis.insights = this.generatePlatformHealthInsights(analysis);
    analysis.launchReadiness = this.prepareLaunchMetrics(analysis);

    return analysis;
  }

  /**
   * Calculate overall platform health score
   */
  calculateOverallHealth(arenaData, discussionData, userData) {
    const healthMetrics = {
      userActivity: this.calculateUserActivityHealth(userData),
      contentCreation: this.calculateContentCreationHealth(arenaData, discussionData),
      engagement: this.calculateEngagementHealth(arenaData, discussionData),
      retention: this.calculateRetentionHealth(userData),
      technicalReliability: this.calculateTechnicalHealth(arenaData, discussionData),
      growth: this.calculateGrowthHealth(userData)
    };

    // Weighted average (can be adjusted based on importance)
    const weights = {
      userActivity: 0.2,
      contentCreation: 0.15,
      engagement: 0.25,
      retention: 0.2,
      technicalReliability: 0.1,
      growth: 0.1
    };

    const overallScore = Object.keys(healthMetrics).reduce((score, metric) => {
      return score + (healthMetrics[metric] * weights[metric]);
    }, 0);

    return {
      overallScore: Math.round(overallScore),
      componentScores: healthMetrics,
      weights,
      healthLevel: this.categorizeHealthLevel(overallScore),
      criticalAreas: this.identifyCriticalAreas(healthMetrics),
      strengths: this.identifyStrengths(healthMetrics)
    };
  }

  /**
   * Analyze cross-room engagement patterns
   */
  analyzeCrossRoomEngagement(arenaData, discussionData) {
    // Combine participant data from all room types
    const allParticipants = [
      ...arenaData.participants.map(p => ({ ...p, roomType: 'arena' })),
      ...discussionData.participants.map(p => ({ ...p, roomType: p.roomType || 'discussion' }))
    ];

    // Group by user
    const userParticipation = _.groupBy(allParticipants, 'userId');
    
    const crossRoomMetrics = Object.keys(userParticipation).map(userId => {
      const userSessions = userParticipation[userId];
      const roomTypes = [...new Set(userSessions.map(s => s.roomType))];
      
      return {
        userId,
        totalSessions: userSessions.length,
        roomTypesUsed: roomTypes.length,
        roomTypeBreakdown: _.countBy(userSessions, 'roomType'),
        crossRoomUser: roomTypes.length > 1,
        dominantRoomType: this.getDominantRoomType(userSessions),
        engagementDiversity: this.calculateEngagementDiversity(userSessions)
      };
    });

    const totalUsers = crossRoomMetrics.length;
    const crossRoomUsers = crossRoomMetrics.filter(u => u.crossRoomUser).length;
    const singleRoomUsers = totalUsers - crossRoomUsers;

    // Room type transition analysis
    const transitionMatrix = this.calculateRoomTypeTransitions(allParticipants);
    const preferenceStability = this.analyzePreferenceStability(crossRoomMetrics);

    return {
      totalUsers,
      crossRoomUsers,
      singleRoomUsers,
      crossRoomPercentage: this.calculateCompletionRate(totalUsers, crossRoomUsers),
      roomTypeDistribution: {
        arenaOnly: crossRoomMetrics.filter(u => _.isEqual(Object.keys(u.roomTypeBreakdown), ['arena'])).length,
        discussionOnly: crossRoomMetrics.filter(u => _.isEqual(Object.keys(u.roomTypeBreakdown), ['discussion'])).length,
        openDiscussionOnly: crossRoomMetrics.filter(u => _.isEqual(Object.keys(u.roomTypeBreakdown), ['open_discussion'])).length,
        multiRoom: crossRoomUsers
      },
      averageRoomTypesPerUser: _.mean(crossRoomMetrics.map(u => u.roomTypesUsed)),
      averageEngagementDiversity: _.mean(crossRoomMetrics.map(u => u.engagementDiversity)),
      transitionMatrix,
      preferenceStability,
      topCrossRoomUsers: crossRoomMetrics
        .sort((a, b) => b.engagementDiversity - a.engagementDiversity)
        .slice(0, 10)
    };
  }

  /**
   * Compare retention rates across room types
   */
  compareRetentionAcrossRoomTypes(arenaData, discussionData) {
    const retentionPeriods = [1, 7, 14, 30]; // days
    
    const roomTypeRetention = {
      arena: this.calculateRoomTypeRetention(arenaData.participants, retentionPeriods),
      discussion: this.calculateRoomTypeRetention(
        discussionData.participants.filter(p => (p.roomType || 'discussion') === 'discussion'),
        retentionPeriods
      ),
      open_discussion: this.calculateRoomTypeRetention(
        discussionData.participants.filter(p => p.roomType === 'open_discussion'),
        retentionPeriods
      )
    };

    // Cross-room retention boost analysis
    const crossRoomRetentionBoost = this.analyzeCrossRoomRetentionBoost(arenaData, discussionData);
    
    // Retention by user segments
    const segmentRetention = this.analyzeRetentionBySegments(arenaData, discussionData);

    return {
      roomTypeRetention,
      retentionComparison: this.compareRetentionMetrics(roomTypeRetention),
      crossRoomRetentionBoost,
      segmentRetention,
      retentionTrends: this.analyzeRetentionTrends(roomTypeRetention),
      bestRetentionRoomType: this.identifyBestRetentionRoomType(roomTypeRetention),
      retentionInsights: this.generateRetentionInsights(roomTypeRetention, crossRoomRetentionBoost)
    };
  }

  /**
   * Analyze platform growth and user stickiness
   */
  analyzePlatformGrowth(userData, arenaData, discussionData) {
    const userRegistrations = userData.users.map(user => ({
      userId: user.$id,
      registrationDate: new Date(user.createdAt),
      registrationWeek: this.getWeekKey(new Date(user.createdAt))
    }));

    // Growth metrics by time period
    const weeklyGrowth = this.calculateWeeklyGrowth(userRegistrations);
    const monthlyGrowth = this.calculateMonthlyGrowth(userRegistrations);
    
    // Activation and engagement metrics
    const activationMetrics = this.calculateActivationMetrics(userData, arenaData, discussionData);
    const engagementDepth = this.calculateEngagementDepth(arenaData, discussionData);
    
    // Cohort analysis
    const cohortAnalysis = this.performCohortAnalysis(userRegistrations, arenaData, discussionData);
    
    // Network effects
    const networkEffects = this.analyzeNetworkEffects(arenaData, discussionData);

    return {
      totalUsers: userData.users.length,
      weeklyGrowth,
      monthlyGrowth,
      growthRate: this.calculateGrowthRate(weeklyGrowth),
      activationMetrics,
      engagementDepth,
      cohortAnalysis,
      networkEffects,
      growthProjections: this.calculateGrowthProjections(weeklyGrowth),
      growthQuality: this.assessGrowthQuality(activationMetrics, cohortAnalysis)
    };
  }

  /**
   * Analyze user stickiness across the platform
   */
  analyzeUserStickiness(arenaData, discussionData, userData) {
    const allParticipants = [
      ...arenaData.participants.map(p => ({ ...p, roomType: 'arena' })),
      ...discussionData.participants.map(p => ({ ...p, roomType: p.roomType || 'discussion' }))
    ];

    // User session analysis
    const userSessions = _.groupBy(allParticipants, 'userId');
    
    const stickinessMetrics = Object.keys(userSessions).map(userId => {
      const sessions = userSessions[userId];
      const sessionDates = sessions.map(s => new Date(s.joinedAt || s.createdAt)).sort();
      
      const daysSinceFirst = sessionDates.length > 0 ? 
        DateHelpers.calculateDuration(sessionDates[0], new Date()).days : 0;
      const daysSinceLast = sessionDates.length > 0 ? 
        DateHelpers.calculateDuration(sessionDates[sessionDates.length - 1], new Date()).days : 0;
      
      return {
        userId,
        totalSessions: sessions.length,
        daysSinceFirst,
        daysSinceLast,
        sessionFrequency: sessions.length / Math.max(1, daysSinceFirst),
        stickinessScore: this.calculateUserStickinessScore(sessions, daysSinceFirst, daysSinceLast),
        engagementConsistency: this.calculateEngagementConsistency(sessions)
      };
    });

    // Stickiness distribution
    const stickinessDistribution = {
      verySticky: stickinessMetrics.filter(s => s.stickinessScore >= 80).length,
      sticky: stickinessMetrics.filter(s => s.stickinessScore >= 60 && s.stickinessScore < 80).length,
      moderate: stickinessMetrics.filter(s => s.stickinessScore >= 40 && s.stickinessScore < 60).length,
      low: stickinessMetrics.filter(s => s.stickinessScore < 40).length
    };

    return {
      totalActiveUsers: stickinessMetrics.length,
      averageStickinessScore: _.mean(stickinessMetrics.map(s => s.stickinessScore)),
      stickinessDistribution,
      averageSessionFrequency: _.mean(stickinessMetrics.map(s => s.sessionFrequency)),
      averageEngagementConsistency: _.mean(stickinessMetrics.map(s => s.engagementConsistency)),
      stickinessFactors: this.analyzeStickinessFactors(stickinessMetrics, allParticipants),
      topStickyUsers: stickinessMetrics.sort((a, b) => b.stickinessScore - a.stickinessScore).slice(0, 10),
      churnRisk: stickinessMetrics.filter(s => s.daysSinceLast > 7 && s.stickinessScore < 50).length
    };
  }

  /**
   * Analyze system reliability across all components
   */
  analyzeSystemReliability(timerData, arenaData, discussionData) {
    const reliabilityMetrics = {
      timerReliability: this.calculateTimerReliability(timerData),
      roomCreationSuccess: this.calculateRoomCreationSuccess(arenaData, discussionData),
      sessionStability: this.calculateSessionStability(arenaData, discussionData),
      voiceQuality: this.calculateVoiceQuality(arenaData, discussionData),
      realTimeUpdates: this.calculateRealTimeUpdateReliability(arenaData, discussionData)
    };

    const overallReliability = _.mean(Object.values(reliabilityMetrics));
    
    const systemHealth = {
      overallReliability: Math.round(overallReliability),
      componentReliability: reliabilityMetrics,
      uptime: this.calculateSystemUptime(arenaData, discussionData),
      errorRates: this.calculateErrorRates(arenaData, discussionData),
      performanceMetrics: this.calculatePerformanceMetrics(timerData, arenaData, discussionData),
      reliabilityTrends: this.analyzeReliabilityTrends(reliabilityMetrics)
    };

    return systemHealth;
  }

  /**
   * Helper methods for complex calculations
   */
  async getArenaHealthData(startDate, endDate) {
    const [rooms, participants, judgments] = await Promise.all([
      this.db.getArenaRooms(startDate, endDate),
      this.db.getArenaParticipants(),
      this.db.getArenaJudgments()
    ]);

    return {
      rooms: rooms.documents,
      participants: participants.documents,
      judgments: judgments.documents
    };
  }

  async getDiscussionHealthData(startDate, endDate) {
    const [rooms, participants, handRaises] = await Promise.all([
      this.db.getDiscussionRooms(startDate, endDate),
      this.db.getDiscussionParticipants(),
      this.db.getHandRaises()
    ]);

    return {
      rooms: rooms.documents,
      participants: participants.documents,
      handRaises: handRaises.documents
    };
  }

  async getUserHealthData(startDate, endDate) {
    const users = await this.db.getAllDocuments('users');
    return { users };
  }

  async getTimerHealthData(startDate, endDate) {
    const [timers, timerEvents] = await Promise.all([
      this.db.getTimers(),
      this.db.getTimerEvents()
    ]);

    return {
      timers: timers.documents,
      events: timerEvents.documents
    };
  }

  calculateUserActivityHealth(userData) {
    const totalUsers = userData.users.length;
    const recentlyActive = userData.users.filter(user => {
      const daysSinceLastActivity = DateHelpers.calculateDuration(user.lastActiveAt || user.createdAt, new Date()).days;
      return daysSinceLastActivity <= 7;
    }).length;

    const activityRate = this.calculateCompletionRate(totalUsers, recentlyActive);
    
    // Health score based on activity rate
    if (activityRate >= 25) return 100;
    if (activityRate >= 15) return 80;
    if (activityRate >= 10) return 60;
    if (activityRate >= 5) return 40;
    return 20;
  }

  calculateContentCreationHealth(arenaData, discussionData) {
    const totalRooms = arenaData.rooms.length + discussionData.rooms.length;
    const totalUsers = new Set([
      ...arenaData.participants.map(p => p.userId),
      ...discussionData.participants.map(p => p.userId)
    ]).size;

    const roomsPerUser = totalUsers > 0 ? totalRooms / totalUsers : 0;
    
    // Health score based on content creation rate
    if (roomsPerUser >= 0.5) return 100;
    if (roomsPerUser >= 0.3) return 80;
    if (roomsPerUser >= 0.2) return 60;
    if (roomsPerUser >= 0.1) return 40;
    return 20;
  }

  calculateEngagementHealth(arenaData, discussionData) {
    const allParticipants = [...arenaData.participants, ...discussionData.participants];
    const avgSessionDuration = _.mean(allParticipants.map(p => p.sessionDuration || 30));
    const avgParticipantsPerRoom = allParticipants.length / (arenaData.rooms.length + discussionData.rooms.length);
    
    // Composite engagement score
    let score = 0;
    
    // Session duration component (30 minutes is ideal)
    if (avgSessionDuration >= 30) score += 40;
    else if (avgSessionDuration >= 20) score += 30;
    else if (avgSessionDuration >= 10) score += 20;
    else score += 10;
    
    // Participants per room component
    if (avgParticipantsPerRoom >= 5) score += 40;
    else if (avgParticipantsPerRoom >= 3) score += 30;
    else if (avgParticipantsPerRoom >= 2) score += 20;
    else score += 10;
    
    // Completion rate component
    const completedRooms = [...arenaData.rooms, ...discussionData.rooms].filter(r => r.status === 'completed').length;
    const completionRate = this.calculateCompletionRate(arenaData.rooms.length + discussionData.rooms.length, completedRooms);
    
    if (completionRate >= 80) score += 20;
    else if (completionRate >= 60) score += 15;
    else if (completionRate >= 40) score += 10;
    else score += 5;
    
    return Math.min(100, score);
  }

  calculateRetentionHealth(userData) {
    const users = userData.users;
    const weekRetention = users.filter(user => {
      const daysSinceRegistration = DateHelpers.calculateDuration(user.createdAt, new Date()).days;
      const daysSinceLastActive = DateHelpers.calculateDuration(user.lastActiveAt || user.createdAt, new Date()).days;
      return daysSinceRegistration >= 7 && daysSinceLastActive <= 7;
    }).length;

    const weekEligibleUsers = users.filter(user => {
      const daysSinceRegistration = DateHelpers.calculateDuration(user.createdAt, new Date()).days;
      return daysSinceRegistration >= 7;
    }).length;

    const retentionRate = this.calculateCompletionRate(weekEligibleUsers, weekRetention);
    
    // Health score based on retention rate
    if (retentionRate >= 40) return 100;
    if (retentionRate >= 30) return 80;
    if (retentionRate >= 20) return 60;
    if (retentionRate >= 10) return 40;
    return 20;
  }

  calculateTechnicalHealth(arenaData, discussionData) {
    const allRooms = [...arenaData.rooms, ...discussionData.rooms];
    const failedRooms = allRooms.filter(room => room.status === 'failed' || room.status === 'error').length;
    const successRate = this.calculateCompletionRate(allRooms.length, allRooms.length - failedRooms);
    
    // Health score based on technical success rate
    if (successRate >= 98) return 100;
    if (successRate >= 95) return 90;
    if (successRate >= 90) return 80;
    if (successRate >= 85) return 70;
    if (successRate >= 80) return 60;
    return 40;
  }

  calculateGrowthHealth(userData) {
    const users = userData.users;
    const last30Days = users.filter(user => {
      const daysSinceRegistration = DateHelpers.calculateDuration(user.createdAt, new Date()).days;
      return daysSinceRegistration <= 30;
    }).length;

    const previous30Days = users.filter(user => {
      const daysSinceRegistration = DateHelpers.calculateDuration(user.createdAt, new Date()).days;
      return daysSinceRegistration > 30 && daysSinceRegistration <= 60;
    }).length;

    const growthRate = previous30Days > 0 ? ((last30Days - previous30Days) / previous30Days) * 100 : 0;
    
    // Health score based on growth rate
    if (growthRate >= 20) return 100;
    if (growthRate >= 10) return 80;
    if (growthRate >= 5) return 60;
    if (growthRate >= 0) return 40;
    return 20;
  }

  categorizeHealthLevel(score) {
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'fair';
    if (score >= 40) return 'poor';
    return 'critical';
  }

  identifyCriticalAreas(healthMetrics) {
    return Object.keys(healthMetrics)
      .filter(metric => healthMetrics[metric] < 50)
      .map(metric => ({
        area: metric,
        score: healthMetrics[metric],
        severity: healthMetrics[metric] < 30 ? 'critical' : 'concerning'
      }));
  }

  identifyStrengths(healthMetrics) {
    return Object.keys(healthMetrics)
      .filter(metric => healthMetrics[metric] >= 80)
      .map(metric => ({
        area: metric,
        score: healthMetrics[metric]
      }));
  }

  getDominantRoomType(userSessions) {
    const roomTypeCounts = _.countBy(userSessions, 'roomType');
    return Object.keys(roomTypeCounts).reduce((a, b) => 
      roomTypeCounts[a] > roomTypeCounts[b] ? a : b
    );
  }

  calculateEngagementDiversity(userSessions) {
    const roomTypes = [...new Set(userSessions.map(s => s.roomType))];
    const total = userSessions.length;
    
    if (total <= 1) return 0;
    
    const diversity = roomTypes.map(type => {
      const count = userSessions.filter(s => s.roomType === type).length;
      const ratio = count / total;
      return ratio * Math.log2(ratio);
    }).reduce((sum, val) => sum - val, 0);
    
    return Math.round(diversity * 100) / 100;
  }

  calculateRoomTypeTransitions(allParticipants) {
    const userSessions = _.groupBy(allParticipants, 'userId');
    const transitions = {};
    
    Object.values(userSessions).forEach(sessions => {
      const sortedSessions = sessions.sort((a, b) => 
        new Date(a.joinedAt || a.createdAt) - new Date(b.joinedAt || b.createdAt)
      );
      
      for (let i = 1; i < sortedSessions.length; i++) {
        const from = sortedSessions[i - 1].roomType;
        const to = sortedSessions[i].roomType;
        const transition = `${from}_to_${to}`;
        
        transitions[transition] = (transitions[transition] || 0) + 1;
      }
    });
    
    return transitions;
  }

  analyzePreferenceStability(crossRoomMetrics) {
    const stableUsers = crossRoomMetrics.filter(user => {
      const breakdown = user.roomTypeBreakdown;
      const maxUsage = Math.max(...Object.values(breakdown));
      const totalUsage = Object.values(breakdown).reduce((sum, val) => sum + val, 0);
      
      return (maxUsage / totalUsage) >= 0.7; // 70% or more in one room type
    }).length;
    
    return {
      stableUsers,
      exploratoryUsers: crossRoomMetrics.length - stableUsers,
      stabilityRate: this.calculateCompletionRate(crossRoomMetrics.length, stableUsers)
    };
  }

  calculateRoomTypeRetention(participants, retentionPeriods) {
    const userFirstSessions = new Map();
    
    participants.forEach(participant => {
      const userId = participant.userId;
      const sessionDate = new Date(participant.joinedAt || participant.createdAt);
      
      if (!userFirstSessions.has(userId) || sessionDate < userFirstSessions.get(userId)) {
        userFirstSessions.set(userId, sessionDate);
      }
    });
    
    const retention = {};
    
    retentionPeriods.forEach(days => {
      const eligibleUsers = Array.from(userFirstSessions.entries()).filter(([userId, firstSession]) => {
        const daysSinceFirst = DateHelpers.calculateDuration(firstSession, new Date()).days;
        return daysSinceFirst >= days;
      });
      
      const retainedUsers = eligibleUsers.filter(([userId, firstSession]) => {
        const cutoffDate = new Date(firstSession.getTime() + (days * 24 * 60 * 60 * 1000));
        return participants.some(p => 
          p.userId === userId && 
          new Date(p.joinedAt || p.createdAt) >= cutoffDate
        );
      });
      
      retention[`day_${days}`] = {
        eligible: eligibleUsers.length,
        retained: retainedUsers.length,
        rate: this.calculateCompletionRate(eligibleUsers.length, retainedUsers.length)
      };
    });
    
    return retention;
  }

  compareRetentionMetrics(roomTypeRetention) {
    const roomTypes = Object.keys(roomTypeRetention);
    const comparisonMetrics = {};
    
    ['day_1', 'day_7', 'day_14', 'day_30'].forEach(period => {
      comparisonMetrics[period] = roomTypes.map(roomType => ({
        roomType,
        rate: roomTypeRetention[roomType][period]?.rate || 0
      })).sort((a, b) => b.rate - a.rate);
    });
    
    return comparisonMetrics;
  }

  analyzeCrossRoomRetentionBoost(arenaData, discussionData) {
    const allParticipants = [
      ...arenaData.participants.map(p => ({ ...p, roomType: 'arena' })),
      ...discussionData.participants.map(p => ({ ...p, roomType: p.roomType || 'discussion' }))
    ];
    
    const userRoomTypes = _.groupBy(allParticipants, 'userId');
    
    const singleRoomUsers = Object.values(userRoomTypes).filter(sessions => {
      const roomTypes = [...new Set(sessions.map(s => s.roomType))];
      return roomTypes.length === 1;
    });
    
    const multiRoomUsers = Object.values(userRoomTypes).filter(sessions => {
      const roomTypes = [...new Set(sessions.map(s => s.roomType))];
      return roomTypes.length > 1;
    });
    
    const singleRoomRetention = this.calculateGroupRetention(singleRoomUsers);
    const multiRoomRetention = this.calculateGroupRetention(multiRoomUsers);
    
    return {
      singleRoomRetention,
      multiRoomRetention,
      retentionBoost: multiRoomRetention - singleRoomRetention,
      crossRoomAdvantage: multiRoomRetention > singleRoomRetention
    };
  }

  calculateGroupRetention(userGroups) {
    const retainedUsers = userGroups.filter(sessions => {
      const dates = sessions.map(s => new Date(s.joinedAt || s.createdAt)).sort();
      if (dates.length < 2) return false;
      
      const daysBetween = DateHelpers.calculateDuration(dates[0], dates[dates.length - 1]).days;
      return daysBetween >= 7; // Retained if they came back after a week
    }).length;
    
    return this.calculateCompletionRate(userGroups.length, retainedUsers);
  }

  analyzeRetentionBySegments(arenaData, discussionData) {
    // Implement retention analysis by user segments
    // This would involve segmenting users by behavior patterns and calculating retention for each segment
    return {
      newUsers: 0,
      regularUsers: 0,
      powerUsers: 0
    };
  }

  analyzeRetentionTrends(roomTypeRetention) {
    // Analyze trends in retention over time
    const trends = {};
    
    Object.keys(roomTypeRetention).forEach(roomType => {
      const retention = roomTypeRetention[roomType];
      const retentionRates = ['day_1', 'day_7', 'day_14', 'day_30'].map(period => 
        retention[period]?.rate || 0
      );
      
      trends[roomType] = {
        retentionCurve: retentionRates,
        dropoffRate: retentionRates[0] - retentionRates[retentionRates.length - 1],
        steepestDropoff: this.findSteepestDropoff(retentionRates)
      };
    });
    
    return trends;
  }

  findSteepestDropoff(retentionRates) {
    let maxDropoff = 0;
    let dropoffPeriod = null;
    
    for (let i = 1; i < retentionRates.length; i++) {
      const dropoff = retentionRates[i - 1] - retentionRates[i];
      if (dropoff > maxDropoff) {
        maxDropoff = dropoff;
        dropoffPeriod = `period_${i}`;
      }
    }
    
    return { period: dropoffPeriod, dropoff: maxDropoff };
  }

  identifyBestRetentionRoomType(roomTypeRetention) {
    const avgRetention = {};
    
    Object.keys(roomTypeRetention).forEach(roomType => {
      const retention = roomTypeRetention[roomType];
      const rates = Object.values(retention).map(r => r.rate || 0);
      avgRetention[roomType] = _.mean(rates);
    });
    
    return Object.keys(avgRetention).reduce((a, b) => 
      avgRetention[a] > avgRetention[b] ? a : b
    );
  }

  generateRetentionInsights(roomTypeRetention, crossRoomRetentionBoost) {
    const insights = [];
    
    if (crossRoomRetentionBoost.retentionBoost > 10) {
      insights.push({
        type: 'positive',
        message: `Cross-room users show ${crossRoomRetentionBoost.retentionBoost.toFixed(1)}% better retention`,
        recommendation: 'Encourage users to explore different room types'
      });
    }
    
    // Add more retention insights based on the data
    return insights;
  }

  // Additional helper methods for other analyses...
  
  calculateWeeklyGrowth(userRegistrations) {
    const weeklyGroups = _.groupBy(userRegistrations, 'registrationWeek');
    const weeks = Object.keys(weeklyGroups).sort();
    
    return weeks.map(week => ({
      week,
      newUsers: weeklyGroups[week].length,
      cumulativeUsers: this.getCumulativeUsers(weeklyGroups, weeks, week)
    }));
  }

  getWeekKey(date) {
    const year = date.getFullYear();
    const week = Math.ceil(((date - new Date(year, 0, 1)) / 86400000 + 1) / 7);
    return `${year}-W${week.toString().padStart(2, '0')}`;
  }

  getCumulativeUsers(weeklyGroups, weeks, currentWeek) {
    const currentIndex = weeks.indexOf(currentWeek);
    return weeks.slice(0, currentIndex + 1)
      .reduce((sum, week) => sum + weeklyGroups[week].length, 0);
  }

  calculateMonthlyGrowth(userRegistrations) {
    const monthlyGroups = _.groupBy(userRegistrations, reg => 
      `${reg.registrationDate.getFullYear()}-${(reg.registrationDate.getMonth() + 1).toString().padStart(2, '0')}`
    );
    
    return Object.keys(monthlyGroups).sort().map(month => ({
      month,
      newUsers: monthlyGroups[month].length
    }));
  }

  calculateGrowthRate(weeklyGrowth) {
    if (weeklyGrowth.length < 2) return 0;
    
    const recent = weeklyGrowth.slice(-4); // Last 4 weeks
    const previous = weeklyGrowth.slice(-8, -4); // Previous 4 weeks
    
    const recentAvg = _.mean(recent.map(w => w.newUsers));
    const previousAvg = _.mean(previous.map(w => w.newUsers));
    
    return previousAvg > 0 ? ((recentAvg - previousAvg) / previousAvg) * 100 : 0;
  }

  calculateActivationMetrics(userData, arenaData, discussionData) {
    const allParticipants = [...arenaData.participants, ...discussionData.participants];
    const activeUsers = new Set(allParticipants.map(p => p.userId));
    
    return {
      totalRegistered: userData.users.length,
      activated: activeUsers.size,
      activationRate: this.calculateCompletionRate(userData.users.length, activeUsers.size)
    };
  }

  calculateEngagementDepth(arenaData, discussionData) {
    const allParticipants = [...arenaData.participants, ...discussionData.participants];
    const userSessions = _.groupBy(allParticipants, 'userId');
    
    const sessionCounts = Object.values(userSessions).map(sessions => sessions.length);
    
    return {
      averageSessionsPerUser: _.mean(sessionCounts),
      medianSessionsPerUser: this.calculateMedian(sessionCounts),
      powerUsers: sessionCounts.filter(count => count >= 10).length
    };
  }

  calculateMedian(values) {
    const sorted = [...values].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
  }

  performCohortAnalysis(userRegistrations, arenaData, discussionData) {
    // Simplified cohort analysis
    const cohorts = _.groupBy(userRegistrations, reg => 
      `${reg.registrationDate.getFullYear()}-${(reg.registrationDate.getMonth() + 1).toString().padStart(2, '0')}`
    );
    
    return {
      totalCohorts: Object.keys(cohorts).length,
      averageCohortSize: _.mean(Object.values(cohorts).map(cohort => cohort.length))
    };
  }

  analyzeNetworkEffects(arenaData, discussionData) {
    // Simplified network effects analysis
    const totalRooms = arenaData.rooms.length + discussionData.rooms.length;
    const totalParticipants = arenaData.participants.length + discussionData.participants.length;
    
    return {
      averageParticipantsPerRoom: totalRooms > 0 ? totalParticipants / totalRooms : 0,
      networkDensity: this.calculateNetworkDensity(arenaData, discussionData)
    };
  }

  calculateNetworkDensity(arenaData, discussionData) {
    // Simplified network density calculation
    const uniqueUsers = new Set([
      ...arenaData.participants.map(p => p.userId),
      ...discussionData.participants.map(p => p.userId)
    ]);
    
    const totalRooms = arenaData.rooms.length + discussionData.rooms.length;
    
    return uniqueUsers.size > 0 ? totalRooms / uniqueUsers.size : 0;
  }

  calculateGrowthProjections(weeklyGrowth) {
    // Simple linear projection
    if (weeklyGrowth.length < 4) return null;
    
    const recentGrowth = weeklyGrowth.slice(-4);
    const avgWeeklyGrowth = _.mean(recentGrowth.map(w => w.newUsers));
    
    return {
      nextWeek: Math.round(avgWeeklyGrowth),
      nextMonth: Math.round(avgWeeklyGrowth * 4),
      projection: 'linear_trend'
    };
  }

  assessGrowthQuality(activationMetrics, cohortAnalysis) {
    let qualityScore = 0;
    
    // Activation rate component
    if (activationMetrics.activationRate >= 60) qualityScore += 40;
    else if (activationMetrics.activationRate >= 40) qualityScore += 30;
    else if (activationMetrics.activationRate >= 20) qualityScore += 20;
    else qualityScore += 10;
    
    // Cohort consistency component
    if (cohortAnalysis.averageCohortSize >= 50) qualityScore += 30;
    else if (cohortAnalysis.averageCohortSize >= 20) qualityScore += 20;
    else if (cohortAnalysis.averageCohortSize >= 10) qualityScore += 10;
    
    // Engagement depth component (simplified)
    qualityScore += 30; // Placeholder
    
    return {
      score: qualityScore,
      level: qualityScore >= 80 ? 'high' : qualityScore >= 60 ? 'medium' : 'low'
    };
  }

  calculateUserStickinessScore(sessions, daysSinceFirst, daysSinceLast) {
    let score = 0;
    
    // Frequency component
    const sessionFrequency = sessions.length / Math.max(1, daysSinceFirst);
    if (sessionFrequency >= 0.5) score += 40; // Daily usage
    else if (sessionFrequency >= 0.2) score += 30; // Few times per week
    else if (sessionFrequency >= 0.1) score += 20; // Weekly
    else score += 10;
    
    // Recency component
    if (daysSinceLast <= 1) score += 30;
    else if (daysSinceLast <= 3) score += 25;
    else if (daysSinceLast <= 7) score += 20;
    else if (daysSinceLast <= 14) score += 10;
    else score += 0;
    
    // Session count component
    if (sessions.length >= 20) score += 30;
    else if (sessions.length >= 10) score += 20;
    else if (sessions.length >= 5) score += 15;
    else score += 10;
    
    return Math.min(100, score);
  }

  calculateEngagementConsistency(sessions) {
    if (sessions.length < 2) return 0;
    
    const sessionDates = sessions.map(s => new Date(s.joinedAt || s.createdAt)).sort();
    const intervals = [];
    
    for (let i = 1; i < sessionDates.length; i++) {
      const interval = DateHelpers.calculateDuration(sessionDates[i - 1], sessionDates[i]).days;
      intervals.push(interval);
    }
    
    const avgInterval = _.mean(intervals);
    const variance = _.mean(intervals.map(interval => Math.pow(interval - avgInterval, 2)));
    const stdDev = Math.sqrt(variance);
    
    // Lower standard deviation = more consistent
    const consistencyScore = Math.max(0, 100 - (stdDev / avgInterval) * 100);
    return Math.round(consistencyScore);
  }

  analyzeStickinessFactors(stickinessMetrics, allParticipants) {
    const userParticipation = _.groupBy(allParticipants, 'userId');
    
    const factorAnalysis = stickinessMetrics.map(user => {
      const sessions = userParticipation[user.userId] || [];
      const roomTypes = [...new Set(sessions.map(s => s.roomType))];
      const roles = [...new Set(sessions.map(s => s.role || 'participant'))];
      
      return {
        userId: user.userId,
        stickinessScore: user.stickinessScore,
        roomTypeDiversity: roomTypes.length,
        roleDiversity: roles.length,
        hasModerated: roles.includes('moderator'),
        hasSpoken: roles.includes('speaker')
      };
    });
    
    // Correlation analysis
    const roomDiversityCorrelation = this.calculateCorrelation(
      factorAnalysis,
      f => f.roomTypeDiversity,
      f => f.stickinessScore
    );
    
    const roleDiversityCorrelation = this.calculateCorrelation(
      factorAnalysis,
      f => f.roleDiversity,
      f => f.stickinessScore
    );
    
    return {
      roomDiversityCorrelation,
      roleDiversityCorrelation,
      moderatorStickinessBoost: this.calculateModerationBoost(factorAnalysis),
      speakerStickinessBoost: this.calculateSpeakingBoost(factorAnalysis)
    };
  }

  calculateCorrelation(data, xFunc, yFunc) {
    if (data.length < 2) return 0;
    
    const x = data.map(xFunc);
    const y = data.map(yFunc);
    const n = data.length;
    
    const sumX = _.sum(x);
    const sumY = _.sum(y);
    const sumXY = _.sum(x.map((xi, i) => xi * y[i]));
    const sumX2 = _.sum(x.map(xi => xi * xi));
    const sumY2 = _.sum(y.map(yi => yi * yi));
    
    const numerator = n * sumXY - sumX * sumY;
    const denominator = Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
    
    return denominator === 0 ? 0 : Math.round((numerator / denominator) * 100) / 100;
  }

  calculateModerationBoost(factorAnalysis) {
    const moderators = factorAnalysis.filter(f => f.hasModerated);
    const nonModerators = factorAnalysis.filter(f => !f.hasModerated);
    
    const moderatorAvgStickiness = _.mean(moderators.map(m => m.stickinessScore));
    const nonModeratorAvgStickiness = _.mean(nonModerators.map(m => m.stickinessScore));
    
    return moderatorAvgStickiness - nonModeratorAvgStickiness;
  }

  calculateSpeakingBoost(factorAnalysis) {
    const speakers = factorAnalysis.filter(f => f.hasSpoken);
    const nonSpeakers = factorAnalysis.filter(f => !f.hasSpoken);
    
    const speakerAvgStickiness = _.mean(speakers.map(s => s.stickinessScore));
    const nonSpeakerAvgStickiness = _.mean(nonSpeakers.map(s => s.stickinessScore));
    
    return speakerAvgStickiness - nonSpeakerAvgStickiness;
  }

  // Placeholder methods for remaining analyses
  analyzeEngagementQuality(arenaData, discussionData) {
    return { placeholder: 'Engagement quality analysis' };
  }

  analyzeContentHealth(arenaData, discussionData) {
    return { placeholder: 'Content health analysis' };
  }

  analyzeCommunityHealth(arenaData, discussionData, userData) {
    return { placeholder: 'Community health analysis' };
  }

  analyzeScalabilityMetrics(arenaData, discussionData, timerData) {
    return { placeholder: 'Scalability metrics analysis' };
  }

  analyzeCompetitivePositioning(arenaData, discussionData) {
    return { placeholder: 'Competitive positioning analysis' };
  }

  analyzeHealthTrends(period) {
    return { placeholder: 'Health trends analysis' };
  }

  calculateTimerReliability(timerData) {
    return 95; // Placeholder
  }

  calculateRoomCreationSuccess(arenaData, discussionData) {
    return 98; // Placeholder
  }

  calculateSessionStability(arenaData, discussionData) {
    return 96; // Placeholder
  }

  calculateVoiceQuality(arenaData, discussionData) {
    return 92; // Placeholder
  }

  calculateRealTimeUpdateReliability(arenaData, discussionData) {
    return 97; // Placeholder
  }

  calculateSystemUptime(arenaData, discussionData) {
    return 99.5; // Placeholder
  }

  calculateErrorRates(arenaData, discussionData) {
    return { placeholder: 'Error rates analysis' };
  }

  calculatePerformanceMetrics(timerData, arenaData, discussionData) {
    return { placeholder: 'Performance metrics analysis' };
  }

  analyzeReliabilityTrends(reliabilityMetrics) {
    return { placeholder: 'Reliability trends analysis' };
  }

  /**
   * Generate Platform Health specific insights
   */
  generatePlatformHealthInsights(analysis) {
    const insights = [];

    // Overall health insights
    if (analysis.overallHealth.overallScore < 70) {
      insights.push({
        type: 'warning',
        category: 'platform_health',
        message: `Overall platform health score is ${analysis.overallHealth.overallScore}/100`,
        priority: 'high',
        suggestion: 'Focus on critical areas: ' + analysis.overallHealth.criticalAreas.map(a => a.area).join(', ')
      });
    }

    // Cross-room engagement insights
    if (analysis.crossRoomEngagement.crossRoomPercentage < 30) {
      insights.push({
        type: 'warning',
        category: 'cross_room_engagement',
        message: `Only ${analysis.crossRoomEngagement.crossRoomPercentage}% of users engage with multiple room types`,
        priority: 'medium',
        suggestion: 'Implement features to encourage cross-room exploration'
      });
    }

    // User stickiness insights
    if (analysis.userStickiness.averageStickinessScore < 60) {
      insights.push({
        type: 'warning',
        category: 'user_stickiness',
        message: `Low average user stickiness score (${Math.round(analysis.userStickiness.averageStickinessScore)})`,
        priority: 'high',
        suggestion: 'Improve user engagement and retention strategies'
      });
    }

    // Platform growth insights
    if (analysis.platformGrowth.growthRate < 5) {
      insights.push({
        type: 'warning',
        category: 'growth',
        message: `Low growth rate (${analysis.platformGrowth.growthRate.toFixed(1)}%)`,
        priority: 'medium',
        suggestion: 'Enhance user acquisition and viral features'
      });
    }

    return insights;
  }
}