/**
 * Performance Tracking and Analysis for Arena Launch
 * 
 * Tracks detailed performance metrics and identifies bottlenecks
 */

export class PerformanceTracker {
  constructor() {
    this.metrics = {
      responseTimeHistory: [],
      errorRateHistory: [],
      throughputHistory: [],
      userLoadHistory: []
    };
    
    this.thresholds = {
      responseTime: {
        excellent: 200,
        good: 500,
        warning: 1000,
        critical: 2000
      },
      errorRate: {
        excellent: 0.1,
        good: 0.5,
        warning: 1.0,
        critical: 2.0
      },
      availability: {
        excellent: 99.9,
        good: 99.5,
        warning: 99.0,
        critical: 98.0
      }
    };
  }

  recordResponseTime(operation, duration) {
    const timestamp = Date.now();
    this.metrics.responseTimeHistory.push({
      timestamp,
      operation,
      duration,
      status: this.getPerformanceStatus(duration, 'responseTime')
    });
    
    // Keep only last 1000 entries
    if (this.metrics.responseTimeHistory.length > 1000) {
      this.metrics.responseTimeHistory = this.metrics.responseTimeHistory.slice(-1000);
    }
  }

  recordError(operation, errorType) {
    const timestamp = Date.now();
    this.metrics.errorRateHistory.push({
      timestamp,
      operation,
      errorType,
      severity: this.getErrorSeverity(errorType)
    });
    
    // Keep only last 1000 entries
    if (this.metrics.errorRateHistory.length > 1000) {
      this.metrics.errorRateHistory = this.metrics.errorRateHistory.slice(-1000);
    }
  }

  recordThroughput(operation, count, duration) {
    const timestamp = Date.now();
    const throughput = count / (duration / 1000); // operations per second
    
    this.metrics.throughputHistory.push({
      timestamp,
      operation,
      count,
      duration,
      throughput
    });
    
    // Keep only last 1000 entries
    if (this.metrics.throughputHistory.length > 1000) {
      this.metrics.throughputHistory = this.metrics.throughputHistory.slice(-1000);
    }
  }

  recordUserLoad(userCount, activeRooms) {
    const timestamp = Date.now();
    this.metrics.userLoadHistory.push({
      timestamp,
      userCount,
      activeRooms,
      avgUsersPerRoom: activeRooms > 0 ? userCount / activeRooms : 0
    });
    
    // Keep only last 1000 entries
    if (this.metrics.userLoadHistory.length > 1000) {
      this.metrics.userLoadHistory = this.metrics.userLoadHistory.slice(-1000);
    }
  }

  getPerformanceStatus(value, metric) {
    const thresholds = this.thresholds[metric];
    if (!thresholds) return 'unknown';
    
    if (value <= thresholds.excellent) return 'excellent';
    if (value <= thresholds.good) return 'good';
    if (value <= thresholds.warning) return 'warning';
    return 'critical';
  }

  getErrorSeverity(errorType) {
    const criticalErrors = [
      'database_connection_failed',
      'timer_sync_failed',
      'agora_connection_failed',
      'authentication_failed'
    ];
    
    const warningErrors = [
      'slow_query',
      'timeout',
      'rate_limit_exceeded',
      'room_creation_delayed'
    ];
    
    if (criticalErrors.includes(errorType)) return 'critical';
    if (warningErrors.includes(errorType)) return 'warning';
    return 'info';
  }

  // Analysis methods
  getAverageResponseTime(operation = null, timeWindowMs = 300000) { // 5 minutes
    const cutoff = Date.now() - timeWindowMs;
    const relevantMetrics = this.metrics.responseTimeHistory
      .filter(m => m.timestamp > cutoff)
      .filter(m => !operation || m.operation === operation);
    
    if (relevantMetrics.length === 0) return 0;
    
    const total = relevantMetrics.reduce((sum, m) => sum + m.duration, 0);
    return Math.round(total / relevantMetrics.length);
  }

  getErrorRate(operation = null, timeWindowMs = 300000) { // 5 minutes
    const cutoff = Date.now() - timeWindowMs;
    const relevantErrors = this.metrics.errorRateHistory
      .filter(m => m.timestamp > cutoff)
      .filter(m => !operation || m.operation === operation);
    
    const relevantOperations = this.metrics.responseTimeHistory
      .filter(m => m.timestamp > cutoff)
      .filter(m => !operation || m.operation === operation);
    
    if (relevantOperations.length === 0) return 0;
    
    return (relevantErrors.length / relevantOperations.length) * 100;
  }

  getThroughput(operation = null, timeWindowMs = 300000) { // 5 minutes
    const cutoff = Date.now() - timeWindowMs;
    const relevantMetrics = this.metrics.throughputHistory
      .filter(m => m.timestamp > cutoff)
      .filter(m => !operation || m.operation === operation);
    
    if (relevantMetrics.length === 0) return 0;
    
    const total = relevantMetrics.reduce((sum, m) => sum + m.throughput, 0);
    return Math.round((total / relevantMetrics.length) * 100) / 100;
  }

