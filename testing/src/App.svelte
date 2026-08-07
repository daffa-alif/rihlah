<script>
  // Top-level page for the KYC test harness: owns the form state, builds the
  // `KycVerificationRequest` JSON payload, and wires the camera components'
  // captured Blobs into one POST /kyc/verify submission. See lib/api.js for
  // the actual request, and README.md's "Layout" section for how the pieces
  // fit together.
  import CameraCapture from './lib/CameraCapture.svelte';
  import BurstCapture from './lib/BurstCapture.svelte';
  import ResultView from './lib/ResultView.svelte';
  import { submitKycVerification } from './lib/api.js';
  import { getDeviceId } from './lib/deviceId.js';
  import { getCurrentLocation } from './lib/geolocation.js';

  // Must stay >= the backend's KYC_MIN_LIVENESS_FRAMES (default 5).
  const SELFIE_FRAME_COUNT = 8;

  let documentType = $state('KTP');

  let claimedVehicle = $state({
    plate_number: '',
    vehicle_type: 'MOTOR',
    brand: '',
    model: '',
    year: '',
  });

  let includeStnkPhoto = $state(false);
  let includeFinancial = $state(false);
  let financial = $state({
    bank_name: '',
    bank_account_number: '',
    bank_account_holder_name: '',
    skck_number: '',
    skck_valid_until: '',
  });

  const deviceId = getDeviceId();
  let location = $state(null);
  let locationError = $state('');
  let locatingBusy = $state(false);

  let idPhotoBlob = $state(null);
  let selfieFrameBlobs = $state([]);
  let stnkPhotoBlob = $state(null);
  let photosResetKey = $state(0);

  let submitting = $state(false);
  let result = $state(null);
  let submitError = $state(null);

  const canSubmit = $derived(
    !!idPhotoBlob &&
      selfieFrameBlobs.length >= SELFIE_FRAME_COUNT &&
      (!includeStnkPhoto || !!stnkPhotoBlob) &&
      !!location &&
      claimedVehicle.plate_number.trim().length > 0 &&
      (includeStnkPhoto ||
        (claimedVehicle.brand.trim().length > 0 &&
          claimedVehicle.model.trim().length > 0 &&
          !!claimedVehicle.year))
  );

  async function requestLocation() {
    locatingBusy = true;
    locationError = '';
    try {
      location = await getCurrentLocation();
    } catch (err) {
      locationError = err.message;
    } finally {
      locatingBusy = false;
    }
  }

  function buildPayload() {
    const vehicle = {
      plate_number: claimedVehicle.plate_number,
      vehicle_type: claimedVehicle.vehicle_type,
    };
    if (claimedVehicle.brand) vehicle.brand = claimedVehicle.brand;
    if (claimedVehicle.model) vehicle.model = claimedVehicle.model;
    if (claimedVehicle.year) vehicle.year = Number(claimedVehicle.year);

    const payload = {
      document_type: documentType,
      claimed_vehicle: vehicle,
      device: { device_id: deviceId, location },
    };

    if (includeFinancial) {
      const f = { ...financial };
      if (!f.skck_number) delete f.skck_number;
      if (!f.skck_valid_until) delete f.skck_valid_until;
      payload.financial = f;
    }

    return payload;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (!canSubmit || submitting) return;

    submitting = true;
    submitError = null;
    result = null;

    try {
      const payload = buildPayload();
      result = await submitKycVerification(payload, {
        idDocumentPhoto: idPhotoBlob,
        selfieFrames: selfieFrameBlobs,
        stnkPhoto: includeStnkPhoto ? stnkPhotoBlob : null,
      });
    } catch (err) {
      submitError = err;
    } finally {
      submitting = false;
      // This harness processes each photo/frame exactly once: drop every
      // reference right after the request settles, and remount the camera
      // components (photosResetKey) so a retry always starts from a fresh
      // capture.
      idPhotoBlob = null;
      selfieFrameBlobs = [];
      stnkPhotoBlob = null;
      photosResetKey += 1;
    }
  }
</script>

