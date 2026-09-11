import { Injectable } from '@nestjs/common';
import { PrismaService } from '@rihlah/database';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Dashboard KPIs — server-aggregated using SQL.
   * Replaces the P2 era's client-side computation from bounded Firestore streams.
   */
  async getDashboard() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [onlineDrivers, tripsToday, gmvResult, avgRatingResult] =
      await Promise.all([
        // Drivers currently online
        this.prisma.driver.count({ where: { online: true } }),

        // Trips completed today
        this.prisma.trip.count({
          where: {
            status: 'completed',
            completedAt: { gte: today },
          },
        }),

        // GMV today (sum of fareIdr for completed trips)
        this.prisma.trip.aggregate({
          _sum: { fareIdr: true },
          where: {
            status: 'completed',
            completedAt: { gte: today },
          },
        }),

        // Average driver rating
        this.prisma.driver.aggregate({
          _avg: { ratingAvg: true },
          where: { ratingCount: { gt: 0 } },
        }),
      ]);

    return {
      onlineDrivers,
      tripsToday,
      gmvToday: gmvResult._sum.fareIdr || 0,
      avgRating: Math.round((avgRatingResult._avg.ratingAvg || 0) * 100) / 100,
    };
  }

  /**
   * Weekly trip/GMV summary for the dashboard chart.
   */
  async getWeeklySummary() {
    const days: { date: string; trips: number; gmv: number }[] = [];

    for (let i = 6; i >= 0; i--) {
      const dayStart = new Date();
      dayStart.setDate(dayStart.getDate() - i);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(dayStart);
      dayEnd.setHours(23, 59, 59, 999);

      const [count, gmv] = await Promise.all([
        this.prisma.trip.count({
          where: {
            status: 'completed',
            completedAt: { gte: dayStart, lte: dayEnd },
          },
        }),
        this.prisma.trip.aggregate({
          _sum: { fareIdr: true },
          where: {
            status: 'completed',
            completedAt: { gte: dayStart, lte: dayEnd },
          },
        }),
      ]);

      days.push({
        date: dayStart.toISOString().split('T')[0],
        trips: count,
        gmv: gmv._sum.fareIdr || 0,
      });
    }

    return days;
  }

  /**
   * Reports: GMV, platform revenue, average fare, top drivers.
   * @param periodDays 7, 30, or 90
   */
  async getReports(periodDays: number = 30) {
    const since = new Date();
    since.setDate(since.getDate() - periodDays);

    const [
      tripCount,
      gmvResult,
      platformFeeResult,
      avgFareResult,
    ] = await Promise.all([
      this.prisma.trip.count({
        where: { status: 'completed', completedAt: { gte: since } },
      }),
      this.prisma.trip.aggregate({
        _sum: { fareIdr: true },
        where: { status: 'completed', completedAt: { gte: since } },
      }),
      this.prisma.trip.aggregate({
        _sum: { platformFeeIdr: true },
        where: { status: 'completed', completedAt: { gte: since } },
      }),
      this.prisma.trip.aggregate({
        _avg: { fareIdr: true },
        where: { status: 'completed', completedAt: { gte: since } },
      }),
    ]);

    // Top drivers by trip count
    const topDriversRaw: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT t."driverId", COUNT(*)::int as trips, SUM(t."fareIdr")::int as gmv
       FROM trips t
       WHERE t.status = 'completed' AND t."completedAt" >= $1
       GROUP BY t."driverId"
       ORDER BY trips DESC
       LIMIT 10`,
      since,
    );

    return {
      periodDays,
      since,
      tripCount,
      gmvTotal: gmvResult._sum.fareIdr || 0,
      platformRevenue: platformFeeResult._sum.platformFeeIdr || 0,
      averageFare: Math.round(avgFareResult._avg.fareIdr || 0),
      topDrivers: topDriversRaw,
    };
  }
}
