import { spawnSync } from "node:child_process";

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed with exit code ${result.status}.`);
}

run(process.execPath, ["--test", "tools/data-pipeline/test/*.test.mjs"]);
run(process.env.PYTHON ?? "python", ["-m", "unittest", "discover", "-v", "-s", "tools/scanner", "-p", "test_talent_scanner.py"]);
run(process.execPath, ["scripts/addon-integrity.mjs"]);
console.log("Addon validation passed.");
