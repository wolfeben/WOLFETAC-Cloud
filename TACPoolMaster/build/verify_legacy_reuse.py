import hashlib
import json
import zipfile
import difflib
from pathlib import Path
from urllib.parse import unquote

p = Path(r'D:\WOLFETAC\Cloud\TACPoolMaster')
def sources(path):
    with zipfile.ZipFile(path) as z:
        return {unquote(unquote(Path(n).name)): z.read(n).decode('utf-8-sig').replace('\r\n','\n') for n in z.namelist() if n.lower().endswith('.al')}
baseline = sources(p/'build/DIY-ERP_TAC Pool Master_2.0.0.3_grower-fix.app')
release = p/'build/DIY-ERP_TAC Pool Master_2.0.0.7_legacy-reuse.app'
recovery = p/'build/DIY-ERP_TAC Pool Master_2.0.0.8_legacy-reuse-recovery.app'
candidate = sources(release)
assert len(baseline) == len(candidate) == 130
assert candidate.keys() == baseline.keys()
changed = [name for name in baseline if baseline[name] != candidate[name]]
assert changed == ['_TAC Pool_.Table.al'], changed
assert sources(recovery) == baseline
for name, contents in candidate.items():
    assert (p/name).read_text(encoding='utf-8-sig') == contents, name
name = changed[0]
diff = ''.join(difflib.unified_diff(baseline[name].splitlines(True), candidate[name].splitlines(True), fromfile='2.0.0.3/'+name, tofile='2.0.0.7/'+name))
(p/'build/legacy-reuse-2.0.0.7.patch').write_text(diff, encoding='utf-8')
result = {'baseline': '2.0.0.3', 'release': '2.0.0.7', 'recovery': '2.0.0.8', 'changedALFiles': changed, 'unchangedALFiles': 129, 'schemaChanges': False, 'recoveryMatchesAllBaselineALSources': True, 'packages': [{'file': str(q), 'sha256': hashlib.sha256(q.read_bytes()).hexdigest()} for q in [release, recovery]]}
(p/'build/legacy-reuse-package-verification.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
