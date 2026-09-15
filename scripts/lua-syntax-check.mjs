import { readFile } from "node:fs/promises";

export function assertLuaSyntax(source) {
  const stack = [];
  let quote = null;
  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    if (quote) { if (char === "\\") index += 1; else if (char === quote) quote = null; continue; }
    if (char === "-" && source[index + 1] === "-") { while (index < source.length && source[index] !== "\n") index += 1; continue; }
    if (char === '"' || char === "'") { quote = char; continue; }
    if (char === "{" || char === "(" || char === "[") stack.push(char);
    if (char === "}" || char === ")" || char === "]") {
      if (stack.pop() !== ({ "}": "{", ")": "(", "]": "[" })[char]) throw new Error(`Invalid Lua delimiter near character ${index}.`);
    }
  }
  if (quote || stack.length) throw new Error("Unterminated Lua string or delimiter.");
}

const target = process.argv[2];
if (target) { assertLuaSyntax(await readFile(target, "utf8")); console.log(`Lua syntax check passed: ${target}`); }
