import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { scannerRowsToBuilds, scannerRowsToStatPriorities } from "../tools/data-pipeline/lib/scanner-adapter.mjs";

const artifacts = path.join("tools", "scanner", ".artifacts", `update-${process.pid}-${Date.now()}`);
const output = path.resolve("addon", "TalentMinder", "TalentMinderGeneratedData.lua");
const temporaryOutput = path.join(path.dirname(output), `.${path.basename(output)}.${process.pid}.tmp`);

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed with exit code ${result.status}.`);
}

await mkdir(artifacts, { recursive: true });
try {
  run(process.env.PYTHON ?? "python", ["tools/scanner/talent_scanner.py", "tools/scanner/scanner-input.json", "--output", artifacts]);
  run(process.execPath, ["scripts/data-validate.mjs", artifacts]);
  if (process.env.DATA_UPDATE_SUMMARY) {
    const [rows, priorities] = await Promise.all([readFile(path.join(artifacts, "talent-builds.json"), "utf8").then(JSON.parse), readFile(path.join(artifacts, "stat-priorities.json"), "utf8").then(JSON.parse)]);
    const builds = scannerRowsToBuilds(rows);
    await writeFile(process.env.DATA_UPDATE_SUMMARY, JSON.stringify({
      buildsBySource: Object.fromEntries(["Wowhead", "Icy Veins"].map((source) => [source, builds.filter((build) => build.source === source).length])),
      specializationsCovered: new Set(builds.map((build) => `${build.classFile}/${build.specId}`)).size,
      statPrioritiesFound: scannerRowsToStatPriorities(priorities).length,
      excludedMalformedRecords: rows.filter((row) => row.extraction_status === "malformed_code").length,
    }, null, 2));
  }
  run(process.execPath, ["scripts/data-generate.mjs", artifacts, temporaryOutput]);
  run(process.execPath, ["scripts/lua-syntax-check.mjs", temporaryOutput]);
  await rename(temporaryOutput, output);
  await rm(artifacts, { recursive: true, force: true });
  console.log(`Updated ${output}`);
} finally {
  await rm(temporaryOutput, { force: true });
}
