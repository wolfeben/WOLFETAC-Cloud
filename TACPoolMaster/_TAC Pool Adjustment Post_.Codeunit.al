codeunit 50274 "TAC Pool Adjustment Post"
{
    // AL-12: posts a manual kg transfer as paired ledger entries — TRD out of
    // the From Pool, TRA into the To Pool (design §4.5, §F-06). Allowed only
    // while the Pool Group is Open so a closed payout is never invalidated.

    var
        TRACodeTok: Label 'TRA', Locked = true;
        TRDCodeTok: Label 'TRD', Locked = true;
        AlreadyPostedErr: Label 'Adjustment %1 has already been posted.', Comment = '%1 = Adjustment ID';

    procedure PostAdjustment(var PoolAdjustment: Record "TAC Pool Adjustment")
    var
        PoolGroup: Record "TAC Pool Group Header";
    begin
        if PoolAdjustment.Posted then
            Error(AlreadyPostedErr, PoolAdjustment."Adjustment ID");

        PoolGroup.Get(PoolAdjustment."Pool Group ID");
        PoolGroup.TestStatusOpen();

        PoolAdjustment.TestField(Comment); // mandatory (design §4.5)
        PoolAdjustment.TestField(Kgs);
        PoolAdjustment.TestField("From Pool Code");
        PoolAdjustment.TestField("To Pool Code");

        // TRD removes kgs from the From Pool; TRA adds them to the To Pool.
        WriteEntry(PoolAdjustment, TRDCodeTok, PoolAdjustment."From Pool Code", -PoolAdjustment.Kgs);
        WriteEntry(PoolAdjustment, TRACodeTok, PoolAdjustment."To Pool Code", PoolAdjustment.Kgs);

        PoolAdjustment.Posted := true;
        PoolAdjustment."Posted By" := CopyStr(UserId(), 1, MaxStrLen(PoolAdjustment."Posted By"));
        PoolAdjustment."Posted DateTime" := CurrentDateTime();
        PoolAdjustment.Modify();
    end;

    procedure PostAdjustmentEntry(var PoolAdjustment: Record "TAC Pool Adjustment"; TransTypeCode: Code[10]; PoolCode: Code[20]; SignedKgs: Decimal)
    var
        PoolGroup: Record "TAC Pool Group Header";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolGroup.Get(PoolAdjustment."Pool Group ID");
        PoolGroup.TestStatusOpen();
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Source Document No.", Format(PoolAdjustment."Adjustment ID"));
        PoolLedgerEntry.SetRange("Trans Type Code", TransTypeCode);
        if not PoolLedgerEntry.IsEmpty() then
            exit;
        WriteEntry(PoolAdjustment, TransTypeCode, PoolCode, SignedKgs);
    end;

    local procedure WriteEntry(var PoolAdjustment: Record "TAC Pool Adjustment";
                                TransTypeCode: Code[10];
                                PoolCode: Code[20];
                                SignedKgs: Decimal)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := PoolCode;
        PoolLedgerEntry."Pool Group ID" := PoolAdjustment."Pool Group ID";
        PoolLedgerEntry."Trans Type Code" := TransTypeCode;
        PoolLedgerEntry."Grower Code" := PoolAdjustment."Grower Code";
        PoolLedgerEntry."Quantity (Kg)" := SignedKgs;
        PoolLedgerEntry."Transaction Date" := PoolAdjustment."Date";
        PoolLedgerEntry."Posting Date" := Today();
        PoolLedgerEntry."Source Document No." := Format(PoolAdjustment."Adjustment ID");
        PoolLedgerEntry."Source Type" := PoolLedgerEntry."Source Type"::Adjustment;
        PoolLedgerEntry."Source System ID" := PoolAdjustment.SystemId;
        PoolLedgerEntry.Comment := PoolAdjustment.Comment;
        PoolLedgerEntry.Insert(true);
    end;
}
