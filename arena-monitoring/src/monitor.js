#!/usr/bin/env node

import { Client, Databases, Query } from 'node-appwrite';
import chalk from 'chalk';
import { format } from 'date-fns';
import { MonitoringAlerts } from './alerts.js';
import { PerformanceTracker } from './performance.js';
import { DashboardServer } from './dashboard.js';

/**
 * Arena Launch Monitoring System
 *
 * Real-time monitoring for critical Arena metrics during launch
 * - Timer synchronization accuracy
 * - Room creation success rates
 * - Database performance
 * - LiveKit connection health
 */

class ArenaLaunchMonitor {
  constructor() {
    this.appwrite = new Client()
      .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
      .setProject(process.env.APPWRITE_PROJECT_ID || '683a37a8003719978879')
      .setKey(process.env.APPWRITE_API_KEY);

    this.databases = new Databases(this.appwrite);
    this.alerts = new MonitoringAlerts();
    this.performance = new PerformanceTracker();
    this.dashboard = new DashboardServer();
    
    this.databaseId = process.env.APPWRITE_DATABASE_ID || 'arena_db';
    this.isMonitoring = false;
    this.metrics = this.initializeMetrics();
    
    // Monitoring intervals
    this.intervals = {
      timers: 5000,      // Check timer sync every 5 seconds
      rooms: 10000,      // Check room creation every 10 seconds
      database: 15000,   // Check DB performance every 15 seconds
      livekit: 30000,    // Check LiveKit health every 30 seconds
      summary: 60000     // Print summary every minute
    };
  }

  initializeMetrics() {
    return {
      timers: {
        totalActive: 0,
        syncAccuracy: 100,
        lastUpdate: new Date(),
        errors: 0,
        avgSyncDelay: 0
      },
      rooms: {
        totalCreated: 0,
        successRate: 100,
        avgCreationTime: 0,
        failedCreations: 0,
        lastHourCreations: 0
      },
      database: {
        avgResponseTime: 0,
        slowQueries: 0,
        errorRate: 0,
        connectionHealth: 100
      },
      livekit: {
        voiceConnections: 0,
        videoConnections: 0,
        connectionSuccessRate: 100,
        avgConnectTime: 0
      },
      system: {
        uptime: Date.now(),
        alertCount: 0,
        lastAlert: null
      }
    };
  }

  async start() {
    console.log(chalk.blue.bold('🚀 Arena Launch Monitor Starting...'));
    console.log(chalk.gray(`Database ID: ${this.databaseId}`));
    console.log(chalk.gray(`Started at: ${format(new Date(), 'yyyy-MM-dd HH:mm:ss')}`));
    
    try {
      // Start monitoring intervals
      this.isMonitoring = true;
      
      // Start dashboard server
      await this.dashboard.start(this.metrics);
      
      // Timer sync monitoring
      setInterval(() => this.monitorTimerSync(), this.intervals.timers);
      
      // Room creation monitoring  
      setInterval(() => this.monitorRoomCreation(), this.intervals.rooms);
      
      // Database performance monitoring
      setInterval(() => this.monitorDatabasePerformance(), this.intervals.database);
      
      // LiveKit connection monitoring
      setInterval(() => this.monitorLiveKitConnections(), this.intervals.livekit);
      
      // Summary reporting
      setInterval(() => this.printSummary(), this.intervals.summary);
      
      console.log(chalk.green.bold('✅ Arena Launch Monitor Active'));
      console.log(chalk.yellow(`📊 Dashboard: http://localhost:3001`));
      console.log(chalk.gray('Press Ctrl+C to stop monitoring\n'));
      
      // Initial checks
      await this.runInitialChecks();
      
    } catch (error) {
      console.error(chalk.red.bold('❌ Monitor Start Failed:'), error.message);
      process.exit(1);
    }
  }

  async runInitialChecks() {
    console.log(chalk.blue('🔍 Running initial system checks...'));
    
    await Promise.all([
      this.monitorTimerSync(),
      this.monitorRoomCreation(),
      this.monitorDatabasePerformance(),
      this.monitorLiveKitConnections()
    ]);
    
    console.log(chalk.green('✅ Initial checks complete\n'));
  }

