codeunit 50273 "TAC Pool Group Close"
{
    // AL-09 / §7 / ADR-001. Orchestrates the close: pre-close validation
    // (V1-V6), a charge validate pass that writes nothing, then the write pass
    // (charges, above-the-line proration, net, grower payments), then delegates
    // GL + invoice posting to 50279, then advances status. The whole thing runs
    // calculation-first; the only feature that posts money is 50279.
    var PPCodeTok: Label 'PP', Locked = true;
    PPVCodeTok: Label 'PPV', Locked = true;
    ClosedStatusErr: Label 'Pool Group %1 is already Closed.', Comment = '%1 = Pool Group Code';
    ProvisionalAfterFinalErr: Label 'Pool Group %1 cannot be provisionally closed after a final close.', Comment = '%1 = Pool Group Code';
    GTypeBlockErr: Label 'Contract Pack (G) Pool Group %1 cannot be closed in v1.', Comment = '%1 = Pool Group Code';
    ProvisionalLimitErr: Label 'Pool Group %1 has reached its provisional close limit of %2.', Comment = '%1 = Pool Group Code, %2 = limit';
    UnpostedExpenseErr: Label 'Pool Group %1 has unposted expenses; post or remove them before closing.', Comment = '%1 = Pool Group Code';
    MandatoryGLErr: Label 'Mandatory trans type %1 has no G/L account configured for this pool type.', Comment = '%1 = Trans Type Code';
    NoGrowerVendorErr: Label 'Pool Group %1 cannot be closed: grower %2 has no vendor. Set Grower Code %2 on the grower''s vendor card.', Comment = '%1 = Pool Group Code, %2 = Grower Code';
    PostingSetupErr: Label 'Pool Group %1 cannot be closed because %2 is not configured.', Comment = '%1 = Pool Group Code, %2 = setup field caption';
    NoResumablePaymentErr: Label 'Pool Group %1 has no incomplete payment run to resume.', Comment = '%1 = Pool Group Code';
    ResumableCloseStatusErr: Label 'Pool Group %1 is already closed.', Comment = '%1 = Pool Group Code';
    /// <summary>Close the Pool Group provisionally or finally (design §7).</summary>
    procedure Close(PoolGroupID: Integer; PaymentType: Enum "TAC Pool Payment Type")
    var
        PoolGroup: Record "TAC Pool Group Header";
        GLPosting: Codeunit "TAC Pool GL Posting";
        PoolPaymentID: Integer;
        BatchName: Code[10];
    begin
        PoolGroup.Get(PoolGroupID);
        ValidatePreClose(PoolGroup, PaymentType); // V1-V6
        RunChargeValidatePass(PoolGroup); // ADR-001 dry-run (no writes)
        // Write pass.
        // Step 2 (FR) is a guarded stub — blocked by OI-04.
        // Step 3 (CP for consignments paid since the last close) is handled by
        // F-05 on payment; a close-time re-scan is a TODO pending OI-PE-02.
        PoolPaymentID:=CreatePaymentHeader(PoolGroup, PaymentType, BatchName);
        ApplyGroupCloseCharges(PoolGroup, PoolPaymentID); // steps 4,5,7
        ProrateAboveTheLine(PoolGroup, PoolPaymentID); // step 6
        WriteGrowerPayments(PoolGroup, PaymentType, PoolPaymentID); // steps 8,9
        WriteGrowerValueCharges(PoolGroup, PoolPaymentID); // step 10
        GLPosting.PostClose(PoolGroup, PaymentType, PoolPaymentID, BatchName); // steps 11,12
        AdvanceStatus(PoolGroup, PaymentType); // steps 13,14,15
        MarkPaymentCompleted(PoolPaymentID);
    end;
    /// <summary>
    /// Recovers a close that posted its G/L journal but stopped before the
    /// grower invoices and Pool Group status could be completed.
    /// </summary>
    procedure ResumeLastClose(PoolGroupID: Integer)
    var
        PoolGroup: Record "TAC Pool Group Header";
        PoolPaymentHeader: Record "TAC Pool Payment Header";
        GLPosting: Codeunit "TAC Pool GL Posting";
    begin
        PoolGroup.Get(PoolGroupID);
        if PoolGroup.Status = PoolGroup.Status::Closed then Error(ResumableCloseStatusErr, PoolGroup."Pool Group Code");
        PoolPaymentHeader.SetRange("Pool Group ID", PoolGroupID);
        PoolPaymentHeader.SetRange(Reversed, false);
        PoolPaymentHeader.SetRange("Completed DateTime", 0DT);
        PoolPaymentHeader.SetCurrentKey("Pool Group ID", "Payment No.");
        if not PoolPaymentHeader.FindLast()then Error(NoResumablePaymentErr, PoolGroup."Pool Group Code");
        // A provisional run cannot be incomplete if the group is already
        // provisionally closed. This prevents a legacy, completed payment
        // header (created before completion tracking existed) being advanced
        // a second time.
        if(PoolPaymentHeader."Payment Type" = PoolPaymentHeader."Payment Type"::Provisional) and (PoolGroup.Status = PoolGroup.Status::"Provisionally Closed")then Error(NoResumablePaymentErr, PoolGroup."Pool Group Code");
        GLPosting.ResumePaymentInvoices(PoolGroup, PoolPaymentHeader."Pool Payment ID", PoolPaymentHeader."Payment Type");
        AdvanceStatus(PoolGroup, PoolPaymentHeader."Payment Type");
        MarkPaymentCompleted(PoolPaymentHeader."Pool Payment ID");
    end;
    local procedure ValidatePreClose(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type")
    begin
        // V1 — status + G-type block. (Message wording to be aligned with §7.1.)
        if PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::"Contract Pack" then Error(GTypeBlockErr, PoolGroup."Pool Group Code");
        if PoolGroup.Status = PoolGroup.Status::Closed then Error(ClosedStatusErr, PoolGroup."Pool Group Code");
        if(PaymentType = PaymentType::Provisional) and (PoolGroup.Status = PoolGroup.Status::"Provisionally Closed")then; // a further provisional is allowed up to the limit (V2)
        if(PaymentType = PaymentType::Provisional) and (PoolGroup.Status = PoolGroup.Status::Closed)then Error(ProvisionalAfterFinalErr, PoolGroup."Pool Group Code");
        // V2 — provisional limit (2 for Internal, 1 otherwise — confirm split).
        if PaymentType = PaymentType::Provisional then if PoolGroup."Provisional Close Count" >= MaxProvisionalCloses(PoolGroup)then Error(ProvisionalLimitErr, PoolGroup."Pool Group Code", MaxProvisionalCloses(PoolGroup));
        // V3 — all PKD orders finished / V4 — all consignments despatched:
        // cross-engagement checks (sales-execution-stock). TODO once those
        // sources are reachable (OI-PE-02/03/07).
        // V5 — no unposted expenses.
        CheckNoUnpostedExpenses(PoolGroup);
        // V6 — mandatory trans types have a G/L account for this pool type.
        CheckMandatoryGLAccounts(PoolGroup);
        CheckPostingSetup(PoolGroup);
        // V7 — every grower in the group resolves to exactly one vendor. The
        // grower key is a grower dimension value; step 11 needs the vendor that
        // carries it (ADR-004).
        CheckGrowersResolveToVendors(PoolGroup);
    end;
    local procedure MaxProvisionalCloses(var PoolGroup: Record "TAC Pool Group Header"): Integer begin
        if PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::Internal then exit(2);
        exit(1);
    end;
    local procedure CheckNoUnpostedExpenses(var PoolGroup: Record "TAC Pool Group Header")
    var
        PoolExpenseHeader: Record "TAC Pool Expense Header";
    begin
        PoolExpenseHeader.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolExpenseHeader.SetRange(Posted, false);
        if not PoolExpenseHeader.IsEmpty()then Error(UnpostedExpenseErr, PoolGroup."Pool Group Code");
    end;
    local procedure CheckMandatoryGLAccounts(var PoolGroup: Record "TAC Pool Group Header")
    var
        TransType: Record "TAC Pool Trans Type";
        GLAccountNo: Code[20];
    begin
        TransType.SetRange(Active, true);
        TransType.SetRange(Mandatory, true);
        if TransType.FindSet()then repeat if PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::External then GLAccountNo:=TransType."GL Account External"
                else
                    GLAccountNo:=TransType."GL Account Internal";
                if GLAccountNo = '' then Error(MandatoryGLErr, TransType."Code");
            until TransType.Next() = 0;
    end;
    local procedure CheckGrowersResolveToVendors(var PoolGroup: Record "TAC Pool Group Header")
    var
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
        Growers: List of[Code[20]];
        GrowerCode: Code[20];
        VendorNo: Code[20];
    begin
        // Fail here, in the pre-close pass, rather than part-way through step 11
        // with the ledger already written (ADR-001). A grower code that maps to
        // two vendors errors from inside the resolution — it is a master-data
        // fault the close cannot pick a winner for.
        Growers:=DistinctGrowersInGroup(PoolGroup."Pool Group ID");
        foreach GrowerCode in Growers do if not GrowerMgt.FindVendorNoForGrower(GrowerCode, VendorNo)then Error(NoGrowerVendorErr, PoolGroup."Pool Group Code", GrowerCode);
    end;
    local procedure CheckPostingSetup(var PoolGroup: Record "TAC Pool Group Header")
    var
        PoolSetup: Record "TAC Pool Setup";
    begin
        if not PoolSetup.Get()then Error(PostingSetupErr, PoolGroup."Pool Group Code", 'Pool Payment Setup');
        if PoolSetup."Pool Charge Clearing Account" = '' then Error(PostingSetupErr, PoolGroup."Pool Group Code", PoolSetup.FieldCaption("Pool Charge Clearing Account"));
        if PoolSetup."Grower Posting Group" = '' then Error(PostingSetupErr, PoolGroup."Pool Group Code", PoolSetup.FieldCaption("Grower Posting Group"));
        if(PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::External) and (PoolSetup."Grower Ext. Posting Group" = '')then Error(PostingSetupErr, PoolGroup."Pool Group Code", PoolSetup.FieldCaption("Grower Ext. Posting Group"));
    end;
    local procedure RunChargeValidatePass(var PoolGroup: Record "TAC Pool Group Header")
    var
        Pool: Record "TAC Pool";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
    begin
        // ADR-001: resolve every GroupClose charge (raising mandatory no-match /
        // config errors) without writing a single ledger entry.
        Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        if Pool.FindSet()then repeat BuildPoolContext(ChargeContext, PoolGroup, Pool, 0);
                ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::GroupClose, ChargeContext, Enum::"TAC Pool Charge Mode"::Validate);
            until Pool.Next() = 0;
    end;
    local procedure ApplyGroupCloseCharges(var PoolGroup: Record "TAC Pool Group Header"; PoolPaymentID: Integer)
    var
        Pool: Record "TAC Pool";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
    begin
        // Steps 4/5/7: kg-based charges over adjusted kgs and value charges over
        // the current pool net, posted at pool level by the engine.
        Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        if Pool.FindSet()then repeat BuildPoolContext(ChargeContext, PoolGroup, Pool, PoolPaymentID);
                ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::GroupClose, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);
            until Pool.Next() = 0;
    end;
    local procedure BuildPoolContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var PoolGroup: Record "TAC Pool Group Header"; var Pool: Record "TAC Pool"; PoolPaymentID: Integer)
    begin
        ChargeContext.Init();
        ChargeContext."Pool Code":=Pool."Pool Code";
        ChargeContext."Pool Group ID":=PoolGroup."Pool Group ID";
        ChargeContext."Supplier Type":=PoolGroup."Grower Pool Type";
        ChargeContext."Variety Code":=Pool."Variety Code";
        ChargeContext."Grade Code":=Pool."Grade Code";
        ChargeContext."Size Code":=Pool."Size Code";
        ChargeContext.Kgs:=GetPoolAdjKgs(Pool."Pool Code"); // TR + TRA - TRD
        ChargeContext.Value:=GetPoolNet(Pool."Pool Code"); // current net (value charges)
        ChargeContext."Posting Date":=Today();
        ChargeContext."Source Document No.":=PoolGroup."Pool Group Code";
        ChargeContext."Source Line No.":=PoolPaymentID;
        ChargeContext."Pool Payment ID":=PoolPaymentID;
    end;
    local procedure ProrateAboveTheLine(var PoolGroup: Record "TAC Pool Group Header"; PoolPaymentID: Integer)
    var
        TransType: Record "TAC Pool Trans Type";
        Pool: Record "TAC Pool";
    begin
        // Step 6: per Trans Type with Prorata <> None, prorate the pool-level
        // charge across growers by adjusted-kg share, writing a Pool Grower
        // Charge per grower plus a contra entry so the pool net is not
        // double-counted. Pool-Group scope sums kgs across the whole group.
        TransType.SetRange(Active, true);
        TransType.SetFilter("Prorata to Grower Level", '<>%1', TransType."Prorata to Grower Level"::"None");
        if TransType.FindSet()then repeat if TransType."Prorata to Grower Level" = TransType."Prorata to Grower Level"::PoolGroup then ProrateGroupScope(PoolGroup, TransType."Code", PoolPaymentID)
                else
                begin
                    Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
                    if Pool.FindSet()then repeat ProratePoolScope(PoolGroup, Pool, TransType."Code", PoolPaymentID);
                        until Pool.Next() = 0;
                end;
            until TransType.Next() = 0;
    end;
    local procedure ProratePoolScope(var PoolGroup: Record "TAC Pool Group Header"; var Pool: Record "TAC Pool"; TransTypeCode: Code[10]; PoolPaymentID: Integer)
    var
        Growers: List of[Code[20]];
        GrowerCode: Code[20];
        Total: Decimal;
        DenomKgs: Decimal;
        RunningShare: Decimal;
        Share: Decimal;
        Idx: Integer;
    begin
        Total:=GetPoolLevelChargeTotal(Pool."Pool Code", TransTypeCode);
        if Total = 0 then exit;
        DenomKgs:=GetPoolAdjKgs(Pool."Pool Code");
        if DenomKgs = 0 then exit;
        // Contra (opposite sign) nets the pool-level charge back out.
        WriteContraEntry(PoolGroup, Pool."Pool Code", TransTypeCode, -Total);
        Growers:=DistinctGrowersInPool(Pool."Pool Code");
        for Idx:=1 to Growers.Count()do begin
            GrowerCode:=Growers.Get(Idx);
            if Idx < Growers.Count()then Share:=Round(Total * GetGrowerAdjKgs(Pool."Pool Code", GrowerCode) / DenomKgs)
            else
                Share:=Total - RunningShare; // last-grower rounding correction
            RunningShare+=Share;
            WriteGrowerCharge(PoolGroup, Pool."Pool Code", GrowerCode, TransTypeCode, -Share, PoolPaymentID);
        end;
    end;
    local procedure ProrateGroupScope(var PoolGroup: Record "TAC Pool Group Header"; TransTypeCode: Code[10]; PoolPaymentID: Integer)
    var
        Growers: List of[Code[20]];
        GrowerCode: Code[20];
        Total: Decimal;
        DenomKgs: Decimal;
        RunningShare: Decimal;
        Share: Decimal;
        Idx: Integer;
    begin
        Total:=GetGroupLevelChargeTotal(PoolGroup."Pool Group ID", TransTypeCode);
        if Total = 0 then exit;
        DenomKgs:=GetGroupAdjKgs(PoolGroup."Pool Group ID");
        if DenomKgs = 0 then exit;
        WriteContraEntry(PoolGroup, '', TransTypeCode, -Total);
        Growers:=DistinctGrowersInGroup(PoolGroup."Pool Group ID");
        for Idx:=1 to Growers.Count()do begin
            GrowerCode:=Growers.Get(Idx);
            if Idx < Growers.Count()then Share:=Round(Total * GetGrowerGroupAdjKgs(PoolGroup."Pool Group ID", GrowerCode) / DenomKgs)
            else
                Share:=Total - RunningShare;
            RunningShare+=Share;
            WriteGrowerCharge(PoolGroup, '', GrowerCode, TransTypeCode, -Share, PoolPaymentID);
        end;
    end;
    local procedure WriteGrowerPayments(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type"; PoolPaymentID: Integer)
    var
        Pool: Record "TAC Pool";
        Growers: List of[Code[20]];
        GrowerCode: Code[20];
        PoolValue: Decimal;
        TargetPct: Decimal;
        Distributable: Decimal;
        PoolAdjKgs: Decimal;
        RunningTotal: Decimal;
        Payment: Decimal;
        Idx: Integer;
        TransTypeCode: Code[10];
    begin
        if PaymentType = PaymentType::Final then TransTypeCode:=PPCodeTok
        else
            TransTypeCode:=PPVCodeTok;
        TargetPct:=TargetPaymentPct(PoolGroup, PaymentType);
        Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        if Pool.FindSet()then repeat // The pool's value BEFORE any payment, so the percentage is a
                // share of the pool rather than a share of what is left of it.
                PoolValue:=GetPoolValueExclPayments(Pool."Pool Code");
                // Cumulative target less what earlier closes already paid. Under
                // the reverse-and-rewrite model the reversal drives the paid
                // figure to zero and the same expression pays the target in full.
                Distributable:=Round(PoolValue * TargetPct / 100) - GetPaymentsInPool(Pool."Pool Code");
                PoolAdjKgs:=GetPoolAdjKgs(Pool."Pool Code");
                if(PoolAdjKgs <> 0) and (Distributable <> 0)then begin
                    Growers:=DistinctGrowersInPool(Pool."Pool Code");
                    RunningTotal:=0;
                    for Idx:=1 to Growers.Count()do begin
                        GrowerCode:=Growers.Get(Idx);
                        // Payment = Distributable x (grower adj kgs / pool adj kgs) x -1.
                        if Idx < Growers.Count()then Payment:=Round(Distributable * GetGrowerAdjKgs(Pool."Pool Code", GrowerCode) / PoolAdjKgs * -1)
                        else
                            Payment:=(-Distributable) - RunningTotal; // rounding correction
                        RunningTotal+=Payment;
                        WritePaymentEntry(PoolGroup, Pool."Pool Code", GrowerCode, TransTypeCode, Payment, PoolPaymentID);
                    end;
                end;
            until Pool.Next() = 0;
    end;
    /// <summary>
    /// The cumulative share of the pool payable by the end of this close. A
    /// final close always targets 100% — it pays whatever the provisionals left.
    /// </summary>
    local procedure TargetPaymentPct(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type"): Decimal var
        PoolSetup: Record "TAC Pool Setup";
    begin
        if PaymentType = PaymentType::Final then exit(100);
        if not PoolSetup.Get()then PoolSetup.Init();
        exit(PoolSetup.CumulativeProvisionalPct(PoolGroup."Grower Pool Type", PoolGroup."Provisional Close Count"));
    end;
    local procedure WriteGrowerValueCharges(var PoolGroup: Record "TAC Pool Group Header"; PoolPaymentID: Integer)
    var
        TransType: Record "TAC Pool Trans Type";
        Pool: Record "TAC Pool";
        Growers: List of[Code[20]];
        GrowerCode: Code[20];
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        Idx: Integer;
    begin
        // Step 10: grower-level value charges = Rate x grower PP/PPV. Modelled as
        // a per-grower Pool Grower Charge. (Lightweight pass; rate is read from
        // the matching template via the engine when the per-grower context model
        // is finalised — placeholder amount is zero until then.)
        TransType.SetRange(Active, true);
        TransType.SetRange("Charge Level", TransType."Charge Level"::Grower);
        TransType.SetRange("Charge Action", TransType."Charge Action"::GroupClose);
        if TransType.IsEmpty()then exit;
        Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        if Pool.FindSet()then repeat Growers:=DistinctGrowersInPool(Pool."Pool Code");
                for Idx:=1 to Growers.Count()do begin
                    GrowerCode:=Growers.Get(Idx);
                    TransType.FindSet();
                    repeat // Rate x grower payment magnitude. ResolveRate keeps the
                        // rate-source logic in the engine (ADR-003).
                        WriteGrowerCharge(PoolGroup, Pool."Pool Code", GrowerCode, TransType."Code", GrowerValueCharge(ChargeEngine, TransType, Pool."Pool Code", GrowerCode), PoolPaymentID);
                    until TransType.Next() = 0;
                end;
            until Pool.Next() = 0;
    end;
    local procedure GrowerValueCharge(var ChargeEngine: Codeunit "TAC Pool Charge Engine"; var TransType: Record "TAC Pool Trans Type"; PoolCode: Code[20]; GrowerCode: Code[20]): Decimal var
        Template: Record "TAC Pool Charge Template";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        Payment: Decimal;
    begin
        Template.SetRange("Trans Type Code", TransType."Code");
        Template.SetRange("Charge Action", TransType."Charge Action"::GroupClose);
        Template.SetRange(Active, true);
        if not Template.FindFirst()then exit(0);
        ChargeContext."Customer No.":='';
        Payment:=GetGrowerPaymentInPool(PoolCode, GrowerCode);
        exit(ChargeEngine.ResolveRate(Template, ChargeContext) * Payment);
    end;
    local procedure AdvanceStatus(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type")
    begin
        if PaymentType = PaymentType::Final then begin
            PoolGroup.Status:=PoolGroup.Status::Closed;
            PoolGroup."Final Closed DateTime":=CurrentDateTime();
        end
        else
        begin
            PoolGroup.Status:=PoolGroup.Status::"Provisionally Closed";
            PoolGroup."Provisional Close Count"+=1;
            PoolGroup."Last Prov. Closed DateTime":=CurrentDateTime();
        end;
        PoolGroup."Closed By User":=CopyStr(UserId(), 1, MaxStrLen(PoolGroup."Closed By User"));
        PoolGroup.Modify(true);
    end;
    local procedure CreatePaymentHeader(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type"; var BatchName: Code[10]): Integer var
        PoolPaymentHeader: Record "TAC Pool Payment Header";
    begin
        PoolPaymentHeader.Init();
        PoolPaymentHeader."Pool Group ID":=PoolGroup."Pool Group ID";
        PoolPaymentHeader."Payment Type":=PaymentType;
        PoolPaymentHeader."Payment No.":=NextPaymentNo(PoolGroup."Pool Group ID");
        PoolPaymentHeader."Closed DateTime":=CurrentDateTime();
        PoolPaymentHeader."Closed By User":=CopyStr(UserId(), 1, MaxStrLen(PoolPaymentHeader."Closed By User"));
        PoolPaymentHeader.Insert(true);
        BatchName:=CopyStr('PCLS' + Format(PoolPaymentHeader."Pool Payment ID"), 1, MaxStrLen(BatchName));
        PoolPaymentHeader."GL Journal Batch Name":=BatchName;
        PoolPaymentHeader.Modify();
        exit(PoolPaymentHeader."Pool Payment ID");
    end;
    local procedure MarkPaymentCompleted(PoolPaymentID: Integer)
    var
        PoolPaymentHeader: Record "TAC Pool Payment Header";
    begin
        if not PoolPaymentHeader.Get(PoolPaymentID)then exit;
        PoolPaymentHeader."Completed DateTime":=CurrentDateTime();
        PoolPaymentHeader."Completed By User":=CopyStr(UserId(), 1, MaxStrLen(PoolPaymentHeader."Completed By User"));
        PoolPaymentHeader.Modify(true);
    end;
    local procedure NextPaymentNo(PoolGroupID: Integer): Integer var
        PoolPaymentHeader: Record "TAC Pool Payment Header";
    begin
        PoolPaymentHeader.SetRange("Pool Group ID", PoolGroupID);
        exit(PoolPaymentHeader.Count() + 1);
    end;
    // --- ledger write helpers (sign convention enforced here) ---
    local procedure WriteContraEntry(var PoolGroup: Record "TAC Pool Group Header"; PoolCode: Code[20]; TransTypeCode: Code[10]; Amount: Decimal)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code":=PoolCode;
        PoolLedgerEntry."Pool Group ID":=PoolGroup."Pool Group ID";
        PoolLedgerEntry."Entry Type":=PoolLedgerEntry."Entry Type"::Charge;
        PoolLedgerEntry."Trans Type Code":=TransTypeCode;
        PoolLedgerEntry.Amount:=Amount;
        PoolLedgerEntry."Posting Date":=Today();
        PoolLedgerEntry."Source Document No.":=PoolGroup."Pool Group Code";
        PoolLedgerEntry.Comment:='Above-the-line proration contra';
        PoolLedgerEntry.Insert(true);
    end;
    local procedure WriteGrowerCharge(var PoolGroup: Record "TAC Pool Group Header"; PoolCode: Code[20]; GrowerCode: Code[20]; TransTypeCode: Code[10]; Amount: Decimal; PoolPaymentID: Integer)
    var
        PoolGrowerCharge: Record "TAC Pool Grower Charge";
    begin
        if Amount = 0 then exit;
        PoolGrowerCharge.Init();
        PoolGrowerCharge."Pool Payment ID":=PoolPaymentID;
        PoolGrowerCharge."Pool Group ID":=PoolGroup."Pool Group ID";
        PoolGrowerCharge."Pool Code":=PoolCode;
        PoolGrowerCharge."Grower Code":=GrowerCode;
        PoolGrowerCharge."Trans Type Code":=TransTypeCode;
        PoolGrowerCharge.Amount:=Amount; // positive = cost to grower
        PoolGrowerCharge.Insert(true);
    end;
    local procedure WritePaymentEntry(var PoolGroup: Record "TAC Pool Group Header"; PoolCode: Code[20]; GrowerCode: Code[20]; TransTypeCode: Code[10]; Amount: Decimal; PoolPaymentID: Integer)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code":=PoolCode;
        PoolLedgerEntry."Pool Group ID":=PoolGroup."Pool Group ID";
        PoolLedgerEntry."Entry Type":=PoolLedgerEntry."Entry Type"::Payment;
        PoolLedgerEntry."Trans Type Code":=TransTypeCode;
        PoolLedgerEntry."Grower Code":=GrowerCode;
        PoolLedgerEntry.Amount:=Amount; // negative: paid out of the pool
        PoolLedgerEntry."Posting Date":=Today();
        PoolLedgerEntry."Pool Payment ID":=PoolPaymentID;
        PoolLedgerEntry."Source Document No.":=PoolGroup."Pool Group Code";
        PoolLedgerEntry.Insert(true);
    end;
    // --- aggregation helpers ---
    local procedure GetPoolNet(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
    end;
    /// <summary>
    /// The pool's value ignoring grower payments — the base a provisional
    /// percentage is a share of. GetPoolNet is the remaining balance and is
    /// deliberately not used here: a percentage of the balance would shrink with
    /// every close instead of being a fixed share of the pool.
    /// </summary>
    local procedure GetPoolValueExclPayments(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetFilter("Trans Type Code", '<>%1&<>%2', PPCodeTok, PPVCodeTok);
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
    end;
    /// <summary>
    /// What earlier closes have already paid out of this pool, as a positive
    /// figure. PP/PPV entries are negative (money leaving the pool).
    /// </summary>
    local procedure GetPaymentsInPool(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetFilter("Trans Type Code", '%1|%2', PPCodeTok, PPVCodeTok);
        PoolLedgerEntry.CalcSums(Amount);
        exit(-PoolLedgerEntry.Amount);
    end;
    local procedure GetPoolAdjKgs(PoolCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.CalcSums("Quantity (kg)");
        exit(PoolLedgerEntry."Quantity (Kg)");
    end;
    local procedure GetGrowerAdjKgs(PoolCode: Code[20]; GrowerCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Grower Code", GrowerCode);
        PoolLedgerEntry.CalcSums("Quantity (Kg)");
        exit(PoolLedgerEntry."Quantity (Kg)");
    end;
    local procedure GetGroupAdjKgs(PoolGroupID: Integer): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroupID);
        PoolLedgerEntry.CalcSums("Quantity (Kg)");
        exit(PoolLedgerEntry."Quantity (Kg)");
    end;
    local procedure GetGrowerGroupAdjKgs(PoolGroupID: Integer; GrowerCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroupID);
        PoolLedgerEntry.SetRange("Grower Code", GrowerCode);
        PoolLedgerEntry.CalcSums("Quantity (Kg)");
        exit(PoolLedgerEntry."Quantity (Kg)");
    end;
    local procedure GetPoolLevelChargeTotal(PoolCode: Code[20]; TransTypeCode: Code[10]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Trans Type Code", TransTypeCode);
        PoolLedgerEntry.SetRange("Grower Code", '');
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
    end;
    local procedure GetGroupLevelChargeTotal(PoolGroupID: Integer; TransTypeCode: Code[10]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroupID);
        PoolLedgerEntry.SetRange("Trans Type Code", TransTypeCode);
        PoolLedgerEntry.SetRange("Grower Code", '');
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
    end;
    local procedure GetGrowerPaymentInPool(PoolCode: Code[20]; GrowerCode: Code[20]): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Grower Code", GrowerCode);
        PoolLedgerEntry.SetFilter("Trans Type Code", '%1|%2', PPCodeTok, PPVCodeTok);
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
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
    local procedure DistinctGrowersInGroup(PoolGroupID: Integer): List of[Code[20]]var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        Growers: List of[Code[20]];
    begin
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroupID);
        PoolLedgerEntry.SetFilter("Grower Code", '<>%1', '');
        if PoolLedgerEntry.FindSet()then repeat if not Growers.Contains(PoolLedgerEntry."Grower Code")then Growers.Add(PoolLedgerEntry."Grower Code");
            until PoolLedgerEntry.Next() = 0;
        exit(Growers);
    end;
}
