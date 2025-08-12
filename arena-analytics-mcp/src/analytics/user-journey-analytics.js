import _ from 'lodash';
import { BaseAnalytics } from './base-analytics.js';
import { DateHelpers } from '../utils/date-helpers.js';
import { AppwriteClient } from '../db/appwrite-client.js';

export class UserJourneyAnalytics extends BaseAnalytics {
  constructor(appwriteClient) {
    super(appwriteClient);
  }

  /**
   * Comprehensive user journey analytics across all room types
   */
  async analyzeUserJourneys(period = 'week') {
    const { startDate, endDate } = DateHelpers.getDateRange(period);
    
    // Get all participants across all room types
    const [arenaParticipants, discussionParticipants, users] = await Promise.all([
      this.getAllArenaParticipants(startDate, endDate),
      this.getAllDiscussionParticipants(startDate, endDate),
      this.getAllUsers()
    ]);

    const analysis = {
      period: { startDate, endDate, period },
      crossRoomMovement: this.analyzeCrossRoomMovement(arenaParticipants, discussionParticipants),
      roomTypePreferences: this.analyzeRoomTypePreferences(arenaParticipants, discussionParticipants, users),
      roleProgression: this.analyzeRoleProgression(arenaParticipants, discussionParticipants),
      userSegmentation: this.analyzeUserSegmentation(arenaParticipants, discussionParticipants, users),
      engagementJourney: this.analyzeEngagementJourney(arenaParticipants, discussionParticipants),
      retentionPatterns: this.analyzeRetentionPatterns(arenaParticipants, discussionParticipants),
      userLifecycle: this.analyzeUserLifecycle(arenaParticipants, discussionParticipants, users),
      conversionFunnels: this.analyzeConversionFunnels(arenaParticipants, discussionParticipants),
      demographicInsights: this.analyzeDemographicInsights(arenaParticipants, discussionParticipants, users)
    };

    // Generate insights and recommendations
    analysis.insights = this.generateUserJourneyInsights(analysis);
    analysis.launchReadiness = this.prepareLaunchMetrics(analysis);

    return analysis;
  }

  /**
   * Analyze user movement between different room types
   */
  analyzeCrossRoomMovement(arenaParticipants, discussionParticipants) {
    // Create user participation map
    const userRoomTypes = new Map();
    
    // Track arena participation
    arenaParticipants.forEach(participant => {
      const userId = participant.userId;
      if (!userRoomTypes.has(userId)) {
        userRoomTypes.set(userId, { arena: 0, discussion: 0, openDiscussion: 0 });
      }
      userRoomTypes.get(userId).arena++;
    });

    // Track discussion participation (including open discussions and debates & discussions)
    discussionParticipants.forEach(participant => {
      const userId = participant.userId;
      if (!userRoomTypes.has(userId)) {
        userRoomTypes.set(userId, { arena: 0, discussion: 0, openDiscussion: 0 });
      }
      
      // Determine room type from room data
      if (participant.roomType === 'open_discussion') {
        userRoomTypes.get(userId).openDiscussion++;
      } else {
        userRoomTypes.get(userId).discussion++;
      }
    });

    // Analyze movement patterns
    const movementPatterns = Array.from(userRoomTypes.entries()).map(([userId, participation]) => {
      const totalRooms = participation.arena + participation.discussion + participation.openDiscussion;
      const diversity = this.calculateRoomTypeDiversity(participation);
      
      return {
        userId,
        totalParticipation: totalRooms,
        arenaParticipation: participation.arena,
        discussionParticipation: participation.discussion,
        openDiscussionParticipation: participation.openDiscussion,
        diversityScore: diversity,
        primaryRoomType: this.determinePrimaryRoomType(participation),
        userType: this.categorizeUserType(participation, totalRooms)
      };
    });

    // Aggregate statistics
    const totalUsers = movementPatterns.length;
    const roomTypeStats = {
      arenaOnly: movementPatterns.filter(p => p.arenaParticipation > 0 && p.discussionParticipation === 0 && p.openDiscussionParticipation === 0).length,
      discussionOnly: movementPatterns.filter(p => p.arenaParticipation === 0 && p.discussionParticipation > 0 && p.openDiscussionParticipation === 0).length,
      openDiscussionOnly: movementPatterns.filter(p => p.arenaParticipation === 0 && p.discussionParticipation === 0 && p.openDiscussionParticipation > 0).length,
      multiRoomUsers: movementPatterns.filter(p => this.countActiveRoomTypes(p) > 1).length,
      universalUsers: movementPatterns.filter(p => p.arenaParticipation > 0 && p.discussionParticipation > 0 && p.openDiscussionParticipation > 0).length
    };

    const averageDiversityScore = _.mean(movementPatterns.map(p => p.diversityScore));
    const userTypeDistribution = _.countBy(movementPatterns, 'userType');
    const primaryRoomDistribution = _.countBy(movementPatterns, 'primaryRoomType');

    return {
      totalUsers,
      roomTypeStats,
      userTypeDistribution,
      primaryRoomDistribution,
      averageDiversityScore,
      crossRoomEngagement: {
        singleRoomUsers: roomTypeStats.arenaOnly + roomTypeStats.discussionOnly + roomTypeStats.openDiscussionOnly,
        multiRoomUsers: roomTypeStats.multiRoomUsers,
        universalUsers: roomTypeStats.universalUsers
      },
      movementMatrix: this.createMovementMatrix(movementPatterns),
      topCrossRoomUsers: movementPatterns.sort((a, b) => b.diversityScore - a.diversityScore).slice(0, 10)
    };
  }

