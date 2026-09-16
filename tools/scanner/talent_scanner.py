#!/usr/bin/env python3
"""Conservative WoW talent scanner. Python 3.10+; see SCANNER-README.md."""
import argparse
import json
import re
import copy
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin, urlsplit, unquote

from bs4 import BeautifulSoup

SOURCES = ('wowhead', 'icy-veins')
DEFAULT_SOURCES = ('wowhead', 'icy-veins')
EXPORT_LOCK = threading.Lock()
HOSTS = {'wowhead': 'www.wowhead.com', 'icy-veins': 'www.icy-veins.com'}
CURRENT_EXPANSION = 'Midnight'
CURRENT_PATCH_MAJOR = 12


def live_retail_url(url):
    parts = urlsplit(url)
    host = parts.hostname or ''
    path = unquote(parts.path).lower()
    return not (host.startswith(('ptr.', 'classic.')) or
                re.search(r'/(?:ptr(?:-\d+)?|classic[^/]*|tbc|wotlk[^/]*|cata[^/]*|mop[^/]*)(?:/|$)', path) or
                re.search(r'\b(?:dragonflight|shadowlands|war-within|battle-for-azeroth|legion)\b', path))


def expansion_matches(html, expansion=CURRENT_EXPANSION, patch_major=CURRENT_PATCH_MAJOR):
    soup = BeautifulSoup(html, 'html.parser')
    root = soup.find('main') or soup
    # Examine the guide itself, not site-wide menus, comments, or old changelogs.
    for el in root.select('nav, footer, script, style, [id*=comments]'):
        el.decompose()
    title = text(root.find('h1'))
    patches = re.findall(r'\b(\d{1,2})\.\d+(?:\.\d+)?\b', title)
    if patches:
        return all(int(p) == patch_major for p in patches)
    if expansion.lower() in title.lower():
        return True
    h1 = root.find('h1')
    intro = []
    if h1:
        for node in h1.find_all_next(['p', 'h2']):
            if node.name == 'h2':
                break
            intro.append(text(node))
    return expansion.lower() in ' '.join(intro).lower()
RETAIL_CATALOG_PATH = Path(__file__).resolve().parents[1] / 'retail-specializations.json'
RETAIL_SPECIALIZATIONS = json.loads(RETAIL_CATALOG_PATH.read_text(encoding='utf-8'))
SPECIALIZATIONS_BY_SLUG = {(item['classSlug'], item['specSlug']): item for item in RETAIL_SPECIALIZATIONS}
SPECS = {item['classSlug']: [] for item in RETAIL_SPECIALIZATIONS}
for item in RETAIL_SPECIALIZATIONS:
    SPECS[item['classSlug']].append(item['specSlug'])
CODE = re.compile(r'^[A-Za-z0-9+/]{60,}={0,2}$')
TOKEN = re.compile(r'(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{60,}={0,2}(?![A-Za-z0-9+/])')
# Current Retail Hero Talent trees. A page may put this label in either the
# heading or the build row, so extraction checks both locations below.
HERO = re.compile(r"Aldrachi Reaver|Archon|Chronowarden|Colossus|Conduit of the Celestials|Dark Ranger|Deathbringer|Deathstalker|Diabolist|Elune.s Chosen|Farseer|Fatebound|Fel.Scarred|Flameshaper|Frostfire|Hellcaller|Herald of the Sun|Keeper of the Grove|Lightsmith|Master of Harmony|Mountain Thane|Oracle|Pack Leader|Rider of the Apocalypse|San.layn|Scalecommander|Sentinel|Shado.Pan|Slayer|Soul Harvester|Spellslinger|Stormbringer|Sunfury|Templar|Totemic|Trickster|Voidweaver|Wildstalker", re.I)


def slug(value):
    return re.sub(r'\s+', '-', value.strip().lower())


def text(node):
    return node.get_text(' ', strip=True) if node else ''


def role_for(cls, spec):
    specialization = SPECIALIZATIONS_BY_SLUG.get((cls, spec))
    return specialization['role'] if specialization else 'dps'


