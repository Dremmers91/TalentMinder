# Python talent build scanner

Scope: **current retail expansion only**. The default target is Midnight (12.x), based on the live guides inspected for this project. Classic, PTR, and known older-expansion routes are excluded. A guide must identify the target expansion in its title/introduction or the matching major patch in its title before builds are extracted. Unconfirmed pages are skipped explicitly. At the next expansion, update `expansion` and `patch_major` in the input; the script does not automatically detect expansion launches.

Requires Python 3.10 or later. Run these commands in the folder containing the script:

```sh
python -m pip install -r scanner-requirements.txt
python -m playwright install chromium
python talent_scanner.py scanner-input.json
```

On Windows, use `py` instead of `python` if that is how Python is installed.

Edit `scanner-input.json` to list your class/spec combinations. The scanner uses these fixed retail routes for each combination. The `{role}` suffix is `dps`, `healer`, or `tank` for the selected specialization; the Icy Veins healer route uses `healing`.

```text
Icy Veins PvE talents:
https://www.icy-veins.com/wow/{spec}-{class}-pve-{role}-spec-builds-talents

Icy Veins PvP:
https://www.icy-veins.com/wow/{spec}-{class}-pvp-talents-and-builds

Wowhead PvE:
https://www.wowhead.com/guide/classes/{class}/{spec}/talent-builds-pve-{role}

Wowhead stat priority:
https://www.wowhead.com/guide/classes/{class}/{spec}/stat-priority-pve-{role}

```

Names are converted to lowercase hyphenated slugs, for example `Death Knight` becomes `death-knight`. The sample contains Unholy Death Knight and Balance Druid: three guide URLs per spec, six pages total. No linked pages are crawled. Build tabs within those pages can still be read/exported.

`content: ["pve", "pvp"]` enables all applicable patterns. The supplied companion configuration currently enables Wowhead and Icy Veins. Icy Veins PvP routes are attempted for DPS and healer specializations only because it does not publish tank PvP build pages.

The default browser is headless and isolated from your personal browser profile. To see it:

The enabled sites run concurrently. Each site scans its own pages sequentially, with its own browser instance. Clipboard exports are locked across workers to prevent code mix-ups. Per-site checkpoints are under `scan-results/per-site/`; combined reports update whenever a site finishes.

To disable concurrency, add `--workers 1`. The default is `--workers 2`.

```sh
python talent_scanner.py scanner-input.json --headed --output my-builds
```

Reports are checkpointed after each page:

- `scan-results/talent-builds.json`: build records and available import strings.
- `scan-results/stat-priorities.json`: Wowhead-only ordered PvE stat lists. Multiple
  labeled lists for a spec (such as survivability and DPS) are retained separately.
- `scan-results/talent-builds.md`: readable report with copyable codes.
- `scan-results/scan-status.json`: attempted pages, failures, and coverage limitations.

The scanner uses actual rendered pages through [Playwright](https://playwright.dev/python/docs/library) and parses bounded code blocks and build links using [Beautiful Soup](https://www.crummy.com/software/BeautifulSoup/bs4/doc/). It does not use an AI API or require an API key.

## What is implemented

Build names are checked case-insensitively for the whole words **best** and **recommended**. Either sets `recommended: true`; **best** also sets `best: true`. `recommendation_labels` preserves which words matched, and the Markdown report displays BEST/RECOMMENDED badges. Names without those words remain unmarked unless a separate source recommendation was detected. This marks the site's labels; it does not rank builds independently.

- Class/spec JSON input and validation, two site adapters, PvE/PvP route selection.
- Wowhead Blizzard import-code links and row/heading association.
- Icy Veins text/code blocks and named Export Talents controls, plus recognized build tabs.
- Fixed Wowhead PvE and Icy Veins PvE/PvP routes, without guide discovery.
- Fixed Wowhead PvE stat-priority routes, with every ordered list under the guide's
  **Best Stats** section retained for generated addon data.
- Sequential clipboard exports, malformed-code detection, and explicit failure records.

## Current limitations

This is a best-effort scanner, not a guarantee of exhaustive recommendation coverage. Site layouts and access controls change. Headless Chromium may be blocked even if a normal personal browser works. The scanner stops on access challenges and records the failure; it does not bypass them.

Builds with explicit best/recommended labels are marked. Other extracted builds are retained with recommendation basis `unconfirmed`, so useful codes are not silently lost. Compare those labels with the linked guide before choosing a build. Prose/table recommendation conflicts are not automatically resolved. Multi-use labels such as M+/Delves remain in `build_name`; `mode` records the first recognized mode.

Some Icy Veins generic selectors and nested hero-tree selectors may require adapter updates. Hero-tree names are recognized for the examples investigated; other names may be null. A clipboard success message alone is insufficient: empty clipboard output is recorded as a failed export.

Only the configured fixed patterns are attempted. If a class/spec does not have a guide at that URL, it is reported as missing or failed; the scanner does not search for alternatives.

Codes are checked for basic string shape only. They are not decoded or tested in-game. This script does not implement every advanced requirement in TALENT-BUILD-SCANNER-INSTRUCTIONS.md, including full talent-tree validation, all recommendation conflicts, or all optional filters.

## Tests

```sh
python -m unittest -v test_talent_scanner.py
```

The tests exercise fixture HTML, malformed codes, source/row matching, PvP routes, and bounded discovery. They do not establish live end-to-end success on every source.
