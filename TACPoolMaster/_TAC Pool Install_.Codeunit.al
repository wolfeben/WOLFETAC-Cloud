codeunit 50278 "TAC Pool Install"
{
    // Seeds the three No. Series and the setup singleton (design §F-01, §12).
    // Idempotent: every step guards on existence, so a re-run (or upgrade)
    // inserts no duplicates.
    Subtype = Install;

    var PoolGroupNoSeriesTok: Label 'POOL-GRP', Locked = true;
    PoolLedgerNoSeriesTok: Label 'POOL-LE', Locked = true;
    PoolPaymentNoSeriesTok: Label 'POOL-PAY', Locked = true;
    trigger OnInstallAppPerCompany()
    begin
        SeedSetup();
    end;
    /// <summary>Public so an Upgrade codeunit or a manual setup action can re-run it.</summary>
    procedure SeedSetup()
    begin
        EnsureNoSeries(PoolGroupNoSeriesTok, 'Pool Group Code', 'PG-00001');
        EnsureNoSeries(PoolLedgerNoSeriesTok, 'Pool Ledger Entry No.', 'PLE-00001');
        EnsureNoSeries(PoolPaymentNoSeriesTok, 'Pool Payment No.', 'PP-00001');
        EnsureSetup();
    end;
    local procedure EnsureNoSeries(SeriesCode: Code[20]; Description: Text[100]; StartingNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if NoSeries.Get(SeriesCode)then exit;
        NoSeries.Init();
        NoSeries.Code:=SeriesCode;
        NoSeries.Description:=Description;
        NoSeries."Default Nos.":=true;
        NoSeries."Manual Nos.":=true;
        NoSeries.Insert();
        NoSeriesLine.Init();
        NoSeriesLine."Series Code":=SeriesCode;
        NoSeriesLine."Line No.":=10000;
        NoSeriesLine."Starting No.":=StartingNo;
        NoSeriesLine."Increment-by No.":=1;
        NoSeriesLine.Insert();
    end;
    local procedure EnsureSetup()
    var
        PoolSetup: Record "TAC Pool Setup";
    begin
        if not PoolSetup.Get()then begin
            PoolSetup.Init();
            PoolSetup.Insert();
        end;
        /*if PoolSetup."Pool Group Nos." = '' then
            PoolSetup."Pool Group Nos." := PoolGroupNoSeriesTok;
        if PoolSetup."Pool Ledger Entry Nos." = '' then
            PoolSetup."Pool Ledger Entry Nos." := PoolLedgerNoSeriesTok;
        if PoolSetup."Pool Payment Nos." = '' then
            PoolSetup."Pool Payment Nos." := PoolPaymentNoSeriesTok;*/
        // Provisional percentages: seeded on upgrade too, because InitValue only
        // fires on Init() and the setup record already exists on every install
        // that predates these fields. Zero means "not yet set", not "pay
        // nothing" — a genuine zero would make the provisional close pointless.
        if PoolSetup."Internal Prov. 1 %" = 0 then PoolSetup."Internal Prov. 1 %":=40;
        if PoolSetup."Internal Prov. 2 %" = 0 then PoolSetup."Internal Prov. 2 %":=40;
        if PoolSetup."External Prov. 1 %" = 0 then PoolSetup."External Prov. 1 %":=50;
        PoolSetup.Modify();
    end;
}
