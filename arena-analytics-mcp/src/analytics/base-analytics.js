import _ from 'lodash';
import { DateHelpers } from '../utils/date-helpers.js';

export class BaseAnalytics {
  constructor(appwriteClient) {
    this.db = appwriteClient;
  }

  /**
   * Calculate completion rate
   */
  calculateCompletionRate(total, completed) {
    if (total === 0) return 0;
    return Math.round((completed / total) * 100);
  }

  /**
   * Calculate average duration
   */
  calculateAverageDuration(durations) {
    if (durations.length === 0) return 0;
    const sum = durations.reduce((acc, duration) => acc + duration, 0);
    return Math.round(sum / durations.length);
  }

  /**
   * Calculate percentiles
   */
  calculatePercentiles(values, percentiles = [25, 50, 75, 90, 95]) {
    if (values.length === 0) return {};
    
    const sorted = [...values].sort((a, b) => a - b);
    const result = {};
    
    percentiles.forEach(p => {
      const index = Math.ceil((p / 100) * sorted.length) - 1;
      result[`p${p}`] = sorted[Math.max(0, index)];
    });
    
    return result;
  }

  /**
   * Detect outliers using IQR method
   */
  detectOutliers(values) {
    if (values.length < 4) return { outliers: [], cleanValues: values };
    
    const sorted = [...values].sort((a, b) => a - b);
    const q1Index = Math.floor(sorted.length * 0.25);
    const q3Index = Math.floor(sorted.length * 0.75);
    
    const q1 = sorted[q1Index];
    const q3 = sorted[q3Index];
    const iqr = q3 - q1;
    
    const lowerBound = q1 - (1.5 * iqr);
    const upperBound = q3 + (1.5 * iqr);
    
    const outliers = values.filter(v => v < lowerBound || v > upperBound);
    const cleanValues = values.filter(v => v >= lowerBound && v <= upperBound);
    
    return { outliers, cleanValues, bounds: { lower: lowerBound, upper: upperBound } };
  }

  /**
   * Calculate trend over time periods
   */
  calculateTrend(data, dateField = 'createdAt', period = 'day') {
    const grouped = DateHelpers.groupByPeriod(data, dateField, period);
    const sortedPeriods = Object.keys(grouped).sort();
    
    const trend = sortedPeriods.map(period => ({
      period,
      count: grouped[period].length,
      data: grouped[period]
    }));
    
    // Calculate growth rate
    if (trend.length > 1) {
      for (let i = 1; i < trend.length; i++) {
        const current = trend[i].count;
        const previous = trend[i - 1].count;
        trend[i].growthRate = previous === 0 ? 0 : Math.round(((current - previous) / previous) * 100);
      }
    }
    
    return trend;
  }

  /**
   * Generate insights based on data patterns
   */
  generateInsights(data, thresholds = {}) {
    const insights = [];
    const defaultThresholds = {
      lowEngagement: 30,
      highDropout: 50,
      excellentCompletion: 90,
      poorCompletion: 60,
      shortDuration: 300, // 5 minutes
      longDuration: 3600, // 1 hour
      ...thresholds
    };

    // Add specific insights based on patterns
    if (data.completionRate && data.completionRate < defaultThresholds.poorCompletion) {
      insights.push({
        type: 'warning',
        category: 'completion',
        message: `Low completion rate (${data.completionRate}%) may indicate user experience issues`,
        priority: 'high',
        suggestion: 'Review onboarding flow and user friction points'
      });
    }

    if (data.averageDuration && data.averageDuration < defaultThresholds.shortDuration) {
      insights.push({
        type: 'warning',
        category: 'engagement',
        message: `Short average duration (${DateHelpers.formatDuration(data.averageDuration)}) suggests low engagement`,
        priority: 'medium',
        suggestion: 'Analyze content quality and user interest factors'
      });
    }

    if (data.dropoffRate && data.dropoffRate > defaultThresholds.highDropout) {
      insights.push({
        type: 'critical',
        category: 'retention',
        message: `High dropout rate (${data.dropoffRate}%) indicates critical retention issues`,
        priority: 'critical',
        suggestion: 'Immediate investigation of user journey and pain points required'
      });
    }

    return insights;
  }

  /**
   * Calculate statistical summary
   */
  calculateStats(values, label = 'metric') {
    if (values.length === 0) {
      return {
        count: 0,
        mean: 0,
        median: 0,
        min: 0,
        max: 0,
        stdDev: 0,
        percentiles: {}
      };
    }

    const sorted = [...values].sort((a, b) => a - b);
    const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
    const median = sorted[Math.floor(sorted.length / 2)];
    
    // Standard deviation
    const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
    const stdDev = Math.sqrt(variance);

    return {
      count: values.length,
      mean: Math.round(mean * 100) / 100,
      median,
      min: sorted[0],
      max: sorted[sorted.length - 1],
      stdDev: Math.round(stdDev * 100) / 100,
      percentiles: this.calculatePercentiles(values)
    };
  }

  /**
   * Prepare launch readiness metrics
   */
  prepareLaunchMetrics(data) {
    const daysUntilLaunch = DateHelpers.daysUntilLaunch();
    
    return {
      ...data,
      launchReadiness: {
        daysRemaining: daysUntilLaunch,
        criticalIssues: data.insights?.filter(i => i.priority === 'critical') || [],
        warningIssues: data.insights?.filter(i => i.priority === 'high') || [],
        readinessScore: this.calculateReadinessScore(data),
        recommendations: this.generateLaunchRecommendations(data)
      }
    };
  }

  /**
   * Calculate overall readiness score (0-100)
   */
  calculateReadinessScore(data) {
    let score = 100;
    
    // Deduct points for issues
    const criticalIssues = data.insights?.filter(i => i.priority === 'critical').length || 0;
    const highIssues = data.insights?.filter(i => i.priority === 'high').length || 0;
    const mediumIssues = data.insights?.filter(i => i.priority === 'medium').length || 0;
    
    score -= (criticalIssues * 25); // Critical issues: -25 points each
    score -= (highIssues * 10);     // High issues: -10 points each
    score -= (mediumIssues * 5);    // Medium issues: -5 points each
    
    // Factor in completion rates
    if (data.completionRate < 70) score -= 15;
    if (data.completionRate < 50) score -= 20;
    
    return Math.max(0, Math.min(100, score));
  }

  /**
   * Generate launch recommendations
   */
  generateLaunchRecommendations(data) {
    const recommendations = [];
    const daysUntilLaunch = DateHelpers.daysUntilLaunch();
    
    // Critical path recommendations
    if (daysUntilLaunch <= 30) {
      recommendations.push({
        category: 'urgent',
        action: 'Focus on critical bug fixes and stability improvements',
        timeline: 'Next 7 days'
      });
    }
    
    if (data.completionRate < 80) {
      recommendations.push({
        category: 'ux',
        action: 'Optimize user onboarding and reduce friction points',
        timeline: daysUntilLaunch > 14 ? 'Next 2 weeks' : 'Pre-launch priority'
      });
    }
    
    return recommendations;
  }
}