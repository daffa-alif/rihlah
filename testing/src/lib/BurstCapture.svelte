<script>
  // Captures an ordered burst of still frames from the device camera for
  // the backend's frame-by-frame liveness check (see
  // BACKEND/app/services/kyc/vision.py's analyze_liveness_frames). Frames
  // live only as in-memory Blobs — nothing here ever touches localStorage,
  // IndexedDB, or the filesystem, and the camera stream is stopped the
  // instant the burst finishes (or the component is destroyed).
  //
  // This is a stand-in for the real capture flow: the production Flutter
  // app will extract frames from a couple of seconds of live video instead
  // of a JS-timer burst of still snapshots, but the wire contract is the
  // same — an ordered set of `selfie_frames` uploads.
  let { label, frameCount = 8, intervalMs = 200, onCapture, onClear } = $props();

  /** @type {HTMLVideoElement} */
  let videoEl;
  /** @type {HTMLCanvasElement} */
  let canvasEl;

  let stream = $state(null);
  let error = $state('');
  let capturing = $state(false);
  let capturedCount = $state(0);
  let previewUrls = $state([]);
  let done = $state(false);

  async function startCamera() {
    error = '';
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 960 } },
        audio: false,
      });
      videoEl.srcObject = stream;
      await videoEl.play();
    } catch (err) {
      error = `Camera unavailable: ${err.message}`;
      stream = null;
    }
  }

  function stopCamera() {
    if (stream) {
      for (const track of stream.getTracks()) track.stop();
      stream = null;
    }
  }

  function grabFrame() {
    return new Promise((resolve) => {
      canvasEl.width = videoEl.videoWidth;
      canvasEl.height = videoEl.videoHeight;
      canvasEl.getContext('2d').drawImage(videoEl, 0, 0);
      canvasEl.toBlob((blob) => resolve(blob), 'image/jpeg', 0.85);
    });
  }

  async function captureBurst() {
    if (!videoEl || !videoEl.videoWidth || capturing) return;
    capturing = true;
    capturedCount = 0;
    const blobs = [];
    const urls = [];

    for (let i = 0; i < frameCount; i++) {
      const blob = await grabFrame();
      if (blob) {
        blobs.push(blob);
        urls.push(URL.createObjectURL(blob));
        capturedCount = blobs.length;
        previewUrls = urls;
      }
      if (i < frameCount - 1) {
        await new Promise((r) => setTimeout(r, intervalMs));
      }
    }

    capturing = false;
    done = true;
    stopCamera(); // release the camera the instant the burst finishes
    onCapture(blobs);
  }

  function retake() {
    for (const url of previewUrls) URL.revokeObjectURL(url);
    previewUrls = [];
    capturedCount = 0;
    done = false;
    onClear?.();
    startCamera();
  }

  $effect(() => {
    return () => {
      stopCamera();
      for (const url of previewUrls) URL.revokeObjectURL(url);
    };
  });
</script>

<div class="capture">
  <h3>{label} <span class="required">*</span></h3>
  <p class="hint">
    Captures {frameCount} frames over ~{((frameCount - 1) * intervalMs) / 1000}s for
    liveness analysis (blink + natural movement).
  </p>

  {#if error}
    <p class="error">{error}</p>
  {/if}

  <div class="frame" class:hidden={done}>
    <video bind:this={videoEl} class:hidden={!stream} playsinline muted>
      <track kind="captions" />
    </video>
    {#if !stream && !error}
      <p class="placeholder">Camera is off</p>
    {/if}
  </div>

  {#if done && previewUrls.length > 0}
    <div class="thumbs">
      {#each previewUrls as url, i (i)}
        <img src={url} alt="frame {i + 1}" />
      {/each}
    </div>
  {/if}

  <canvas bind:this={canvasEl} class="hidden"></canvas>

  <div class="actions">
    {#if done}
      <span class="hint">{capturedCount} frames captured</span>
      <button type="button" onclick={retake}>Retake</button>
    {:else if capturing}
      <span class="hint">Capturing… {capturedCount}/{frameCount}</span>
    {:else if stream}
      <button type="button" class="primary" onclick={captureBurst}>Capture burst</button>
    {:else}
      <button type="button" onclick={startCamera}>Open camera</button>
    {/if}
  </div>
</div>

<style>
  .capture {
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 14px;
    background: var(--bg-panel);
  }

  .required {
    color: var(--bad);
  }

  .frame {
    width: 100%;
    aspect-ratio: 4 / 3;
    border-radius: 8px;
    background: #000;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 8px 0;
  }

  .frame.hidden {
    display: none;
  }

  video {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  video.hidden {
    display: none;
  }

  .placeholder {
    color: #9ca3af;
    font-size: 13px;
    margin: 0;
  }

  .error {
    color: var(--bad);
    font-size: 13px;
  }

  .hint {
    color: var(--text-muted);
    font-size: 12px;
  }

  canvas.hidden {
    display: none;
  }

  .thumbs {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(48px, 1fr));
    gap: 4px;
    margin: 8px 0;
  }

  .thumbs img {
    width: 100%;
    aspect-ratio: 1;
    object-fit: cover;
    border-radius: 4px;
  }

  .actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 10px;
  }
</style>
