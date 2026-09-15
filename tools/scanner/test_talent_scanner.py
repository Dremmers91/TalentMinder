import unittest
import json
import tempfile
import threading
import argparse
from unittest.mock import patch
from pathlib import Path
from talent_scanner import parse_html, parse_stat_priorities_html, seeds, stat_priority_url, discover, mode_for, live_retail_url, expansion_matches, DEFAULT_SOURCES, record, role_for
from talent_scanner import unique, modes_for
from talent_scanner import scan

CODE = 'CwP' + 'A' * 95


class ScannerTests(unittest.TestCase):
    def test_concurrent_sites_and_report_merge(self):
        barrier = threading.Barrier(2)
        outputs = []
        def fake_scan(config, args):
            source = config['sources'][0]
            outputs.append(args.output)
            barrier.wait(timeout=5)
            row = record(source, 'https://example.com/' + source, 'Best Raid', CODE)
            row.update({'class': 'Mage', 'spec': 'Arcane'})
            return [row], [dict(source=source, **{'class': 'Mage', 'spec': 'Arcane'}, status='ok')], []
        with tempfile.TemporaryDirectory() as tmp, patch('talent_scanner.scan_site', side_effect=fake_scan):
            rows, statuses, priorities = scan({'specs': [], 'sources': ['wowhead', 'icy-veins']}, argparse.Namespace(output=tmp, workers=2))
            self.assertEqual(len(rows), 2)
            self.assertEqual(priorities, [])
            self.assertTrue(all(s['status'] == 'ok' for s in statuses))
            self.assertEqual(len(set(outputs)), 2)
            self.assertTrue((Path(tmp) / 'talent-builds.json').exists())

    def test_failed_worker_does_not_reuse_old_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            old = Path(tmp) / 'per-site' / 'wowhead'
            old.mkdir(parents=True)
            (old / 'talent-builds.json').write_text('[{"stale":true}]')
            with patch('talent_scanner.scan_site', side_effect=RuntimeError('browser failed')):
                rows, statuses, priorities = scan({'specs': [], 'sources': ['wowhead']}, argparse.Namespace(output=tmp, workers=1))
            self.assertEqual(rows, [])
            self.assertEqual(priorities, [])
            self.assertEqual(statuses[0]['status'], 'worker_error')

    def test_fallback_html_is_not_a_build(self):
        html = f'<noscript><a href="/talent-calc/blizzard/{CODE}">Build</a></noscript>'
        self.assertEqual(parse_html(html, 'wowhead', 'https://www.wowhead.com'), [])

    def test_deduplicate_export_preserves_best_label_and_link(self):
        a = record('icy-veins', 'https://www.icy-veins.com', 'Current build', CODE, 'https://calculator.example')
        b = record('icy-veins', 'https://www.icy-veins.com', 'Best 3v3 Balance Build', CODE)
        rows = unique([a, b])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['build_name'], 'Best 3v3 Balance Build')
        self.assertTrue(rows[0]['recommended'])
        self.assertEqual(rows[0]['calculator_url'], 'https://calculator.example')
        self.assertEqual(rows[0]['modes'], ['arena_3v3'])
        self.assertEqual(len(unique(rows)), 1)

    def test_preserve_multiple_modes(self):
        self.assertEqual(modes_for('Mythic+/Delves', ''), ['mythic_plus', 'delves'])

    def test_catalog_contains_every_configured_retail_specialization(self):
        from talent_scanner import RETAIL_SPECIALIZATIONS
        config = json.loads((Path(__file__).parent / 'scanner-input.json').read_text())
        configured = {(item['class'], item['spec']) for item in config['specs']}
        catalog = {(item['class'], item['spec']) for item in RETAIL_SPECIALIZATIONS}
        self.assertEqual(configured, catalog)
        self.assertEqual(next(item for item in RETAIL_SPECIALIZATIONS if item['spec'] == 'Devourer')['specId'], 1480)

    def test_build_name_recommendation_flags(self):
        for name in ['Single Target (Best)', 'BEST Arena Build', 'Recommended Raid', 'rEcOmMeNdEd Mythic+']:
            with self.subTest(name=name):
                row = record('wowhead', 'https://www.wowhead.com', name)
                self.assertTrue(row['recommended'])
                self.assertEqual(row['recommendation_basis'], 'build_name')
        both = record('icy-veins', 'https://www.icy-veins.com', 'Recommended Best 3v3 Build')
        self.assertTrue(both['best'])
        self.assertEqual(both['recommendation_labels'], ['best', 'recommended'])
        self.assertFalse(record('wowhead', 'https://www.wowhead.com', 'Alternative Raid')['recommended'])
        self.assertFalse(record('wowhead', 'https://www.wowhead.com', 'Bestiary Build')['best'])

    def test_only_requested_route_patterns(self):
        self.assertEqual(DEFAULT_SOURCES, ('wowhead', 'icy-veins'))
        self.assertEqual(seeds('wowhead', 'death-knight', 'unholy', ['pve', 'pvp']),
                         ['https://www.wowhead.com/guide/classes/death-knight/unholy/talent-builds-pve-dps'])
        self.assertEqual(seeds('icy-veins', 'druid', 'balance', ['pve', 'pvp']),
                         ['https://www.icy-veins.com/wow/balance-druid-pve-dps-spec-builds-talents',
                          'https://www.icy-veins.com/wow/balance-druid-pvp-talents-and-builds'])

    def test_role_aware_pve_routes_and_tank_pvp_exclusion(self):
        self.assertEqual(role_for('paladin', 'holy'), 'healer')
        self.assertEqual(role_for('paladin', 'protection'), 'tank')
        self.assertEqual(seeds('wowhead', 'paladin', 'holy', ['pve']),
                         ['https://www.wowhead.com/guide/classes/paladin/holy/talent-builds-pve-healer'])
        self.assertEqual(seeds('icy-veins', 'paladin', 'holy', ['pve']),
                         ['https://www.icy-veins.com/wow/holy-paladin-pve-healing-spec-builds-talents'])
        self.assertEqual(seeds('icy-veins', 'paladin', 'protection', ['pve', 'pvp']),
                         ['https://www.icy-veins.com/wow/protection-paladin-pve-tank-spec-builds-talents'])

    def test_current_expansion_only(self):
        self.assertTrue(expansion_matches('<main><h1>Arcane Mage — 12.1</h1></main>'))
        self.assertFalse(expansion_matches('<main><nav>Midnight</nav><h1>Arcane Mage — 11.2</h1></main>'))
        self.assertFalse(live_retail_url('https://www.wowhead.com/ptr/guide/classes/mage/arcane/talents'))
        self.assertTrue(live_retail_url('https://www.icy-veins.com/wow/balance-druid-pvp-talents-and-builds'))

    def test_wowhead_row_association(self):
        html = f'<main><h3>San\'layn</h3><table><tr><td>M+/Delves (Best)</td><td><a href="https://www.wowhead.com/talent-calc/blizzard/{CODE}">Build</a></td></tr></table></main>'
        rows = parse_html(html, 'wowhead', 'https://www.wowhead.com/guide')
        self.assertEqual(rows[0]['import_code'], CODE)
        self.assertEqual(rows[0]['hero_tree'], "San'layn")
        self.assertTrue(rows[0]['recommended'])
        self.assertEqual(rows[0]['mode'], 'mythic_plus')

    def test_wowhead_stat_priorities_keep_labeled_dual_lists(self):
        html = '''<main><h2>Best Stats for Protection Paladin</h2>
        <h3>Survivability Stat Priority</h3><ol><li>Strength</li><li>Haste</li><li>Mastery</li></ol>
        <h3>DPS Stat Priority</h3><ol><li>Strength</li><li>Haste</li><li>Critical Strike</li></ol>
        <h2>Stats Explained</h2><ol><li>Not included</li></ol></main>'''
        priorities = parse_stat_priorities_html(html, 'wowhead', 'https://www.wowhead.com/guide')
        self.assertEqual(priorities, [
            {'label': 'Survivability Stat Priority', 'stats': ['Strength', 'Haste', 'Mastery']},
            {'label': 'DPS Stat Priority', 'stats': ['Strength', 'Haste', 'Critical Strike']},
        ])
        self.assertEqual(stat_priority_url('paladin', 'protection'),
                         'https://www.wowhead.com/guide/classes/paladin/protection/stat-priority-pve-tank')

    def test_malformed_link_not_repaired(self):
        html = f'<h2>Open World</h2><a href="/talent-calc/blizzard/[{CODE}">Build</a>'
        row = parse_html(html, 'wowhead', 'https://www.wowhead.com/guide')[0]
        self.assertIsNone(row['import_code'])
        self.assertEqual(row['extraction_status'], 'malformed_code')

    def test_quick_start_label(self):
        html = f'<main><p>Quick Start Import Codes:</p><div title="Arcane Raid - Sunfury"><span>{CODE}</span><button>Copy</button></div></main>'
        row = parse_html(html, 'icy-veins', 'https://www.icy-veins.com/wow/arcane-mage-pve-dps-spec-builds-talents')[0]
        self.assertEqual(row['build_name'], 'Arcane Raid - Sunfury')
        self.assertEqual(row['mode'], 'raid')

    def test_ignore_comment_and_script_codes(self):
        html = f'<main><script>{CODE}</script><div id="comments">{CODE}</div></main>'
        self.assertEqual(parse_html(html, 'icy-veins', 'https://www.icy-veins.com'), [])

    def test_pvp_route(self):
        self.assertEqual(seeds('icy-veins', 'druid', 'balance', ['pvp']),
                         ['https://www.icy-veins.com/wow/balance-druid-pvp-talents-and-builds'])
        self.assertEqual(mode_for('Best Battleground Blitz Build', ''), 'battleground_blitz')

    def test_discovery_stays_on_spec_and_host(self):
        html = '<a href="/guide/classes/mage/arcane/talent-builds-pve-dps">yes</a><a href="https://evil.example/guide/classes/mage/arcane/talents">no</a><a href="/guide/classes/mage/fire/talents">no</a>'
        found = discover(html, 'https://www.wowhead.com', 'wowhead', 'mage', 'arcane', ['pve'])
        self.assertEqual(len(found), 1)

if __name__ == '__main__':
    unittest.main()
