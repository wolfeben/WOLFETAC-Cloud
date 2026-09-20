import difflib
import hashlib
import json
import zipfile
from pathlib import Path
from urllib.parse import unquote

p = Path(r'D:\WOLFETAC\Cloud\TACPoolMaster')
m = json.loads((p/'SOURCE-PROVENANCE-20260920.json').read_text())
files = [x for x in m['files'] if not Path(x['target']).is_absolute()]
changed, diff = [], []
with zipfile.ZipFile(m['package']) as base:
    for e in files:
        a = base.read(e['source']).decode('utf-8-sig').replace('\r\n', '\n')
        b = (p/e['target']).read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        if a != b:
            changed.append(e['target'])
            diff.extend(difflib.unified_diff(a.splitlines(True), b.splitlines(True), fromfile='2.0.0.2/'+e['target'], tofile='2.0.0.3/'+e['target']))
assert sorted(changed) == sorted(['_TAC Pool Prod Order Post_.Codeunit.al', '_TAC Pool Dimension Mgt_.Codeunit.al', '_TAC Pool Grower Mgt_.Codeunit.al']), changed
assert len(list(p.glob('*.al'))) == 130
(p/'build/grower-only-2.0.0.3.patch').write_text(''.join(diff), encoding='utf-8')
result = {'changedALFiles': changed, 'unchangedALFiles': 127, 'schemaChanges': False, 'packages': []}
for f in ['DIY-ERP_TAC Pool Master_2.0.0.3_grower-fix.app', 'DIY-ERP_TAC Pool Master_2.0.0.4_recovery.app']:
    q = p/'build'/f
    with zipfile.ZipFile(q) as z, zipfile.ZipFile(m['package']) as base:
        al = [n for n in z.namelist() if n.lower().endswith('.al')]
        assert len(al) == 130, (f, len(al))
        for e in files:
            candidate = next(n for n in al if unquote(unquote(Path(n).name)) == e['target'])
            expected = (p/e['target']).read_text(encoding='utf-8-sig') if 'grower-fix' in f else base.read(e['source']).decode('utf-8-sig')
            assert z.read(candidate).decode('utf-8-sig').replace('\r\n', '\n') == expected.replace('\r\n', '\n'), (f, e['target'])
    result['packages'].append({'file': str(q), 'sha256': hashlib.sha256(q.read_bytes()).hexdigest(), 'sourceVerified': True})
(p/'build/grower-only-package-verification.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
