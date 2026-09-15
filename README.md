# TalentMinder

TalentMinder is a WoW addon with an offline scanner and data pipeline. The addon
does not host a local website or require an approval service.

## Layout

- `addon/TalentMinder/` — addon files, including the only generated Lua data file.
- `tools/scanner/` — Python Playwright scanner, input, and tests.
- `tools/data-pipeline/` — Node parsers, scanner adapters, Lua escaping, and Lua generator.
- `scripts/` — repository validation helpers.

## Data pipeline

Install scanner prerequisites once:

```sh
python -m pip install -r tools/scanner/scanner-requirements.txt
python -m playwright install chromium
```

Run `npm run data:update` to scan both configured sources, validate the complete
scan, normalize its results, and atomically replace
`addon/TalentMinder/TalentMinderGeneratedData.lua`. It never retains prior
records: the validated scan is the complete snapshot.

For individual stages, use `npm run data:scan`, `npm run data:validate -- <scan-dir>`,
or `npm run data:generate -- <scan-dir> [output-file]`. Scanner artifacts are
ignored under `tools/scanner/.artifacts/`.

Generated Lua contains a stable SHA-256 content hash. Retrieval timestamps and
source URLs are not emitted, so unchanged normalized recommendations do not
produce a diff.

Publication requires complete coverage from Wowhead and Icy Veins. It rejects
blocked/error targets, missing configured specializations, missing source builds,
invalid talent strings, and drops below 80% of the previous build or spec
coverage. A partial target is allowed only when it still has valid builds and
every rejected record is individually marked `malformed_code`.

## Tests

```sh
npm test
```

Run the production gate with `npm run addon:validate`. Package the validated
addon with `npm run addon:package`; it writes `dist/TalentMinder-0.1.0.zip`.

## Install from GitHub Releases

Download `TalentMinder-<version>.zip` from this repository's GitHub Releases
page. Extract it into your World of Warcraft installation so the resulting path
is `World of Warcraft/_retail_/Interface/AddOns/TalentMinder/`. The folder must
contain `TalentMinder.toc` directly; do not leave an extra nested ZIP folder.

## Scheduled updates

`.github/workflows/update-data.yml` runs every Tuesday at 17:00 UTC, after the
North American reset, and can also be started manually. To change the schedule,
edit its `on.schedule[0].cron` value; GitHub Actions cron expressions use UTC.

Set `PYTHON` if your Python executable has a nonstandard name or location.

To create a distributable addon archive on Windows:

```powershell
npm run package:addon
```
