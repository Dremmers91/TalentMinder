import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { renderLua } from "../lib/lua.mjs";

const code = "C" + "A".repeat(70);
const generatedData = {
  MAGE: {
    62: {
      Wowhead: {
        "Mythic+": { variantOrder: ["Default", "Burst"], variants: { Default: { talentImportString: `${code}1` }, Burst: { talentImportString: `${code}2` } } },
        Raid: { talentImportString: `${code}3` },
        Delves: { talentImportString: `${code}4` },
      },
      "Icy Veins": { PvP: { variantOrder: ["Solo"], variants: { Solo: { talentImportString: `${code}5` } } } },
    },
  },
};

function addonLookup({ source, content, variant }) {
  const categories = { "M+": "Mythic+", PVP: "PvP", Raid: "Raid", Delves: "Delves" };
  const entry = generatedData.MAGE[62]?.[source]?.[categories[content]];
  if (!entry) return "";
  if (!entry.variants) return entry.talentImportString;
  return (entry.variants[variant] ?? entry.variants[entry.variantOrder[0]]).talentImportString;
}

test("generated Lua declares data and metadata before applying it", () => {
  const lua = renderLua([{ classFile: "MAGE", specId: 62, source: "Wowhead", content: "Raid", variant: "Raid", talentImportString: code }],
    [{ classFile: "MAGE", specId: 62, label: "Stat Priority", stats: ["Haste"] }]);
  const order = ["local _, TalentMinder", "TalentMinder.generatedBuildData", "TalentMinder.generatedStatPriorityData", "TalentMinder.generatedDatasetMetadata", "TalentMinder:SetBuildData", "TalentMinder:SetStatPriorityData"].map((needle) => lua.indexOf(needle));
  assert.ok(order.every((position) => position >= 0));
  assert.deepEqual([...order].sort((a, b) => a - b), order);
  assert.match(lua, /schemaVersion = 1/);
  assert.match(lua, /contentHash = "[a-f0-9]{64}"/);
});

test("addon lookup contract selects sources, categories, variants, and missing builds", () => {
  assert.equal(addonLookup({ source: "Wowhead", content: "M+", variant: "Burst" }), `${code}2`);
  assert.equal(addonLookup({ source: "Wowhead", content: "Raid" }), `${code}3`);
  assert.equal(addonLookup({ source: "Wowhead", content: "Delves" }), `${code}4`);
  assert.equal(addonLookup({ source: "Icy Veins", content: "PVP", variant: "Solo" }), `${code}5`);
  assert.equal(addonLookup({ source: "Wowhead", content: "M+", variant: "Unknown" }), `${code}1`);
  assert.equal(addonLookup({ source: "Icy Veins", content: "Raid" }), "");
});

test("TOC loads generated data after the data API and before consumers", async () => {
  const toc = (await readFile(new URL("../../../addon/TalentMinder/TalentMinder.toc", import.meta.url), "utf8")).split(/\r?\n/);
  const indexOf = (name) => toc.indexOf(name);
  assert.ok(indexOf("TalentMinderData.lua") < indexOf("TalentMinderGeneratedData.lua"));
  assert.ok(indexOf("TalentMinderGeneratedData.lua") < indexOf("TalentMinderImport.lua"));
  assert.ok(indexOf("TalentMinderGeneratedData.lua") < indexOf("TalentWindow.lua"));
  assert.ok(indexOf("TalentMinderGeneratedData.lua") < indexOf("TalentMinderStats.lua"));
});

test("stat priorities and dataset metadata are available after generated loading", () => {
  const statPriorities = { MAGE: { 62: { source: "Wowhead", priorityOrder: ["Stat Priority"], priorities: { "Stat Priority": ["Haste"] } } } };
  const metadata = { schemaVersion: 1, contentHash: "a".repeat(64) };
  assert.deepEqual(statPriorities.MAGE[62].priorities[statPriorities.MAGE[62].priorityOrder[0]], ["Haste"]);
  assert.equal(metadata.schemaVersion, 1);
  assert.match(metadata.contentHash, /^[a-f0-9]{64}$/);
});
