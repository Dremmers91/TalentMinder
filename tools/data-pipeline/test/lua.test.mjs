import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { escapeLuaString, renderLua } from "../lib/lua.mjs";
import { findExports, hashExport, parseIcyVeinsQuickStarts } from "../lib/scrapers.mjs";
import { RETAIL_SPECIALIZATIONS, addonCategories, normalizeSourceName, scannerRowToBuild, scannerRowToBuilds, scannerRowsToBuilds, scannerRowToStatPriority } from "../lib/scanner-adapter.mjs";

function assertValidGeneratedLuaSyntax(lua) {
  // The generator uses a fixed Lua table template. Validate each generated
  // double-quoted literal so control characters or unterminated quotes cannot
  // make that template invalid Lua.
  for (let index = 0; index < lua.length; index += 1) {
    if (lua[index] !== '"') continue;
    let closed = false;
    for (index += 1; index < lua.length; index += 1) {
      const character = lua[index];
      assert.notEqual(character, "\n", "Lua quoted strings cannot contain literal newlines");
      assert.notEqual(character, "\r", "Lua quoted strings cannot contain literal carriage returns");
      assert.ok(character.charCodeAt(0) >= 32, "Lua quoted strings cannot contain raw control characters");
      if (character === "\\") {
        index += 1;
        assert.ok(index < lua.length, "Lua escape cannot end a string");
        continue;
      }
      if (character === '"') {
        closed = true;
        break;
      }
    }
    assert.ok(closed, "Lua quoted string must be closed");
  }
}

test("extracts and normalizes unique talent exports", () => {
  const code = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA";
  assert.deepEqual(findExports(`Copy ${code} and ${code}`), [code]);
  assert.equal(hashExport(code), hashExport(` ${code} `));
});

test("keeps Icy Veins content and hero talent labels", () => {
  const code = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA";
  const builds = parseIcyVeinsQuickStarts(`Arcane Raid - Sunfury\n${code}\nArcane Delves - Spellslinger\n${code}`, { classFile: "MAGE", specId: 62, specName: "Arcane Mage", source: "Icy Veins", url: "https://example.test" });
  assert.deepEqual(builds.map(({ content, variant }) => [content, variant]), [["Raid", "Sunfury"], ["Delves", "Spellslinger"]]);
});

test("renders a source/content/variant data table", () => {
  const lua = renderLua([{ classFile: "MAGE", specId: 62, source: "Icy Veins", content: "PvP", variant: "Solo", talentImportString: "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA" }]);
  assert.match(lua, /MAGE/);
  assert.match(lua, /\["Icy Veins"\]/);
  assert.match(lua, /variantOrder = \{ "Solo" \}/);
});

test("serializes scraped text as valid one-line Lua strings", () => {
  const scrapedTitle = "Arcane Raid -\nSunfury \\\\ \\\"quoted\\\"";
  const lua = renderLua([{
    classFile: "MAGE",
    specId: 62,
    source: 'Wowhead\r\n"Source"',
    content: "Raid\tMode",
    variant: scrapedTitle,
    talentImportString: "C4DA\\\\safe",
  }]);

  const serializedTitle = escapeLuaString(scrapedTitle);
  assert.equal(serializedTitle.includes("\n"), false);
  assert.equal(serializedTitle.includes("\r"), false);
  assert.ok(serializedTitle.startsWith("Arcane Raid - Sunfury "));
  assert.ok(lua.includes(`"${serializedTitle}"`));
  assert.match(lua, /\["Wowhead \\\"Source\\\""\]/);
  assert.match(lua, /\["Raid Mode"\]/);
  assert.match(lua, /talentImportString = "C4DA\\\\\\\\safe"/);
  assertValidGeneratedLuaSyntax(lua);
});

test("content hash and Lua output ignore retrieval metadata", () => {
  const build = { classFile: "MAGE", specId: 62, source: "Wowhead", content: "Raid", variant: "Raid", talentImportString: "C" + "A".repeat(70), checkedAt: "2026-01-01", sourceUrl: "https://first.test" };
  const priority = { classFile: "MAGE", specId: 62, label: "Stat Priority", stats: ["Intellect", "Haste"], checkedAt: "2026-01-01", sourceUrl: "https://first.test" };
  const first = renderLua([build], [priority]);
  const second = renderLua([{ ...build, checkedAt: "2026-02-02", sourceUrl: "https://second.test" }], [{ ...priority, checkedAt: "2026-02-02", sourceUrl: "https://second.test" }]);
  assert.equal(first, second);
  assert.match(first, /^-- Content hash: [a-f0-9]{64}$/m);
  assert.equal(first.includes("checkedAt"), false);
  assert.equal(first.includes("sourceUrl"), false);
});

test("maps a scanner record into addon build data", () => {
  const code = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA";
  const build = scannerRowToBuild({ class: "Mage", spec: "Arcane", source: "icy-veins", mode: "mythic_plus", build_name: "Sunfury Mythic+", import_code: code, extraction_status: "ok", source_url: "https://example.test" });
  assert.equal(build.classFile, "MAGE");
  assert.equal(build.specId, 62);
  assert.equal(build.source, "Icy Veins");
  assert.equal(build.content, "Mythic+");
  assert.equal(build.variant, "Sunfury Mythic+");
});