def mode_for(label, url):
    value = (label + ' ' + url).lower()
    for pattern, mode in [(r'blitz', 'battleground_blitz'), (r'solo|shuffle', 'solo_shuffle'),
                          (r'3v3', 'arena_3v3'), (r'2v2', 'arena_2v2'), (r'\brbg\b', 'rated_battlegrounds'),
                          (r'mythic|m\+|m%2b', 'mythic_plus'), (r'delve', 'delves'),
                          (r'open.world', 'open_world'), (r'raid', 'raid'),
                          (r'single.target|\bst\b', 'single_target')]:
        if re.search(pattern, value):
            return mode
    return 'pvp_unspecified' if 'pvp' in value else 'pve_unspecified'


def record(source, url, label, code=None, calculator=None, recommended=False, hero=None):
    valid = bool(code and CODE.fullmatch(code.strip()))
    is_best = bool(re.search(r'\bbest\b', label, re.I))
    is_recommended = bool(re.search(r'\brecommended\b', label, re.I))
    matched_labels = [name for name, matched in [('best', is_best), ('recommended', is_recommended)] if matched]
    return dict(source=source, source_url=url, build_name=label, mode=mode_for(label, url), modes=modes_for(label, url),
                hero_tree=hero, best=is_best,
                recommended=bool(recommended or is_best or is_recommended),
                recommendation_labels=matched_labels,
                recommendation_basis='build_name' if matched_labels else ('source_label' if recommended else 'unconfirmed'),
                import_code=code.strip() if valid else None, raw_import_code=code,
                calculator_url=calculator,
                extraction_status='ok' if valid else ('malformed_code' if code else 'no_import_code'),
                validation_level='extracted_only' if valid else None)


def parse_html(html, source, url):
    """Extract bounded links/blocks, never combine a talent heatmap into a build."""
    soup = BeautifulSoup(html, 'html.parser')
    root = soup.find('main') or soup
    # Exclude comments and executable content from candidate-code searches.
    for el in root.select('script, style, noscript, template, nav, footer, [hidden], [id*=comments], .comments'):
        el.decompose()
    results = []
    for link in root.select('a[href*="talent-calc/blizzard/"]'):
        href = urljoin(url, link['href'])
        code = unquote(urlsplit(href).path.split('/blizzard/', 1)[1])
        if re.search(r'[<>"\s]', code):
            continue  # HTML fallback fragments are not build records.
        row = link.find_parent('tr')
        heading = link.find_previous(['h3', 'h2'])
        label = text(row.find(['td', 'th'])) if row else text(heading)
        label = label or 'Unlabelled talent build'
        hero = HERO.search(text(row) + ' ' + text(heading))
        recommended = bool(re.search(r'\bbest\b|recommend', label, re.I))
        results.append(record(source, url, label, code, href, recommended,
                              hero.group() if hero else None))
    # Icy Veins Quick Start codes are often text, inputs, or copy-button data.
    if source == 'icy-veins':
        candidates = []
        for node in root.find_all(string=TOKEN):
            if node.parent.name not in ('script', 'style'):
                candidates.append((node.parent, str(node).strip()))
        for node in root.select('input[value], textarea, [data-clipboard-text], [data-copy]'):
            candidates.append((node, node.get('value') or node.get('data-clipboard-text')
                               or node.get('data-copy') or text(node)))
        for node, raw in candidates:
            if not CODE.fullmatch(raw):
                continue
            parent = node
            label = ''
            for _ in range(4):
                if not parent or parent is root:
                    break
                title = parent.get('title') or parent.get('aria-label')
                surrounding = text(parent).replace(raw, '').strip()
                if title or (surrounding and len(surrounding) < 180):
                    label = title or surrounding
                    if re.search(r'raid|mythic|delve|sunfury|spellslinger', label, re.I):
                        break
                parent = parent.parent
            label = label or 'Quick Start build (label unresolved)'
            hero = HERO.search(label)
            results.append(record(source, url, label, raw, recommended=bool(re.search(r'best|recommend', label, re.I)),
                                  hero=hero.group() if hero else None))
    return unique(results)


