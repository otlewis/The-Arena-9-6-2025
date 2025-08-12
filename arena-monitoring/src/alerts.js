import chalk from 'chalk';
import { format } from 'date-fns';
import nodemailer from 'nodemailer';

/**
 * Arena Launch Monitoring Alerts System
 * 
 * Handles different alert levels and notification methods
 */

export class MonitoringAlerts {
  constructor() {
    this.alertCounts = {
      critical: 0,
      warning: 0,
      error: 0,
      info: 0
    };
    
    this.lastAlerts = {
      timerSync: null,
      roomCreation: null,
      database: null,
      agora: null
    };
    
    this.setupEmailAlerts();
    this.alertHistory = [];
  }

  setupEmailAlerts() {
    // Configure email notifications (optional)
    if (process.env.SMTP_HOST && process.env.ALERT_EMAIL) {
      this.emailTransporter = nodemailer.createTransporter({
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT || 587,
        secure: false,
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS
        }
      });
    }
  }

  critical(category, message) {
    const alert = this.createAlert('CRITICAL', category, message);
    console.log(chalk.red.bold('🚨 CRITICAL ALERT:'), chalk.red(`${category}: ${message}`));
    this.alertCounts.critical++;
    this.sendEmailAlert(alert);
    this.logToHistory(alert);
  }

  warning(category, message) {
    const alert = this.createAlert('WARNING', category, message);
    console.log(chalk.yellow.bold('⚠️  WARNING:'), chalk.yellow(`${category}: ${message}`));
    this.alertCounts.warning++;
    this.logToHistory(alert);
  }

  error(category, message) {
    const alert = this.createAlert('ERROR', category, message);
    console.log(chalk.red.bold('❌ ERROR:'), chalk.red(`${category}: ${message}`));
    this.alertCounts.error++;
    this.logToHistory(alert);
  }

  info(category, message) {
    const alert = this.createAlert('INFO', category, message);
    console.log(chalk.blue.bold('ℹ️  INFO:'), chalk.blue(`${category}: ${message}`));
    this.alertCounts.info++;
    this.logToHistory(alert);
  }

  // Specific alert methods for common scenarios
  timerSyncError(timerId, syncDelay) {
    // Rate limit timer sync alerts (max 1 per minute per timer)
    const alertKey = `timer_${timerId}`;
    if (this.isRateLimited(alertKey, 60000)) return;
    
    this.warning('Timer Sync', 
      `Timer ${timerId} sync delay: ${syncDelay}ms`);
  }

  roomCreationFailure(roomType, errorMessage) {
    this.error('Room Creation', 
      `Failed to create ${roomType} room: ${errorMessage}`);
  }

  databaseSlowQuery(queryTime) {
    // Rate limit database alerts (max 1 per 30 seconds)
    if (this.isRateLimited('database_slow', 30000)) return;
    
    this.warning('Database Performance', 
      `Slow query detected: ${queryTime}ms`);
  }

  agoraConnectionFailure(connectionType, errorMessage) {
    this.error('Agora Connection', 
      `${connectionType} connection failed: ${errorMessage}`);
  }

  launchMetricsAlert(metric, value, threshold) {
    this.critical('Launch Metrics', 
      `${metric} (${value}) below threshold (${threshold})`);
  }

  createAlert(level, category, message) {
    return {
      id: Date.now().toString(),
      level,
      category,
      message,
      timestamp: new Date(),
      acknowledged: false
    };
  }

  isRateLimited(key, intervalMs) {
    const now = Date.now();
    const lastAlert = this.lastAlerts[key];
    
    if (lastAlert && (now - lastAlert) < intervalMs) {
      return true;
    }
    
    this.lastAlerts[key] = now;
    return false;
  }

  logToHistory(alert) {
    this.alertHistory.unshift(alert);
    
    // Keep only last 100 alerts
    if (this.alertHistory.length > 100) {
      this.alertHistory = this.alertHistory.slice(0, 100);
    }
  }

  async sendEmailAlert(alert) {
    if (!this.emailTransporter || !process.env.ALERT_EMAIL) return;
    
    try {
      const subject = `🚨 Arena Launch Alert: ${alert.category}`;
      const html = this.formatEmailAlert(alert);
      
      await this.emailTransporter.sendMail({
        from: process.env.SMTP_FROM || 'noreply@arena.app',
        to: process.env.ALERT_EMAIL,
        subject,
        html
      });
      
      console.log(chalk.gray('📧 Email alert sent'));
      
    } catch (error) {
      console.error(chalk.red('Failed to send email alert:'), error.message);
    }
  }

  formatEmailAlert(alert) {
    const timestamp = format(alert.timestamp, 'yyyy-MM-dd HH:mm:ss');
    
    return `
      <h2 style="color: #dc3545;">🚨 Arena Launch Alert</h2>
      <p><strong>Level:</strong> ${alert.level}</p>
      <p><strong>Category:</strong> ${alert.category}</p>
      <p><strong>Message:</strong> ${alert.message}</p>
      <p><strong>Time:</strong> ${timestamp}</p>
      <hr>
      <p><em>Arena Launch Monitoring System</em></p>
    `;
  }

  // Dashboard data methods
  getAlertCounts() {
    return this.alertCounts;
  }

  getRecentAlerts(limit = 20) {
    return this.alertHistory.slice(0, limit);
  }

  acknowledgeAlert(alertId) {
    const alert = this.alertHistory.find(a => a.id === alertId);
    if (alert) {
      alert.acknowledged = true;
      this.info('Alert Management', `Alert ${alertId} acknowledged`);
    }
  }

  clearAlerts() {
    this.alertHistory = [];
    this.alertCounts = {
      critical: 0,
      warning: 0,
      error: 0,
      info: 0
    };
    this.info('Alert Management', 'Alert history cleared');
  }

  // Health check based on recent alerts
  getSystemHealthScore() {
    const recentAlerts = this.alertHistory
      .filter(alert => Date.now() - alert.timestamp.getTime() < 300000); // Last 5 minutes
    
    const criticalAlerts = recentAlerts.filter(a => a.level === 'CRITICAL').length;
    const warningAlerts = recentAlerts.filter(a => a.level === 'WARNING').length;
    const errorAlerts = recentAlerts.filter(a => a.level === 'ERROR').length;
    
    // Calculate health score
    let healthScore = 100;
    healthScore -= (criticalAlerts * 25); // Critical alerts -25 each
    healthScore -= (errorAlerts * 10);    // Error alerts -10 each  
    healthScore -= (warningAlerts * 5);   // Warning alerts -5 each
    
    return Math.max(0, healthScore);
  }
}