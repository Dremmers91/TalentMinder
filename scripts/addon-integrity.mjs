import { readFile } from "node:fs/promises";
import { assertLuaSyntax } from "./lua-syntax-check.mjs";

const generated = await readFile("addon/TalentMinder/TalentMinderGeneratedData.lua", "utf8");
if (!generated.trim()) throw new Error("Generated Lua file is empty.");
for (const required of ["TalentMinder.generatedBuildData", "TalentMinder.generatedStatPriorityData", "TalentMinder.generatedDatasetMetadata", "TalentMinder:SetBuildData", "TalentMinder:SetStatPriorityData"]) {
  if (!generated.includes(required)) throw new Error(`Generated Lua is missing ${required}.`);
}
assertLuaSyntax(generated);