  /**
   * Analyze room type preferences by user demographics and behavior
   */
  analyzeRoomTypePreferences(arenaParticipants, discussionParticipants, users) {
    const userMap = new Map(users.map(user => [user.$id, user]));
    const preferences = [];

    // Analyze each user's preferences
    const allParticipants = [...arenaParticipants, ...discussionParticipants];
    const userParticipation = _.groupBy(allParticipants, 'userId');

    Object.keys(userParticipation).forEach(userId => {
      const user = userMap.get(userId);
      const participations = userParticipation[userId];
      
      const roomTypeCounts = {
        arena: participations.filter(p => p.roomType === 'arena' || p.hasOwnProperty('judgeId')).length,
        debate_discussion: participations.filter(p => p.roomType === 'debate_discussion' || p.roomType === 'discussion' || p.roomType === 'debate' || p.roomType === 'take').length,
        open_discussion: participations.filter(p => p.roomType === 'open_discussion').length
      };

      const totalParticipations = Object.values(roomTypeCounts).reduce((sum, count) => sum + count, 0);
      
      if (totalParticipations > 0) {
        preferences.push({
          userId,
          userProfile: user ? {
            createdAt: user.createdAt,
            country: user.country,
            ageGroup: this.calculateAgeGroup(user.dateOfBirth),
            profileCompleteness: this.calculateProfileCompleteness(user)
          } : null,
          roomTypePreferences: {
            arena: (roomTypeCounts.arena / totalParticipations) * 100,
            debate_discussion: (roomTypeCounts.debate_discussion / totalParticipations) * 100,
            open_discussion: (roomTypeCounts.open_discussion / totalParticipations) * 100
          },
          strongestPreference: this.getStrongestPreference(roomTypeCounts),
          participationLevel: this.categorizeParticipationLevel(totalParticipations),
          totalParticipations
        });
      }
    });

    // Demographic analysis
    const demographicBreakdown = this.analyzeDemographicPreferences(preferences);
    const participationLevelAnalysis = this.analyzeParticipationLevelPreferences(preferences);
    const preferenceCorrelations = this.analyzePreferenceCorrelations(preferences);

    return {
      totalUsersAnalyzed: preferences.length,
      overallPreferences: {
        arena: _.mean(preferences.map(p => p.roomTypePreferences.arena)),
        debate_discussion: _.mean(preferences.map(p => p.roomTypePreferences.debate_discussion)),
        open_discussion: _.mean(preferences.map(p => p.roomTypePreferences.open_discussion))
      },
      strongestPreferenceDistribution: _.countBy(preferences, 'strongestPreference'),
      demographicBreakdown,
      participationLevelAnalysis,
      preferenceCorrelations,
      loyaltyAnalysis: this.analyzeLoyalty(preferences),
      explorationPatterns: this.analyzeExplorationPatterns(preferences)
    };
  }

  /**
   * Analyze user role progression: audience → speaker → moderator
   */
  analyzeRoleProgression(arenaParticipants, discussionParticipants) {
    const userRoleHistory = new Map();

    // Track role progression across all room types
    [...arenaParticipants, ...discussionParticipants].forEach(participant => {
      const userId = participant.userId;
      const role = participant.role || 'participant';
      const timestamp = participant.joinedAt || participant.createdAt;

      if (!userRoleHistory.has(userId)) {
        userRoleHistory.set(userId, []);
      }

      userRoleHistory.get(userId).push({
        role,
        timestamp,
        roomType: this.determineRoomType(participant),
        roomId: participant.roomId
      });
    });

    // Analyze progression patterns
    const progressionAnalysis = [];
    userRoleHistory.forEach((history, userId) => {
      // Sort by timestamp
      const sortedHistory = history.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
      
      const roleSequence = sortedHistory.map(h => h.role);
      const uniqueRoles = [...new Set(roleSequence)];
      const progression = this.analyzeIndividualProgression(sortedHistory);

      progressionAnalysis.push({
        userId,
        totalSessions: sortedHistory.length,
        uniqueRoles: uniqueRoles.length,
        roleSequence,
        progression: progression.type,
        progressionScore: progression.score,
        moderatorSessions: roleSequence.filter(r => r === 'moderator').length,
        speakerSessions: roleSequence.filter(r => r === 'speaker').length,
        audienceSessions: roleSequence.filter(r => r === 'audience').length,
        timeToFirstSpeaker: progression.timeToFirstSpeaker,
        timeToModerator: progression.timeToModerator,
        retentionAfterModerating: progression.retentionAfterModerating
      });
    });

    // Aggregate insights
    const progressionStats = {
      totalUsers: progressionAnalysis.length,
      progressionTypes: _.countBy(progressionAnalysis, 'progression'),
      averageProgressionScore: _.mean(progressionAnalysis.map(p => p.progressionScore)),
      moderatorConversionRate: this.calculateCompletionRate(
        progressionAnalysis.length,
        progressionAnalysis.filter(p => p.moderatorSessions > 0).length
      ),
      speakerConversionRate: this.calculateCompletionRate(
        progressionAnalysis.length,
        progressionAnalysis.filter(p => p.speakerSessions > 0).length
      )
    };

    const roleTransitionMatrix = this.createRoleTransitionMatrix(progressionAnalysis);
    const progressionSpeed = this.analyzeProgressionSpeed(progressionAnalysis);

    return {
      progressionStats,
      roleTransitionMatrix,
      progressionSpeed,
      fastestProgressors: progressionAnalysis
        .filter(p => p.timeToModerator !== null)
        .sort((a, b) => a.timeToModerator - b.timeToModerator)
        .slice(0, 10),
      retentionByRole: this.analyzeRetentionByRole(progressionAnalysis),
      progressionBottlenecks: this.identifyProgressionBottlenecks(progressionAnalysis)
    };
  }

