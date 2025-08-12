import { 
  subDays, 
  subWeeks, 
  subMonths, 
  startOfDay, 
  endOfDay, 
  format,
  parseISO,
  differenceInMinutes,
  differenceInHours,
  differenceInDays
} from 'date-fns';

export class DateHelpers {
  /**
   * Get date range for common periods
   */
  static getDateRange(period = 'week') {
    const now = new Date();
    let startDate, endDate;

    switch (period) {
      case 'day':
        startDate = startOfDay(now);
        endDate = endOfDay(now);
        break;
      case 'week':
        startDate = startOfDay(subWeeks(now, 1));
        endDate = endOfDay(now);
        break;
      case 'month':
        startDate = startOfDay(subMonths(now, 1));
        endDate = endOfDay(now);
        break;
      case '3months':
        startDate = startOfDay(subMonths(now, 3));
        endDate = endOfDay(now);
        break;
      case 'all':
        startDate = startOfDay(subMonths(now, 12));
        endDate = endOfDay(now);
        break;
      default:
        startDate = startOfDay(subWeeks(now, 1));
        endDate = endOfDay(now);
    }

    return {
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
      startDateFormatted: format(startDate, 'yyyy-MM-dd'),
      endDateFormatted: format(endDate, 'yyyy-MM-dd')
    };
  }

  /**
   * Calculate duration between two dates
   */
  static calculateDuration(startDate, endDate) {
    const start = typeof startDate === 'string' ? parseISO(startDate) : startDate;
    const end = typeof endDate === 'string' ? parseISO(endDate) : endDate;

    return {
      minutes: differenceInMinutes(end, start),
      hours: differenceInHours(end, start),
      days: differenceInDays(end, start)
    };
  }

  /**
   * Group data by time periods
   */
  static groupByPeriod(data, dateField = 'createdAt', period = 'day') {
    const groups = {};

    data.forEach(item => {
      const date = typeof item[dateField] === 'string' ? parseISO(item[dateField]) : item[dateField];
      let key;

      switch (period) {
        case 'hour':
          key = format(date, 'yyyy-MM-dd HH:00');
          break;
        case 'day':
          key = format(date, 'yyyy-MM-dd');
          break;
        case 'week':
          key = format(date, 'yyyy-ww');
          break;
        case 'month':
          key = format(date, 'yyyy-MM');
          break;
        default:
          key = format(date, 'yyyy-MM-dd');
      }

      if (!groups[key]) {
        groups[key] = [];
      }
      groups[key].push(item);
    });

    return groups;
  }

  /**
   * Check if date is within launch preparation period (before Sep 12)
   */
  static isPreLaunch(date) {
    const launchDate = new Date('2024-09-12');
    const checkDate = typeof date === 'string' ? parseISO(date) : date;
    return checkDate < launchDate;
  }

  /**
   * Days until launch
   */
  static daysUntilLaunch() {
    const launchDate = new Date('2024-09-12');
    const now = new Date();
    return Math.max(0, differenceInDays(launchDate, now));
  }

  /**
   * Format duration for display
   */
  static formatDuration(minutes) {
    if (minutes < 60) {
      return `${minutes}m`;
    } else if (minutes < 1440) {
      const hours = Math.floor(minutes / 60);
      const remainingMinutes = minutes % 60;
      return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
    } else {
      const days = Math.floor(minutes / 1440);
      const remainingHours = Math.floor((minutes % 1440) / 60);
      return remainingHours > 0 ? `${days}d ${remainingHours}h` : `${days}d`;
    }
  }
}