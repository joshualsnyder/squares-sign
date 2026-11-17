import { MAX_UPLOAD_SIZE_BYTES } from "../types/domain.ts";
import type { EnvSource } from "../utils/env.ts";

// Multipart files travel through the Netlify function. Leave room below its
// encoded request limit for the form fields and multipart headers.
export function uploadSizeLimit(env: EnvSource = process.env): number {
  return env.NETLIFY === "true" || env.STORAGE_DRIVER === "netlify"
    ? 4 * 1024 * 1024
    : MAX_UPLOAD_SIZE_BYTES;
}