  /**
   * Analyze user segmentation based on behavior patterns
   */
  analyzeUserSegmentation(arenaParticipants, discussionParticipants, users) {
    const userBehavior = new Map();

    // Aggregate user behavior across all room types
    [...arenaParticipants, ...discussionParticipants].forEach(participant => {
      const userId = participant.userId;
      if (!userBehavior.has(userId)) {
        userBehavior.set(userId, {
          totalSessions: 0,
          arenaRooms: 0,
          discussionRooms: 0,
          openDiscussionRooms: 0,
          moderatorSessions: 0,
          speakerSessions: 0,
          audienceSessions: 0,
          averageSessionDuration: 0,
          roomsCreated: 0,
          firstSession: null,
          lastSession: null,
          totalDuration: 0
        });
      }

      const behavior = userBehavior.get(userId);
      behavior.totalSessions++;

      // Room type tracking
      const roomType = this.determineRoomType(participant);
      if (roomType === 'arena') behavior.arenaRooms++;
      else if (roomType === 'open_discussion') behavior.openDiscussionRooms++;
      else behavior.discussionRooms++;

      // Role tracking
      const role = participant.role || 'participant';
      if (role === 'moderator') behavior.moderatorSessions++;
      else if (role === 'speaker') behavior.speakerSessions++;
      else behavior.audienceSessions++;

      // Session duration and timing
      const sessionStart = new Date(participant.joinedAt || participant.createdAt);
      const sessionEnd = participant.leftAt ? new Date(participant.leftAt) : new Date();
      const duration = Math.max(0, (sessionEnd - sessionStart) / (1000 * 60)); // minutes

      behavior.totalDuration += duration;
      behavior.averageSessionDuration = behavior.totalDuration / behavior.totalSessions;

      if (!behavior.firstSession || sessionStart < new Date(behavior.firstSession)) {
        behavior.firstSession = sessionStart.toISOString();
      }
      if (!behavior.lastSession || sessionStart > new Date(behavior.lastSession)) {
        behavior.lastSession = sessionStart.toISOString();
      }

      // Room creation tracking (moderator role implies room creation in some contexts)
      if (role === 'moderator' && participant.createdRoom) {
        behavior.roomsCreated++;
      }
    });

    // Create user segments
    const segments = Array.from(userBehavior.entries()).map(([userId, behavior]) => {
      const user = users.find(u => u.$id === userId);
      const daysSinceFirst = behavior.firstSession ? 
        DateHelpers.calculateDuration(behavior.firstSession, new Date()).days : 0;
      const daysSinceLast = behavior.lastSession ? 
        DateHelpers.calculateDuration(behavior.lastSession, new Date()).days : 0;

      return {
        userId,
        userProfile: user,
        ...behavior,
        daysSinceFirst,
        daysSinceLast,
        engagementLevel: this.calculateEngagementLevel(behavior),
        userSegment: this.determineUserSegment(behavior, daysSinceFirst, daysSinceLast),
        roomTypeDiversity: this.calculateRoomTypeDiversity({
          arena: behavior.arenaRooms,
          discussion: behavior.discussionRooms,
          openDiscussion: behavior.openDiscussionRooms
        }),
        roleAdvancement: this.calculateRoleAdvancement(behavior)
      };
    });

    // Segment analysis
    const segmentDistribution = _.countBy(segments, 'userSegment');
    const engagementDistribution = _.countBy(segments, 'engagementLevel');
    const segmentCharacteristics = this.analyzeSegmentCharacteristics(segments);

    return {
      totalUsers: segments.length,
      segmentDistribution,
      engagementDistribution,
      segmentCharacteristics,
      highValueUsers: segments.filter(s => s.userSegment === 'power_user' || s.userSegment === 'content_creator').length,
      atRiskUsers: segments.filter(s => s.userSegment === 'at_risk' || s.daysSinceLast > 7).length,
      averageSessionsPerUser: _.mean(segments.map(s => s.totalSessions)),
      averageSessionDuration: _.mean(segments.map(s => s.averageSessionDuration)),
      retentionBySegment: this.calculateRetentionBySegment(segments)
    };
  }

  /**
   * Helper methods for complex calculations
   */
  async getAllArenaParticipants(startDate, endDate) {
    // Get arena rooms first, then participants
    const arenaRooms = await this.db.getArenaRooms(startDate, endDate);
    const roomIds = arenaRooms.documents.map(room => room.$id);
    
    if (roomIds.length === 0) return [];
    
    const participants = await this.db.getArenaParticipants(roomIds);
    return participants.documents.map(p => ({ ...p, roomType: 'arena' }));
  }

  async getAllDiscussionParticipants(startDate, endDate) {
    // Get discussion rooms first, then participants
    const discussionRooms = await this.db.getDiscussionRooms(startDate, endDate);
    const roomIds = discussionRooms.documents.map(room => room.$id);
    
    if (roomIds.length === 0) return [];
    
    const participants = await this.db.getDiscussionParticipants(roomIds);
    
    // Add room type information
    const roomTypeMap = new Map(discussionRooms.documents.map(room => [room.$id, room.roomType || 'discussion']));
    
    return participants.documents.map(p => ({
      ...p,
      roomType: roomTypeMap.get(p.roomId) || 'discussion'
    }));
  }

  async getAllUsers() {
    const users = await this.db.getAllDocuments('users');
    return users;
  }

  calculateRoomTypeDiversity(participation) {
    const total = participation.arena + participation.discussion + participation.openDiscussion;
    if (total === 0) return 0;

    const ratios = [
      participation.arena / total,
      participation.discussion / total,
      participation.openDiscussion / total
    ].filter(ratio => ratio > 0);

    // Shannon diversity index adapted for room types
    const diversity = -ratios.reduce((sum, ratio) => sum + ratio * Math.log2(ratio), 0);
    return Math.round(diversity * 100) / 100;
  }

  determinePrimaryRoomType(participation) {
    const max = Math.max(participation.arena, participation.discussion, participation.openDiscussion);
    if (participation.arena === max) return 'arena';
    if (participation.discussion === max) return 'discussion';
    return 'open_discussion';
  }

  categorizeUserType(participation, totalRooms) {
    if (totalRooms === 1) return 'new_user';
    if (totalRooms < 5) return 'casual_user';
    if (totalRooms < 15) return 'regular_user';
    if (totalRooms < 50) return 'active_user';
    return 'power_user';
  }

  countActiveRoomTypes(pattern) {
    let count = 0;
    if (pattern.arenaParticipation > 0) count++;
    if (pattern.discussionParticipation > 0) count++;
    if (pattern.openDiscussionParticipation > 0) count++;
    return count;
  }

  createMovementMatrix(movementPatterns) {
    // Create a matrix showing movement between room types
    const matrix = {
      'arena_to_discussion': 0,
      'arena_to_open': 0,
      'discussion_to_arena': 0,
      'discussion_to_open': 0,
      'open_to_arena': 0,
      'open_to_discussion': 0
    };

    movementPatterns.forEach(pattern => {
      if (pattern.arenaParticipation > 0 && pattern.discussionParticipation > 0) {
        matrix.arena_to_discussion++;
        matrix.discussion_to_arena++;
      }
      if (pattern.arenaParticipation > 0 && pattern.openDiscussionParticipation > 0) {
        matrix.arena_to_open++;
        matrix.open_to_arena++;
      }
      if (pattern.discussionParticipation > 0 && pattern.openDiscussionParticipation > 0) {
        matrix.discussion_to_open++;
        matrix.open_to_discussion++;
      }
    });

    return matrix;
  }

