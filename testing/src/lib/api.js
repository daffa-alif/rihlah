const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api/v1';

export class ApiError extends Error {
  constructor(message, status, body) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

/**
 * Submits one KYC verification attempt. The photo/frame Blobs passed in are
 * only ever read here to build the multipart body — this function does not
 * write them anywhere (no localStorage/IndexedDB/disk), and the caller is
 * expected to drop its own references right after this resolves.
 */
export async function submitKycVerification(payload, { idDocumentPhoto, selfieFrames, stnkPhoto }) {
  const form = new FormData();
  form.append('payload', JSON.stringify(payload));
  form.append('id_document_photo', idDocumentPhoto, 'id_document.jpg');
  selfieFrames.forEach((frame, i) => {
    form.append('selfie_frames', frame, `selfie_frame_${String(i).padStart(2, '0')}.jpg`);
  });
  if (stnkPhoto) {
    form.append('stnk_photo', stnkPhoto, 'stnk.jpg');
  }

  const response = await fetch(`${API_BASE}/kyc/verify`, {
    method: 'POST',
    body: form,
  });

  let data = null;
  try {
    data = await response.json();
  } catch {
    // non-JSON error body (e.g. a proxy error page) — fall through with data=null
  }

  if (!response.ok) {
    const message = data?.error?.message || `Request failed with status ${response.status}`;
    throw new ApiError(message, response.status, data);
  }

  return data;
}
