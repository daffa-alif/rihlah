import { Injectable } from '@nestjs/common';

/**
 * Composite driver scoring for dispatch ordering.
 *
 * Formula (per SRS §6.3):
 *   score = 0.40 * proximityScore + 0.25 * ratingScore
 *         + 0.20 * acceptanceScore + 0.15 * spreadScore
 *
 * All sub-scores are normalized 0–1. Higher total = better candidate.
 */
export interface DriverCandidate {
  id: string;
  distanceKm: number;
  ratingAvg: number;
  acceptanceRate: number;
  totalTrips: number;
  vehicleType: string;
}

export interface ScoredDriver extends DriverCandidate {
  score: number;
  proximityScore: number;
  ratingScore: number;
  acceptanceScore: number;
  spreadScore: number;
}

@Injectable()
export class ScorerService {
  // SRS-specified weights
  private readonly wProximity = 0.4;
  private readonly wRating = 0.25;
  private readonly wAcceptance = 0.2;
  private readonly wSpread = 0.15;

  /** Score a list of driver candidates and return them sorted best-first. */
  score(candidates: DriverCandidate[], tripsTodayMap: Record<string, number>): ScoredDriver[] {
    if (candidates.length === 0) return [];

    // Find max values for normalization
    const maxDist = Math.max(...candidates.map((d) => d.distanceKm), 1);
    const maxTrips = Math.max(...Object.values(tripsTodayMap), 1);

    const scored: ScoredDriver[] = candidates.map((driver) => {
      // Proximity: closer = higher score (invert and normalize)
      const proximityScore = 1 - driver.distanceKm / maxDist;

      // Rating: normalize 0–5 to 0–1
      const ratingScore = driver.ratingAvg / 5;

      // Acceptance rate: already 0–1
      const acceptanceScore = Math.max(0, Math.min(1, driver.acceptanceRate));

      // Trip spread: drivers with fewer trips today get higher score
      // (fair distribution — prevents one driver from monopolizing orders)
      const tripsToday = tripsTodayMap[driver.id] || 0;
      const spreadScore = 1 - tripsToday / maxTrips;

      const score =
        this.wProximity * proximityScore +
        this.wRating * ratingScore +
        this.wAcceptance * acceptanceScore +
        this.wSpread * spreadScore;

      return {
        ...driver,
        score: Math.round(score * 10000) / 10000, // 4 decimal places
        proximityScore: Math.round(proximityScore * 1000) / 1000,
        ratingScore: Math.round(ratingScore * 1000) / 1000,
        acceptanceScore: Math.round(acceptanceScore * 1000) / 1000,
        spreadScore: Math.round(spreadScore * 1000) / 1000,
      };
    });

    // Sort descending by score
    scored.sort((a, b) => b.score - a.score);
    return scored;
  }
}
