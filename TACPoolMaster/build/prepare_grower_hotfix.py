import hashlib
import json
import zipfile
from pathlib import Path

project = Path(r'D:\WOLFETAC\Cloud\TACPoolMaster').resolve()
assert project == Path(r'D:\WOLFETAC\Cloud\TACPoolMaster')
manifest = json.loads((project / 'SOURCE-PROVENANCE-20260920.json').read_text())
package = Path(manifest['package'])
assert hashlib.sha256(package.read_bytes()).hexdigest() == manifest['packageSha256']
snapshot = Path(r'D:\WOLFETAC\.snapshots\PoolMaster-grower-only-20260920')
snapshot.mkdir(exist_ok=True)
archive = snapshot / 'deferred-full-work-in-progress.zip'
assert not archive.exists(), 'Do not overwrite the WIP snapshot'
active = [x for x in manifest['files'] if not Path(x['target']).is_absolute()]
assert len(active) == 130
expected = {x['target'] for x in active}
extras = {'_TAC Pool Source Mgt_.Codeunit.al', '_TAC Pool Allocation Mgt_.Codeunit.al', '_TAC Pool Shipment Allocation_.Table.al'}
assert {p.name for p in project.glob('*.al')} == expected | extras
with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(project.iterdir()):
        if p.is_file() and p.suffix.lower() in {'.al', '.json', '.md'}:
            z.write(p, p.name)
    for p in (project/'build').glob('*.py'):
        z.write(p, 'build/'+p.name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name in expected | extras:
        assert z.read(name) == (project/name).read_bytes()
with zipfile.ZipFile(package) as z:
    for entry in active:
        (project / entry['target']).write_bytes(z.read(entry['source']))
app = json.loads((project/'app.json').read_text())
app['version'] = '2.0.0.4'
(project/'app.json').write_text(json.dumps(app, indent=2)+'\n', encoding='utf-8')
print('Preserved full WIP:', archive)
print('Restored installed baseline; manifest 2.0.0.4 for recovery build.')
print('Move only the three named WIP-only AL objects out of the project before compiling.')
