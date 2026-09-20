import hashlib
import json
import shutil
import zipfile
from pathlib import Path
from urllib.parse import unquote

project = Path(r'D:\WOLFETAC\Cloud\TACPoolMaster')
snapshot = Path(r'D:\WOLFETAC\.snapshots\PoolMaster-legacy-reuse-20260920')
baseline = project / 'build/DIY-ERP_TAC Pool Master_2.0.0.3_grower-fix.app'
assert project.resolve().is_relative_to(Path(r'D:\WOLFETAC').resolve())
assert hashlib.sha256(baseline.read_bytes()).hexdigest() == 'fcbe5f62edfe9eb236f4509e9fa449f09686fc07ea463e10f4fb3163ac0c4a34'
with zipfile.ZipFile(baseline) as z:
    sources = {unquote(unquote(Path(n).name)): z.read(n).decode('utf-8-sig').replace('\r\n', '\n') for n in z.namelist() if n.lower().endswith('.al')}
assert len(sources) == 130
assert {p.name for p in project.glob('*.al')} == set(sources)
for name, text in sources.items():
    assert (project/name).read_text(encoding='utf-8-sig') == text, name
assert json.loads((project/'app.json').read_text())['version'] == '2.0.0.3'
snapshot.mkdir(parents=True, exist_ok=False)
shutil.copytree(project, snapshot/'recovery-source-2.0.0.8', ignore=shutil.ignore_patterns('.alpackages', 'build', '.git'))
recovery = snapshot/'recovery-source-2.0.0.8/app.json'
manifest = json.loads(recovery.read_text())
manifest['version'] = '2.0.0.8'
recovery.write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
shutil.copytree(Path(r'D:\WOLFETAC\Cloud\PoolGrowerFixTests'), snapshot/'test-helper-before', ignore=shutil.ignore_patterns('.alpackages', '*.app'))
print('Verified all 130 active AL sources against published 2.0.0.3; preserved recovery and test-helper source at '+str(snapshot))