def modes_for(label, url):
    patterns = [(r'blitz', 'battleground_blitz'), (r'solo|shuffle', 'solo_shuffle'),
                (r'3v3', 'arena_3v3'), (r'2v2', 'arena_2v2'), (r'\brbg\b', 'rated_battlegrounds'),
                (r'mythic|m\+', 'mythic_plus'), (r'delve', 'delves'),
                (r'open.world', 'open_world'), (r'raid', 'raid'),
                (r'single.target|\bst\b', 'single_target'), (r'\baoe\b|cleave', 'aoe')]
    return [mode for pattern, mode in patterns if re.search(pattern, label, re.I)] or [mode_for(label, url)]


def unique(rows):
    """Merge identical source codes, keeping the most specific name and aliases."""
    seen, out = {}, []
    for row in rows:
        if re.search(r'[<>"\s]', row.get('raw_import_code') or ''):
            continue
        row = dict(row)
        row['modes'] = row.get('modes') or modes_for(row['build_name'], row['source_url'])
        key = (row['source_url'], row['import_code'] or (row['build_name'], row['calculator_url']))
        if key in seen:
            old = seen[key]
            def score(r):
                generic = r['build_name'] == 'Current build' or 'Talent Builds for' in r['build_name']
                return (not generic, bool(r.get('recommended')), bool(r.get('hero_tree')))
            winner, other = (row, old) if score(row) > score(old) else (old, row)
            merged = dict(winner)
            merged['aliases'] = sorted(set(old.get('aliases', []) + row.get('aliases', []) +
                                           [other['build_name']]) - {winner['build_name']})
            merged['modes'] = list(dict.fromkeys(winner['modes'] + other['modes']))
            if len(merged['modes']) > 1:
                merged['modes'] = [m for m in merged['modes'] if not m.endswith('_unspecified')]
            merged['calculator_url'] = winner.get('calculator_url') or other.get('calculator_url')
            merged['hero_tree'] = winner.get('hero_tree') or other.get('hero_tree')
            merged['recommended'] = bool(old.get('recommended') or row.get('recommended'))
            merged['best'] = bool(old.get('best') or row.get('best'))
            merged['recommendation_labels'] = sorted(set(old.get('recommendation_labels', []) + row.get('recommendation_labels', [])))
            old.clear()
            old.update(merged)
        else:
            seen[key] = row
            out.append(row)
    return out


def seeds(source, cls, spec, content):
    role = role_for(cls, spec)
    if source == 'wowhead':
        return ([f'https://www.wowhead.com/guide/classes/{cls}/{spec}/talent-builds-pve-{role}']
                if 'pve' in content else [])
    if source == 'icy-veins':
        pve_role = 'healing' if role == 'healer' else role
        pve = [f'https://www.icy-veins.com/wow/{spec}-{cls}-pve-{pve_role}-spec-builds-talents'] if 'pve' in content else []
        # Icy Veins does not publish PvP talent pages for tank specializations.
        pvp = [f'https://www.icy-veins.com/wow/{spec}-{cls}-pvp-talents-and-builds'] if 'pvp' in content and role != 'tank' else []
        return pve + pvp
    return []


def stat_priority_url(cls, spec):
    """The single, fixed Wowhead route used for a spec's PvE stat priorities."""
    return f'https://www.wowhead.com/guide/classes/{cls}/{spec}/stat-priority-pve-{role_for(cls, spec)}'


