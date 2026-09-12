param(
    [string]$Compiler = 'C:\Users\BenL\.vscode\extensions\ms-dynamics-smb.al-18.0.2732683\bin\alc.exe',
    [string]$CloudSymbols = 'D:\WOLFETAC\Cloud\.alpackages',
    [string]$PlatformSymbol = 'D:\WOLFETAC\ONPREM\TAC-Dispatcher-BC\.alpackages\Microsoft_System_28.0.50938.0.app'
)
$ErrorActionPreference = 'Stop'
$taskProject = [IO.Path]::GetFullPath($PSScriptRoot)
if (-not $taskProject.StartsWith('D:\WOLFETAC\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Build must use the canonical BC root.' }
$taskOutput = Join-Path $taskProject 'build'
$taskSymbols = Join-Path $taskOutput 'symbols'
New-Item -ItemType Directory -Path $taskSymbols -Force | Out-Null
# The platform package contains Microsoft platform symbols only. No on-premises custom dependency is referenced.
Get-ChildItem -LiteralPath $CloudSymbols -Filter 'Microsoft_*.app' | Copy-Item -Destination $taskSymbols -Force
Copy-Item -LiteralPath $PlatformSymbol -Destination $taskSymbols -Force
$taskApp = Join-Path $taskOutput 'WOLFE_TAC Pool Review_0.4.0.1.app'
& $Compiler "/project:$taskProject" "/packagecachepath:$taskSymbols" "/out:$taskApp" "/errorlog:$taskOutput\compile.json"
if ($LASTEXITCODE -ne 0) { throw "Production compile failed: $LASTEXITCODE" }
$taskTests = [IO.Path]::GetFullPath((Join-Path $taskProject '..\Test\PoolReview'))
$taskTestOutput = Join-Path $taskTests 'build'
$taskTestSymbols = Join-Path $taskTestOutput 'symbols'
New-Item -ItemType Directory -Path $taskTestSymbols -Force | Out-Null
Get-ChildItem -LiteralPath $taskSymbols -Filter '*.app' | Copy-Item -Destination $taskTestSymbols -Force
Copy-Item -LiteralPath $taskApp -Destination $taskTestSymbols -Force
& $Compiler "/project:$taskTests" "/packagecachepath:$taskTestSymbols" "/out:$taskTestOutput\WOLFE_TAC Pool Review Tests_0.4.0.1.app" "/errorlog:$taskTestOutput\compile.json"
if ($LASTEXITCODE -ne 0) { throw "Test compile failed: $LASTEXITCODE" }
& (Join-Path $taskProject 'Verify-ReadOnly.ps1')
if (-not $?) { throw 'Read-only structural checks failed.' }
Get-FileHash -LiteralPath $taskApp -Algorithm SHA256 | Format-List
Write-Output 'Both apps compiled locally. AL test methods have not been executed on a BC server. Nothing was published.'



