import { createRequire } from "node:module";
import { hashExport } from "./scrapers.mjs";

const require = createRequire(import.meta.url);
export const RETAIL_SPECIALIZATIONS = require("../../retail-specializations.json");
const specializationByName = new Map(RETAIL_SPECIALIZATIONS.map((item) => [`${item.classSlug}/${item.specSlug}`, item]));
const VALID_EXPORT = /^[A-Za-z0-9+/]{60,}={0,2}$/;
const SOURCE_NAMES = new Map([["wowhead", "Wowhead"], ["icy-veins", "Icy Veins"], ["icy veins", "Icy Veins"], ["icyveins", "Icy Veins"]]);
const PVP_MODES = new Set(["solo_shuffle", "arena_2v2", "arena_3v3", "battleground_blitz", "rated_battlegrounds", "pvp_unspecified"]);
const CATEGORY_BY_MODE = new Map([["mythic_plus", "Mythic+"], ["aoe", "Mythic+"], ["raid", "Raid"], ["single_target", "Raid"], ["delves", "Delves"]]);

function slug(value) {
  return String(value ?? "").trim().toLowerCase().replace(/\s+/g, "-");
}

export function normalizeSourceName(value) {
  return SOURCE_NAMES.get(String(value ?? "").trim().toLowerCase().replace(/_/g, " ")) ?? null;
}

function specializationFor(row) {
  return specializationByName.get(`${slug(row.class)}/${slug(row.spec)}`) ?? null;
}

function normalizedExport(value) {
  const exportString = typeof value === "string" ? value.trim() : "";
  return VALID_EXPORT.test(exportString) ? exportString : null;
}

export function addonCategories(modes) {
  const values = Array.isArray(modes) ? modes : [modes];
  const categories = new Set();
  for (const mode of values) {
    if (PVP_MODES.has(mode)) categories.add("PvP");
    else if (CATEGORY_BY_MODE.has(mode)) categories.add(CATEGORY_BY_MODE.get(mode));
  }
  return [...categories].sort();
}

function rowModes(row) {
  const modes = Array.isArray(row.modes) && row.modes.length ? row.modes : [row.mode];
  return modes.filter((mode) => typeof mode === "string");
}

function variantLabel(row) {
  const buildName = String(row.build_name || "Recommended build").trim() || "Recommended build";
  const heroTree = String(row.hero_tree || "").trim();
  if (!heroTree || buildName.toLocaleLowerCase().includes(heroTree.toLocaleLowerCase())) return buildName;
  return `${heroTree} — ${buildName}`;
}

export function scannerRowToBuilds(row) {
  if (row?.extraction_status !== "ok") return [];
  const specialization = specializationFor(row);
  const source = normalizeSourceName(row.source);
  const talentImportString = normalizedExport(row.import_code);
  if (!specialization || !source || !talentImportString) return [];
  const variant = variantLabel(row);
  const modes = rowModes(row);
  return addonCategories(modes).map((content) => ({
    classFile: specialization.classFile, specId: specialization.specId,
    specName: `${specialization.spec} ${specialization.class}`, source, content, variant,
    talentImportString, hash: hashExport(talentImportString), sourceUrl: row.source_url,
    checkedAt: row.retrieved_at,
    scannerMetadata: { buildName: String(row.build_name || "Recommended build").trim() || "Recommended build", heroTree: row.hero_tree, recommended: row.recommended, best: row.best, modes },
  }));
}

export function scannerRowToBuild(row) {
  return scannerRowToBuilds(row)[0] ?? null;
}

function buildKey(build) {
  return [build.classFile, build.specId, build.source, build.content, build.variant, build.talentImportString].join("\0");
}

export function scannerRowsToBuilds(rows) {
  const unique = new Map();
  for (const build of rows.flatMap(scannerRowToBuilds)) {
    const key = buildKey(build);
    const existing = unique.get(key);
    if (!existing || JSON.stringify(build).localeCompare(JSON.stringify(existing)) < 0) unique.set(key, build);
  }
  return [...unique.values()].sort((a, b) => buildKey(a).localeCompare(buildKey(b)));
}

export function scannerRowToStatPriority(row) {
  const specialization = specializationFor(row);
  if (normalizeSourceName(row?.source) !== "Wowhead" || !specialization || !Array.isArray(row.stats)) return null;
  const stats = row.stats.map((stat) => String(stat).trim()).filter(Boolean);
  if (!stats.length) return null;
  return { classFile: specialization.classFile, specId: specialization.specId, source: "Wowhead", sourceUrl: row.source_url,
    checkedAt: row.retrieved_at, label: String(row.label || "Stat Priority").trim() || "Stat Priority", stats };
}

export function scannerRowsToStatPriorities(rows) {
  const unique = new Map();
  for (const priority of rows.map(scannerRowToStatPriority).filter(Boolean)) {
    const key = [priority.classFile, priority.specId, priority.label, priority.stats.join("\0")].join("\0");
    if (!unique.has(key)) unique.set(key, priority);
  }
  return [...unique.values()].sort((a, b) =>
    [a.classFile, a.specId, a.label, a.stats.join("\0")].join("\0").localeCompare([b.classFile, b.specId, b.label, b.stats.join("\0")].join("\0")));
}
