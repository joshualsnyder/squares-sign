import { getStore, type Store } from "@netlify/blobs";

import type { EnvSource } from "../../utils/env.ts";
import {
  normalizeStorageKey,
  StorageObjectNotFoundError,
  type StorageService,
} from "./types.ts";

type DocumentStore = Pick<
  Store,
  "delete" | "getWithMetadata" | "getMetadata" | "set"
>;

// Production documents persist across deploys. Every preview gets a separate
// namespace baked in at build time, so it cannot modify production documents.
// Keep this direct process.env access: Next.js replaces it with the build's
// namespace; dynamic access through an env object is not substituted.
const BUILD_NAMESPACE = process.env.NETLIFY_STORAGE_NAMESPACE || "local";

export function netlifyDocumentStoreName(env: EnvSource): string {
  const scope = env.NETLIFY_STORAGE_NAMESPACE?.trim() || BUILD_NAMESPACE;
  if (!/^[a-zA-Z0-9_-]{1,48}$/.test(scope)) {
    throw new Error("Invalid Netlify document storage namespace.");
  }
  return `signudoc-${scope}`;
}

export function createNetlifyStorageService({
  env = process.env,
  store = getStore({
    name: netlifyDocumentStoreName(env),
    consistency: "strong",
  }),
}: { env?: EnvSource; store?: DocumentStore } = {}): StorageService {
  const bucketName = netlifyDocumentStoreName(env);

  return {
    async deleteObject(key) {
      await store.delete(normalizeStorageKey(key));
    },
    async getObject(key) {
      const normalized = normalizeStorageKey(key);
      const entry = await store.getWithMetadata(normalized, {
        type: "arrayBuffer",
      });
      if (!entry || !entry.data)
        throw new StorageObjectNotFoundError(normalized);
      return {
        bucketName,
        key: normalized,
        body: new Uint8Array(entry.data),
        contentLength: entry.data.byteLength,
        contentType: entry.metadata.contentType as string | undefined,
        etag: entry.etag,
      };
    },
    async getObjectStream(key) {
      const normalized = normalizeStorageKey(key);
      const entry = await store.getWithMetadata(normalized, { type: "stream" });
      if (!entry || !entry.data)
        throw new StorageObjectNotFoundError(normalized);
      return {
        bucketName,
        key: normalized,
        stream: entry.data as ReadableStream<Uint8Array>,
        contentLength: entry.metadata.contentLength as number | undefined,
        contentType: entry.metadata.contentType as string | undefined,
      };
    },
    async headObject(key) {
      const normalized = normalizeStorageKey(key);
      const entry = await store.getMetadata(normalized);
      return {
        bucketName,
        key: normalized,
        exists: entry !== null,
        contentLength: entry?.metadata.contentLength as number | undefined,
        contentType: entry?.metadata.contentType as string | undefined,
        etag: entry?.etag,
      };
    },
    async putObject({ body, contentType, key, keepExisting }) {
      const normalized = normalizeStorageKey(key);
      await store.set(normalized, Uint8Array.from(body).buffer, {
        metadata: { contentType, contentLength: body.byteLength },
        ...(keepExisting ? { onlyIfNew: true } : {}),
      });
      return { bucketName, key: normalized };
    },
  };
}
