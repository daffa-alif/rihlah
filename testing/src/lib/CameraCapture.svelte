<script>
  // Captures a single still frame from the device camera straight into
  // memory (a Blob) and hands it to the parent via onCapture. Nothing this
  // component does ever touches localStorage, IndexedDB, or the filesystem
  // — the preview image is an in-memory object URL that gets revoked the
  // moment it's no longer shown, and the camera stream is stopped as soon
  // as a frame is captured (or the component is destroyed).
  let { label, required = true, onCapture, onClear } = $props();

  /** @type {HTMLVideoElement} */
  let videoEl;
  /** @type {HTMLCanvasElement} */
  let canvasEl;

  let stream = $state(null);
  let previewUrl = $state(null);
  let error = $state('');

  async function startCamera() {
    error = '';
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 960 } },
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

  function capture() {
    if (!videoEl || !videoEl.videoWidth) return;
    canvasEl.width = videoEl.videoWidth;
    canvasEl.height = videoEl.videoHeight;
    canvasEl.getContext('2d').drawImage(videoEl, 0, 0);
    canvasEl.toBlob(
      (blob) => {
        if (!blob) return;
        previewUrl = URL.createObjectURL(blob);
        onCapture(blob);
        stopCamera(); // release the camera the instant we have a frame
      },
      'image/jpeg',
      0.92
    );
  }

  function retake() {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
      previewUrl = null;
    }
    onClear?.();
    startCamera();
  }

  $effect(() => {
    return () => {
      stopCamera();
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  });
</script>

<div class="capture">
  <h3>{label} {#if required}<span class="required">*</span>{/if}</h3>

  {#if error}
    <p class="error">{error}</p>
  {/if}

  <div class="frame" class:hidden={!!previewUrl}>
    <video bind:this={videoEl} class:hidden={!stream} playsinline muted>
      <track kind="captions" />
    </video>
    {#if !stream && !error}
      <p class="placeholder">Camera is off</p>
    {/if}
  </div>

  {#if previewUrl}
    <img src={previewUrl} alt="{label} preview" class="frame preview" />
  {/if}

  <canvas bind:this={canvasEl} class="hidden"></canvas>

  <div class="actions">
    {#if previewUrl}
      <button type="button" onclick={retake}>Retake</button>
    {:else if stream}
      <button type="button" class="primary" onclick={capture}>Capture</button>
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

  video,
  img.preview {
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

  canvas.hidden {
    display: none;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
  }
</style>
