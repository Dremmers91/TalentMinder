import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { RETAIL_SPECIALIZATIONS } from "../lib/scanner-adapter.mjs";

function run(args) {
  const result = spawnSync(process.execPath, args, { cwd: path.resolve("."), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

test("complete scan fixture validates, generates Lua, and packages an addon-only ZIP", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "talentminder-pipeline-"));
  const results = path.join(root, "results");
  const addon = path.join(root, "TalentMinder");
  const output = path.join(addon, "TalentMinderGeneratedData.lua");
  try {
    await mkdir(results, { recursive: true });
    await mkdir(addon, { recursive: true });
    const rows = [];
    const statuses = [];
    let index = 0;
    for (const specialization of RETAIL_SPECIALIZATIONS) {
      for (const source of ["wowhead", "icy-veins"]) {
        statuses.push({ source, class: specialization.class, spec: specialization.spec, status: "ok" });
        for (const mode of ["raid", "mythic_plus", "delves"]) {
          for (let variant = 0; variant < 10; variant += 1) {
            rows.push({ source, class: specialization.class, spec: specialization.spec, mode, build_name: `${mode}-${variant}`, extraction_status: "ok", import_code: `C${"A".repeat(65)}${index++}` });
          }
        }
      }
    }
    await Promise.all([
      writeFile(path.join(results, "talent-builds.json"), JSON.stringify(rows)),
      writeFile(path.join(results, "stat-priorities.json"), "[]"),
      writeFile(path.join(results, "scan-status.json"), JSON.stringify(statuses)),
      writeFile(path.join(addon, "TalentMinder.toc"), "## Interface: 120100\nTalentMinderGeneratedData.lua\n"),
    ]);
    run(["scripts/data-validate.mjs", results]);
    run(["scripts/data-generate.mjs", results, output]);
    run(["scripts/lua-syntax-check.mjs", output]);
    assert.match(await readFile(output, "utf8"), /TalentMinder:SetStatPriorityData/);

    if (process.platform === "win32") {
      const zip = path.join(root, "TalentMinder.zip");
      const command = `Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::CreateFromDirectory('${addon.replace(/'/g, "''")}', '${zip.replace(/'/g, "''")}', [IO.Compression.CompressionLevel]::Optimal, $true); [IO.Compression.ZipFile]::OpenRead('${zip.replace(/'/g, "''")}').Entries.FullName`;
      const result = spawnSync("powershell", ["-NoProfile", "-Command", command], { encoding: "utf8" });
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /^TalentMinder[\\/]/m);
      assert.equal(result.stdout.includes("tools/") || result.stdout.includes("tools\\"), false);
    }
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