  calculateAgeGroup(dateOfBirth) {
    if (!dateOfBirth) return 'unknown';
    
    const today = new Date();
    const birth = new Date(dateOfBirth);
    const age = Math.floor((today - birth) / (365.25 * 24 * 60 * 60 * 1000));
    
    if (age < 18) return 'under_18';
    if (age < 25) return '18_24';
    if (age < 35) return '25_34';
    if (age < 45) return '35_44';
    if (age < 55) return '45_54';
    return '55_plus';
  }

  calculateProfileCompleteness(user) {
    const fields = ['name', 'email', 'dateOfBirth', 'country', 'bio', 'avatar'];
    const completedFields = fields.filter(field => user[field] && user[field].length > 0).length;
    return Math.round((completedFields / fields.length) * 100);
  }

  getStrongestPreference(roomTypeCounts) {
    const max = Math.max(...Object.values(roomTypeCounts));
    return Object.keys(roomTypeCounts).find(key => roomTypeCounts[key] === max);
  }

  categorizeParticipationLevel(totalParticipations) {
    if (totalParticipations === 1) return 'trial';
    if (totalParticipations < 5) return 'casual';
    if (totalParticipations < 15) return 'regular';
    if (totalParticipations < 30) return 'active';
    return 'power';
  }

  analyzeDemographicPreferences(preferences) {
    const byAgeGroup = _.groupBy(preferences.filter(p => p.userProfile?.ageGroup), p => p.userProfile.ageGroup);
    const byCountry = _.groupBy(preferences.filter(p => p.userProfile?.country), p => p.userProfile.country);

    return {
      byAgeGroup: Object.keys(byAgeGroup).map(ageGroup => ({
        ageGroup,
        count: byAgeGroup[ageGroup].length,
        averagePreferences: {
          arena: _.mean(byAgeGroup[ageGroup].map(p => p.roomTypePreferences.arena)),
          debate_discussion: _.mean(byAgeGroup[ageGroup].map(p => p.roomTypePreferences.debate_discussion)),
          open_discussion: _.mean(byAgeGroup[ageGroup].map(p => p.roomTypePreferences.open_discussion))
        }
      })),
      topCountries: Object.keys(byCountry)
        .map(country => ({
          country,
          count: byCountry[country].length,
          averagePreferences: {
            arena: _.mean(byCountry[country].map(p => p.roomTypePreferences.arena)),
            debate_discussion: _.mean(byCountry[country].map(p => p.roomTypePreferences.debate_discussion)),
            open_discussion: _.mean(byCountry[country].map(p => p.roomTypePreferences.open_discussion))
          }
        }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 10)
    };
  }

  analyzeParticipationLevelPreferences(preferences) {
    const byLevel = _.groupBy(preferences, 'participationLevel');
    
    return Object.keys(byLevel).map(level => ({
      participationLevel: level,
      count: byLevel[level].length,
      averagePreferences: {
        arena: _.mean(byLevel[level].map(p => p.roomTypePreferences.arena)),
        debate_discussion: _.mean(byLevel[level].map(p => p.roomTypePreferences.debate_discussion)),
        open_discussion: _.mean(byLevel[level].map(p => p.roomTypePreferences.open_discussion))
      }
    }));
  }

  analyzePreferenceCorrelations(preferences) {
    // Calculate correlations between different preferences and user characteristics
    return {
      profileCompletenessCorrelation: this.calculateCorrelation(
        preferences.filter(p => p.userProfile?.profileCompleteness),
        p => p.userProfile.profileCompleteness,
        p => p.totalParticipations
      ),
      diversityCorrelation: this.calculateCorrelation(
        preferences,
        p => this.calculateRoomTypeDiversity(p.roomTypePreferences),
        p => p.totalParticipations
      )
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
    
    return denominator === 0 ? 0 : numerator / denominator;
  }

  analyzeLoyalty(preferences) {
    const loyaltyScores = preferences.map(p => {
      const maxPreference = Math.max(...Object.values(p.roomTypePreferences));
      return maxPreference; // Higher percentage = more loyal to one room type
    });

    return {
      averageLoyalty: _.mean(loyaltyScores),
      highLoyaltyUsers: loyaltyScores.filter(score => score > 70).length,
      diversifiedUsers: loyaltyScores.filter(score => score < 50).length
    };
  }

  analyzeExplorationPatterns(preferences) {
    const explorers = preferences.filter(p => 
      Object.values(p.roomTypePreferences).filter(pref => pref > 10).length >= 2
    );

    return {
      totalExplorers: explorers.length,
      explorationRate: this.calculateCompletionRate(preferences.length, explorers.length),
      averageExplorationDiversity: _.mean(explorers.map(p => 
        this.calculateRoomTypeDiversity(p.roomTypePreferences)
      ))
    };
  }

  determineRoomType(participant) {
    // Determine room type from participant data
    if (participant.roomType) return participant.roomType;
    if (participant.judgeId || participant.judgment) return 'arena';
    return 'discussion'; // Default fallback
  }

  analyzeIndividualProgression(sortedHistory) {
    const roles = sortedHistory.map(h => h.role);
    const timestamps = sortedHistory.map(h => new Date(h.timestamp));
    
    let progressionScore = 0;
    let progressionType = 'static';
    let timeToFirstSpeaker = null;
    let timeToModerator = null;
    let retentionAfterModerating = null;

    // Calculate progression metrics
    const firstSpeakerIndex = roles.indexOf('speaker');
    const firstModeratorIndex = roles.indexOf('moderator');
    
    if (firstSpeakerIndex !== -1) {
      timeToFirstSpeaker = DateHelpers.calculateDuration(timestamps[0], timestamps[firstSpeakerIndex]).days;
      progressionScore += 25;
    }
    
    if (firstModeratorIndex !== -1) {
      timeToModerator = DateHelpers.calculateDuration(timestamps[0], timestamps[firstModeratorIndex]).days;
      progressionScore += 50;
      
      // Check retention after first moderating
      const sessionsAfterModerating = roles.slice(firstModeratorIndex + 1).length;
      retentionAfterModerating = sessionsAfterModerating;
      if (sessionsAfterModerating > 0) progressionScore += 25;
    }

    // Determine progression type
    const uniqueRoles = [...new Set(roles)];
    if (uniqueRoles.length === 1) {
      progressionType = 'static';
    } else if (uniqueRoles.includes('moderator')) {
      progressionType = 'advanced';
    } else if (uniqueRoles.includes('speaker')) {
      progressionType = 'progressing';
    } else {
      progressionType = 'exploring';
    }

    return {
      type: progressionType,
      score: progressionScore,
      timeToFirstSpeaker,
      timeToModerator,
      retentionAfterModerating
    };
  }

  createRoleTransitionMatrix(progressionAnalysis) {
    const transitions = {
      'audience_to_speaker': 0,
      'audience_to_moderator': 0,
      'speaker_to_moderator': 0,
      'speaker_to_audience': 0,
      'moderator_to_speaker': 0,
      'moderator_to_audience': 0
    };

    progressionAnalysis.forEach(analysis => {
      const roleSequence = analysis.roleSequence;
      
      for (let i = 1; i < roleSequence.length; i++) {
        const from = roleSequence[i - 1];
        const to = roleSequence[i];
        const transition = `${from}_to_${to}`;
        
        if (transitions.hasOwnProperty(transition)) {
          transitions[transition]++;
        }
      }
    });

    return transitions;
  }

  analyzeProgressionSpeed(progressionAnalysis) {
    const speakerProgressors = progressionAnalysis.filter(p => p.timeToFirstSpeaker !== null);
    const moderatorProgressors = progressionAnalysis.filter(p => p.timeToModerator !== null);

    return {
      averageTimeToSpeaker: speakerProgressors.length > 0 ? 
        _.mean(speakerProgressors.map(p => p.timeToFirstSpeaker)) : null,
      averageTimeToModerator: moderatorProgressors.length > 0 ? 
        _.mean(moderatorProgressors.map(p => p.timeToModerator)) : null,
      fastTrackUsers: moderatorProgressors.filter(p => p.timeToModerator < 7).length,
      slowProgressors: moderatorProgressors.filter(p => p.timeToModerator > 30).length
    };
  }

  analyzeRetentionByRole(progressionAnalysis) {
    const roleRetention = {
      audience: { total: 0, retained: 0 },
      speaker: { total: 0, retained: 0 },
      moderator: { total: 0, retained: 0 }
    };

    progressionAnalysis.forEach(analysis => {
      if (analysis.audienceSessions > 0) {
        roleRetention.audience.total++;
        if (analysis.totalSessions > 1) roleRetention.audience.retained++;
      }
      if (analysis.speakerSessions > 0) {
        roleRetention.speaker.total++;
        if (analysis.totalSessions > 1) roleRetention.speaker.retained++;
      }
      if (analysis.moderatorSessions > 0) {
        roleRetention.moderator.total++;
        if (analysis.retentionAfterModerating > 0) roleRetention.moderator.retained++;
      }
    });

    return {
      audience: this.calculateCompletionRate(roleRetention.audience.total, roleRetention.audience.retained),
      speaker: this.calculateCompletionRate(roleRetention.speaker.total, roleRetention.speaker.retained),
      moderator: this.calculateCompletionRate(roleRetention.moderator.total, roleRetention.moderator.retained)
    };
  }

  identifyProgressionBottlenecks(progressionAnalysis) {
    const bottlenecks = [];
    
    const speakerConversionRate = this.calculateCompletionRate(
      progressionAnalysis.length,
      progressionAnalysis.filter(p => p.speakerSessions > 0).length
    );
    
    const moderatorConversionRate = this.calculateCompletionRate(
      progressionAnalysis.filter(p => p.speakerSessions > 0).length,
      progressionAnalysis.filter(p => p.moderatorSessions > 0).length
    );

    if (speakerConversionRate < 30) {
      bottlenecks.push({
        stage: 'audience_to_speaker',
        conversionRate: speakerConversionRate,
        severity: 'high',
        recommendation: 'Improve speaker onboarding and encourage participation'
      });
    }

    if (moderatorConversionRate < 20) {
      bottlenecks.push({
        stage: 'speaker_to_moderator',
        conversionRate: moderatorConversionRate,
        severity: 'medium',
        recommendation: 'Provide better moderator tools and training'
      });
    }

    return bottlenecks;
  }

  calculateEngagementLevel(behavior) {
    let score = 0;
    
    // Session frequency
    score += Math.min(40, behavior.totalSessions * 2);
    
    // Role diversity
    if (behavior.moderatorSessions > 0) score += 30;
    else if (behavior.speakerSessions > 0) score += 20;
    else if (behavior.audienceSessions > 0) score += 10;
    
    // Session duration
    if (behavior.averageSessionDuration > 30) score += 20;
    else if (behavior.averageSessionDuration > 15) score += 10;
    
    // Room creation
    score += Math.min(10, behavior.roomsCreated * 5);
    
    if (score >= 80) return 'high';
    if (score >= 50) return 'medium';
    return 'low';
  }

  determineUserSegment(behavior, daysSinceFirst, daysSinceLast) {
    // Churn risk
    if (daysSinceLast > 14) return 'at_risk';
    if (daysSinceLast > 7 && behavior.totalSessions < 3) return 'dormant';
    
    // New users
    if (daysSinceFirst < 7) return 'new_user';
    
    // Engagement-based segments
    if (behavior.moderatorSessions > 5 || behavior.roomsCreated > 3) return 'content_creator';
    if (behavior.totalSessions > 20 && behavior.speakerSessions > 10) return 'power_user';
    if (behavior.totalSessions > 10) return 'regular_user';
    if (behavior.totalSessions > 3) return 'engaged_user';
    
    return 'casual_user';
  }

  calculateRoleAdvancement(behavior) {
    let score = 0;
    
    if (behavior.audienceSessions > 0) score += 1;
    if (behavior.speakerSessions > 0) score += 2;
    if (behavior.moderatorSessions > 0) score += 3;
    
    return score;
  }

  analyzeSegmentCharacteristics(segments) {
    const segmentGroups = _.groupBy(segments, 'userSegment');
    
    return Object.keys(segmentGroups).map(segment => {
      const group = segmentGroups[segment];
      
      return {
        segment,
        count: group.length,
        averageSessions: _.mean(group.map(s => s.totalSessions)),
        averageDuration: _.mean(group.map(s => s.averageSessionDuration)),
        moderatorRate: this.calculateCompletionRate(group.length, group.filter(s => s.moderatorSessions > 0).length),
        averageDaysSinceLast: _.mean(group.map(s => s.daysSinceLast)),
        roomTypeDiversity: _.mean(group.map(s => s.roomTypeDiversity))
      };
    });
  }

  calculateRetentionBySegment(segments) {
    const segmentGroups = _.groupBy(segments, 'userSegment');
    
    return Object.keys(segmentGroups).reduce((retention, segment) => {
      const group = segmentGroups[segment];
      const activeUsers = group.filter(s => s.daysSinceLast <= 7).length;
      
      retention[segment] = this.calculateCompletionRate(group.length, activeUsers);
      return retention;
    }, {});
  }

  analyzeEngagementJourney(arenaParticipants, discussionParticipants) {
    // Analyze how user engagement evolves over time
    const userEngagementTimeline = new Map();
    
    [...arenaParticipants, ...discussionParticipants].forEach(participant => {
      const userId = participant.userId;
      const sessionDate = new Date(participant.joinedAt || participant.createdAt);
      
      if (!userEngagementTimeline.has(userId)) {
        userEngagementTimeline.set(userId, []);
      }
      
      userEngagementTimeline.get(userId).push({
        date: sessionDate,
        roomType: this.determineRoomType(participant),
        role: participant.role || 'participant',
        duration: participant.sessionDuration || 0
      });
    });

    // Analyze engagement patterns
    const engagementJourneys = Array.from(userEngagementTimeline.entries()).map(([userId, timeline]) => {
      timeline.sort((a, b) => a.date - b.date);
      
      const journeyLength = DateHelpers.calculateDuration(timeline[0].date, timeline[timeline.length - 1].date).days;
      const sessionFrequency = timeline.length / Math.max(1, journeyLength);
      const engagementTrend = this.calculateEngagementTrend(timeline);
      
      return {
        userId,
        journeyLength,
        totalSessions: timeline.length,
        sessionFrequency,
        engagementTrend,
        firstRoomType: timeline[0].roomType,
        currentRoomType: timeline[timeline.length - 1].roomType,
        roleEvolution: this.analyzeRoleEvolution(timeline)
      };
    });

    return {
      totalUsers: engagementJourneys.length,
      averageJourneyLength: _.mean(engagementJourneys.map(j => j.journeyLength)),
      averageSessionFrequency: _.mean(engagementJourneys.map(j => j.sessionFrequency)),
      engagementTrends: _.countBy(engagementJourneys, 'engagementTrend'),
      roomTypePathways: this.analyzeRoomTypePathways(engagementJourneys),
      retentionCohorts: this.analyzeRetentionCohorts(engagementJourneys)
    };
  }

  calculateEngagementTrend(timeline) {
    if (timeline.length < 3) return 'insufficient_data';
    
    const firstHalf = timeline.slice(0, Math.floor(timeline.length / 2));
    const secondHalf = timeline.slice(Math.floor(timeline.length / 2));
    
    const firstHalfEngagement = _.mean(firstHalf.map(session => session.duration || 30));
    const secondHalfEngagement = _.mean(secondHalf.map(session => session.duration || 30));
    
    const change = ((secondHalfEngagement - firstHalfEngagement) / firstHalfEngagement) * 100;
    
    if (change > 20) return 'increasing';
    if (change < -20) return 'decreasing';
    return 'stable';
  }

  analyzeRoleEvolution(timeline) {
    const roles = timeline.map(session => session.role);
    const roleProgression = [...new Set(roles)];
    
    return {
      totalRoles: roleProgression.length,
      progression: roleProgression,
      advanced: roleProgression.includes('moderator'),
      consistent: roles.every(role => role === roles[0])
    };
  }

  analyzeRoomTypePathways(engagementJourneys) {
    const pathways = {};
    
    engagementJourneys.forEach(journey => {
      const pathway = `${journey.firstRoomType}_to_${journey.currentRoomType}`;
      pathways[pathway] = (pathways[pathway] || 0) + 1;
    });
    
    return pathways;
  }

  analyzeRetentionCohorts(engagementJourneys) {
    const cohorts = {
      '1_week': engagementJourneys.filter(j => j.journeyLength >= 7).length,
      '1_month': engagementJourneys.filter(j => j.journeyLength >= 30).length,
      '3_months': engagementJourneys.filter(j => j.journeyLength >= 90).length
    };
    
    return {
      cohorts,
      retentionRates: {
        '1_week': this.calculateCompletionRate(engagementJourneys.length, cohorts['1_week']),
        '1_month': this.calculateCompletionRate(engagementJourneys.length, cohorts['1_month']),
        '3_months': this.calculateCompletionRate(engagementJourneys.length, cohorts['3_months'])
      }
    };
  }

  analyzeRetentionPatterns(arenaParticipants, discussionParticipants) {
    // Analyze user retention patterns across room types
    const userSessions = new Map();
    
    [...arenaParticipants, ...discussionParticipants].forEach(participant => {
      const userId = participant.userId;
      const sessionDate = new Date(participant.joinedAt || participant.createdAt);
      
      if (!userSessions.has(userId)) {
        userSessions.set(userId, []);
      }
      
      userSessions.get(userId).push({
        date: sessionDate,
        roomType: this.determineRoomType(participant)
      });
    });

    // Calculate retention metrics
    const retentionAnalysis = Array.from(userSessions.entries()).map(([userId, sessions]) => {
      sessions.sort((a, b) => a.date - b.date);
      
      const daysBetweenSessions = [];
      for (let i = 1; i < sessions.length; i++) {
        const days = DateHelpers.calculateDuration(sessions[i-1].date, sessions[i].date).days;
        daysBetweenSessions.push(days);
      }
      
      return {
        userId,
        totalSessions: sessions.length,
        averageDaysBetween: daysBetweenSessions.length > 0 ? _.mean(daysBetweenSessions) : null,
        longestGap: daysBetweenSessions.length > 0 ? Math.max(...daysBetweenSessions) : null,
        retentionScore: this.calculateUserRetentionScore(sessions),
        roomTypeConsistency: this.calculateRoomTypeConsistency(sessions)
      };
    });

    return {
      totalUsers: retentionAnalysis.length,
      averageRetentionScore: _.mean(retentionAnalysis.map(r => r.retentionScore)),
      retentionDistribution: {
        high: retentionAnalysis.filter(r => r.retentionScore >= 80).length,
        medium: retentionAnalysis.filter(r => r.retentionScore >= 50 && r.retentionScore < 80).length,
        low: retentionAnalysis.filter(r => r.retentionScore < 50).length
      },
      averageDaysBetweenSessions: _.mean(retentionAnalysis.filter(r => r.averageDaysBetween).map(r => r.averageDaysBetween)),
      churnRisk: retentionAnalysis.filter(r => r.longestGap > 14).length
    };
  }

  calculateUserRetentionScore(sessions) {
    if (sessions.length <= 1) return 0;
    
    let score = 0;
    
    // Frequency bonus
    score += Math.min(50, sessions.length * 5);
    
    // Consistency bonus (regular intervals)
    const intervals = [];
    for (let i = 1; i < sessions.length; i++) {
      intervals.push(DateHelpers.calculateDuration(sessions[i-1].date, sessions[i].date).days);
    }
    
    if (intervals.length > 0) {
      const avgInterval = _.mean(intervals);
      const intervalConsistency = 1 - (Math.sqrt(_.mean(intervals.map(i => Math.pow(i - avgInterval, 2)))) / avgInterval);
      score += Math.max(0, intervalConsistency * 30);
    }
    
    // Recency bonus
    const daysSinceLastSession = DateHelpers.calculateDuration(sessions[sessions.length - 1].date, new Date()).days;
    if (daysSinceLastSession <= 7) score += 20;
    else if (daysSinceLastSession <= 14) score += 10;
    
    return Math.min(100, score);
  }

  calculateRoomTypeConsistency(sessions) {
    const roomTypes = sessions.map(s => s.roomType);
    const uniqueTypes = [...new Set(roomTypes)];
    
    return 100 - ((uniqueTypes.length - 1) * 25); // Penalty for switching room types
  }

  analyzeUserLifecycle(arenaParticipants, discussionParticipants, users) {
    // Analyze complete user lifecycle from onboarding to potential churn
    const userLifecycles = new Map();
    
    users.forEach(user => {
      userLifecycles.set(user.$id, {
        userId: user.$id,
        registrationDate: new Date(user.createdAt),
        profileCompleteness: this.calculateProfileCompleteness(user),
        firstSession: null,
        lastSession: null,
        totalSessions: 0,
        lifecycleStage: 'registered',
        daysSinceRegistration: DateHelpers.calculateDuration(user.createdAt, new Date()).days,
        activationEvents: []
      });
    });

    // Add session data
    [...arenaParticipants, ...discussionParticipants].forEach(participant => {
      const userId = participant.userId;
      const lifecycle = userLifecycles.get(userId);
      
      if (lifecycle) {
        const sessionDate = new Date(participant.joinedAt || participant.createdAt);
        lifecycle.totalSessions++;
        
        if (!lifecycle.firstSession || sessionDate < lifecycle.firstSession) {
          lifecycle.firstSession = sessionDate;
        }
        if (!lifecycle.lastSession || sessionDate > lifecycle.lastSession) {
          lifecycle.lastSession = sessionDate;
        }
        
        // Track activation events
        if (participant.role === 'speaker') {
          lifecycle.activationEvents.push('first_speak');
        }
        if (participant.role === 'moderator') {
          lifecycle.activationEvents.push('first_moderate');
        }
      }
    });

    // Determine lifecycle stages
    userLifecycles.forEach((lifecycle, userId) => {
      lifecycle.activationEvents = [...new Set(lifecycle.activationEvents)];
      lifecycle.daysSinceFirstSession = lifecycle.firstSession ? 
        DateHelpers.calculateDuration(lifecycle.firstSession, new Date()).days : null;
      lifecycle.daysSinceLastSession = lifecycle.lastSession ? 
        DateHelpers.calculateDuration(lifecycle.lastSession, new Date()).days : null;
      
      lifecycle.lifecycleStage = this.determineLifecycleStage(lifecycle);
    });

    const lifecycles = Array.from(userLifecycles.values());
    
    return {
      totalUsers: lifecycles.length,
      stageDistribution: _.countBy(lifecycles, 'lifecycleStage'),
      averageDaysToActivation: _.mean(lifecycles.filter(l => l.firstSession).map(l => 
        DateHelpers.calculateDuration(l.registrationDate, l.firstSession).days
      )),
      activationRate: this.calculateCompletionRate(
        lifecycles.length,
        lifecycles.filter(l => l.totalSessions > 0).length
      ),
      churnRate: this.calculateCompletionRate(
        lifecycles.filter(l => l.totalSessions > 0).length,
        lifecycles.filter(l => l.daysSinceLastSession > 30).length
      ),
      lifecycleMetrics: this.calculateLifecycleMetrics(lifecycles)
    };
  }

  determineLifecycleStage(lifecycle) {
    if (lifecycle.totalSessions === 0) return 'inactive';
    if (lifecycle.daysSinceLastSession > 30) return 'churned';
    if (lifecycle.daysSinceLastSession > 14) return 'at_risk';
    if (lifecycle.totalSessions === 1) return 'new';
    if (lifecycle.activationEvents.length === 0) return 'exploring';
    if (lifecycle.activationEvents.includes('first_moderate')) return 'power_user';
    if (lifecycle.activationEvents.includes('first_speak')) return 'engaged';
    return 'active';
  }

  calculateLifecycleMetrics(lifecycles) {
    const stages = _.groupBy(lifecycles, 'lifecycleStage');
    
    return Object.keys(stages).map(stage => {
      const stageUsers = stages[stage];
      
      return {
        stage,
        count: stageUsers.length,
        averageSessions: _.mean(stageUsers.map(u => u.totalSessions)),
        averageProfileCompleteness: _.mean(stageUsers.map(u => u.profileCompleteness)),
        averageDaysSinceRegistration: _.mean(stageUsers.map(u => u.daysSinceRegistration))
      };
    });
  }

  analyzeConversionFunnels(arenaParticipants, discussionParticipants) {
    // Analyze conversion funnels across different user actions
    const userActions = new Map();
    
    [...arenaParticipants, ...discussionParticipants].forEach(participant => {
      const userId = participant.userId;
      if (!userActions.has(userId)) {
        userActions.set(userId, {
          participated: true,
          spoke: false,
          moderated: false,
          multiRoomTypes: false,
          roomTypes: new Set()
        });
      }
      
      const actions = userActions.get(userId);
      actions.roomTypes.add(this.determineRoomType(participant));
      
      if (participant.role === 'speaker') actions.spoke = true;
      if (participant.role === 'moderator') actions.moderated = true;
      if (actions.roomTypes.size > 1) actions.multiRoomTypes = true;
    });

    const totalUsers = userActions.size;
    const conversions = Array.from(userActions.values());

    return {
      totalUsers,
      conversionRates: {
        participation: 100, // All users in this analysis have participated
        speaking: this.calculateCompletionRate(totalUsers, conversions.filter(c => c.spoke).length),
        moderating: this.calculateCompletionRate(totalUsers, conversions.filter(c => c.moderated).length),
        multiRoom: this.calculateCompletionRate(totalUsers, conversions.filter(c => c.multiRoomTypes).length)
      },
      funnelAnalysis: {
        step1_participate: totalUsers,
        step2_speak: conversions.filter(c => c.spoke).length,
        step3_moderate: conversions.filter(c => c.moderated).length,
        step4_multiRoom: conversions.filter(c => c.multiRoomTypes).length
      }
    };
  }

  analyzeDemographicInsights(arenaParticipants, discussionParticipants, users) {
    const userMap = new Map(users.map(user => [user.$id, user]));
    const participantUsers = [...new Set([...arenaParticipants, ...discussionParticipants].map(p => p.userId))];
    
    const demographicData = participantUsers.map(userId => {
      const user = userMap.get(userId);
      const userParticipations = [...arenaParticipants, ...discussionParticipants].filter(p => p.userId === userId);
      
      return {
        userId,
        ageGroup: user ? this.calculateAgeGroup(user.dateOfBirth) : 'unknown',
        country: user?.country || 'unknown',
        profileCompleteness: user ? this.calculateProfileCompleteness(user) : 0,
        totalParticipations: userParticipations.length,
        roomTypePreferences: this.calculateUserRoomTypePreferences(userParticipations),
        roleHistory: userParticipations.map(p => p.role || 'participant')
      };
    });

    return {
      totalUsers: demographicData.length,
      ageGroupDistribution: _.countBy(demographicData, 'ageGroup'),
      countryDistribution: _.countBy(demographicData, 'country'),
      ageGroupPreferences: this.analyzeAgeGroupPreferences(demographicData),
      countryPreferences: this.analyzeCountryPreferences(demographicData),
      profileCompletenessImpact: this.analyzeProfileCompletenessImpact(demographicData)
    };
  }

  calculateUserRoomTypePreferences(participations) {
    const roomTypeCounts = _.countBy(participations, p => this.determineRoomType(p));
    const total = participations.length;
    
    return {
      arena: (roomTypeCounts.arena || 0) / total * 100,
      discussion: (roomTypeCounts.discussion || 0) / total * 100,
      open_discussion: (roomTypeCounts.open_discussion || 0) / total * 100
    };
  }

  analyzeAgeGroupPreferences(demographicData) {
    const ageGroups = _.groupBy(demographicData.filter(d => d.ageGroup !== 'unknown'), 'ageGroup');
    
    return Object.keys(ageGroups).map(ageGroup => {
      const group = ageGroups[ageGroup];
      
      return {
        ageGroup,
        count: group.length,
        averageParticipations: _.mean(group.map(g => g.totalParticipations)),
        roomTypePreferences: {
          arena: _.mean(group.map(g => g.roomTypePreferences.arena)),
          discussion: _.mean(group.map(g => g.roomTypePreferences.discussion)),
          open_discussion: _.mean(group.map(g => g.roomTypePreferences.open_discussion))
        }
      };
    });
  }

  analyzeCountryPreferences(demographicData) {
    const countries = _.groupBy(demographicData.filter(d => d.country !== 'unknown'), 'country');
    
    return Object.keys(countries)
      .map(country => {
        const group = countries[country];
        
        return {
          country,
          count: group.length,
          averageParticipations: _.mean(group.map(g => g.totalParticipations)),
          roomTypePreferences: {
            arena: _.mean(group.map(g => g.roomTypePreferences.arena)),
            discussion: _.mean(group.map(g => g.roomTypePreferences.discussion)),
            open_discussion: _.mean(group.map(g => g.roomTypePreferences.open_discussion))
          }
        };
      })
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);
  }

  analyzeProfileCompletenessImpact(demographicData) {
    const byCompleteness = _.groupBy(demographicData, d => {
      if (d.profileCompleteness >= 80) return 'complete';
      if (d.profileCompleteness >= 50) return 'partial';
      return 'minimal';
    });
    
    return Object.keys(byCompleteness).map(level => {
      const group = byCompleteness[level];
      
      return {
        completenessLevel: level,
        count: group.length,
        averageParticipations: _.mean(group.map(g => g.totalParticipations)),
        averageProfileCompleteness: _.mean(group.map(g => g.profileCompleteness))
      };
    });
  }

  /**
   * Generate User Journey specific insights
   */
  generateUserJourneyInsights(analysis) {
    const insights = [];

    // Cross-room movement insights
    if (analysis.crossRoomMovement.crossRoomEngagement.singleRoomUsers / analysis.crossRoomMovement.totalUsers > 0.7) {
      insights.push({
        type: 'warning',
        category: 'cross_room_engagement',
        message: `${Math.round((analysis.crossRoomMovement.crossRoomEngagement.singleRoomUsers / analysis.crossRoomMovement.totalUsers) * 100)}% of users stick to single room type`,
        priority: 'medium',
        suggestion: 'Implement cross-room recommendations and onboarding'
      });
    }

    // Role progression insights
    if (analysis.roleProgression.progressionStats.moderatorConversionRate < 10) {
      insights.push({
        type: 'warning',
        category: 'role_progression',
        message: `Low moderator conversion rate (${analysis.roleProgression.progressionStats.moderatorConversionRate}%)`,
        priority: 'high',
        suggestion: 'Improve moderator onboarding and incentives'
      });
    }

    // User segmentation insights
    const atRiskUsers = analysis.userSegmentation.atRiskUsers;
    if (atRiskUsers > analysis.userSegmentation.totalUsers * 0.2) {
      insights.push({
        type: 'critical',
        category: 'retention',
        message: `High number of at-risk users (${atRiskUsers})`,
        priority: 'critical',
        suggestion: 'Implement re-engagement campaigns and retention strategies'
      });
    }

    // Engagement journey insights
    if (analysis.engagementJourney.engagementTrends.decreasing > analysis.engagementJourney.engagementTrends.increasing) {
      insights.push({
        type: 'warning',
        category: 'engagement_trend',
        message: 'More users showing decreasing engagement than increasing',
        priority: 'high',
        suggestion: 'Focus on mid-journey engagement and value delivery'
      });
    }

    return insights;
  }
}