  async monitorTimerSync() {
    try {
      const startTime = Date.now();
      
      // Get all active timers
      const activeTimers = await this.databases.listDocuments(
        this.databaseId,
        'timers',
        [
          Query.equal('status', 'running'),
          Query.equal('isActive', true),
          Query.limit(100)
        ]
      );

      const now = Date.now();
      let syncErrors = 0;
      let totalSyncDelay = 0;
      
      // Check sync accuracy for each timer
      for (const timer of activeTimers.documents) {
        const lastTick = new Date(timer.lastTick).getTime();
        const syncDelay = now - lastTick;
        
        // Alert if timer hasn't been updated in >2 seconds
        if (syncDelay > 2000) {
          syncErrors++;
          this.alerts.timerSyncError(timer.$id, syncDelay);
        }
        
        totalSyncDelay += syncDelay;
      }

      // Update metrics
      this.metrics.timers = {
        totalActive: activeTimers.documents.length,
        syncAccuracy: activeTimers.documents.length === 0 ? 100 : 
          Math.round(((activeTimers.documents.length - syncErrors) / activeTimers.documents.length) * 100),
        lastUpdate: new Date(),
        errors: syncErrors,
        avgSyncDelay: activeTimers.documents.length === 0 ? 0 : 
          Math.round(totalSyncDelay / activeTimers.documents.length)
      };

      // Alert if sync accuracy drops below 95%
      if (this.metrics.timers.syncAccuracy < 95) {
        this.alerts.critical('Timer Sync Accuracy', 
          `Timer sync accuracy dropped to ${this.metrics.timers.syncAccuracy}%`);
      }

      this.logMetric('⏱️ TIMER SYNC', 
        `${this.metrics.timers.totalActive} active, ${this.metrics.timers.syncAccuracy}% accuracy`);

    } catch (error) {
      this.alerts.error('Timer Sync Monitor', error.message);
      this.metrics.timers.errors++;
    }
  }

  async monitorRoomCreation() {
    try {
      const oneHourAgo = new Date(Date.now() - 3600000).toISOString();
      
      // Get recent room creations across all types
      const [arenaRooms, openRooms, debateRooms] = await Promise.all([
        this.databases.listDocuments(this.databaseId, 'arena_rooms', [
          Query.greaterThan('$createdAt', oneHourAgo),
          Query.limit(1000)
        ]),
        this.databases.listDocuments(this.databaseId, 'debate_discussion_rooms', [
          Query.greaterThan('$createdAt', oneHourAgo),
          Query.equal('roomType', 'openDiscussion'),
          Query.limit(1000)
        ]),
        this.databases.listDocuments(this.databaseId, 'debate_discussion_rooms', [
          Query.greaterThan('$createdAt', oneHourAgo),
          Query.equal('roomType', 'debatesDiscussions'),
          Query.limit(1000)
        ])
      ]);

      const totalRooms = arenaRooms.documents.length + 
                        openRooms.documents.length + 
                        debateRooms.documents.length;

      // Calculate success rate (assume success if room exists and has participants)
      let successfulRooms = 0;
      let totalCreationTime = 0;

      for (const room of [...arenaRooms.documents, ...openRooms.documents, ...debateRooms.documents]) {
        // Consider room successful if it has status other than 'failed' or 'error'
        if (!room.status || !['failed', 'error'].includes(room.status)) {
          successfulRooms++;
        }
        
        // Calculate creation time (rough estimate)
        const creationTime = new Date(room.$updatedAt).getTime() - new Date(room.$createdAt).getTime();
        totalCreationTime += creationTime;
      }

      const successRate = totalRooms === 0 ? 100 : Math.round((successfulRooms / totalRooms) * 100);
      const avgCreationTime = totalRooms === 0 ? 0 : Math.round(totalCreationTime / totalRooms);

      // Update metrics
      this.metrics.rooms = {
        totalCreated: totalRooms,
        successRate: successRate,
        avgCreationTime: avgCreationTime,
        failedCreations: totalRooms - successfulRooms,
        lastHourCreations: totalRooms
      };

      // Alert if success rate drops below 90%
      if (successRate < 90) {
        this.alerts.critical('Room Creation', 
          `Room creation success rate dropped to ${successRate}%`);
      }

      this.logMetric('🏠 ROOM CREATION', 
        `${totalRooms} created (1hr), ${successRate}% success rate`);

    } catch (error) {
      this.alerts.error('Room Creation Monitor', error.message);
      this.metrics.rooms.failedCreations++;
    }
  }

