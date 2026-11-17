import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();
const siteId = "f0430c0b-fda1-471b-9b95-96a708d1687c";
const production = process.argv.includes("--prod");
if (git("branch", "--show-current") !== "main")
  throw new Error("Deploy from main only.");
if (git("status", "--porcelain"))
  throw new Error("Commit all changes before deploying.");
if (git("rev-parse", "HEAD") !== git("rev-parse", "origin/main")) {
  throw new Error("Deploy only the published origin/main commit.");
}
const state = JSON.parse(readFileSync(".netlify/state.json", "utf8"));
if (state.siteId !== siteId)
  throw new Error("This checkout is linked to another Netlify project.");
const result = spawnSync(
  "netlify",
  [
    "deploy",
    "--site",
    siteId,
    "--context",
    production ? "production" : "deploy-preview",
    "--message",
    `SquaresSign ${git("rev-parse", "HEAD")}`,
    ...(production ? ["--prod"] : []),
  ],
  { stdio: "inherit", env: process.env },
);
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
