$ErrorActionPreference = 'Stop'
$taskSrc = Join-Path $PSScriptRoot 'src'
$taskFiles = Get-ChildItem -LiteralPath $taskSrc -Filter '*.al' -Recurse
$taskText = ($taskFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join [Environment]::NewLine
$taskTables = [regex]::Matches($taskText, '(?m)^table\s+5930[0-3]\b').Count
$taskTemporary = [regex]::Matches($taskText, '(?im)^\s*TableType\s*=\s*Temporary\s*;').Count
if ($taskTables -ne 4 -or $taskTemporary -ne 4) { throw 'Expected exactly four temporary review tables.' }
if ($taskText -match '(?i)\[EventSubscriber|SubType\s*=\s*(Install|Upgrade)|\bCommit\s*\(|Codeunit\.Run\s*\(|HttpClient|\bFindOrCreate\s*\(') { throw 'Unexpected subscriber, business invocation, commit or external client.' }
# Inspect executable lines, excluding comments, and allow mutations only on named temporary review buffers.
$taskCode = ($taskText -split '\r?\n' | Where-Object { $_ -notmatch '^\s*//' }) -join [Environment]::NewLine
$taskMutations = [regex]::Matches($taskCode, '(?i)\b(?<receiver>\w+)\.(?<method>Insert|Modify|Delete|DeleteAll|ModifyAll|Rename|Validate)\s*\(')
$taskAllowed = @('Groups','Facts','Fact','Issues','Fields','Rec','ScanRows','Group')
foreach ($taskMutation in $taskMutations) {
    if ($taskMutation.Groups['receiver'].Value -notin $taskAllowed) { throw "Unexpected write receiver: $($taskMutation.Value)" }
}
foreach ($taskFile in ($taskFiles | Where-Object { $_.Directory.Name -eq 'Page' })) {
    $taskPage = Get-Content -LiteralPath $taskFile.FullName -Raw
    $taskRequiredProperties = @('Editable = false','InsertAllowed = false','ModifyAllowed = false','DeleteAllowed = false')
    if ($taskPage -match 'SourceTable\s*=') { $taskRequiredProperties += 'SourceTableTemporary = true' }
    foreach ($taskProperty in $taskRequiredProperties) {
        if (-not $taskPage.Contains($taskProperty)) { throw "$($taskFile.Name) lacks $taskProperty" }
    }
}
$taskPermissions = Get-Content -LiteralPath (Join-Path $taskSrc 'PermissionSet\PoolReview.PermissionSet.al') -Raw
$taskGrants = [regex]::Matches($taskPermissions, '(?im)^\s*tabledata\s+"(?<name>[^"]+)"')
foreach ($taskGrant in $taskGrants) {
    if (-not $taskGrant.Groups['name'].Value.StartsWith('WLF Pool Review ')) { throw 'Unexpected source data permission grant.' }
}
$taskReport = [ordered]@{
    CheckedAt = [DateTime]::UtcNow.ToString('o')
    Result = 'Passed structural checks; not BC runtime validation'
    TemporaryTables = $taskTemporary
    ReadOnlyPages = ($taskFiles | Where-Object { $_.Directory.Name -eq 'Page' }).Count
    MutationCallsOnAllowedTemporaryBuffers = $taskMutations.Count
    SourceTablePermissionGrants = 0
    Scope = 'Current source files; manual receiver/type review supplements these structural guards'
}
$taskReport | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'build\read-only-checks.json') -Encoding utf8
$taskReport | ConvertTo-Json