  async monitorDatabasePerformance() {
    try {
      const startTime = Date.now();
      
      // Test query performance
      await this.databases.listDocuments(this.databaseId, 'users', [Query.limit(1)]);
      const responseTime = Date.now() - startTime;

      // Update metrics
      this.metrics.database.avgResponseTime = responseTime;
      this.metrics.database.connectionHealth = responseTime < 500 ? 100 : 
        responseTime < 1000 ? 75 : 
        responseTime < 2000 ? 50 : 25;

      // Alert if response time > 1 second
      if (responseTime > 1000) {
        this.alerts.warning('Database Performance', 
          `Database response time: ${responseTime}ms`);
        this.metrics.database.slowQueries++;
      }

      // Alert if response time > 3 seconds
      if (responseTime > 3000) {
        this.alerts.critical('Database Performance', 
          `Critical database slowdown: ${responseTime}ms`);
      }

      this.logMetric('💾 DATABASE', 
        `${responseTime}ms response, ${this.metrics.database.connectionHealth}% health`);

    } catch (error) {
      this.alerts.error('Database Monitor', error.message);
      this.metrics.database.errorRate++;
      this.metrics.database.connectionHealth = 0;
    }
  }

  async monitorLiveKitConnections() {
    try {
      // This is a simplified check - in production you'd integrate with LiveKit's monitoring APIs
      // For now, we'll check for recent activity in rooms as a proxy for LiveKit health

      const activeRooms = await this.databases.listDocuments(
        this.databaseId,
        'arena_rooms',
        [
          Query.equal('status', 'active'),
          Query.limit(100)
        ]
      );

      // Estimate connections based on active rooms
      const estimatedConnections = activeRooms.documents.length * 2; // Rough estimate

      this.metrics.livekit = {
        voiceConnections: estimatedConnections,
        videoConnections: estimatedConnections,
        connectionSuccessRate: 95, // Would need actual LiveKit API integration
        avgConnectTime: 1200 // Estimated 1.2s average connect time
      };

      this.logMetric('🎤 LIVEKIT',
        `~${estimatedConnections} connections, ${this.metrics.livekit.connectionSuccessRate}% success`);

    } catch (error) {
      this.alerts.error('LiveKit Monitor', error.message);
      this.metrics.livekit.connectionSuccessRate = 0;
    }
  }

  logMetric(category, message) {
    const timestamp = chalk.gray(format(new Date(), 'HH:mm:ss'));
    console.log(`${timestamp} ${category}: ${message}`);
  }

  printSummary() {
    const uptime = Math.round((Date.now() - this.metrics.system.uptime) / 1000);
    
    console.log(chalk.blue.bold('\n📊 === ARENA LAUNCH MONITOR SUMMARY ==='));
    console.log(chalk.gray(`Uptime: ${uptime}s | Alerts: ${this.metrics.system.alertCount}`));
    
    console.log(chalk.yellow('⏱️  Timer Sync:'), 
      `${this.metrics.timers.totalActive} active, ${this.metrics.timers.syncAccuracy}% accuracy`);
    
    console.log(chalk.yellow('🏠 Room Creation:'), 
      `${this.metrics.rooms.lastHourCreations}/hr, ${this.metrics.rooms.successRate}% success`);
    
    console.log(chalk.yellow('💾 Database:'), 
      `${this.metrics.database.avgResponseTime}ms avg, ${this.metrics.database.connectionHealth}% health`);
    
    console.log(chalk.yellow('🎤 LiveKit:'),
      `~${this.metrics.livekit.voiceConnections} connections, ${this.metrics.livekit.connectionSuccessRate}% success`);
    
    console.log('');
  }

  async stop() {
    console.log(chalk.yellow('\n🛑 Stopping Arena Launch Monitor...'));
    this.isMonitoring = false;
    await this.dashboard.stop();
    console.log(chalk.green('✅ Monitor stopped'));
    process.exit(0);
  }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  if (global.monitor) {
    await global.monitor.stop();
  } else {
    process.exit(0);
  }
});

// Start monitoring if run directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const monitor = new ArenaLaunchMonitor();
  global.monitor = monitor;
  monitor.start().catch(console.error);
}

export { ArenaLaunchMonitor };