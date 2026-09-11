import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { ScoredDriver } from './scorer.service';

export interface CascadeState {
  tripId: string;
  candidateIds: string[];
  currentIndex: number;
  startedAt: number; // epoch ms
}

/**
 * Manages the dispatch cascade: offer to top-1 driver → 15s timeout →
 * next driver → ... → 90s total budget → no_drivers_available.
 *
 * State is stored in Redis with TTL-based auto-expiry for each offer.
 */
@Injectable()
export class CascadeService {
  private readonly OFFER_TTL_S = 15; // per-driver offer window
  private readonly TOTAL_BUDGET_S = 90; // max search time from first offer
  private readonly RADIUS_STEPS_M = [1500, 3000, 5000, 8000]; // expand radius

  constructor(private readonly redis: Redis) {}

  /** Start a new cascade for a trip. */
  async startCascade(
    tripId: string,
    scoredDrivers: ScoredDriver[],
  ): Promise<{ driverId: string; expiresAt: number } | null> {
    if (scoredDrivers.length === 0) return null;

    const candidateIds = scoredDrivers.map((d) => d.id);
    const now = Date.now();

    const state: CascadeState = {
      tripId,
      candidateIds,
      currentIndex: 0,
      startedAt: now,
    };

    // Store cascade state in Redis with TTL = total budget
    await this.redis.set(
      `cascade:${tripId}`,
      JSON.stringify(state),
      'EX',
      this.TOTAL_BUDGET_S,
    );

    // Offer to first driver
    return this.offerToCurrent(tripId, state);
  }

  /** Advance to the next driver after the current offer expires. */
  async advanceCascade(
    tripId: string,
  ): Promise<{ driverId: string; expiresAt: number } | null> {
    const raw = await this.redis.get(`cascade:${tripId}`);
    if (!raw) return null; // cascade expired or completed

    const state: CascadeState = JSON.parse(raw);

    // Check total budget
    if (Date.now() - state.startedAt > this.TOTAL_BUDGET_S * 1000) {
      await this.redis.del(`cascade:${tripId}`);
      return null; // total budget exhausted
    }

    // Move to next candidate
    state.currentIndex++;

    if (state.currentIndex >= state.candidateIds.length) {
      // All candidates exhausted at this radius — return null
      // (caller should expand radius and retry)
      await this.redis.del(`cascade:${tripId}`);
      return null;
    }

    await this.redis.set(
      `cascade:${tripId}`,
      JSON.stringify(state),
      'EX',
      this.TOTAL_BUDGET_S,
    );

    return this.offerToCurrent(tripId, state);
  }

  /** Get the current radius step for expansion. */
  getRadiusStep(stepIndex: number): number {
    if (stepIndex >= this.RADIUS_STEPS_M.length) {
      return this.RADIUS_STEPS_M[this.RADIUS_STEPS_M.length - 1];
    }
    return this.RADIUS_STEPS_M[stepIndex];
  }

  get radiusSteps(): number[] {
    return [...this.RADIUS_STEPS_M];
  }

  get totalBudgetMs(): number {
    return this.TOTAL_BUDGET_S * 1000;
  }

  get offerTtlMs(): number {
    return this.OFFER_TTL_S * 1000;
  }

  /** Complete a cascade (driver accepted — clean up state). */
  async completeCascade(tripId: string): Promise<void> {
    await this.redis.del(`cascade:${tripId}`);
  }

  /** Check if a cascade is still active for a trip. */
  async isCascadeActive(tripId: string): Promise<boolean> {
    const raw = await this.redis.get(`cascade:${tripId}`);
    if (!raw) return false;

    const state: CascadeState = JSON.parse(raw);
    return Date.now() - state.startedAt <= this.TOTAL_BUDGET_S * 1000;
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  private async offerToCurrent(
    tripId: string,
    state: CascadeState,
  ): Promise<{ driverId: string; expiresAt: number } | null> {
    if (state.currentIndex >= state.candidateIds.length) return null;

    const driverId = state.candidateIds[state.currentIndex];
    const expiresAt = Date.now() + this.OFFER_TTL_S * 1000;

    // Store current offer in Redis with TTL
    await this.redis.set(
      `offer:${tripId}:${driverId}`,
      JSON.stringify({ tripId, driverId, expiresAt }),
      'EX',
      this.OFFER_TTL_S,
    );

    return { driverId, expiresAt };
  }
}
