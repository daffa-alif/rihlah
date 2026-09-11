import { ScorerService, DriverCandidate } from '../libs/matching/src/scorer.service';

describe('ScorerService — Composite Driver Scoring', () => {
  const scorer = new ScorerService();

  const makeDriver = (overrides: Partial<DriverCandidate> = {}): DriverCandidate => ({
    id: 'd-001',
    distanceKm: 1.0,
    ratingAvg: 4.8,
    acceptanceRate: 0.85,
    totalTrips: 120,
    vehicleType: 'car',
    ...overrides,
  });

  const emptyTripsMap = {};

  // ── Proximity ────────────────────────────────────────────────────────────

  it('should rank closer drivers higher (all else equal)', () => {
    const near: DriverCandidate = makeDriver({ id: 'near', distanceKm: 0.5 });
    const far: DriverCandidate = makeDriver({ id: 'far', distanceKm: 5.0 });

    const scored = scorer.score([near, far], emptyTripsMap);
    expect(scored[0].id).toBe('near');
    expect(scored[1].id).toBe('far');
    expect(scored[0].proximityScore).toBeGreaterThan(scored[1].proximityScore);
  });

  // ── Rating ───────────────────────────────────────────────────────────────

  it('should rank higher-rated drivers higher (all else equal)', () => {
    const high: DriverCandidate = makeDriver({ id: 'high', ratingAvg: 5.0 });
    const low: DriverCandidate = makeDriver({ id: 'low', ratingAvg: 3.0 });

    const scored = scorer.score([low, high], emptyTripsMap);
    expect(scored[0].id).toBe('high');
    expect(scored[0].ratingScore).toBeGreaterThan(scored[1].ratingScore);
  });

  // ── Acceptance Rate ──────────────────────────────────────────────────────

  it('should rank higher-acceptance drivers higher', () => {
    const good: DriverCandidate = makeDriver({ id: 'good', acceptanceRate: 0.95 });
    const bad: DriverCandidate = makeDriver({ id: 'bad', acceptanceRate: 0.3 });

    const scored = scorer.score([bad, good], emptyTripsMap);
    expect(scored[0].id).toBe('good');
  });

  // ── Trip Spread (fairness) ───────────────────────────────────────────────

  it('should spread orders by giving lower-trip-count drivers higher spread score', () => {
    const d1: DriverCandidate = makeDriver({ id: 'few-trips' });
    const d2: DriverCandidate = makeDriver({ id: 'many-trips' });

    const tripsMap = {
      'few-trips': 2,
      'many-trips': 15,
    };

    const scored = scorer.score([d1, d2], tripsMap);
    const fewTrips = scored.find((d) => d.id === 'few-trips')!;
    const manyTrips = scored.find((d) => d.id === 'many-trips')!;

    expect(fewTrips.spreadScore).toBeGreaterThan(manyTrips.spreadScore);
  });

  // ── Weight Distribution ──────────────────────────────────────────────────

  it('should give proximity the highest weight (0.40)', () => {
    // A very close but poorly-rated driver vs a far but excellent driver
    const closeButBad: DriverCandidate = makeDriver({
      id: 'close-bad',
      distanceKm: 0.2,
      ratingAvg: 3.0,
      acceptanceRate: 0.5,
    });
    const farButGreat: DriverCandidate = makeDriver({
      id: 'far-great',
      distanceKm: 7.0,
      ratingAvg: 5.0,
      acceptanceRate: 1.0,
    });

    const tripsMap = { 'close-bad': 5, 'far-great': 5 };
    const scored = scorer.score([closeButBad, farButGreat], tripsMap);

    // Proximity (0.40) > Rating (0.25) + Acceptance (0.20) + Spread (0.15)
    // The close driver should win despite lower rating/acceptance
    expect(scored[0].id).toBe('close-bad');
  });

  // ── Edge Cases ───────────────────────────────────────────────────────────

  it('should return empty array for no candidates', () => {
    const scored = scorer.score([], {});
    expect(scored).toHaveLength(0);
  });

  it('should handle single driver', () => {
    const scored = scorer.score([makeDriver()], emptyTripsMap);
    expect(scored).toHaveLength(1);
    expect(scored[0].score).toBeGreaterThan(0);
  });

  it('should normalize scores when all drivers are identical', () => {
    const d1 = makeDriver({ id: 'a' });
    const d2 = makeDriver({ id: 'b' });

    const scored = scorer.score([d1, d2], emptyTripsMap);
    // Same stats = same score
    expect(scored[0].score).toBe(scored[1].score);
  });

  it('should handle zero-rated drivers gracefully', () => {
    const driver: DriverCandidate = makeDriver({ ratingAvg: 0 });
    const scored = scorer.score([driver], emptyTripsMap);
    expect(scored[0].ratingScore).toBe(0);
  });

  // ── Score Bounds ─────────────────────────────────────────────────────────

  it('should produce scores between 0 and 1 for realistic inputs', () => {
    const drivers: DriverCandidate[] = [
      makeDriver({ id: 'd1', distanceKm: 0.5, ratingAvg: 5.0, acceptanceRate: 1.0 }),
      makeDriver({ id: 'd2', distanceKm: 3.0, ratingAvg: 4.5, acceptanceRate: 0.8 }),
      makeDriver({ id: 'd3', distanceKm: 7.0, ratingAvg: 3.5, acceptanceRate: 0.5 }),
    ];

    const scored = scorer.score(drivers, { d1: 0, d2: 3, d3: 10 });

    for (const d of scored) {
      expect(d.score).toBeGreaterThanOrEqual(0);
      expect(d.score).toBeLessThanOrEqual(1);
      expect(d.proximityScore).toBeGreaterThanOrEqual(0);
      expect(d.proximityScore).toBeLessThanOrEqual(1);
    }
  });
});
