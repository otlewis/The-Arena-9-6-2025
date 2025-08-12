import { Client, Databases, Query } from 'node-appwrite';

export class AppwriteClient {
  constructor() {
    this.client = new Client();
    this.databases = new Databases(this.client);
    this.databaseId = process.env.APPWRITE_DATABASE_ID;
    
    this.client
      .setEndpoint(process.env.APPWRITE_ENDPOINT)
      .setProject(process.env.APPWRITE_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);
  }

  // Collection IDs
  static COLLECTIONS = {
    USERS: 'users',
    ARENA_ROOMS: 'arena_rooms',
    ARENA_PARTICIPANTS: 'arena_participants', 
    ARENA_JUDGMENTS: 'arena_judgments',
    DEBATE_DISCUSSION_ROOMS: 'debate_discussion_rooms',
    DEBATE_DISCUSSION_PARTICIPANTS: 'debate_discussion_participants',
    ROOM_HAND_RAISES: 'room_hand_raises',
    TIMERS: 'timers',
    TIMER_EVENTS: 'timer_events'
  };

  /**
   * Generic query method with pagination and filters
   */
  async queryCollection(collectionId, queries = [], limit = 100, offset = 0) {
    try {
      const queryParams = [
        Query.limit(limit),
        Query.offset(offset),
        ...queries
      ];

      const response = await this.databases.listDocuments(
        this.databaseId,
        collectionId,
        queryParams
      );

      return {
        documents: response.documents,
        total: response.total
      };
    } catch (error) {
      console.error(`Error querying collection ${collectionId}:`, error);
      throw error;
    }
  }

  /**
   * Get documents with date range filter
   */
  async queryByDateRange(collectionId, startDate, endDate, additionalQueries = []) {
    const queries = [
      Query.greaterThanEqual('createdAt', startDate),
      Query.lessThanEqual('createdAt', endDate),
      ...additionalQueries
    ];

    return this.queryCollection(collectionId, queries);
  }

  /**
   * Arena Rooms specific queries
   */
  async getArenaRooms(startDate, endDate, status = null) {
    const queries = [];
    if (status) {
      queries.push(Query.equal('status', status));
    }
    
    return this.queryByDateRange(AppwriteClient.COLLECTIONS.ARENA_ROOMS, startDate, endDate, queries);
  }

  async getArenaParticipants(roomIds = null) {
    const queries = [];
    if (roomIds && roomIds.length > 0) {
      queries.push(Query.equal('roomId', roomIds));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.ARENA_PARTICIPANTS, queries);
  }

  async getArenaJudgments(roomIds = null) {
    const queries = [];
    if (roomIds && roomIds.length > 0) {
      queries.push(Query.equal('roomId', roomIds));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.ARENA_JUDGMENTS, queries);
  }

  /**
   * Discussion Rooms specific queries
   */
  async getDiscussionRooms(startDate, endDate, roomType = null, category = null) {
    const queries = [];
    if (roomType) {
      queries.push(Query.equal('roomType', roomType));
    }
    if (category) {
      queries.push(Query.equal('category', category));
    }

    return this.queryByDateRange(AppwriteClient.COLLECTIONS.DEBATE_DISCUSSION_ROOMS, startDate, endDate, queries);
  }

  async getDiscussionParticipants(roomIds = null, role = null) {
    const queries = [];
    if (roomIds && roomIds.length > 0) {
      queries.push(Query.equal('roomId', roomIds));
    }
    if (role) {
      queries.push(Query.equal('role', role));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.DEBATE_DISCUSSION_PARTICIPANTS, queries);
  }

  async getHandRaises(roomIds = null, status = null) {
    const queries = [];
    if (roomIds && roomIds.length > 0) {
      queries.push(Query.equal('roomId', roomIds));
    }
    if (status) {
      queries.push(Query.equal('status', status));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.ROOM_HAND_RAISES, queries);
  }

  /**
   * Timer system queries
   */
  async getTimers(roomIds = null, roomType = null) {
    const queries = [];
    if (roomIds && roomIds.length > 0) {
      queries.push(Query.equal('roomId', roomIds));
    }
    if (roomType) {
      queries.push(Query.equal('roomType', roomType));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.TIMERS, queries);
  }

  async getTimerEvents(timerIds = null, eventType = null) {
    const queries = [];
    if (timerIds && timerIds.length > 0) {
      queries.push(Query.equal('timerId', timerIds));
    }
    if (eventType) {
      queries.push(Query.equal('eventType', eventType));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.TIMER_EVENTS, queries);
  }

  /**
   * User queries
   */
  async getUsers(userIds = null) {
    const queries = [];
    if (userIds && userIds.length > 0) {
      queries.push(Query.equal('$id', userIds));
    }

    return this.queryCollection(AppwriteClient.COLLECTIONS.USERS, queries);
  }

  /**
   * Aggregation helpers
   */
  async getAllDocuments(collectionId, queries = []) {
    let allDocuments = [];
    let offset = 0;
    const limit = 100;
    let hasMore = true;

    while (hasMore) {
      const result = await this.queryCollection(collectionId, queries, limit, offset);
      allDocuments = [...allDocuments, ...result.documents];
      
      hasMore = result.documents.length === limit;
      offset += limit;
    }

    return allDocuments;
  }
}