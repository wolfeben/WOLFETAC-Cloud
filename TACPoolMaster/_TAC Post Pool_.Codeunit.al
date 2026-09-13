codeunit 50201 "TAC Post Pool"
{
    procedure ProvisionalClose(PoolCode: Code[20]; CloseSequenceNo: Integer)
    var
        Pool: Record "TAC Pool";
        Schedule: Record "TAC Pool Payment Schedule";
    begin
        // Provisional close
        // Resolve the schedule row for this pool type and sequence (`T-16`).
        Pool.Get(PoolCode);
        ResolveProvisionalSchedule(Pool, CloseSequenceNo, Schedule);
        // Reject a sequence that is out of order or already used.
        EnsureProvisionalSequence(Pool, CloseSequenceNo);
        // Validate `V-04` (every kilogram priced) unless overridden by permission.
        ValidateConsingmentLines(PoolCode);
        //"Reverse the OUTSTANDING provisional G/L batch" in provisional close Pool
        RevertInterimRevenue(PoolCode);
        ProcessPoolCloseChargeType(Pool);
        CalcGrowerPmtAtClose(Pool, false, CloseSequenceNo);
        PostInterimRevenue(PoolCode);
        // Set `Status = Provisionally Closed`; increment `Provisional Count`; stamp the close sequence.
        Pool.Status:=Pool.Status::"Provisionally Closed";
        Pool."Provisional Count"+=1;
        Pool."Close Sequence":=CloseSequenceNo;
        Pool.Modify();
    end;
    procedure FinalClose(PoolCode: Code[20]; CloseSequenceNo: Integer)
    var
        Pool: Record "TAC Pool";
        Schedule: Record "TAC Pool Payment Schedule";
    begin
        Pool.Get(PoolCode);
        ResolveFinalSchedule(Pool, Schedule);
        EnsureFinalSequence(Pool, CloseSequenceNo, Schedule."Sequence No.");
        ProcessPoolCloseChargeType(Pool);
        CalcGrowerPmtAtClose(Pool, true, CloseSequenceNo);
        Pool.Status:=Pool.Status::Closed;
        Pool."Close Sequence":=CloseSequenceNo;
        Pool."Closed DateTime":=CurrentDateTime();
        Pool."Closed By":=CopyStr(UserId(), 1, MaxStrLen(Pool."Closed By"));
        Pool.Modify();
    end;
    procedure RevertInterimRevenue(PoolCode: Code[20])
    var
        PoolSetup: Record "TAC Pool Setup";
        GLEntry: Record "G/L Entry";
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        LineNo: Integer;
        InterimBalance: Decimal;
    begin
        PoolSetup.Get();
        PoolSetup.TestField("Interim Revenue Account");
        PoolSetup.TestField("Interim Revenue Bal. Account");
        GLEntry.SetRange("G/L Account No.", PoolSetup."Interim Revenue Account");
        GLEntry.SetRange("Document No.", PoolCode);
        GLEntry.CalcSums(Amount);
        InterimBalance:=GLEntry.Amount;
        if InterimBalance = 0 then exit;
        EnsurePoolCloseGLJournalBatch();
        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", GLJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", GLJnlBatchTok);
        if GenJournalLine.FindLast()then LineNo:=GenJournalLine."Line No." + 10000
        else
            LineNo:=10000;
        GenJournalLine.Init();
        GenJournalLine."Journal Template Name":=GLJnlTemplateTok;
        GenJournalLine."Journal Batch Name":=GLJnlBatchTok;
        GenJournalLine."Line No.":=LineNo;
        GenJournalLine."Posting Date":=WorkDate();
        GenJournalLine.Validate("Document No.", PoolCode);
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::"G/L Account");
        GenJournalLine.Validate("Account No.", PoolSetup."Interim Revenue Account");
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", PoolSetup."Interim Revenue Bal. Account");
        GenJournalLine.Validate(Amount, -InterimBalance);
        GenJournalLine.Description:=CopyStr(StrSubstNo('Revert interim revenue %1', PoolCode), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine.Insert(true);
        GenJnlPostLine.RunWithCheck(GenJournalLine);
    end;
    procedure PostInterimRevenue(PoolCode: Code[20])
    var
        PoolSetup: Record "TAC Pool Setup";
        ConsignmentLine: Record "TAC Consignment Line";
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        Pool: Record "TAC Pool";
        LineNo: Integer;
        EstimatedAmount: Decimal;
    begin
        PoolSetup.Get();
        PoolSetup.TestField("Interim Revenue Account");
        PoolSetup.TestField("Interim Revenue Bal. Account");
        EnsurePoolCloseGLJournalBatch();
        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", GLJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", GLJnlBatchTok);
        if GenJournalLine.FindLast()then LineNo:=GenJournalLine."Line No."
        else
            LineNo:=0;
        ConsignmentLine.SetRange("Pool Code", PoolCode);
        if ConsignmentLine.FindSet()then repeat EstimatedAmount:=ConsignmentLine.EstimatedAmount();
                if EstimatedAmount = 0 then continue;
                LineNo+=10000;
                GenJournalLine.Init();
                GenJournalLine."Journal Template Name":=GLJnlTemplateTok;
                GenJournalLine."Journal Batch Name":=GLJnlBatchTok;
                GenJournalLine."Line No.":=LineNo;
                GenJournalLine."Posting Date":=WorkDate();
                GenJournalLine.Validate("Document No.", PoolCode);
                GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::"G/L Account");
                GenJournalLine.Validate("Account No.", PoolSetup."Interim Revenue Account");
                GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
                GenJournalLine.Validate("Bal. Account No.", PoolSetup."Interim Revenue Bal. Account");
                GenJournalLine.Validate(Amount, EstimatedAmount);
                GenJournalLine.Description:=CopyStr(StrSubstNo('Interim revenue %1', PoolCode), 1, MaxStrLen(GenJournalLine.Description));
                GenJournalLine."Dimension Set ID":=ConsignmentLine."Dimension Set ID";
                GenJournalLine.Insert(true);
                GenJnlPostLine.RunWithCheck(GenJournalLine);
            until ConsignmentLine.Next() = 0;
    end;
    local procedure ProcessPoolCloseChargeType(Pool: Record "TAC Pool")
    var
        PoolGroup: Record "TAC Pool Group Header";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        LastEntryNoBefore: Integer;
    begin
        Pool.CalcFields("Total Kilograms", "Net Value");
        LastEntryNoBefore:=GetLastPoolLedgerEntryNo();
        ChargeContext.Init();
        ChargeContext."Pool Code":=Pool."Pool Code";
        ChargeContext."Pool Group ID":=Pool."Pool Group ID";
        ChargeContext."Grower Code":=Pool."Grower No.";
        ChargeContext."Grower Type":=MapGrowerType(Pool."Pool Type");
        ChargeContext."Supplier Type":=Pool."Pool Type";
        ChargeContext."Variety Code":=CopyStr(Pool."Variety Code", 1, MaxStrLen(ChargeContext."Variety Code"));
        ChargeContext."Grade Code":=Pool."Grade Code";
        ChargeContext."Size Code":=Pool."Size Code";
        ChargeContext.Kgs:=Pool."Total Kilograms";
        ChargeContext.Value:=Pool."Net Value";
        ChargeContext."Transaction Date":=WorkDate();
        ChargeContext."Posting Date":=WorkDate();
        if PoolGroup.Get(Pool."Pool Group ID")then ChargeContext."Source Document No.":=PoolGroup."Pool Group Code"
        else
            ChargeContext."Source Document No.":=Pool."Pool Code";
        // Pool close charges are executed through the shared charge engine.
        ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::GroupClose, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);
        // Ensure close entries are split and tagged by Pool Charge Type (50210).
        NormalizePoolCloseLedgerEntries(Pool, LastEntryNoBefore);
        // Post only the entries created by this close-charge pass.
        PostNewPoolCloseChargesToGL(Pool, LastEntryNoBefore);
    end;
    local procedure NormalizePoolCloseLedgerEntries(Pool: Record "TAC Pool"; LastEntryNoBefore: Integer)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", Pool."Pool Code");
        PoolLedgerEntry.SetFilter("Entry No.", '>%1', LastEntryNoBefore);
        if PoolLedgerEntry.FindSet()then repeat PoolLedgerEntry."Entry Type":=PoolLedgerEntry."Entry Type"::Charge;
                PoolLedgerEntry."Document Type":=PoolLedgerEntry."Document Type"::"Pool Close";
                PoolLedgerEntry."Charge Type Code":=ResolvePoolCloseChargeTypeCode(PoolLedgerEntry."Trans Type Code");
                PoolLedgerEntry.Modify();
            until PoolLedgerEntry.Next() = 0;
    end;
    local procedure ResolvePoolCloseChargeTypeCode(TransTypeCode: Code[10]): Code[20]var
        ChargeType: Record "TAC Pool Charge Type";
        ChargeTypeCode: Code[20];
    begin
        ChargeTypeCode:=CopyStr(TransTypeCode, 1, MaxStrLen(ChargeType.Code));
        ChargeType.SetRange(Code, ChargeTypeCode);
        ChargeType.SetRange("Trigger Point", ChargeType."Trigger Point"::"Pool Close");
        ChargeType.SetRange(Active, true);
        if not ChargeType.FindFirst()then Error(PoolCloseChargeTypeMapErr, TransTypeCode);
        exit(ChargeType.Code);
    end;
    local procedure GetLastPoolLedgerEntryNo(): Integer var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        if PoolLedgerEntry.FindLast()then exit(PoolLedgerEntry."Entry No.");
        exit(0);
    end;
    local procedure PostNewPoolCloseChargesToGL(Pool: Record "TAC Pool"; LastEntryNoBefore: Integer)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", Pool."Pool Code");
        PoolLedgerEntry.SetFilter("Entry No.", '>%1', LastEntryNoBefore);
        if PoolLedgerEntry.FindSet()then repeat PostPoolCloseLedgerToGL(PoolLedgerEntry);
            until PoolLedgerEntry.Next() = 0;
    end;
    local procedure PostPoolCloseLedgerToGL(PoolLedgerEntry: Record "TAC Pool Ledger Entry")
    var
        ChargeType: Record "TAC Pool Charge Type";
        PoolSetup: Record "TAC Pool Setup";
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        LineNo: Integer;
    begin
        if PoolLedgerEntry.Amount = 0 then exit;
        PoolLedgerEntry.TestField("Charge Type Code");
        ChargeType.Get(PoolLedgerEntry."Charge Type Code");
        ChargeType.TestField("G/L Account No.");
        ChargeType.TestField("Bal. G/L Account No.");
        PoolSetup.Get();
        PoolSetup.TestField("Pool Charge Clearing Account");
        EnsurePoolCloseGLJournalBatch();
        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", GLJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", GLJnlBatchTok);
        if GenJournalLine.FindLast()then LineNo:=GenJournalLine."Line No." + 10000
        else
            LineNo:=10000;
        GenJournalLine.Init();
        GenJournalLine."Journal Template Name":=GLJnlTemplateTok;
        GenJournalLine."Journal Batch Name":=GLJnlBatchTok;
        GenJournalLine."Line No.":=LineNo;
        if PoolLedgerEntry."Posting Date" <> 0D then GenJournalLine."Posting Date":=PoolLedgerEntry."Posting Date"
        else
            GenJournalLine."Posting Date":=WorkDate();
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::"G/L Account");
        GenJournalLine.Validate("Account No.", ChargeType."G/L Account No.");
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", ChargeType."Bal. G/L Account No.");
        GenJournalLine.Validate(Amount, Abs(PoolLedgerEntry.Amount));
        if PoolLedgerEntry."Source Document No." <> '' then GenJournalLine.Validate("Document No.", PoolLedgerEntry."Source Document No.");
        GenJournalLine.Description:=CopyStr(StrSubstNo('Pool close charge %1', PoolLedgerEntry."Charge Type Code"), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine."Dimension Set ID":=PoolLedgerEntry."Dimension Set ID";
        GenJournalLine.Insert(true);
        GenJnlPostLine.RunWithCheck(GenJournalLine);
    end;
    local procedure EnsurePoolCloseGLJournalBatch()
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
    begin
        if not GenJournalTemplate.Get(GLJnlTemplateTok)then begin
            GenJournalTemplate.Init();
            GenJournalTemplate.Name:=GLJnlTemplateTok;
            GenJournalTemplate.Validate(Type, GenJournalTemplate.Type::General);
            GenJournalTemplate.Insert(true);
        end;
        if not GenJournalBatch.Get(GLJnlTemplateTok, GLJnlBatchTok)then begin
            GenJournalBatch.Init();
            GenJournalBatch."Journal Template Name":=GLJnlTemplateTok;
            GenJournalBatch.Name:=GLJnlBatchTok;
            GenJournalBatch.Insert(true);
        end;
    end;
    local procedure MapGrowerType(PoolType: Enum "TAC Grower Pool Type"): Enum "TAC Grower Type" begin
        case PoolType of PoolType::External: exit(Enum::"TAC Grower Type"::External);
        PoolType::"Contract Pack": exit(Enum::"TAC Grower Type"::"Contract Pack");
        else
            exit(Enum::"TAC Grower Type"::Internal);
        end;
    end;
    local procedure CalcGrowerPmtAtClose(Pool: Record "TAC Pool"; IsFinal: Boolean; CloseSequenceNo: Integer)
    var
        PaymentSchedule: Record "TAC Pool Payment Schedule";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        Growers: List of[Code[20]];
        GrowerCode: Code[20];
        ResidualGrowerCode: Code[20];
        RealisedNet: Decimal;
        CumulativePct: Decimal;
        AlreadyPaid: Decimal;
        PoolPayment: Decimal;
        PoolKg: Decimal;
        GrowerKg: Decimal;
        GrowerPayment: Decimal;
        RunningTotal: Decimal;
        DistributedAmount: Decimal;
        FinalResidualTolerance: Decimal;
        UnallocatedResidual: Decimal;
        EntryType: Option Revenue, Charge, Freight, Payment, Quantity;
        DocumentType: Option Consignment, "Sales Invoice", "Run Close", "Pool Close", Manual;
        TransTypeCode: Code[10];
        PoolGroup: Record "TAC Pool Group Header";
        Idx: Integer;
    begin
        /*
        C-07 — Grower payment at close `\\\\\\\\\\\\\\\[v2.0]`
        Two models are possible and they pay different amounts. The setup field `Payment Model` selects between them; `Retention` is the default and the recommended value.
        Retention model (default). The scheduled percentage is a retention against the value realised so far. The balance is held back as a buffer against later downward adjustment.
        ```
        RealisedNet   := SUM(PoolLedgerEntry.Amount)          // all posted entries for the pool
        CumulativePct := PaymentSchedule."Cumulative Share %" // for this close sequence
        AlreadyPaid   := SUM(prior PP/PPV amounts for this pool)

        PoolPayment   := ROUND(CumulativePct / 100 \\\\\\\\\\\\\\\* RealisedNet, 0.01) - AlreadyPaid
        ```
        Full payout model. `CumulativePct` is treated as 100 at every close, so each close pays out everything realised to date. Selecting this model is a configuration change, not a code change.
        The final close always pays the residual in full, whatever the schedule says:
        ```
        IF PaymentSchedule."Is Final" THEN
            PoolPayment := RealisedNet - AlreadyPaid
        ```
        This guarantees no value is stranded in a closed pool.
        Per-grower split. Within the pool, each grower's share is by kilogram:
        ```
        GrowerPayment := ROUND(PoolPayment \\\\\\\\\\\\\\\* (GrowerKg / PoolKg), 0.01)
        ```
        Rounding residual is applied to the largest grower by kilograms, so the sum of grower payments equals the pool payment exactly.
        Worked example — Internal pool, retention model. Gross pool value $180,000.00, charges $42,000.00, realised net $138,000.00 (assume fully realised by the first close for illustration):
        Close	Offset	Cumulative %	Cumulative entitlement	Already paid	Paid this close
        Provisional 1	4 weeks	40	$55,200.00	$0.00	$55,200.00
        Provisional 2	8 weeks	80	$110,400.00	$55,200.00	$55,200.00
        Final	10 weeks	100	$138,000.00	$110,400.00	$27,600.00
        A grower holding 7,830 kg of a 31,861 kg pool takes 24.5755% of each of those amounts.
        */
        ResolveScheduleForClose(Pool, IsFinal, CloseSequenceNo, PaymentSchedule);
        if IsFinal then TransTypeCode:='PP'
        else
            TransTypeCode:='PPV';
        RealisedNet:=GetRealisedNet(Pool."Pool Code");
        CumulativePct:=PaymentSchedule."Cumulative Share %";
        if Pool."Payment Model" = Pool."Payment Model"::"Full Payout" then CumulativePct:=100;
        AlreadyPaid:=GetAlreadyPaid(Pool."Pool Code");
        if IsFinal then PoolPayment:=RealisedNet - AlreadyPaid
        else
            PoolPayment:=Round(CumulativePct / 100 * RealisedNet, 0.01) - AlreadyPaid;
        if PoolPayment = 0 then exit;
        Growers:=DistinctGrowersInPool(Pool."Pool Code");
        PoolKg:=GetPoolKgs(Pool."Pool Code");
        FinalResidualTolerance:=GetFinalResidualTolerance();
        if(Growers.Count() = 0) or (PoolKg = 0)then begin
            if IsFinal and (Abs(PoolPayment) > FinalResidualTolerance)then Error(NoGrowerKgErr, Pool."Pool Code", PoolPayment);
            exit;
        end;
        ResidualGrowerCode:=ResidualGrowerForPool(Pool."Pool Code", Growers);
        if ResidualGrowerCode = '' then begin
            if IsFinal and (Abs(PoolPayment) > FinalResidualTolerance)then Error(NoGrowerKgErr, Pool."Pool Code", PoolPayment);
            exit;
        end;
        if PoolGroup.Get(Pool."Pool Group ID")then;
        RunningTotal:=0;
        DistributedAmount:=0;
        for Idx:=1 to Growers.Count()do begin
            GrowerCode:=Growers.Get(Idx);
            if GrowerCode <> ResidualGrowerCode then begin
                GrowerKg:=GetGrowerKgs(Pool."Pool Code", GrowerCode);
                GrowerPayment:=Round(PoolPayment * (GrowerKg / PoolKg), 0.01);
                RunningTotal+=GrowerPayment;
                DistributedAmount+=GrowerPayment;
                PoolLedgerEntry.Init();
                PoolLedgerEntry."Pool Code":=Pool."Pool Code";
                PoolLedgerEntry."Pool Group ID":=Pool."Pool Group ID";
                PoolLedgerEntry."Entry Type":=EntryType::Payment;
                PoolLedgerEntry."Document Type":=DocumentType::"Pool Close";
                PoolLedgerEntry."Trans Type Code":=TransTypeCode;
                PoolLedgerEntry."Grower Code":=GrowerCode;
                PoolLedgerEntry.Amount:=-GrowerPayment;
                PoolLedgerEntry.Provisional:=not IsFinal;
                PoolLedgerEntry."Posting Date":=WorkDate();
                PoolLedgerEntry."Source Document No.":=Pool."Pool Code";
                if PoolGroup."Pool Group Code" <> '' then PoolLedgerEntry."Source Document No.":=PoolGroup."Pool Group Code";
                PoolLedgerEntry.Insert(true);
                PostPoolPaymentLedgerToGL(Pool, PoolLedgerEntry);
            end;
        end;
        GrowerPayment:=PoolPayment - RunningTotal;
        DistributedAmount+=GrowerPayment;
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code":=Pool."Pool Code";
        PoolLedgerEntry."Pool Group ID":=Pool."Pool Group ID";
        PoolLedgerEntry."Entry Type":=EntryType::Payment;
        PoolLedgerEntry."Document Type":=DocumentType::"Pool Close";
        PoolLedgerEntry."Trans Type Code":=TransTypeCode;
        PoolLedgerEntry."Grower Code":=ResidualGrowerCode;
        PoolLedgerEntry.Amount:=-GrowerPayment;
        PoolLedgerEntry.Provisional:=not IsFinal;
        PoolLedgerEntry."Posting Date":=WorkDate();
        PoolLedgerEntry."Source Document No.":=Pool."Pool Code";
        if PoolGroup."Pool Group Code" <> '' then PoolLedgerEntry."Source Document No.":=PoolGroup."Pool Group Code";
        PoolLedgerEntry.Insert(true);
        PostPoolPaymentLedgerToGL(Pool, PoolLedgerEntry);
        if IsFinal then begin
            UnallocatedResidual:=PoolPayment - DistributedAmount;
            if Abs(UnallocatedResidual) > FinalResidualTolerance then Error(FinalResidualErr, Pool."Pool Code", UnallocatedResidual, FinalResidualTolerance);
        end;
    end;
    local procedure ResolveScheduleForClose(var Pool: Record "TAC Pool"; IsFinal: Boolean; CloseSequenceNo: Integer; var Schedule: Record "TAC Pool Payment Schedule")
    var
        PoolGroup: Record "TAC Pool Group Header";
    begin
        PoolGroup.Get(Pool."Pool Group ID");
        Schedule.SetRange("Pool Type", ToSchedulePoolType(PoolGroup."Grower Pool Type"));
        Schedule.SetRange(Active, true);
        if IsFinal then begin
            Schedule.SetRange("Is Final", true);
            if not Schedule.FindFirst()then Error(FinalScheduleRowNotFoundErr, Format(ToSchedulePoolType(PoolGroup."Grower Pool Type")));
            exit;
        end;
        Schedule.SetRange("Sequence No.", CloseSequenceNo);
        if not Schedule.FindFirst()then Error(ScheduleRowNotFoundErr, Format(Schedule."Pool Type"), CloseSequenceNo);
        if Schedule."Is Final" then Error(ScheduleRowFinalErr, CloseSequenceNo, Format(Schedule."Pool Type"));
    end;
    local procedure ResolveFinalSchedule(var Pool: Record "TAC Pool"; var Schedule: Record "TAC Pool Payment Schedule")
    var
        PoolGroup: Record "TAC Pool Group Header";
        SchedulePoolType: Option Internal, External, Grower;
    begin
        PoolGroup.Get(Pool."Pool Group ID");
        SchedulePoolType:=ToSchedulePoolType(PoolGroup."Grower Pool Type");
        Schedule.SetRange("Pool Type", SchedulePoolType);
        Schedule.SetRange(Active, true);
        Schedule.SetRange("Is Final", true);
        if not Schedule.FindFirst()then Error(FinalScheduleRowNotFoundErr, Format(SchedulePoolType));
    end;
    local procedure EnsureFinalSequence(var Pool: Record "TAC Pool"; CloseSequenceNo: Integer; FinalSequenceNo: Integer)
    var
        ExpectedSequenceNo: Integer;
        PoolGroup: Record "TAC Pool Group Header";
        ConsignmentLine: Record "TAC Consignment Line";
    begin
        PoolGroup.Get(Pool."Pool Group ID");
        ExpectedSequenceNo:=PoolGroup."Provisional Close Count" + 1;
        if CloseSequenceNo <> ExpectedSequenceNo then Error(FinalSequenceErr, CloseSequenceNo, PoolGroup."Pool Group Code", ExpectedSequenceNo);
        if CloseSequenceNo <> FinalSequenceNo then Error(FinalSequenceErr, CloseSequenceNo, PoolGroup."Pool Group Code", FinalSequenceNo);
        ConsignmentLine.SetRange("Pool Code", Pool."Pool Code");
        ConsignmentLine.CalcFields("Qty. Shipped Not Invoiced");
        ConsignmentLine.SetFilter("Qty. Shipped Not Invoiced", '<>0');
        if not ConsignmentLine.IsEmpty then Error(ErrConsignmentLineNotInvoiced, Pool."Pool Code");
    end;
    local procedure GetRealisedNet(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange(Reversed, false);
        PoolLedgerEntry.SetFilter("Trans Type Code", '<>%1&<>%2', 'PP', 'PPV');
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
    end;
    local procedure GetAlreadyPaid(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange(Reversed, false);
        PoolLedgerEntry.SetFilter("Trans Type Code", '%1|%2', 'PP', 'PPV');
        PoolLedgerEntry.CalcSums(Amount);
        exit(-PoolLedgerEntry.Amount);
    end;
    local procedure DistinctGrowersInPool(PoolCode: Code[20]): List of[Code[20]]var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        Growers: List of[Code[20]];
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetFilter("Grower Code", '<>%1', '');
        if PoolLedgerEntry.FindSet()then repeat if not Growers.Contains(PoolLedgerEntry."Grower Code")then Growers.Add(PoolLedgerEntry."Grower Code");
            until PoolLedgerEntry.Next() = 0;
        exit(Growers);
    end;
    local procedure GetPoolKgs(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.CalcSums("Quantity (Kg)");
        exit(PoolLedgerEntry."Quantity (Kg)");
    end;
    local procedure GetGrowerKgs(PoolCode: Code[20]; GrowerCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Grower Code", GrowerCode);
        PoolLedgerEntry.CalcSums("Quantity (Kg)");
        exit(PoolLedgerEntry."Quantity (Kg)");
    end;
    local procedure ResidualGrowerForPool(PoolCode: Code[20]; Growers: List of[Code[20]]): Code[20]var
        CandidateGrowerCode: Code[20];
        GrowerCode: Code[20];
        CandidateKg: Decimal;
        GrowerKg: Decimal;
        Idx: Integer;
    begin
        CandidateGrowerCode:='';
        CandidateKg:=0;
        for Idx:=1 to Growers.Count()do begin
            GrowerCode:=Growers.Get(Idx);
            GrowerKg:=GetGrowerKgs(PoolCode, GrowerCode);
            if(CandidateGrowerCode = '') or (GrowerKg > CandidateKg) or ((GrowerKg = CandidateKg) and (GrowerCode < CandidateGrowerCode))then begin
                CandidateGrowerCode:=GrowerCode;
                CandidateKg:=GrowerKg;
            end;
        end;
        exit(CandidateGrowerCode);
    end;
    local procedure GetFinalResidualTolerance(): Decimal var
        PoolSetup: Record "TAC Pool Setup";
    begin
        if not PoolSetup.Get()then exit(0);
        exit(PoolSetup."Final Residual Tolerance");
    end;
    local procedure PostPoolPaymentLedgerToGL(Pool: Record "TAC Pool"; PoolLedgerEntry: Record "TAC Pool Ledger Entry")
    var
        PoolSetup: Record "TAC Pool Setup";
        TransType: Record "TAC Pool Trans Type";
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        GLAccountNo: Code[20];
        LineNo: Integer;
    begin
        if PoolLedgerEntry.Amount = 0 then exit;
        if not TransType.Get(PoolLedgerEntry."Trans Type Code")then exit;
        if Pool."Pool Type" = Pool."Pool Type"::External then GLAccountNo:=TransType."GL Account External"
        else
            GLAccountNo:=TransType."GL Account Internal";
        if GLAccountNo = '' then exit;
        PoolSetup.Get();
        PoolSetup.TestField("Pool Charge Clearing Account");
        EnsurePoolCloseGLJournalBatch();
        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", GLJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", GLJnlBatchTok);
        if GenJournalLine.FindLast()then LineNo:=GenJournalLine."Line No." + 10000
        else
            LineNo:=10000;
        GenJournalLine.Init();
        GenJournalLine."Journal Template Name":=GLJnlTemplateTok;
        GenJournalLine."Journal Batch Name":=GLJnlBatchTok;
        GenJournalLine."Line No.":=LineNo;
        if PoolLedgerEntry."Posting Date" <> 0D then GenJournalLine."Posting Date":=PoolLedgerEntry."Posting Date"
        else
            GenJournalLine."Posting Date":=WorkDate();
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::"G/L Account");
        GenJournalLine.Validate("Account No.", GLAccountNo);
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", PoolSetup."Pool Charge Clearing Account");
        GenJournalLine.Validate(Amount, PoolLedgerEntry.Amount);
        if PoolLedgerEntry."Source Document No." <> '' then GenJournalLine.Validate("Document No.", PoolLedgerEntry."Source Document No.");
        GenJournalLine.Description:=CopyStr(StrSubstNo('Pool payment %1', PoolLedgerEntry."Grower Code"), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine."Dimension Set ID":=PoolLedgerEntry."Dimension Set ID";
        GenJournalLine.Insert(true);
        GenJnlPostLine.RunWithCheck(GenJournalLine);
    end;
    local procedure ValidateConsingmentLines(PoolCode: Code[20])
    var
        Consignment: Record "TAC Consignment Header";
        ConsignmentLine: Record "TAC Consignment Line";
        PoolSetup: Record "TAC Pool Setup";
    begin
        /*
        Block a provisional close where any consignment detail line in the pool has no corresponding fruit payment. Overridable by permission, controlled by `Allow Provisional with Unpriced Kg` in setup.
        */
        PoolSetup.Get();
        If PoolSetup."Allow Prov. with Unpriced KG" then exit;
        ConsignmentLine.SetRange("Pool Code", PoolCode);
        if ConsignmentLine.FindSet()then repeat // A fruit payment is the source of truth for whether the consignment is priced.
                Consignment.Get(ConsignmentLine."Consignment No.");
                if not Consignment."Fruit Payment Exists" then Error('Unpriced consignment line %1 in pool %2. Cannot provisionally close.', ConsignmentLine."Line No.", PoolCode);
            until ConsignmentLine.Next() = 0;
    end;
    local procedure ResolveProvisionalSchedule(var Pool: Record "TAC Pool"; CloseSequenceNo: Integer; var Schedule: Record "TAC Pool Payment Schedule")
    var
        PoolGroup: Record "TAC Pool Group Header";
    begin
        PoolGroup.Get(Pool."Pool Group ID");
        Schedule.SetRange("Pool Type", ToSchedulePoolType(PoolGroup."Grower Pool Type"));
        Schedule.SetRange("Sequence No.", CloseSequenceNo);
        Schedule.SetRange(Active, true);
        if not Schedule.FindFirst()then Error(ScheduleRowNotFoundErr, Format(Schedule."Pool Type"), CloseSequenceNo);
        if Schedule."Is Final" then Error(ScheduleRowFinalErr, CloseSequenceNo, Format(Schedule."Pool Type"));
    end;
    local procedure EnsureProvisionalSequence(var Pool: Record "TAC Pool"; CloseSequenceNo: Integer)
    var
        ExpectedSequenceNo: Integer;
        PoolGroup: Record "TAC Pool Group Header";
    begin
        PoolGroup.Get(Pool."Pool Group ID");
        ExpectedSequenceNo:=PoolGroup."Provisional Close Count" + 1;
        if CloseSequenceNo <> ExpectedSequenceNo then Error(SequenceOutOfOrderErr, CloseSequenceNo, PoolGroup."Pool Group Code", ExpectedSequenceNo);
    end;
    local procedure ToSchedulePoolType(GrowerPoolType: Enum "TAC Grower Pool Type"): Option Internal, External, Grower var
        SchedulePoolType: Option Internal, External, Grower;
    begin
        case GrowerPoolType of GrowerPoolType::Internal: exit(SchedulePoolType::Internal);
        GrowerPoolType::External: exit(SchedulePoolType::External);
        else
            exit(SchedulePoolType::Grower);
        end;
    end;
    var ScheduleRowNotFoundErr: Label 'No active payment schedule row exists for pool type %1 and sequence %2.', Comment = '%1 = Pool Type, %2 = Sequence No.';
    ScheduleRowFinalErr: Label 'Schedule row %1 for pool type %2 is marked as final and cannot be used for a provisional close.', Comment = '%1 = Sequence No., %2 = Pool Type';
    SequenceOutOfOrderErr: Label 'Close sequence %1 is out of order for pool group %2. Expected sequence is %3.', Comment = '%1 = Requested sequence, %2 = Pool Group Code, %3 = Expected sequence';
    FinalScheduleRowNotFoundErr: Label 'No active final payment schedule row exists for pool type %1.', Comment = '%1 = Pool Type';
    FinalSequenceErr: Label 'Final close sequence %1 is out of order for pool group %2. Expected final sequence is %3.', Comment = '%1 = Requested sequence, %2 = Pool Group Code, %3 = Expected final sequence';
    FinalResidualErr: Label 'Final close residual %2 exceeds tolerance %3 for pool %1.', Comment = '%1 = Pool Code, %2 = Residual, %3 = Tolerance';
    NoGrowerKgErr: Label 'Pool %1 has no grower kilograms to split payment. Final close residual is %2.', Comment = '%1 = Pool Code, %2 = Residual amount';
    PoolCloseChargeTypeMapErr: Label 'No active Pool Close charge type is configured for trans type %1.', Comment = '%1 = Trans Type Code';
    ErrConsignmentLineNotInvoiced: Label 'Consignment Line for Pool %1 is not fully invoiced';
    GLJnlTemplateTok: Label 'POOLCLS', Locked = true;
    GLJnlBatchTok: Label 'CLOSE', Locked = true;
}
