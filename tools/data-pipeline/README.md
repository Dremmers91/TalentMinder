# Data pipeline

This package converts scanner JSON into the canonical addon file:
`addon/TalentMinder/TalentMinderGeneratedData.lua`.

```sh
node tools/data-pipeline/scripts/generate-lua.mjs tools/scanner/results/current
```
