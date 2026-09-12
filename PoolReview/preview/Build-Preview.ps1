param([string]$OutputRoot = 'C:\Users\BenL\.codex\visualizations\2026\09\11\01a08f49-afc5-7630-bbd4-b8f707e230ac')
$ErrorActionPreference='Stop'
$taskProject=Split-Path -Parent $PSScriptRoot
$taskCss=Get-Content -LiteralPath (Join-Path $taskProject 'ui\pooling.css') -Raw
# Keep the preview contained; the BC add-in stylesheet remains unchanged.
$taskCss=$taskCss.Replace(':root {','#pool-branded-preview {').Replace('html, body {','#pool-branded-preview {')
$taskCss += "`n#pool-branded-preview .pw-shell {min-height:0;}`n#pool-branded-preview .pw-table-scroll {max-height:none;}"
$taskJs=Get-Content -LiteralPath (Join-Path $taskProject 'ui\pooling.js') -Raw
$taskStart=Get-Content -LiteralPath (Join-Path $taskProject 'ui\startup.js') -Raw
$taskFixture=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'example-bridge.js') -Raw
$taskImages=@{}
foreach($taskImageName in @('avocado-mark.png','avocado-wordmark.png')) {
    $taskImagePath=Join-Path $taskProject ('ui\images\'+$taskImageName)
    $taskImages['ui/images/'+$taskImageName]='data:image/png;base64,'+[Convert]::ToBase64String([IO.File]::ReadAllBytes($taskImagePath))
}
$taskImageJson=$taskImages | ConvertTo-Json -Compress
$taskBody=@"
<div id="pool-branded-preview">
<style>
$taskCss
#pool-preview-disclosure {background:#fff4da;color:#6e4b05;padding:9px 18px;font:500 13px 'Segoe UI',Arial,sans-serif;}
</style>
<div id="pool-preview-disclosure">Layout preview · example data · not connected to Business Central</div>
<div id="controlAddIn"></div>
<script>window.poolPreviewImages=$taskImageJson;</script>
<script>
$taskFixture
</script>
<script>
$taskJs
</script>
<script>
$taskStart
</script>
</div>
"@
$taskFragment=Join-Path $OutputRoot 'pooling-branded.html'
[IO.File]::WriteAllText($taskFragment,$taskBody,[Text.UTF8Encoding]::new($false))
$taskStandalone='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Pooling Overview — branded preview</title></head><body>'+$taskBody+'</body></html>'
$taskStandalonePath=Join-Path $OutputRoot 'pooling-branded-test.html'
[IO.File]::WriteAllText($taskStandalonePath,$taskStandalone,[Text.UTF8Encoding]::new($false))
Get-Item -LiteralPath $taskFragment,$taskStandalonePath | Select-Object FullName,Length

