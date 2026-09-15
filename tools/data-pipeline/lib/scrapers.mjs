import { createHash } from "node:crypto";

const IMPORT_CODE = /(?<![A-Za-z0-9+/=])[A-Za-z0-9+/=]{30,}(?![A-Za-z0-9+/=])/g;

export function normalizeExport(value) {
  return value.replace(/\s+/g, "").trim();
}

export function hashExport(value) {
  return createHash("sha256").update(normalizeExport(value)).digest("hex");
}

export function findExports(text) {
  return [...new Set((text.match(IMPORT_CODE) || []).map(normalizeExport))];
}

async function loadWithBrowser(url) {
  let chromium;
  try {
    ({ chromium } = await import("playwright"));
  } catch {
    throw new Error("Browser extraction needs Playwright. Run npm install, then npx playwright install chromium.");
  }

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45_000 });
    await page.waitForTimeout(1_500);
    return await page.locator("body").innerText();
  } finally {
    await browser.close();
  }
}

async function loadTarget(target) {
  if (target.adapter === "browser" || target.adapter === "icy-veins") return loadWithBrowser(target.url);
  const response = await fetch(target.url, {
    headers: { "user-agent": "TalentMinder Companion/0.1 (personal local updater)" },
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.text();
}

function labelFor(target, index, total) {
  if (target.variant) return target.variant;
  if (total === 1) return undefined;
  return `Build ${index + 1}`;
}

function icyVeinsContent(label) {
  return label;
}

export function parseIcyVeinsQuickStarts(text, target) {
  const codePattern = "(?<code>[A-Za-z0-9+/=]{30,})";
  const pattern = new RegExp(`(?:^|\\n)[^\\n]*? (?<content>Raid|Mythic\\+|Delves) - (?<variant>[^\\n]+)\\s+${codePattern}`, "g");
  const builds = [];
  for (const match of text.matchAll(pattern)) {
    builds.push({
      classFile: target.classFile,
      specId: target.specId,
      specName: target.specName,
      source: target.source,
      content: icyVeinsContent(match.groups.content),
      variant: match.groups.variant.trim(),
      talentImportString: normalizeExport(match.groups.code),
      sourceUrl: target.url,
      checkedAt: new Date().toISOString(),
    });
  }
  return builds;
}

export async function scrapeTarget(target) {
  const text = await loadTarget(target);
  if (target.adapter === "icy-veins") {
    const builds = parseIcyVeinsQuickStarts(text, target);
    if (!builds.length) throw new Error("No labelled Icy Veins Quick Start export was found.");
    return builds.map((build) => ({ ...build, hash: hashExport(build.talentImportString) }));
  }
  if (!target.content) {
    throw new Error(`No labelled ${target.source} parser is available for this guide yet.`);
  }
  const exports = findExports(text);
  if (!exports.length) throw new Error("No talent export code was found on the page.");

  return exports.map((talentImportString, index) => ({
    classFile: target.classFile,
    specId: target.specId,
    specName: target.specName,
    source: target.source,
    content: target.content,
    variant: labelFor(target, index, exports.length),
    talentImportString,
    hash: hashExport(talentImportString),
    sourceUrl: target.url,
    checkedAt: new Date().toISOString(),
  }));
}