<main>
  <h1>Rihlah — Driver KYC test harness</h1>
  <p class="lede">
    Captures a live document photo and a burst of selfie frames straight into browser memory,
    sends them once to <code>POST /kyc/verify</code>, and discards them. Identity (NIK/name/date
    of birth) is read entirely off the document by OCR and confirmed via a Dukcapil stub — nothing
    here is typed manually. No photo/frame is ever written to disk or localStorage — only
    <code>device_id</code> (an opaque fingerprint) persists locally.
  </p>

  <form onsubmit={handleSubmit}>
    <section class="panel">
      <h2>Document</h2>
      <label for="document_type">Document type</label>
      <select id="document_type" bind:value={documentType}>
        <option value="KTP">KTP</option>
        <option value="SIM">SIM</option>
      </select>
    </section>

    <section class="panel">
      <p class="hint">
        No identity fields here anymore — NIK, name, and date of birth are read entirely off the
        <code>{documentType}</code> photo below by OCR, then confirmed against Dukcapil server-side.
      </p>
    </section>

    <section class="panel">
      <h2>Claimed vehicle</h2>
      <label class="checkbox">
        <input type="checkbox" bind:checked={includeStnkPhoto} />
        Capture an STNK photo (otherwise brand/model/year below are required)
      </label>
      <div class="grid">
        <div>
          <label for="plate_number">Plate number</label>
          <input id="plate_number" bind:value={claimedVehicle.plate_number} placeholder="B 1234 XYZ" />
        </div>
        <div>
          <label for="vehicle_type">Vehicle type</label>
          <select id="vehicle_type" bind:value={claimedVehicle.vehicle_type}>
            <option value="MOTOR">MOTOR</option>
            <option value="MOBIL">MOBIL</option>
          </select>
        </div>
        {#if !includeStnkPhoto}
          <div>
            <label for="brand">Brand</label>
            <input id="brand" bind:value={claimedVehicle.brand} placeholder="Honda" />
          </div>
          <div>
            <label for="model">Model</label>
            <input id="model" bind:value={claimedVehicle.model} placeholder="Vario 160" />
          </div>
          <div>
            <label for="year">Year</label>
            <input id="year" type="number" bind:value={claimedVehicle.year} placeholder="2021" />
          </div>
        {/if}
      </div>
    </section>

    <section class="panel">
      <label class="checkbox">
        <input type="checkbox" bind:checked={includeFinancial} />
        Include financial / SKCK data (optional)
      </label>
      {#if includeFinancial}
        <div class="grid">
          <div>
            <label for="bank_name">Bank name</label>
            <input id="bank_name" bind:value={financial.bank_name} placeholder="BCA" />
          </div>
          <div>
            <label for="bank_account_number">Bank account number</label>
            <input id="bank_account_number" bind:value={financial.bank_account_number} placeholder="1234567890" />
          </div>
          <div>
            <label for="bank_account_holder_name">Account holder name</label>
            <input id="bank_account_holder_name" bind:value={financial.bank_account_holder_name} placeholder="Budi Santoso" />
          </div>
          <div>
            <label for="skck_number">SKCK number</label>
            <input id="skck_number" bind:value={financial.skck_number} placeholder="SKCK/2026/001234" />
          </div>
          <div>
            <label for="skck_valid_until">SKCK valid until</label>
            <input id="skck_valid_until" type="date" bind:value={financial.skck_valid_until} />
          </div>
        </div>
      {/if}
    </section>

    <section class="panel">
      <h2>Device &amp; location</h2>
      <p class="hint">device_id: <code>{deviceId}</code> — ip_address / user_agent are read server-side, not sent from here.</p>
      <button type="button" onclick={requestLocation} disabled={locatingBusy}>
        {locatingBusy ? 'Locating…' : location ? 'Refresh location' : 'Get my location'}
      </button>
      {#if location}
        <p class="hint">lat {location.latitude.toFixed(5)}, lon {location.longitude.toFixed(5)}</p>
      {/if}
      {#if locationError}
        <p class="error">{locationError}</p>
      {/if}
    </section>

    {#key photosResetKey}
      <section class="panel photos">
        <h2>Live photos</h2>
        <div class="camera-grid">
          <CameraCapture label="KTP/SIM photo" onCapture={(blob) => (idPhotoBlob = blob)} onClear={() => (idPhotoBlob = null)} />
          <BurstCapture
            label="Selfie burst (liveness)"
            frameCount={SELFIE_FRAME_COUNT}
            onCapture={(frames) => (selfieFrameBlobs = frames)}
            onClear={() => (selfieFrameBlobs = [])}
          />
          {#if includeStnkPhoto}
            <CameraCapture label="STNK photo" onCapture={(blob) => (stnkPhotoBlob = blob)} onClear={() => (stnkPhotoBlob = null)} />
          {/if}
        </div>
      </section>
    {/key}

    <button type="submit" class="primary submit" disabled={!canSubmit || submitting}>
      {submitting ? 'Verifying…' : 'Run KYC verification'}
    </button>
  </form>

  {#if submitError}
    <section class="panel error-panel">
      <h2>Request failed ({submitError.status ?? '—'})</h2>
      <p>{submitError.message}</p>
      {#if submitError.body}
        <pre>{JSON.stringify(submitError.body, null, 2)}</pre>
      {/if}
    </section>
  {/if}

  {#if result}
    <ResultView {result} />
  {/if}
</main>

<style>
  main {
    max-width: 100%;
  }
  .lede {
    color: var(--text-muted);
    font-size: 14px;
    margin-bottom: 20px;
  }
  .panel {
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px;
    margin-bottom: 16px;
  }
  .hint {
    color: var(--text-muted);
    font-size: 12px;
  }
  .error {
    color: var(--bad);
    font-size: 13px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 12px;
    margin-top: 10px;
  }
  .checkbox {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 400;
    color: var(--text);
  }
  .checkbox input {
    width: auto;
  }
  .camera-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 12px;
  }
  .submit {
    width: 100%;
    padding: 12px;
    font-size: 15px;
  }
  .error-panel {
    border-color: var(--bad);
  }
</style>