def parse_stat_priorities_html(html, source, url):
    """Return every labeled ordered stat list in Wowhead's Best Stats section.

    A guide may publish more than one list (for example, survival and DPS for a
    tank).  Lists are intentionally kept separate rather than flattening them
    into a single recommendation.
    """
    if source != 'wowhead':
        return []
    soup = BeautifulSoup(html, 'html.parser')
    root = soup.find('main') or soup
    for el in root.select('script, style, noscript, template, nav, footer, [hidden], [id*=comments], .comments'):
        el.decompose()
    heading = next((node for node in root.find_all(['h2', 'h3'])
                    if re.search(r'\bbest stats\b', text(node), re.I)), None)
    if not heading:
        return []
    lists, label = [], 'Stat Priority'
    for node in heading.next_elements:
        if node is heading:
            continue
        if getattr(node, 'name', None) == 'h2':
            break
        if getattr(node, 'name', None) in ('h3', 'h4'):
            candidate = text(node)
            if candidate:
                label = candidate
            continue
        if getattr(node, 'name', None) == 'ol':
            stats = [text(item) for item in node.find_all('li', recursive=False)]
            stats = [re.sub(r'^\s*\d+[.)]\s*', '', stat).strip() for stat in stats]
            stats = [stat for stat in stats if stat]
            if stats:
                lists.append({'label': label or 'Stat Priority', 'stats': stats})
            continue
        if getattr(node, 'name', None) in ('p', 'div'):
            # Wowhead has used plain text as well as subheadings for list labels.
            candidate = text(node)
            if re.search(r'(?:stat|priority)', candidate, re.I) and len(candidate) <= 100:
                label = candidate
    # BeautifulSoup's next_elements visits an <ol>'s descendants after the ol.
    # The loop above needs to recognize the list itself before those descendants.
    if not lists:
        for ordered in heading.find_all_next('ol'):
            previous_h2 = ordered.find_previous('h2')
            if previous_h2 is not heading:
                break
            stats = [text(item) for item in ordered.find_all('li', recursive=False)]
            if stats:
                lists.append({'label': 'Stat Priority', 'stats': stats})
    output, seen_labels = [], {}
    for item in lists:
        key = (item['label'], tuple(item['stats']))
        if any(existing['label'] == item['label'] and existing['stats'] == item['stats'] for existing in output):
            continue
        base = item['label']
        seen_labels[base] = seen_labels.get(base, 0) + 1
        if seen_labels[base] > 1:
            item = {**item, 'label': f"{base} ({seen_labels[base]})"}
        output.append(item)
    return output


def discover(html, url, source, cls, spec, content):
    soup = BeautifulSoup(html, 'html.parser')
    out = []
    for a in soup.select('a[href]'):
        target = urljoin(url, a['href']).split('#')[0]
        parts = urlsplit(target)
        path = parts.path
        if parts.hostname != HOSTS[source] or parts.scheme != 'https':
            continue
        if not live_retail_url(target):
            continue
        if source == 'wowhead':
            ok = f'/guide/classes/{cls}/{spec}/' in path and ('talent' in path or 'pvp' in path)
        elif source == 'icy-veins':
            ok = f'/{spec}-{cls}-' in path and ('talent' in path or path.endswith('-guide'))
        else:
            ok = False
        if not ok or ('pvp' in path and 'pvp' not in content):
            continue
        if 'pvp' not in path and 'pve' not in content and source == 'icy-veins':
            continue
        if target not in out:
            out.append(target)
    return out


def browser_exports(page, source, url):
    # Browser instances can share the OS clipboard. Serialize the entire export
    # transaction while independent page loading/parsing continues elsewhere.
    with EXPORT_LOCK:
        return _browser_exports(page, source, url)


