import { readFile } from "node:fs/promises";
import path from "node:path";
import { RETAIL_SPECIALIZATIONS, scannerRowsToBuilds, scannerRowsToStatPriorities } from "../tools/data-pipeline/lib/scanner-adapter.mjs";

const resultsDir = process.argv[2];
if (!resultsDir) throw new Error("Usage: node scripts/data-validate.mjs <scanner-results-dir>");
const readJson = (name) => readFile(path.join(resultsDir, name), "utf8").then(JSON.parse);
const [buildRows, statRows, statuses] = await Promise.all([readJson("talent-builds.json"), readJson("stat-priorities.json"), readJson("scan-status.json")]);
if (![buildRows, statRows, statuses].every(Array.isArray)) throw new Error("Scan reports must be JSON arrays.");

const requiredSources = ["wowhead", "icy-veins"];
const expectedSpecs = new Set(RETAIL_SPECIALIZATIONS.map(({ class: cls, spec }) => `${cls}\0${spec}`));
const hardFailure = new Set(["blocked", "error", "worker_error"]);
const failed = statuses.filter((status) => hardFailure.has(status.status));
if (failed.length) throw new Error(`Required scan target failed: ${failed.map(({ source, class: cls, spec }) => `${source}:${cls}/${spec}`).join(", ")}`);
for (const source of requiredSources) {
  const sourceStatuses = statuses.filter((status) => status.source === source);
  if (!sourceStatuses.length) throw new Error(`Required source completely failed: ${source}`);
  for (const key of expectedSpecs) {
    const [cls, spec] = key.split("\0");
    const targets = sourceStatuses.filter((status) => status.class === cls && status.spec === spec);
    if (!targets.some((status) => status.status === "ok" || status.status === "partial")) throw new Error(`Required scan target is missing or incomplete: ${source}:${cls}/${spec}`);
  }
}

const validExport = /^[A-Za-z0-9+/]{60,}={0,2}$/;
for (const row of buildRows) if (row.import_code && !validExport.test(row.import_code)) throw new Error(`Malformed talent string: ${row.source}:${row.class}/${row.spec}`);
const builds = scannerRowsToBuilds(buildRows);
const coveredSpecs = new Set(builds.map((build) => `${build.classFile}\0${build.specId}`));
for (const source of requiredSources) {
  const normalizedSource = source === "wowhead" ? "Wowhead" : "Icy Veins";
  if (!builds.some((build) => build.source === normalizedSource)) throw new Error(`No valid builds found for source: ${source}`);
}
if (coveredSpecs.size !== RETAIL_SPECIALIZATIONS.length) throw new Error(`Configured specialization missing from valid builds: covered ${coveredSpecs.size}/${RETAIL_SPECIALIZATIONS.length}.`);
for (const status of statuses.filter((item) => item.status === "partial")) {
  const rows = buildRows.filter((row) => row.source === status.source && row.class === status.class && row.spec === status.spec);
  if (!scannerRowsToBuilds(rows).length || !rows.filter((row) => row.extraction_status !== "ok").every((row) => row.extraction_status === "malformed_code")) {
    throw new Error(`Partial target is not publishable: ${status.source}:${status.class}/${status.spec}`);
  }
}

const existingLua = await readFile("addon/TalentMinder/TalentMinderGeneratedData.lua", "utf8");
const baselineBuilds = (existingLua.match(/talentImportString =/g) || []).length;
const baselineSpecs = new Set([...existingLua.matchAll(/^\s*\[(\d+)\] = \{/gm)].map((match) => match[1])).size;
const thresholds = { builds: 0.8, specs: 0.8 };
if (builds.length < baselineBuilds * thresholds.builds) throw new Error(`Build coverage dropped below the ${thresholds.builds * 100}% safety threshold.`);
if (coveredSpecs.size < baselineSpecs * thresholds.specs) throw new Error(`Specialization coverage dropped below the ${thresholds.specs * 100}% safety threshold.`);
console.log(`Validated ${builds.length} normalized builds across ${coveredSpecs.size} specs and ${scannerRowsToStatPriorities(statRows).length} stat-priority lists.`);
