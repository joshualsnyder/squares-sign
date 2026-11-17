// Scheduled functions cannot be invoked through a public URL. The existing
// app endpoint still checks the shared secret, keeping manual calls protected.
export default async function dailyMaintenance() {
  const origin = process.env.APP_URL;
  const secret = process.env.CRON_SECRET;
  if (!origin || !secret)
    throw new Error("Daily maintenance is not configured.");
  const response = await fetch(new URL("/api/internal/retention", origin), {
    headers: { authorization: `Bearer ${secret}` },
    method: "POST",
    signal: AbortSignal.timeout(50_000),
  });
  if (!response.ok)
    throw new Error(`Daily maintenance failed (${response.status}).`);
  return new Response(null, { status: 204 });
}