def _browser_exports(page, source, url):
    """Interact only with build tabs and named export controls, sequentially."""
    results = []
    if source != 'icy-veins':
        return results
    # Inspect rendered controls rather than executing the site's private application state.
    tabs = page.locator('[role=tab]')
    choices = []
    for i in range(min(tabs.count(), 30)):
        name = tabs.nth(i).inner_text().strip()
        if re.search(r'build|raid|mythic|delve|single.target|3v3|blitz|sunfury|spellslinger', name, re.I):
            choices.append(name)
    # Icy Veins has also used generic clickable elements for build selectors.
    if source == 'icy-veins':
        generic = page.get_by_text(re.compile(r'^\s*(?:Recommended\s*)?Best (?:3v3|Battleground Blitz).+Build'))
        for i in range(min(generic.count(), 10)):
            name = generic.nth(i).inner_text().strip()
            if name not in choices:
                choices.append(name)
    for choice in [None] + choices:
        try:
            if choice:
                locator = page.get_by_text(choice, exact=True)
                if locator.count() != 1 or not locator.is_visible():
                    continue
                locator.click(timeout=3000)
                page.wait_for_timeout(500)
            export = page.get_by_text('Export Talents', exact=True)
            visible = [export.nth(i) for i in range(export.count()) if export.nth(i).is_visible()]
            if len(visible) != 1:
                continue
            links = page.get_by_role('link', name='Open in Calculator', exact=True)
            urls = [urljoin(url, links.nth(i).get_attribute('href') or '')
                    for i in range(links.count()) if links.nth(i).is_visible()]
            headings = page.locator('h2:visible, h3:visible').all_text_contents()
            label = choice or next((h for h in headings if re.search(r'build', h, re.I)), 'Current build')
            page.evaluate('navigator.clipboard.writeText("")')
            visible[0].click(timeout=3000)
            page.wait_for_timeout(300)
            code = page.evaluate('navigator.clipboard.readText()').strip()
            row = record(source, url, label, code or None, urls[0] if len(urls) == 1 else None,
                         bool(re.search(r'best|recommend', label, re.I)))
            if not code:
                row['extraction_status'] = 'export_failed'
            results.append(row)
        except Exception as exc:
            row = record(source, url, choice or 'Current build')
            row.update(extraction_status='export_failed', error=str(exc).splitlines()[0][:250])
            results.append(row)
    return unique(results)


def scan_wowhead_stat_priorities(page, config, args):
    """Scan the fixed Wowhead stat page once for every configured spec."""
    priorities, statuses = [], []
    for item in config['specs']:
        cls, spec = slug(item['class']), slug(item['spec'])
        url = stat_priority_url(cls, spec)
        status = dict(source='wowhead', data_type='stat_priority', **item, requested_url=url)
        print(f'[wowhead] {cls}/{spec}: {url}', flush=True)
        try:
            response = page.goto(url, wait_until='domcontentloaded', timeout=45000)
            page.wait_for_timeout(args.delay * 1000)
            status['source_url'] = page.url
            if not live_retail_url(page.url):
                status.update(status='skipped', reason='Not current live retail')
                continue
            if response and response.status >= 400:
                status.update(status='blocked' if response.status in (401, 403, 429) else 'http_error', http_status=response.status)
                continue
            if re.search(r'verify you are human|just a moment|access denied', page.title(), re.I):
                status.update(status='blocked', reason='Browser challenge')
                continue
            html = page.content()
            h1 = ' '.join(page.locator('h1').all_text_contents()).lower()
            if spec not in slug(h1) or cls not in slug(h1):
                status.update(status='discovery_only', reason='Page title does not confirm requested spec/class')
                continue
            if not expansion_matches(html, config.get('expansion', CURRENT_EXPANSION),
                                     config.get('patch_major', CURRENT_PATCH_MAJOR)):
                status.update(status='skipped', reason='Current expansion not confirmed in guide title/intro')
                continue
            body = page.locator('body').inner_text()
            updated = re.search(r'(?:Last Updated:|Updated:|Last updated:)\s*([^\n]+)', body, re.I)
            now = datetime.now(timezone.utc).isoformat()
            lists = parse_stat_priorities_html(html, 'wowhead', page.url)
            for priority in lists:
                priorities.append({
                    **item, **priority, 'source': 'wowhead', 'source_url': page.url,
                    'retrieved_at': now, 'source_updated_raw': updated.group(1) if updated else None,
                    'expansion': config.get('expansion', CURRENT_EXPANSION),
                })
            status.update(status='ok' if lists else 'no_stat_priority', priorities_found=len(lists), title=h1)
        except Exception as exc:
            status.update(status='error', error=str(exc).splitlines()[0][:400])
        finally:
            statuses.append(status)
    return priorities, statuses