test("normalizes scanner sources and excludes malformed exports", () => {
  const code = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA";
  assert.equal(normalizeSourceName("ICY_VEINS"), "Icy Veins");
  assert.equal(normalizeSourceName("wowhead"), "Wowhead");
  assert.equal(normalizeSourceName("other source"), null);
  const base = { class: "Mage", spec: "Arcane", source: "ICY_VEINS", mode: "raid", build_name: "Raid", extraction_status: "ok", import_code: code };
  assert.equal(scannerRowToBuild(base).source, "Icy Veins");
  assert.equal(scannerRowToBuild({ ...base, import_code: "not an export" }), null);
  assert.equal(scannerRowToBuild({ ...base, import_code: `${code.slice(0, 20)} ${code.slice(20)}` }), null);
  assert.equal(scannerRowToBuild({ ...base, import_code: undefined }), null);
});

test("expands multi-mode builds, excludes Open World, and deduplicates deterministically", () => {
  const code = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA";
  const build = { class: "Mage", spec: "Arcane", source: "wowhead", modes: ["open_world", "delves", "mythic_plus"], build_name: "Mythic+/Delves", extraction_status: "ok", import_code: code };
  assert.deepEqual(scannerRowToBuilds(build).map((item) => item.content), ["Delves", "Mythic+"]);
  const duplicate = { ...build, source_url: "https://example.test" };
  const normalized = scannerRowsToBuilds([duplicate, build]);
  assert.deepEqual(normalized.map((item) => item.content), ["Delves", "Mythic+"]);
  assert.equal(normalized.some((item) => item.content === "Open World"), false);
});

test("maps every supported scanner mode to an accessible addon category", () => {
  assert.deepEqual(addonCategories(["mythic_plus", "aoe"]), ["Mythic+"]);
  assert.deepEqual(addonCategories(["raid", "single_target"]), ["Raid"]);
  assert.deepEqual(addonCategories(["delves", "open_world"]), ["Delves"]);
  assert.deepEqual(addonCategories(["solo_shuffle", "arena_2v2", "arena_3v3", "battleground_blitz", "rated_battlegrounds", "pvp_unspecified"]), ["PvP"]);
});

test("catalog includes all Retail specs including Devourer", () => {
  assert.equal(RETAIL_SPECIALIZATIONS.length, 40);
  assert.deepEqual(RETAIL_SPECIALIZATIONS.find((item) => item.class === "Demon Hunter" && item.spec === "Devourer"),
    { class: "Demon Hunter", classSlug: "demon-hunter", classFile: "DEMONHUNTER", spec: "Devourer", specSlug: "devourer", specId: 1480, role: "dps" });
  for (const specialization of RETAIL_SPECIALIZATIONS) {
    const build = scannerRowToBuild({ class: specialization.class, spec: specialization.spec, source: "Wowhead", mode: "raid", build_name: "Raid", extraction_status: "ok", import_code: "C" + "A".repeat(70) });
    assert.equal(build?.classFile, specialization.classFile);
    assert.equal(build?.specId, specialization.specId);
  }
});

test("scanner input configures every shared Retail specialization", async () => {
  const input = JSON.parse(await readFile(new URL("../../scanner/scanner-input.json", import.meta.url), "utf8"));
  assert.deepEqual(new Set(input.specs.map((item) => `${item.class}/${item.spec}`)),
    new Set(RETAIL_SPECIALIZATIONS.map((item) => `${item.class}/${item.spec}`)));
});

test("renders multiple labeled Wowhead stat priorities for one spec", () => {
  const survival = scannerRowToStatPriority({ class: "Paladin", spec: "Protection", source: "wowhead", source_url: "https://example.test", label: "Survivability Stat Priority", stats: ["Strength", "Haste", "Mastery"] });
  const damage = scannerRowToStatPriority({ class: "Paladin", spec: "Protection", source: "wowhead", source_url: "https://example.test", label: "DPS Stat Priority", stats: ["Strength", "Haste", "Critical Strike"] });
  const lua = renderLua([], [survival, damage]);
  assert.match(lua, /TalentMinder\.generatedStatPriorityData/);
  assert.match(lua, /priorityOrder = \{ "DPS Stat Priority", "Survivability Stat Priority" \}/);
  assert.match(lua, /\["DPS Stat Priority"\] = \{ "Strength", "Haste", "Critical Strike" \}/);
  assertValidGeneratedLuaSyntax(lua);
});

test("keeps selectable non-Best Wowhead records without Open World output", () => {
  const code = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA";
  const base = { class: "Mage", spec: "Arcane", source: "wowhead", mode: "raid", build_name: "Raid", import_code: code, extraction_status: "ok", source_url: "https://example.test" };
  assert.equal(scannerRowToBuild(base)?.content, "Raid");
  assert.equal(scannerRowToBuild({ ...base, mode: "open_world" }), null);
});
