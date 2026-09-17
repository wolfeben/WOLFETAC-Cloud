$ErrorActionPreference = 'Stop'
$taskSymbols = Join-Path $PSScriptRoot 'build\symbols'
New-Item -ItemType Directory -Path $taskSymbols -Force | Out-Null
Get-ChildItem -LiteralPath 'D:\WOLFETAC\Cloud\.alpackages' -Filter 'Microsoft_*.app' | Copy-Item -Destination $taskSymbols -Force
Copy-Item -LiteralPath 'D:\WOLFETAC\ONPREM\TAC-Dispatcher-BC\.alpackages\Microsoft_System_28.0.50938.0.app' -Destination $taskSymbols -Force
Copy-Item -LiteralPath 'D:\WOLFETAC\_Staging\Batch-NoDispatcher-20260910\symbols\The Avocados Collective_Avocados Core_1.0.0.41.app' -Destination $taskSymbols -Force
Copy-Item -LiteralPath 'D:\WOLFETAC\Cloud\TACPoolMaster\build\DIY-ERP_TAC Pool Master_2.0.0.2.app' -Destination $taskSymbols -Force
$taskManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'app.json') -Raw | ConvertFrom-Json
$taskOutput = Join-Path $PSScriptRoot ('build\WOLFE_TAC Pool E2E Test Data_' + $taskManifest.version + '.app')
& 'C:\Users\BenL\.vscode\extensions\ms-dynamics-smb.al-18.0.2732683\bin\alc.exe' "/project:$PSScriptRoot" "/packagecachepath:$taskSymbols" "/out:$taskOutput" "/errorlog:$PSScriptRoot\build\compile.json"
if ($LASTEXITCODE -ne 0) { throw 'Test data helper compile failed.' }
Get-FileHash -LiteralPath $taskOutput -Algorithm SHA256
