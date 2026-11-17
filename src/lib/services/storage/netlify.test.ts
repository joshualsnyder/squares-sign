import assert from "node:assert/strict";
import test from "node:test";
import type { Store } from "@netlify/blobs";

import {
  createNetlifyStorageService,
  netlifyDocumentStoreName,
} from "./netlify.ts";
import { StorageObjectNotFoundError } from "./types.ts";
import { resolveStorageDriver, supportsDirectUploads } from "./driver.ts";
import { uploadSizeLimit } from "../upload-limits.ts";

function fixture() {
  const entries = new Map<
    string,
    { data: ArrayBuffer; metadata: Record<string, unknown> }
  >();
  const store = {
    async delete(key: string) {
      entries.delete(key);
    },
    async getMetadata(key: string) {
      const entry = entries.get(key);
      return entry ? { metadata: entry.metadata, etag: "test" } : null;
    },
    async getWithMetadata(key: string, options: { type: string }) {
      const entry = entries.get(key);
      if (!entry) return null;
      return {
        data:
          options.type === "stream"
            ? new Response(entry.data).body
            : entry.data,
        metadata: entry.metadata,
        etag: "test",
      };
    },
    async set(
      key: string,
      data: ArrayBuffer,
      options: { onlyIfNew?: boolean; metadata: Record<string, unknown> },
    ) {
      if (options.onlyIfNew && entries.has(key)) return { modified: false };
      entries.set(key, { data, metadata: options.metadata });
      return { modified: true, etag: "test" };
    },
  } as unknown as Store;
  return createNetlifyStorageService({
    env: { NETLIFY_STORAGE_NAMESPACE: "production" },
    store,
  });
}

test("Netlify documents preserve exact bytes, metadata, streams and create-only writes", async () => {
  const storage = fixture();
  const key = "envelopes/123/source.pdf";
  const bytes = new Uint8Array([0, 1, 2, 255, 3]);
  await storage.putObject({
    key,
    body: bytes.subarray(1, 4),
    contentType: "application/pdf",
  });
  await storage.putObject({
    key,
    body: new Uint8Array([9]),
    contentType: "text/plain",
    keepExisting: true,
  });
  assert.deepEqual(
    (await storage.getObject(key)).body,
    new Uint8Array([1, 2, 255]),
  );
  const head = await storage.headObject(key);
  assert.equal(head.contentLength, 3);
  assert.equal(head.contentType, "application/pdf");
  const streamed = await storage.getObjectStream(key);
  assert.deepEqual(
    new Uint8Array(await new Response(streamed.stream).arrayBuffer()),
    new Uint8Array([1, 2, 255]),
  );
  await storage.deleteObject(key);
  assert.equal((await storage.headObject(key)).exists, false);
  await assert.rejects(storage.getObject(key), StorageObjectNotFoundError);
  await assert.rejects(
    storage.getObjectStream(key),
    StorageObjectNotFoundError,
  );
});

test("previews cannot address the production store and invalid keys are refused", async () => {
  assert.notEqual(
    netlifyDocumentStoreName({ NETLIFY_STORAGE_NAMESPACE: "production" }),
    netlifyDocumentStoreName({ NETLIFY_STORAGE_NAMESPACE: "preview-123" }),
  );
  assert.throws(() =>
    netlifyDocumentStoreName({ NETLIFY_STORAGE_NAMESPACE: "../production" }),
  );
  await assert.rejects(fixture().getObject("user/../other/private.pdf"));
  assert.equal(resolveStorageDriver({ NETLIFY: "true" }), "netlify");
  assert.equal(supportsDirectUploads({ NETLIFY: "true" }), false);
  assert.equal(uploadSizeLimit({ NETLIFY: "true" }), 4 * 1024 * 1024);
  assert.equal(uploadSizeLimit({ STORAGE_DRIVER: "netlify" }), 4 * 1024 * 1024);
  assert.equal(uploadSizeLimit({}), 20 * 1024 * 1024);
});