  getCurrentUserLoad() {
    if (this.metrics.userLoadHistory.length === 0) return null;
    
    return this.metrics.userLoadHistory[this.metrics.userLoadHistory.length - 1];
  }

  // Performance analysis and recommendations
  analyzePerformance(timeWindowMs = 300000) { // 5 minutes
    const analysis = {
      timestamp: new Date(),
      timeWindow: timeWindowMs,
      metrics: {},
      issues: [],
      recommendations: []
    };

    // Analyze response times
    const avgResponseTime = this.getAverageResponseTime(null, timeWindowMs);
    analysis.metrics.avgResponseTime = avgResponseTime;
    analysis.metrics.responseTimeStatus = this.getPerformanceStatus(avgResponseTime, 'responseTime');
    
    if (avgResponseTime > this.thresholds.responseTime.warning) {
      analysis.issues.push({
        type: 'performance',
        severity: avgResponseTime > this.thresholds.responseTime.critical ? 'critical' : 'warning',
        message: `Average response time is ${avgResponseTime}ms`,
        recommendation: 'Investigate database queries and optimize slow operations'
      });
    }

    // Analyze error rates
    const errorRate = this.getErrorRate(null, timeWindowMs);
    analysis.metrics.errorRate = errorRate;
    analysis.metrics.errorRateStatus = this.getPerformanceStatus(errorRate, 'errorRate');
    
    if (errorRate > this.thresholds.errorRate.warning) {
      analysis.issues.push({
        type: 'reliability',
        severity: errorRate > this.thresholds.errorRate.critical ? 'critical' : 'warning',
        message: `Error rate is ${errorRate.toFixed(2)}%`,
        recommendation: 'Review error logs and implement additional error handling'
      });
    }

    // Analyze throughput
    const throughput = this.getThroughput(null, timeWindowMs);
    analysis.metrics.throughput = throughput;
    
    // Analyze user load
    const currentLoad = this.getCurrentUserLoad();
    if (currentLoad) {
      analysis.metrics.userLoad = currentLoad;
      
      if (currentLoad.avgUsersPerRoom < 2) {
        analysis.recommendations.push('Consider promoting rooms with low participation');
      }
      
      if (currentLoad.userCount > 1000) {
        analysis.recommendations.push('Monitor system resources closely under high load');
      }
    }

    return analysis;
  }

  // Performance health score (0-100)
  getPerformanceHealthScore(timeWindowMs = 300000) {
    let score = 100;
    
    // Response time impact (40% weight)
    const avgResponseTime = this.getAverageResponseTime(null, timeWindowMs);
    if (avgResponseTime > this.thresholds.responseTime.excellent) score -= 10;
    if (avgResponseTime > this.thresholds.responseTime.good) score -= 15;
    if (avgResponseTime > this.thresholds.responseTime.warning) score -= 20;
    if (avgResponseTime > this.thresholds.responseTime.critical) score -= 30;
    
    // Error rate impact (35% weight)
    const errorRate = this.getErrorRate(null, timeWindowMs);
    if (errorRate > this.thresholds.errorRate.excellent) score -= 8;
    if (errorRate > this.thresholds.errorRate.good) score -= 12;
    if (errorRate > this.thresholds.errorRate.warning) score -= 18;
    if (errorRate > this.thresholds.errorRate.critical) score -= 25;
    
    // Recent critical errors impact (25% weight)
    const recentCriticalErrors = this.metrics.errorRateHistory
      .filter(e => e.timestamp > (Date.now() - timeWindowMs))
      .filter(e => e.severity === 'critical').length;
    
    score -= Math.min(20, recentCriticalErrors * 5);
    
    return Math.max(0, Math.min(100, score));
  }

  // Reset metrics (useful for testing)
  reset() {
    this.metrics = {
      responseTimeHistory: [],
      errorRateHistory: [],
      throughputHistory: [],
      userLoadHistory: []
    };
  }

  // Export metrics for external analysis
  exportMetrics(timeWindowMs = null) {
    if (!timeWindowMs) {
      return { ...this.metrics };
    }
    
    const cutoff = Date.now() - timeWindowMs;
    return {
      responseTimeHistory: this.metrics.responseTimeHistory.filter(m => m.timestamp > cutoff),
      errorRateHistory: this.metrics.errorRateHistory.filter(m => m.timestamp > cutoff),
      throughputHistory: this.metrics.throughputHistory.filter(m => m.timestamp > cutoff),
      userLoadHistory: this.metrics.userLoadHistory.filter(m => m.timestamp > cutoff)
    };
  }
}