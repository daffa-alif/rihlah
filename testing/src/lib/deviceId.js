const STORAGE_KEY = 'rihlah_kyc_device_id';

/**
 * A stable, random, non-identifying fingerprint for this browser.
 *
 * This is the one piece of client state this app persists in localStorage —
 * intentionally: it's an opaque id, not a photo or personal document data,
 * and the whole point of a device fingerprint is that it stays stable
 * across sessions so the backend can flag one device registering many
 * different identities.
 */
export function getDeviceId() {
  let id = localStorage.getItem(STORAGE_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(STORAGE_KEY, id);
  }
  return id;
}