def scan_site(config, args):
    from playwright.sync_api import sync_playwright
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    builds, statuses, priorities = [], [], []
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=not args.headed)
        context = browser.new_context(permissions=['clipboard-read', 'clipboard-write'])
        page = context.new_page()
        page.set_default_timeout(5000)
        try:
            for item in config['specs']:
                cls, spec = slug(item['class']), slug(item['spec'])
                for source in config.get('sources', DEFAULT_SOURCES):
                    queue = [(u, 0) for u in seeds(source, cls, spec, config.get('content', ['pve', 'pvp']))]
                    seen = set()
                    if not queue:
                        statuses.append(dict(source=source, **item, status='unsupported', reason='No verified route for requested content'))
                    while queue and len(seen) < args.max_pages:
                        url, depth = queue.pop(0)
                        if url in seen:
                            continue
                        seen.add(url)
                        status = dict(source=source, **item, requested_url=url)
                        print(f'[{source}] {cls}/{spec}: {url}', flush=True)
                        try:
                            response = page.goto(url, wait_until='domcontentloaded', timeout=45000)
                            page.wait_for_timeout(args.delay * 1000)
                            status['source_url'] = page.url
                            if not live_retail_url(page.url):
                                status.update(status='skipped', reason='Not current live retail')
                                continue
                            body = page.locator('body').inner_text()
                            if response and response.status >= 400:
                                status.update(status='blocked' if response.status in (401,403,429) else 'http_error', http_status=response.status)
                                continue
                            if re.search(r'verify you are human|just a moment|access denied', page.title(), re.I):
                                status.update(status='blocked', reason='Browser challenge')
                                continue
                            html = page.content()
                            # Fixed input routes only. Do not crawl linked guide pages.
                            h1 = ' '.join(page.locator('h1').all_text_contents()).lower()
                            normalized = slug(h1)
                            if spec not in normalized or cls not in normalized:
                                status.update(status='discovery_only', reason='Page title does not confirm requested spec/class')
                                continue
                            if not expansion_matches(html, config.get('expansion', CURRENT_EXPANSION),
                                                     config.get('patch_major', CURRENT_PATCH_MAJOR)):
                                status.update(status='skipped', reason='Current expansion not confirmed in guide title/intro')
                                continue
                            if 'pvp' in h1 and 'pvp' not in config.get('content', ['pve','pvp']):
                                status.update(status='skipped', reason='PvP excluded')
                                continue
                            if 'pvp' not in h1 and 'pve' not in config.get('content', ['pve','pvp']):
                                status.update(status='skipped', reason='PvE excluded')
                                continue
                            rows = parse_html(html, source, page.url)
                            rows += browser_exports(page, source, page.url)
                            now = datetime.now(timezone.utc).isoformat()
                            updated = re.search(r'(?:Last Updated:|Updated:|Last updated:)\s*([^\n]+)', body, re.I)
                            patch = re.search(r'\b(?:Patch\s+)?(1[2-9]\.\d+(?:\.\d+)?)\b', h1)
                            rows = unique(rows)
                            for row in rows:
                                row.update(**item, content_type='pvp' if 'pvp' in h1 else 'pve',
                                           expansion=config.get('expansion', CURRENT_EXPANSION),
                                           retrieved_at=now, patch=patch.group(1) if patch else None,
                                           source_updated_raw=updated.group(1) if updated else None)
                                builds.append(row)
                            status.update(status=('partial' if any(r['extraction_status'] != 'ok' for r in rows) else 'ok') if rows else 'no_import_code',
                                          builds_found=len(rows), title=h1)
                        except Exception as exc:
                            status.update(status='error', error=str(exc).splitlines()[0][:400])
                        finally:
                            statuses.append(status)
                            write_results(out, builds, statuses)
                    if queue:
                        statuses.append(dict(source=source, **item, status='page_limit', reason='Increase --max-pages for more discovered guides'))
            if source == 'wowhead':
                stat_priorities, stat_statuses = scan_wowhead_stat_priorities(page, config, args)
                priorities.extend(stat_priorities)
                statuses.extend(stat_statuses)
        finally:
            browser.close()
            write_results(out, builds, statuses, priorities)
    return builds, statuses, priorities


