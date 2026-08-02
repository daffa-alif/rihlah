<script>
  let { result } = $props();

  let showRaw = $state(false);
</script>

<section class="result">
  <div class="status" class:verified={result.status === 'VERIFIED'} class:rejected={result.status === 'REJECTED'}>
    <strong>{result.status}</strong>
    <span class="muted">request_id: {result.request_id}</span>
  </div>

  <p class="notice">{result.image_retention_notice}</p>

  {#if result.rejection_reasons.length > 0}
    <div class="panel">
      <h3>Rejection reasons</h3>
      <ul>
        {#each result.rejection_reasons as reason (reason)}
          <li>{reason}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <div class="panel">
    <h3>Biometrics</h3>
    <div class="grid">
      <div>ID face detected<br /><strong>{result.biometrics.id_face_detected}</strong></div>
      <div>Selfie face detected<br /><strong>{result.biometrics.selfie_face_detected}</strong></div>
      <div>Face match score<br /><strong>{result.biometrics.face_match_score.toFixed(2)}</strong> ({result.biometrics.face_match_passed ? 'pass' : 'fail'})</div>
      <div>Liveness score<br /><strong>{result.biometrics.liveness_confidence_score.toFixed(2)}</strong> ({result.biometrics.liveness_passed ? 'pass' : 'fail'})</div>
      <div>Verified at<br /><strong>{result.biometrics.verified_at}</strong></div>
    </div>
  </div>

  {#if result.ktp}
    <div class="panel">
      <h3>KTP (OCR)</h3>
      <div class="grid">
        <div>NIK<br /><strong>{result.ktp.nik}</strong></div>
        <div>Full name<br /><strong>{result.ktp.full_name}</strong></div>
        <div>Date of birth<br /><strong>{result.ktp.date_of_birth}</strong></div>
        <div>Place of birth<br /><strong>{result.ktp.place_of_birth}</strong></div>
        <div>OCR confidence<br /><strong>{(result.ktp.ocr_confidence * 100).toFixed(0)}%</strong></div>
      </div>
    </div>
  {/if}

  {#if result.sim}
    <div class="panel">
      <h3>SIM (OCR)</h3>
      <div class="grid">
        <div>SIM number<br /><strong>{result.sim.sim_number}</strong></div>
        <div>Class<br /><strong>{result.sim.sim_class}</strong></div>
        <div>Full name<br /><strong>{result.sim.full_name}</strong></div>
        <div>Valid until<br /><strong>{result.sim.valid_until}</strong></div>
        <div>OCR confidence<br /><strong>{(result.sim.ocr_confidence * 100).toFixed(0)}%</strong></div>
      </div>
    </div>
  {/if}

  <div class="panel">
    <h3>Vehicle</h3>
    <div class="grid">
      <div>Plate<br /><strong>{result.vehicle.plate_number}</strong></div>
      <div>Owner<br /><strong>{result.vehicle.owner_name}</strong></div>
      <div>Brand / model<br /><strong>{result.vehicle.brand} {result.vehicle.model}</strong></div>
      <div>Year<br /><strong>{result.vehicle.year}</strong></div>
      <div>Source<br /><strong>{result.vehicle.source}</strong></div>
      <div>Tax valid until<br /><strong>{result.vehicle.tax_valid_until ?? 'unknown'}</strong></div>
    </div>
  </div>

  <div class="panel">
    <h3>Device</h3>
    <div class="grid">
      <div>Device id<br /><strong>{result.device.device_id}</strong></div>
      <div>IP address<br /><strong>{result.device.ip_address}</strong></div>
      <div>Within service area<br /><strong>{result.device.within_service_area}</strong></div>
      <div>Location<br /><strong>{result.device.location.latitude}, {result.device.location.longitude}</strong></div>
    </div>
  </div>

  <div class="panel">
    <h3>Cross-validation</h3>
    <table>
      <thead>
        <tr><th>Field</th><th>Extracted</th><th>Claimed</th><th>Match</th></tr>
      </thead>
      <tbody>
        {#each result.cross_validation as check (check.field)}
          <tr>
            <td>{check.field}</td>
            <td>{check.extracted_value ?? '—'}</td>
            <td>{check.claimed_value ?? '—'}</td>
            <td class:ok={check.matched} class:bad={!check.matched}>{check.matched ? '✓' : '✗'}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <button type="button" onclick={() => (showRaw = !showRaw)}>
    {showRaw ? 'Hide' : 'Show'} raw JSON
  </button>
  {#if showRaw}
    <pre>{JSON.stringify(result, null, 2)}</pre>
  {/if}
</section>

<style>
  .status {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 14px;
    border-radius: 8px;
    font-size: 15px;
    margin-bottom: 8px;
  }
  .status.verified {
    background: var(--ok-bg);
    color: var(--ok);
  }
  .status.rejected {
    background: var(--bad-bg);
    color: var(--bad);
  }
  .muted {
    color: var(--text-muted);
    font-size: 12px;
    font-weight: 400;
  }
  .notice {
    color: var(--text-muted);
    font-size: 12px;
    margin-bottom: 16px;
  }
  .panel {
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 12px 14px;
    margin-bottom: 12px;
  }
  .panel h3 {
    margin-bottom: 8px;
  }
  .panel ul {
    margin: 0;
    padding-left: 18px;
    color: var(--bad);
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 10px;
    font-size: 13px;
    color: var(--text-muted);
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }
  th,
  td {
    text-align: left;
    padding: 6px 8px;
    border-bottom: 1px solid var(--border);
  }
  td.ok {
    color: var(--ok);
    font-weight: 700;
  }
  td.bad {
    color: var(--bad);
    font-weight: 700;
  }
</style>
