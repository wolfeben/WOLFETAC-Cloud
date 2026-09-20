param([string]$OutputPath = (Join-Path $PSScriptRoot 'week-20260921-draft-manifest.json'))
$ErrorActionPreference = 'Stop'
# Planning only. This script has no Business Central connection or write operation.
$start = [datetime]'2026-09-21'
$growers = @(
    @{ No='GRW-100'; Blocks=@('100-A','100-BE') },
    @{ No='GRW-102'; Blocks=@('102-A','102-B') },
    @{ No='GRW-030'; Blocks=@('030-BA','030-BB') },
    @{ No='GRW-064'; Blocks=@('064-A','064-B') },
    @{ No='GRW-049'; Blocks=@('049-A1','049-B') }
)
$items = @(
    @{ No='PKD-HATYGL25PR'; Tag='0025'; Qty=160; Unit='TE'; Serial=$true },
    @{ No='PKD-HATYGL23PR'; Tag='0023'; Qty=160; Unit='TE'; Serial=$true },
    @{ No='PKD-HATYGL20PR'; Tag='0020'; Qty=160; Unit='TE'; Serial=$true },
    @{ No='PKD-HATYAV25C1'; Tag='0225'; Qty=160; Unit='TE'; Serial=$true },
    @{ No='PKD-HATYAV23C1'; Tag='0223'; Qty=160; Unit='TE'; Serial=$true },
    @{ No='PKD-HATYAV20C1'; Tag='0220'; Qty=160; Unit='TE'; Serial=$true },
    @{ No='PKD-HABKGL1KPR'; Tag='3700'; Qty=96; Unit='BK'; Serial=$true },
    @{ No='PKD-HAKGMXPG'; Tag='6400'; Qty=440; Unit='KG'; Serial=$false },
    @{ No='PKD-HABKBN1KPP'; Tag='6700'; Qty=440; Unit='KG'; Serial=$false }
)
$deliveries = [System.Collections.Generic.List[object]]::new()
$pallets = [System.Collections.Generic.List[object]]::new()
for ($day=0; $day -lt 5; $day++) {
    foreach ($grower in $growers) {
        foreach ($block in $grower.Blocks) {
            $n = $deliveries.Count + 1
            $deliveries.Add([ordered]@{
                DraftOrderIndex=$n; Date=$start.AddDays($day).ToString('yyyy-MM-dd')
                Grower=$grower.No; Block=$block; Bins=10
                ActualDeliveryNo=$null; ActualBatchNo=$null; ActualProductionOrderNo=$null
            })
            foreach ($item in $items) {
                for ($copy=1; $copy -le 2; $copy++) {
                    $pallets.Add([ordered]@{
                        DraftPalletId=('W26S21P{0:0000}' -f ($pallets.Count+1))
                        Item=$item.No; LabelTag=$item.Tag; Mixed=$false
                        RequestedQuantity=$item.Qty; RequestedUnit=$item.Unit
                        Contributions=@([ordered]@{DraftOrderIndex=$n; Quantity=$item.Qty})
                        RequiredSerials=$(if ($item.Serial) { $item.Qty } else { 0 })
                    })
                }
            }
        }
    }
}
for ($itemIndex=0; $itemIndex -lt $items.Count; $itemIndex++) {
    $item=$items[$itemIndex]
    $contributions=[System.Collections.Generic.List[object]]::new()
    for ($orderIndex=0; $orderIndex -lt 50; $orderIndex++) {
        if ($item.Serial) {
            $share=[math]::Floor($item.Qty / 50)
            if ((($orderIndex-$itemIndex*7+50) % 50) -lt ($item.Qty % 50)) { $share++ }
        } else { $share=[decimal]$item.Qty / 50 }
        $contributions.Add([ordered]@{DraftOrderIndex=$orderIndex+1; Quantity=$share})
    }
    [decimal]$contributionTotal=0
    foreach ($part in $contributions) { $contributionTotal += [decimal]$part.Quantity }
    if ($contributionTotal -ne $item.Qty) { throw "Mixed allocation total mismatch for $($item.No): $contributionTotal." }
    $pallets.Add([ordered]@{
        DraftPalletId=('W26S21P{0:0000}' -f ($pallets.Count+1))
        Item=$item.No; LabelTag=$item.Tag; Mixed=$true
        RequestedQuantity=$item.Qty; RequestedUnit=$item.Unit
        Contributions=@($contributions.ToArray())
        RequiredSerials=$(if ($item.Serial) { $item.Qty } else { 0 })
    })
}
[int]$serialCount=0
$palletIds=[System.Collections.Generic.HashSet[string]]::new()
foreach ($pallet in $pallets) {
    $serialCount += [int]$pallet.RequiredSerials
    if (-not $palletIds.Add($pallet.DraftPalletId)) { throw 'Duplicate draft pallet identifier.' }
}
if ($deliveries.Count -ne 50 -or $pallets.Count -ne 909 -or $serialCount -ne 106656) { throw "Dataset count mismatch: deliveries=$($deliveries.Count), pallets=$($pallets.Count), serials=$serialCount." }
$manifest=[ordered]@{
    Status='DRAFT ONLY - no Business Central records created; identifiers are not reserved'
    Environment='Pool_Sandbox'; Company='LIVE APMS'; PoolWeek='WK-2026-13'
    WeekStart='2026-09-21'; WeekEnd='2026-09-27'
    Pending='Supported KG conversion and current posting workflow verification; two 440 kg pallets per order confirmed'
    Notes=@('Actual batch and bin delivery numbers must come from BC numbering.',
        'Draft pallet identifiers require collision checks before creation.',
        'Serials must be generated after actual batch numbers are allocated and the current serial parser is verified.',
        'Bulk quantities are requested physical kg, not quantities ready to enter into a BC journal.',
        'No input kg or packing yield has been assumed from the bin count.')
    PlanGrouping='One plan per grower, block and delivery day'
    Totals=@{ Deliveries=50; ProductionOrders=50; Bins=500; BatchPlans=50; Pallets=909; MixedPallets=9; UnitSerials=106656 }
    Deliveries=@($deliveries.ToArray()); Pallets=@($pallets.ToArray())
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding utf8
$manifest.Totals | ConvertTo-Json
Write-Output $OutputPath