def scan(config, args):
    """One worker per site; Playwright objects never cross thread boundaries."""
    sources = list(dict.fromkeys(config.get('sources', DEFAULT_SOURCES)))
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    builds, statuses, priorities = [], [], []
    jobs = []
    for source in sources:
        site_config = copy.deepcopy(config)
        site_config['sources'] = [source]
        site_args = copy.copy(args)
        site_args.output = str(out / 'per-site' / source)
        Path(site_args.output).mkdir(parents=True, exist_ok=True)
        write_results(Path(site_args.output), [], [], [])
        jobs.append((source, site_config, site_args))
    workers = max(1, min(getattr(args, 'workers', 2), len(jobs) or 1))
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(scan_site, cfg, opts): (source, opts)
                   for source, cfg, opts in jobs}
        for future in as_completed(futures):
            source, opts = futures[future]
            try:
                site_builds, site_statuses, site_priorities = future.result()
                builds.extend(site_builds)
                statuses.extend(site_statuses)
                priorities.extend(site_priorities)
            except Exception as exc:
                # Retain this run's partial checkpoints if a worker fails.
                for filename, target in [('talent-builds.json', builds), ('scan-status.json', statuses), ('stat-priorities.json', priorities)]:
                    path = Path(opts.output) / filename
                    if path.exists():
                        target.extend(json.loads(path.read_text(encoding='utf-8')))
                statuses.append(dict(source=source, **{'class': 'All', 'spec': 'All'},
                                     status='worker_error', error=str(exc)[:400]))
            builds.sort(key=lambda r: (r['class'], r['spec'], r['source'], r['source_url'], r['build_name']))
            statuses.sort(key=lambda r: (r['class'], r['spec'], r['source'], r.get('requested_url', '')))
            write_results(out, builds, statuses, priorities)
    return builds, statuses, priorities


def write_results(out, builds, statuses, priorities=None):
    priorities = priorities or []
    for filename, data in [('talent-builds.json', unique(builds)), ('scan-status.json', statuses)]:
        (out / filename).write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')
    (out / 'stat-priorities.json').write_text(json.dumps(priorities, indent=2, ensure_ascii=False), encoding='utf-8')
    lines = ['# Talent build scan', '', 'Codes are extracted only, not validated in-game.', '']
    for row in unique(builds):
        badges = ' '.join(f'**{label.upper()}**' for label in row['recommendation_labels'])
        lines += [f"## {row['spec']} {row['class']} — {', '.join(row['modes'])}", '',
                  f"[{row['source']}]({row['source_url']}) — {row['build_name']} {badges}".rstrip(), '',
                  f"Status: {row['extraction_status']}; recommendation: {row['recommendation_basis']}", '']
        if row['import_code']:
            lines += ['```text', row['import_code'], '```', '']
        elif row['calculator_url']:
            lines += [f"[Calculator]({row['calculator_url']})", '']
    lines += ['## Scan coverage', '']
    lines += [f"- {s['source']} / {s['class']} / {s['spec']}: {s['status']} — {s.get('requested_url', s.get('reason', ''))}" for s in statuses]
    (out / 'talent-builds.md').write_text('\n'.join(lines), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='JSON input file')
    parser.add_argument('--output', default='scan-results')
    parser.add_argument('--workers', type=int, default=2, help='Concurrent sites (default 2; use 1 for sequential)')
    parser.add_argument('--headed', action='store_true', help='Show an isolated Chromium window')
    parser.add_argument('--delay', type=float, default=3, help='Seconds between page loads (minimum 1)')
    parser.add_argument('--max-pages', type=int, default=12, help='Maximum pages per site/spec')
    args = parser.parse_args()
    config = json.loads(args.input.read_text(encoding='utf-8-sig'))
    if not config.get('specs'):
        parser.error('Input must contain a nonempty specs list')
    for item in config['specs']:
        if slug(item.get('spec', '')) not in SPECS.get(slug(item.get('class', '')), []):
            parser.error(f'Unknown class/spec: {item}')
    if not set(config.get('sources', DEFAULT_SOURCES)) <= set(SOURCES):
        parser.error('Unknown source')
    if not set(config.get('content', ['pve','pvp'])) <= {'pve','pvp'}:
        parser.error('content must contain pve and/or pvp')
    if args.delay < 1 or args.max_pages < 1 or args.workers < 1:
        parser.error('delay, max-pages and workers must be at least 1')
    scan(config, args)
    print(f'Reports written to {Path(args.output).resolve()}')


if __name__ == '__main__':
    main()
