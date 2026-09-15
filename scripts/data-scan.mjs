import { mkdir } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";

const output = process.argv[2] ?? path.join("tools", "scanner", ".artifacts", `scan-${Date.now()}`);
await mkdir(output, { recursive: true });
const result = spawnSync(process.env.PYTHON ?? "python", ["tools/scanner/talent_scanner.py", "tools/scanner/scanner-input.json", "--output", output], { stdio: "inherit" });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
console.log(`Scan results: ${path.resolve(output)}`);
