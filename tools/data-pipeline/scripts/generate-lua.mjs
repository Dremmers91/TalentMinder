import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderLua } from "../lib/lua.mjs";
import { scannerRowsToBuilds, scannerRowsToStatPriorities } from "../lib/scanner-adapter.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDir, "../../..");
const defaultOutput = path.join(repositoryRoot, "addon", "TalentMinder", "TalentMinderGeneratedData.lua");

function usage() {
  return "Usage: node tools/data-pipeline/scripts/generate-lua.mjs <scanner-results-dir> [output-file]";
}

const [resultsDir, outputFile = defaultOutput] = process.argv.slice(2);
if (!resultsDir) throw new Error(usage());

const [buildRows, statRows] = await Promise.all([
  readFile(path.join(resultsDir, "talent-builds.json"), "utf8").then(JSON.parse),
  readFile(path.join(resultsDir, "stat-priorities.json"), "utf8").then(JSON.parse),
]);
const lua = renderLua(scannerRowsToBuilds(buildRows), scannerRowsToStatPriorities(statRows));
await writeFile(outputFile, lua, "utf8");
console.log(`Generated ${outputFile}`);
