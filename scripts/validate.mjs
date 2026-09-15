import { spawnSync } from "node:child_process";

const commands = [
  [process.execPath, ["--test", "tools/data-pipeline/test/*.test.mjs"]],
  [process.env.PYTHON ?? "python", ["-m", "unittest", "discover", "-v", "-s", "tools/scanner", "-p", "test_talent_scanner.py"]],
];

for (const [command, args] of commands) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status ?? 1;
}
