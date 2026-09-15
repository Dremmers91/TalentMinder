import { spawnSync } from "node:child_process";
import { mkdir, readFile } from "node:fs/promises";
import path from "node:path";

const toc = await readFile("addon/TalentMinder/TalentMinder.toc", "utf8");
const version = toc.match(/^## Version:\s*(\S+)$/m)?.[1];
if (!version) throw new Error("TalentMinder.toc does not contain a version.");
const output = `dist/TalentMinder-${version}.zip`;
const validate = spawnSync(process.execPath, ["scripts/addon-validate.mjs"], { stdio: "inherit" });
if (validate.error) throw validate.error;
if (validate.status !== 0) throw new Error(`Addon validation failed with exit code ${validate.status}.`);
await mkdir("dist", { recursive: true });
const result = process.platform === "win32"
  ? spawnSync("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/package-addon.ps1", "-OutputPath", output], { stdio: "inherit" })
  : spawnSync("zip", ["-r", path.resolve(output), "TalentMinder"], { cwd: "addon", stdio: "inherit" });
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(`Packaging failed with exit code ${result.status}.`);
