codeunit 50272 "TAC Pool Consignment Post"
{
    // Posting runs inside Sales-Post. It writes only pool-owned state and
    // ledger records, so invoice posters do not require Modify permission on
    // standard posted Sales Invoice Header (TableData 112).
    Permissions =
        tabledata "TAC Pool Setup" = R,
        tabledata "TAC Pool Group Header" = RIM,
        tabledata "TAC Pool" = RIM,
        tabledata "TAC Pool Ledger Entry" = RIM,
        tabledata "TAC Pool Invoice Post State" = RIMD,
        tabledata "TAC Pool Credit Memo State" = RIMD,
        tabledata "Sales Invoice Line" = RM;
    // AL-08: on full settlement of a consignment Sales Invoice, write a PR
    // Pool Ledger Entry per consignment line and run the ConsignmentPost
    // charges (design §6.2). Idempotent on the Posted to Pools Flag; PR amounts
    // are never aggregated across pools. Invoked from 50277.

    var
        PRCodeTok: Label 'PR', Locked = true;
        FRCodeTok: Label 'FR', Locked = true;
        GLJnlTemplateTok: Label 'POOLCP', Locked = true;
        GLJnlBatchTok: Label 'CONSIGN', Locked = true;

    procedure ReleaseConsignment(var Consignment: Record "TAC Consignment Header")
    begin
        Consignment.TestField("Status", Consignment."Status"::Open);
        //Run `V-01` (market rules) and `V-07` (kilogram conversion). Block on failure.
        ValidateConsignmentLines(Consignment);
        //Allocate freight (`C-03`); assert `Σ allocated = Total Freight Cost`.
        Consignment.AllocateFreightCost();
        Consignment."Status" := Consignment."Status"::Released;
        Consignment.Modify();
    end;

    procedure DespatchConsignment(var Consignment: Record "TAC Consignment Header")
    begin
        Consignment.TestField("Status", Consignment."Status"::Released);
        Consignment."Status" := Consignment."Status"::Despatched;
        Consignment.CalcFields("Total Freight Cost", "Total Kilograms");
        PostConsignmentLines(Consignment, true, false);
        Consignment.Modify();
    end;

    procedure PostConsignment(var Consignment: Record "TAC Consignment Header")
    begin
        Consignment.TestField("Status", Consignment."Status"::Despatched);
        Consignment.CalcFields("Total Freight Cost", "Total Kilograms");
        PostConsignmentLines(Consignment, false, true);
        Consignment."Posted to Pool" := true;
        Consignment."Status" := Consignment."Status"::Posted;
        Consignment.Modify();
    end;

    /*```
    FOR each detail line:
        Grower := Line."Grower No."
        FOR each leg destination in the consignment's leg chain:
            FOR each TAC Freight Location Market Rule WHERE Mandatory:
                GrowerRule := find TAC Grower Market Rule (Grower, RuleCode)
                IF NOT found THEN
                    ERROR('Grower %1 does not hold market rule %2 required for %3.',
                          Grower, RuleCode, DestinationCode)
                IF GrowerRule."Expiry Date" < Consignment."Despatch Date" THEN
                    ERROR('Market rule %1 for grower %2 expired %3, before despatch date %4.',
                          RuleCode, Grower, GrowerRule."Expiry Date", Consignment."Despatch Date")
    ```
    Three points the implementation must get right:
    This is a blocking error, not a warning. No skip, no confirm dialog.
    Expiry is tested against the despatch date, not the system date. A rule expiring between entry and despatch must fail.
    Export accreditations are in scope for cutover (`D-11`). Where the destination freight location has `Is Export = true`, export accreditation rules apply in addition to domestic rules.
    */
    local procedure ValidateConsignmentLines(Consignment: Record "TAC Consignment Header")
    var
        ConsignmentLine: Record "TAC Consignment Line";
        ConsignmentFreightLeg: Record "TAC Consignment Freight Leg";
        FreightLocationMarketRule: Record "TAC Freight Loc. Market Rule";
        GrowerMarketRule: Record "TAC Grower Market Rule";
    begin
        ConsignmentFreightLeg.Reset();
        ConsignmentFreightLeg.SetRange("Consignment No.", Consignment."Consignment No.");
        if ConsignmentFreightLeg.FindSet() then
            repeat
                FreightLocationMarketRule.SetRange("Freight Location Code", ConsignmentFreightLeg."To Freight Location");
                FreightLocationMarketRule.SetRange(Mandatory, true);
                if FreightLocationMarketRule.FindSet() then
                    repeat
                        GrowerMarketRule.Get(ConsignmentLine."Grower No.", FreightLocationMarketRule."Market Rule Code");
                        if GrowerMarketRule."Expiry Date" < Consignment."Despatch Date" then
                            Error(
                                'Market rule %1 for grower %2 expired %3, before despatch date %4.',
                                FreightLocationMarketRule."Market Rule Code",
                                ConsignmentLine."Grower No.",
                                GrowerMarketRule."Expiry Date",
                                Consignment."Despatch Date");
                    until FreightLocationMarketRule.Next() = 0;
            until ConsignmentFreightLeg.Next() = 0;
        ConsignmentLine.SetRange("Consignment No.", Consignment."Consignment No.");
        if ConsignmentLine.FindSet() then
            repeat
                ConsignmentLine.TestField("Quantity (Kg)");
            until ConsignmentLine.Next() = 0;
    end;

    local procedure PostConsignmentLines(
        var Consignment: Record "TAC Consignment Header";
        Despatch: Boolean;
        Post: Boolean)
    var
        ConsignmentLine: Record "TAC Consignment Line";
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        PoolWeek: Record "TAC Pool Week";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        GrowerCode: Code[20];
        PackTypeCode: Code[20];
        PackTypeCategoryCode: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        PoolGroupID: Integer;
        PoolCode: Code[20];
        AppliedFuelSurchargePct: Decimal;
        AppliedPalletSpaceRate: Decimal;
    begin
        CalcFreightStamping(Consignment, AppliedFuelSurchargePct, AppliedPalletSpaceRate);

        ConsignmentLine.SetRange("Consignment No.", Consignment."Consignment No.");
        if ConsignmentLine.FindSet() then
            repeat
                DimensionMgt.ResolveFromDimensionSet(ConsignmentLine."Dimension Set ID", //SeasonCode, PoolWeekCode, 
                    VarietyCode, GradeCode, SizeCode, //GrowerCode, 
                    GrowerPoolType);
                //if GrowerCode = '' then
                GrowerCode := ConsignmentLine."Grower No.";

                PoolWeek.Reset();
                PoolWeek.SetRange("Week No.", ConsignmentLine."Pool Week");
                PoolWeek.SetRange("Season Code", ConsignmentLine."Season Code");
                PoolWeek.FindLast();

                PoolGroupID := PoolGroup.FindOrCreate(PoolWeek.Code, GrowerPoolType);
                PoolCode := Pool.FindOrCreate(PoolGroupID, CopyStr(VarietyCode, 1, 10), CopyStr(GradeCode, 1, 10), CopyStr(SizeCode, 1, 10), GrowerCode);

                if (Despatch) and (not ConsignmentLine."Freight Posted") then
                    WriteConsignmentFreight(
                        Consignment,
                        ConsignmentLine,
                        PoolCode,
                        PoolGroupID,
                        GrowerCode,
                        AppliedFuelSurchargePct,
                        AppliedPalletSpaceRate);
                if Post then
                    BuildConsignmentContext(
                        ChargeContext,
                        Consignment,
                        ConsignmentLine,
                        PoolCode,
                        PoolGroupID,
                        GrowerCode,
                        GrowerPoolType,
                        VarietyCode,
                        GradeCode,
                        SizeCode);
                ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::ConsignmentPost, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);

            until ConsignmentLine.Next() = 0;
    end;

    local procedure CalcFreightStamping(var Consignment: Record "TAC Consignment Header"; var AppliedFuelSurchargePct: Decimal; var AppliedPalletSpaceRate: Decimal)
    var
        ConsignmentFreightLeg: Record "TAC Consignment Freight Leg";
        TotalPalletSpaces: Decimal;
        WeightedPalletRateTotal: Decimal;
        BaseFreightTotal: Decimal;
    begin
        AppliedFuelSurchargePct := 0;
        AppliedPalletSpaceRate := 0;

        ConsignmentFreightLeg.SetRange("Consignment No.", Consignment."Consignment No.");
        if not ConsignmentFreightLeg.FindSet() then
            exit;

        repeat
            ConsignmentFreightLeg.CalcFields("Pallet Space Rate");
            TotalPalletSpaces += ConsignmentFreightLeg."Pallet Spaces";
            WeightedPalletRateTotal += ConsignmentFreightLeg."Pallet Space Rate" * ConsignmentFreightLeg."Pallet Spaces";
            BaseFreightTotal += ConsignmentFreightLeg."Pallet Space Rate" * ConsignmentFreightLeg."Pallet Spaces";
        until ConsignmentFreightLeg.Next() = 0;

        if TotalPalletSpaces <> 0 then
            AppliedPalletSpaceRate := WeightedPalletRateTotal / TotalPalletSpaces;

        if BaseFreightTotal <> 0 then
            AppliedFuelSurchargePct := ((Consignment."Total Freight Cost" - BaseFreightTotal) / BaseFreightTotal) * 100;
    end;

    local procedure WriteConsignmentFreight(var Consignment: Record "TAC Consignment Header"; var ConsignmentLine: Record "TAC Consignment Line"; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; AppliedFuelSurchargePct: Decimal; AppliedPalletSpaceRate: Decimal)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := PoolCode;
        PoolLedgerEntry."Pool Group ID" := PoolGroupID;
        PoolLedgerEntry."Entry Type" := PoolLedgerEntry."Entry Type"::Freight;
        PoolLedgerEntry."Trans Type Code" := FRCodeTok;
        PoolLedgerEntry."Document Type" := PoolLedgerEntry."Document Type"::Consignment;
        PoolLedgerEntry."Document No." := Consignment."Consignment No.";
        PoolLedgerEntry."Source Consignment No." := Consignment."Consignment No.";
        PoolLedgerEntry."Grower No." := ConsignmentLine."Grower No.";
        PoolLedgerEntry."Grower Code" := GrowerCode;
        PoolLedgerEntry."Item No." := ConsignmentLine."Item No.";
        PoolLedgerEntry.Quantity := ConsignmentLine.Quantity;
        PoolLedgerEntry."Quantity (Kg)" := ConsignmentLine."Quantity (Kg)";
        PoolLedgerEntry.Amount := -ConsignmentLine."Allocated Freight Cost";
        PoolLedgerEntry."Applied Fuel Surcharge %" := AppliedFuelSurchargePct;
        PoolLedgerEntry."Applied Pallet Space Rate" := AppliedPalletSpaceRate;
        PoolLedgerEntry."Dimension Set ID" := ConsignmentLine."Dimension Set ID";
        PoolLedgerEntry."Transaction Date" := Consignment."Despatch Date";
        PoolLedgerEntry."Posting Date" := Today();
        PoolLedgerEntry."Source Document No." := Consignment."Consignment No.";
        PoolLedgerEntry."Source Line No." := ConsignmentLine."Line No.";
        PoolLedgerEntry."Source Type" := PoolLedgerEntry."Source Type"::Consignment;
        PoolLedgerEntry."Source System ID" := ConsignmentLine.SystemId;
        PoolLedgerEntry.Insert(true);

        PostPoolLedger2GL(PoolLedgerEntry);

        ConsignmentLine."Freight Posted" := true;
        ConsignmentLine.Modify();
    end;

    local procedure PostPoolLedger2GL(var PoolLedgerEntry: Record "TAC Pool Ledger Entry")
    var
        PoolTransType: Record "TAC Pool Trans Type";
        PoolGroup: Record "TAC Pool Group Header";
        PoolSetup: Record "TAC Pool Setup";
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        LineNo: Integer;
        GLAccountNo: Code[20];
        AmountToPost: Decimal;
    begin
        if PoolLedgerEntry.Amount = 0 then
            exit;

        PoolLedgerEntry.TestField("Trans Type Code");
        PoolTransType.Get(PoolLedgerEntry."Trans Type Code");
        PoolSetup.Get();
        PoolSetup.TestField("Pool Charge Clearing Account");

        if PoolLedgerEntry."Pool Group ID" <> 0 then
            if PoolGroup.Get(PoolLedgerEntry."Pool Group ID") then
                if PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::External then
                    GLAccountNo := PoolTransType."GL Account External"
                else
                    GLAccountNo := PoolTransType."GL Account Internal";

        if GLAccountNo = '' then
            GLAccountNo := PoolTransType."GL Account Internal";
        if GLAccountNo = '' then
            GLAccountNo := PoolTransType."GL Account External";
        if GLAccountNo = '' then
            Error('No G/L account is configured for trans type %1.', PoolTransType.Code);

        EnsureGLJournalBatch();

        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", GLJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", GLJnlBatchTok);
        if GenJournalLine.FindLast() then
            LineNo := GenJournalLine."Line No." + 10000
        else
            LineNo := 10000;

        AmountToPost := Abs(PoolLedgerEntry.Amount);

        GenJournalLine.Init();
        GenJournalLine."Journal Template Name" := GLJnlTemplateTok;
        GenJournalLine."Journal Batch Name" := GLJnlBatchTok;
        GenJournalLine."Line No." := LineNo;
        if PoolLedgerEntry."Posting Date" <> 0D then
            GenJournalLine."Posting Date" := PoolLedgerEntry."Posting Date"
        else
            GenJournalLine."Posting Date" := Today();
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::"G/L Account");
        GenJournalLine.Validate("Account No.", GLAccountNo);
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", PoolSetup."Pool Charge Clearing Account");
        GenJournalLine.Validate(Amount, AmountToPost);
        GenJournalLine.Validate("Document No.", PoolLedgerEntry."Document No.");
        GenJournalLine.Description := CopyStr(StrSubstNo('Pool freight %1', PoolLedgerEntry."Source Consignment No."), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine."Dimension Set ID" := PoolLedgerEntry."Dimension Set ID";
        GenJournalLine.Insert(true);

        GenJnlPostLine.RunWithCheck(GenJournalLine);

        // This entry has been posted directly to G/L. Mark it here so Pool
        // Group Close does not select and post the same financial entry again.
        PoolLedgerEntry."Posted to G/L" := true;
        PoolLedgerEntry."G/L Posted At" := CurrentDateTime();
        PoolLedgerEntry.Modify(true);
    end;

    local procedure EnsureGLJournalBatch()
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
    begin
        if not GenJournalTemplate.Get(GLJnlTemplateTok) then begin
            GenJournalTemplate.Init();
            GenJournalTemplate.Name := GLJnlTemplateTok;
            GenJournalTemplate.Validate(Type, GenJournalTemplate.Type::General);
            GenJournalTemplate.Insert(true);
        end;

        if not GenJournalBatch.Get(GLJnlTemplateTok, GLJnlBatchTok) then begin
            GenJournalBatch.Init();
            GenJournalBatch."Journal Template Name" := GLJnlTemplateTok;
            GenJournalBatch.Name := GLJnlBatchTok;
            GenJournalBatch.Insert(true);
        end;
    end;

    local procedure BuildConsignmentContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var Consignment: Record "TAC Consignment Header"; var ConsignmentLine: Record "TAC Consignment Line"; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; VarietyCode: Code[20]; GradeCode: Code[20]; SizeCode: Code[20])
    var
        SalesHeader: Record "Sales Header";
    begin
        ChargeContext.Init();
        ChargeContext."Pool Code" := PoolCode;
        ChargeContext."Pool Group ID" := PoolGroupID;
        ChargeContext."Grower Code" := GrowerCode;
        ChargeContext."Supplier Type" := GrowerPoolType;
        ChargeContext."Grower Type" := MapGrowerType(GrowerPoolType);
        ChargeContext."Variety Code" := CopyStr(VarietyCode, 1, 10);
        ChargeContext."Grade Code" := CopyStr(GradeCode, 1, 10);
        ChargeContext."Size Code" := CopyStr(SizeCode, 1, 10);
        ChargeContext."Pack Type Code" := ConsignmentLine."Pack Type Code";
        ChargeContext.Kgs := ConsignmentLine."Quantity (Kg)";
        ChargeContext.Units := ConsignmentLine.Quantity;
        ChargeContext.Value := ConsignmentLine."Allocated Freight Cost";
        ChargeContext."Customer No." := Consignment."Sell-to Customer No.";
        ChargeContext."Transaction Date" := Consignment."Despatch Date";
        ChargeContext."Posting Date" := Today();
        ChargeContext."Source Document No." := Consignment."Consignment No.";
        ChargeContext."Source Line No." := ConsignmentLine."Line No.";
        ChargeContext."Source Type" := ChargeContext."Source Type"::Consignment;
        ChargeContext."Source System ID" := ConsignmentLine.SystemId;
        if Consignment."Sales Order No." <> '' then
            if SalesHeader.Get(SalesHeader."Document Type"::Order, Consignment."Sales Order No.") then begin
                ChargeContext."DC Code" := SalesHeader."Ship-to Code";
            end;
    end;

    local procedure MapGrowerType(GrowerPoolType: Enum "TAC Grower Pool Type"): Enum "TAC Grower Type"
    begin
        case GrowerPoolType of
            GrowerPoolType::External:
                exit(Enum::"TAC Grower Type"::External);
            GrowerPoolType::"Contract Pack":
                exit(Enum::"TAC Grower Type"::"Contract Pack");
            else
                exit(Enum::"TAC Grower Type"::Internal);
        end;
    end;

    local procedure ResolveGrowerMarketRule(GrowerNo: Code[20]): Code[20]
    var
        GrowerMarketRule: Record "TAC Grower Market Rule";
    begin
        GrowerMarketRule.SetRange("Grower No.", GrowerNo);
        GrowerMarketRule.SetFilter("Expiry Date", '<=%1|%2', WorkDate(), 0D);
        GrowerMarketRule.SetCurrentKey("Expiry Date");
        if GrowerMarketRule.FindLast then
            exit(GrowerMarketRule."Market Rule Code")
        else
            Error(
                'Grower %1 does not hold market rule %2 or it has expired.', GrowerNo);
    end;

    procedure ProcessPostedShipment(ShipmentNo: Code[20]; SourceType: Integer)
    var
        ShipmentHeader: Record "Sales Shipment Header";
        ShipmentLine: Record "Sales Shipment Line";
        SalesLine: Record "Sales Line";
        TransShpt: Record "Transfer Shipment Header";
        TransShptLine: Record "Transfer Shipment Line";
        TransLine: Record "Transfer Line";
        ItemLedgerEntry,
        OutputEntry,
        OutputEntry2 : Record "Item Ledger Entry";
        Consignment: Record "TAC Consignment Header";
        ConsignmentLine: Record "TAC Consignment Line";
        PoolWeek: Record "TAC Pool Week";
        Pool: Record "TAC Pool";
        PoolGroup: Record "TAC Pool Group Header";
        BatchPallet: Record "TAC Batch Pallet" temporary;
        DimMgt: Codeunit "TAC Pool Dimension Mgt";
        DummyCode: Code[100];
        ShptLineNo: Integer;
        ShptUOM: Code[20];
        ShptItem: Code[20];
        ConsignmentNo: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        DimSetID: Integer;
        GrowerPoolType: Enum "TAC Grower Pool Type";
        ILEDocType: Enum "Item Ledger Document Type";
    begin
        BatchPallet.DeleteAll();
        ItemLedgerEntry.SetRange("Document No.", ShipmentNo);
        case SourceType of
            database::"Sales Shipment Line":
                begin
                    if not ShipmentHeader.Get(ShipmentNo) then
                        exit;
                    if not Consignment.Get(ShipmentHeader."DIY_Consignment No.") then
                        exit;
                    ConsignmentNo := ShipmentHeader."DIY_Consignment No.";
                    ILEDocType := ILEDocType::"Sales Shipment";
                end;
            database::"Transfer Shipment Line":
                begin
                    if not TransShpt.Get(ShipmentNo) then
                        exit;
                    if not Consignment.Get(TransShpt."DIY_Consignment No.") then
                        exit;
                    ConsignmentNo := TransShpt."DIY_Consignment No.";
                    ILEDocType := ILEDocType::"Transfer Shipment";
                end;
        end;

        ItemLedgerEntry.SetRange("Document Type", ILEDocType);
        ItemLedgerEntry.SetFilter("Lot No.", '<>%1', '');
        if ItemLedgerEntry.FindSet() then
            repeat
                //ResolveBatchPoolWeekNo(ItemLedgerEntry."Lot No.", PoolWeek);
                //Use Pallet No. (Lot No.) to find the batches
                OutputEntry.Reset();
                OutputEntry.SetRange("Entry Type", OutputEntry."Entry Type"::Output);
                OutputEntry.SetRange("Lot No.", ItemLedgerEntry."Lot No.");
                OutputEntry.SetRange("Item No.", ItemLedgerEntry."Item No.");
                if OutputEntry.FindSet() then
                    repeat
                        if not BatchPallet.Get(OutputEntry."Order No.",
                                               OutputEntry."Lot No.",
                                               ItemLedgerEntry."Document No.",
                                               ItemLedgerEntry."Document Line No.") then begin
                            BatchPallet.Init();
                            BatchPallet."Batch No." := OutputEntry."Order No.";
                            BatchPallet."Pallet No." := OutputEntry."Lot No.";
                            OutputEntry.CalcFields("TAC Grower No.");
                            BatchPallet."Grower No." := OutputEntry."TAC Grower No.";
                            BatchPallet."Document No." := ItemLedgerEntry."Document No.";
                            BatchPallet."Line No." := ItemLedgerEntry."Document Line No.";
                            OutputEntry2.Reset();
                            OutputEntry2.SetRange("Order No.", OutputEntry."Order No.");
                            OutputEntry2.SetRange("Lot No.", OutputEntry."Lot No.");
                            OutputEntry2.SetRange("Item No.", ItemLedgerEntry."Item No.");
                            OutputEntry2.CalcSums(Quantity);
                            BatchPallet."Quantity" := OutputEntry2."Quantity";
                            BatchPallet.Insert();
                        end
                    until OutputEntry.Next() = 0;
            until ItemLedgerEntry.Next() = 0;
        if BatchPallet.FindSet() then
            repeat
                PoolWeek.Get(ResolveBatchPoolWeekNo(BatchPallet."Batch No."));
                case ILEDocType of
                    ILEDocType::"Sales Shipment":
                        begin
                            ShipmentLine.Get(BatchPallet."Document No.", BatchPallet."Line No.");
                            DimSetID := ShipmentLine."Dimension Set ID";
                            ShptLineNo := ShipmentLine."Line No.";
                            ShptItem := ShipmentLine."No.";
                            ShptUOM := ShipmentLine."Unit of Measure Code";
                        end;
                    ILEDocType::"Transfer Shipment":
                        begin
                            TransShptLine.Get(BatchPallet."Document No.", BatchPallet."Line No.");
                            DimSetID := TransShptLine."Dimension Set ID";
                            ShptLineNo := TransShptLine."Line No.";
                            ShptItem := TransShptLine."Item No.";
                            ShptUOM := TransShptLine."Unit of Measure Code";
                        end;
                end;
                ConsignmentLine.SetRange("Consignment No.", ConsignmentNo);
                ConsignmentLine.SetRange("Source No.", ShipmentNo);
                ConsignmentLine.SetRange("Pool Week", PoolWeek."Week No.");
                ConsignmentLine.SetRange("Season Code", PoolWeek."Season Code");
                //ConsignmentLine.SetRange("Item No.", ItemLedgerEntry."Item No.");
                ConsignmentLine.SetRange("Item No.", ShptItem);
                if not ConsignmentLine.FindFirst() then begin
                    ConsignmentLine.Init();
                    ConsignmentLine."Consignment No." := ConsignmentNo;
                    ConsignmentLine."Source Type" := Database::"Sales Shipment Line";
                    ConsignmentLine."Source No." := ShipmentNo;
                    //ConsignmentLine."Source Line No." := 0;
                    ConsignmentLine."Source Line No." := ItemLedgerEntry."Document Line No.";
                    ConsignmentLine."Pool Week" := PoolWeek."Week No.";
                    ConsignmentLine."Season Code" := PoolWeek."Season Code";
                    ConsignmentLine."Item No." := ShptItem;
                    ConsignmentLine."Unit of Measure Code" := ShptUOM;
                    ConsignmentLine."Grower No." := BatchPallet."Grower No.";
                    ConsignmentLine."Dimension Set ID" := DimSetID;
                    ConsignmentLine.Insert();
                    DimMgt.ResolveFromDimensionSet(ConsignmentLine."Dimension Set ID",
                    ConsignmentLine."Variety Code",
                    GradeCode, SizeCode, //DummyCode,
                    GrowerPoolType);
                    PoolGroup.Get(PoolGroup.FindOrCreate(PoolWeek.Code, GrowerPoolType));
                    Pool.Get(Pool.FindOrCreate(
                            PoolGroup."Pool Group ID",
                            ConsignmentLine."Variety Code",
                            GradeCode, SizeCode, BatchPallet."Grower No."));
                    ConsignmentLine."Pool Code" := Pool."Pool Code";
                    ConsignmentLine."Pack Type Code" := Format(Pool."Pool Type");
                    ConsignmentLine.Modify();
                    if ILEDocType = ILEDocType::"Sales Shipment" then
                        if SalesLine.Get(SalesLine."Document Type"::Order,
                            ShipmentLine."Order No.", ShipmentLine."Order Line No.") then begin
                            ConsignmentLine."Estimated Price" := SalesLine."Unit Price";
                            ConsignmentLine.Modify();
                        end;
                end;
                ConsignmentLine.Validate(Quantity, ConsignmentLine.Quantity + BatchPallet.Quantity);
                ConsignmentLine.Modify();
            until BatchPallet.Next() = 0;
        ReleaseConsignment(Consignment);
        DespatchConsignment(Consignment);
    end;

    local procedure ResolveBatchPoolWeekNo(BatchNo: Code[4]): Code[20]
    var
        PoolWeek: Record "TAC Pool Week";
        BatchLine: Record "TAC Batch Plan Grower";
        PoolDate: Date;
    begin
        BatchLine.SetRange("Batch No.", BatchNo);
        BatchLine.FindFirst();
        BatchLine.CalcFields("Run Time");
        PoolDate := DT2Date(BatchLine."Run Time");
        PoolWeek.SetFilter("Start Date", '<=%1', PoolDate);
        PoolWeek.SetFilter("End Date", '>=%1', PoolDate);
        PoolWeek.FindLast();
        exit(PoolWeek.Code);
    end;

    procedure ProcessPostedSalesInvoice(SalesInvHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        InvoicePostState: Record "TAC Pool Invoice Post State";
        DidProcessAny: Boolean;
    begin
        if SalesInvHdrNo = '' then
            exit;
        if not SalesInvoiceHeader.Get(SalesInvHdrNo) then
            exit;
        if InvoicePostState.Get(SalesInvoiceHeader.SystemId) then
            exit;
        SalesInvoiceLine.SetRange("Document No.", SalesInvHdrNo);
        SalesInvoiceLine.SetRange(Type, SalesInvoiceLine.Type::Item);
        SalesInvoiceLine.SetFilter("Consignment No.", '<>%1', '');
        SalesInvoiceLine.SetFilter(Quantity, '<>0');
        if SalesInvoiceLine.FindSet() then
            repeat
                ProcessPostedSalesInvoiceLine(SalesInvoiceHeader, SalesInvoiceLine);
                DidProcessAny := true;
            until SalesInvoiceLine.Next() = 0;

        if DidProcessAny then begin
            InvoicePostState.Init();
            InvoicePostState."Posted Invoice SystemId" := SalesInvoiceHeader.SystemId;
            InvoicePostState."Posted Invoice No." := SalesInvoiceHeader."No.";
            InvoicePostState."Posted DateTime" := CurrentDateTime();
            InvoicePostState."Posted By" := CopyStr(UserId(), 1, MaxStrLen(InvoicePostState."Posted By"));
            InvoicePostState.Insert(true);
        end;
    end;

    procedure PostConsignmentLine(var Consignment: Record "TAC Consignment Header"; var ConsignmentLine: Record "TAC Consignment Line")
    var
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        PoolWeek: Record "TAC Pool Week";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        GrowerCode: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        PoolGroupID: Integer;
        PoolCode: Code[20];
        AppliedFuelSurchargePct: Decimal;
        AppliedPalletSpaceRate: Decimal;
    begin
        DimensionMgt.ResolveFromDimensionSet(ConsignmentLine."Dimension Set ID", //SeasonCode, PoolWeekCode, 
            VarietyCode, GradeCode, SizeCode, //GrowerCode, 
            GrowerPoolType);
        //if GrowerCode = '' then
        GrowerCode := ConsignmentLine."Grower No.";

        PoolWeek.Reset();
        PoolWeek.SetRange("Week No.", ConsignmentLine."Pool Week");
        PoolWeek.SetRange("Season Code", ConsignmentLine."Season Code");
        PoolWeek.FindLast();

        PoolGroupID := PoolGroup.FindOrCreate(PoolWeek."Code", GrowerPoolType);

        PoolCode := Pool.FindOrCreate(PoolGroupID, CopyStr(VarietyCode, 1, 10), CopyStr(GradeCode, 1, 10), CopyStr(SizeCode, 1, 10), ConsignmentLine."Grower No.");
        CalcFreightStamping(Consignment, AppliedFuelSurchargePct, AppliedPalletSpaceRate);
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Source Document No.", Consignment."Consignment No.");
        PoolLedgerEntry.SetRange("Source Line No.", ConsignmentLine."Line No.");
        PoolLedgerEntry.SetRange("Trans Type Code", FRCodeTok);
        if PoolLedgerEntry.IsEmpty() then
            WriteConsignmentFreight(Consignment, ConsignmentLine, PoolCode, PoolGroupID, GrowerCode, AppliedFuelSurchargePct, AppliedPalletSpaceRate);
        BuildConsignmentContext(ChargeContext, Consignment, ConsignmentLine, PoolCode, PoolGroupID, GrowerCode, GrowerPoolType, VarietyCode, GradeCode, SizeCode);
        ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::ConsignmentPost, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);
    end;

    /// <summary>
    /// Reverses pooled revenue and invoice-post charges for a posted credit
    /// memo only when the end user enabled credits and the credit is applied to
    /// an invoice already recognised by pooling.
    /// </summary>
    procedure ProcessPostedSalesCreditMemo(SalesCrMemoHdrNo: Code[20]; AppliedInvoiceNo: Code[20])
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        PoolSetup: Record "TAC Pool Setup";
        CreditMemoState: Record "TAC Pool Credit Memo State";
        InvoicePostState: Record "TAC Pool Invoice Post State";
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        DidProcessAny: Boolean;
    begin
        if (SalesCrMemoHdrNo = '') or (AppliedInvoiceNo = '') then
            exit;
        if not PoolSetup.Get() or not PoolSetup."Allow Invoice Credits" then
            exit;
        if not SalesCrMemoHeader.Get(SalesCrMemoHdrNo) then
            exit;
        if CreditMemoState.Get(SalesCrMemoHeader.SystemId) then
            exit;

        InvoicePostState.SetRange("Posted Invoice No.", AppliedInvoiceNo);
        if InvoicePostState.IsEmpty() then
            exit;

        SalesCrMemoLine.SetRange("Document No.", SalesCrMemoHdrNo);
        SalesCrMemoLine.SetRange(Type, SalesCrMemoLine.Type::Item);
        if SalesCrMemoLine.FindSet() then
            repeat
                if DimensionMgt.HasPoolDimensions(SalesCrMemoLine."Dimension Set ID") then begin
                    DimensionMgt.ValidatePoolDimensionValues(SalesCrMemoLine."Dimension Set ID");
                    ProcessPostedSalesCreditMemoLine(SalesCrMemoHeader, SalesCrMemoLine, AppliedInvoiceNo);
                    DidProcessAny := true;
                end;
            until SalesCrMemoLine.Next() = 0;

        if DidProcessAny then begin
            CreditMemoState.Init();
            CreditMemoState."Posted Credit Memo SystemId" := SalesCrMemoHeader.SystemId;
            CreditMemoState."Posted Credit Memo No." := SalesCrMemoHeader."No.";
            CreditMemoState."Applied Invoice No." := AppliedInvoiceNo;
            CreditMemoState."Posted DateTime" := CurrentDateTime();
            CreditMemoState."Posted By" := CopyStr(UserId(), 1, MaxStrLen(CreditMemoState."Posted By"));
            CreditMemoState.Insert(true);
        end;
    end;

    procedure ProcessPostedSalesCreditMemoLine(var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var SalesCrMemoLine: Record "Sales Cr.Memo Line"; AppliedInvoiceNo: Code[20])
    var
        //PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        //PoolWeek: Record "TAC Pool Week";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        ConsignmentLine: Record "TAC Consignment Line";
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        //VarietyCode: Code[20];
        //GradeCode: Code[20];
        //SizeCode: Code[20];
        //GrowerCode: Code[20];
        //PackTypeCode: Code[20];
        //PackTypeCategoryCode: Code[20];
        //GrowerPoolType: Enum "TAC Grower Pool Type";
        //PoolGroupID: Integer;
        //PoolCode: Code[20];
        Proceeds: Decimal;
        LastEntryNoBeforeCharges: Integer;
    begin
        if not FindCrMemoConsignmentLine(SalesCrMemoLine, ConsignmentLine) then
            exit;
        /*DimensionMgt.ResolveFromDimensionSetWithPacking(SalesCrMemoLine."Dimension Set ID",// SeasonCode, PoolWeekCode, 
            VarietyCode, GradeCode, SizeCode, //GrowerCode, 
            GrowerPoolType, PackTypeCode, PackTypeCategoryCode);
        PoolWeek.Reset();
        PoolWeek.SetRange("Week No.", SalesCrMemoLine."Pool Week");
        PoolWeek.SetRange("Season Code", SalesCrMemoLine."Season Code");
        PoolWeek.FindLast();

        PoolGroupID := PoolGroup.FindOrCreate(CopyStr(PoolWeek."Code", 1, 10), GrowerPoolType);
        PoolCode := Pool.FindOrCreate(PoolGroupID, CopyStr(VarietyCode, 1, 10), CopyStr(GradeCode, 1, 10), CopyStr(SizeCode, 1, 10), GrowerCode);
        Proceeds := -Abs(SalesCrMemoLine.Amount);
        if not RevenueAlreadyPosted(PoolCode, SalesCrMemoHeader."No.", SalesCrMemoLine."Line No.") then
            WriteCreditRevenue(SalesCrMemoHeader, SalesCrMemoLine, PoolCode, PoolGroupID, GrowerCode, Proceeds, AppliedInvoiceNo);
        BuildCreditContext(ChargeContext, SalesCrMemoHeader, SalesCrMemoLine, PoolCode, PoolGroupID, GrowerCode, GrowerPoolType, VarietyCode, GradeCode, SizeCode, PackTypeCode, PackTypeCategoryCode, Proceeds);*/
        Pool.Get(ConsignmentLine."Pool Code");
        if not RevenueAlreadyPosted(ConsignmentLine."Pool Code", SalesCrMemoHeader."No.", SalesCrMemoLine."Line No.") then
            WriteCreditRevenue(SalesCrMemoHeader, SalesCrMemoLine, ConsignmentLine."Pool Code",
                Pool."Pool Group ID", ConsignmentLine."Grower No.", Proceeds, AppliedInvoiceNo);
        LastEntryNoBeforeCharges := LastPoolLedgerEntryNo();
        ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::InvoicePost, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);
        PostNewChargeEntriesToGL(LastEntryNoBeforeCharges, SalesCrMemoHeader."No.");
    end;

    procedure ProcessPostedSalesInvoiceLine(var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line")
    var
        ConsignmentLine: Record "TAC Consignment Line";
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        PoolWeek: Record "TAC Pool Week";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        GrowerCode: Code[20];
        PackTypeCode: Code[20];
        PackTypeCategoryCode: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        PoolGroupID: Integer;
        PoolCode: Code[20];
        OriginalQty: Decimal;
        OriginalQtyKg: Decimal;
        AmountLCY: Decimal;
        LastEntryNoBeforeCharges: Integer;
    begin
        if not FindInvoiceConsignmentLine(SalesInvoiceLine, ConsignmentLine) then
            exit;

        DimensionMgt.ValidatePoolDimensionValues(ConsignmentLine."Dimension Set ID");
        DimensionMgt.ResolveFromDimensionSetWithPacking(ConsignmentLine."Dimension Set ID", //SeasonCode, PoolWeekCode, 
            VarietyCode, GradeCode, SizeCode, //GrowerCode, 
            GrowerPoolType, PackTypeCode, PackTypeCategoryCode);
        //if GrowerCode = '' then
        GrowerCode := ConsignmentLine."Grower No.";

        PoolWeek.Reset();
        //PoolWeek.SetRange("Week No.", SalesInvoiceLine."Pool Week");
        //PoolWeek.SetRange("Season Code", SalesInvoiceLine."Season Code");
        PoolWeek.SetRange("Week No.", ConsignmentLine."Pool Week");
        PoolWeek.SetRange("Season Code", ConsignmentLine."Season Code");
        PoolWeek.FindLast();

        PoolGroupID := PoolGroup.FindOrCreate(PoolWeek.Code, GrowerPoolType);
        PoolCode := Pool.FindOrCreate(PoolGroupID, CopyStr(VarietyCode, 1, 10), CopyStr(GradeCode, 1, 10), CopyStr(SizeCode, 1, 10), GrowerCode);

        if SalesInvoiceLine."Original Quantity" <> 0 then
            OriginalQty := SalesInvoiceLine."Original Quantity"
        else
            OriginalQty := SalesInvoiceLine.Quantity;
        OriginalQtyKg := ResolveOriginalQuantityKg(SalesInvoiceLine, ConsignmentLine, OriginalQty);
        AmountLCY := LineAmountLCY(SalesInvoiceHeader, SalesInvoiceLine);

        if not RevenueAlreadyPosted(PoolCode, SalesInvoiceHeader."No.", SalesInvoiceLine."Line No.") then begin
            WriteFruitPayment(SalesInvoiceHeader, SalesInvoiceLine, ConsignmentLine, PoolCode, OriginalQty, OriginalQtyKg, AmountLCY);
            WriteInvoiceRevenue(SalesInvoiceHeader, SalesInvoiceLine, ConsignmentLine, PoolCode, PoolGroupID, GrowerCode, OriginalQty, OriginalQtyKg, AmountLCY);
        end;

        BuildInvoicePostContext(ChargeContext, SalesInvoiceHeader, SalesInvoiceLine, ConsignmentLine, PoolCode, PoolGroupID, GrowerCode, GrowerPoolType, VarietyCode, GradeCode, SizeCode, PackTypeCode, PackTypeCategoryCode, OriginalQty, OriginalQtyKg, AmountLCY);
        LastEntryNoBeforeCharges := LastPoolLedgerEntryNo();
        ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::InvoicePost, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);
        PostNewChargeEntriesToGL(LastEntryNoBeforeCharges, SalesInvoiceHeader."No.");

        SalesInvoiceLine."Pool Week" := ConsignmentLine."Pool Week";
        SalesInvoiceLine."Season Code" := ConsignmentLine."Season Code";
        SalesInvoiceLine.Modify();
    end;

    local procedure FindInvoiceConsignmentLine(var SalesInvoiceLine: Record "Sales Invoice Line"; var ConsignmentLine: Record "TAC Consignment Line"): Boolean
    var
        ConsignmentNo20: Code[20];
        LookupItemNo: Code[20];
    begin
        ConsignmentNo20 := CopyStr(SalesInvoiceLine."Consignment No.", 1, MaxStrLen(ConsignmentNo20));
        if ConsignmentNo20 = '' then
            exit(false);

        if SalesInvoiceLine."Original Item No." <> '' then
            LookupItemNo := SalesInvoiceLine."Original Item No."
        else
            LookupItemNo := SalesInvoiceLine."No.";

        ConsignmentLine.SetRange("Consignment No.", ConsignmentNo20);
        if SalesInvoiceLine."Pool Week" <> 0 then
            ConsignmentLine.SetRange("Pool Week", SalesInvoiceLine."Pool Week");
        if SalesInvoiceLine."Season Code" <> '' then
            ConsignmentLine.SetRange("Season Code", SalesInvoiceLine."Season Code");
        if LookupItemNo <> '' then
            ConsignmentLine.SetRange("Item No.", LookupItemNo);
        if ConsignmentLine.FindFirst() then
            exit(true);

        ConsignmentLine.Reset();
        ConsignmentLine.SetRange("Consignment No.", ConsignmentNo20);
        exit(ConsignmentLine.FindFirst());
    end;

    local procedure FindCrMemoConsignmentLine(var SalesCrLine: Record "Sales Cr.Memo Line"; var ConsignmentLine: Record "TAC Consignment Line"): Boolean
    var
        ConsignmentNo20: Code[20];
        LookupItemNo: Code[20];
    begin
        ConsignmentNo20 := CopyStr(SalesCrLine."Consignment No.", 1, MaxStrLen(ConsignmentNo20));
        if ConsignmentNo20 = '' then
            exit(false);

        if SalesCrLine."Original Item No." <> '' then
            LookupItemNo := SalesCrLine."Original Item No."
        else
            LookupItemNo := SalesCrLine."No.";

        ConsignmentLine.SetRange("Consignment No.", ConsignmentNo20);
        if SalesCrLine."Pool Week" <> 0 then
            ConsignmentLine.SetRange("Pool Week", SalesCrLine."Pool Week");
        if SalesCrLine."Season Code" <> '' then
            ConsignmentLine.SetRange("Season Code", SalesCrLine."Season Code");
        if LookupItemNo <> '' then
            ConsignmentLine.SetRange("Item No.", LookupItemNo);
        if ConsignmentLine.FindFirst() then
            exit(true);

        ConsignmentLine.Reset();
        ConsignmentLine.SetRange("Consignment No.", ConsignmentNo20);
        exit(ConsignmentLine.FindFirst());
    end;

    local procedure ResolveOriginalQuantityKg(var SalesInvoiceLine: Record "Sales Invoice Line"; var ConsignmentLine: Record "TAC Consignment Line"; OriginalQty: Decimal): Decimal
    var
        Item: Record Item;
        UOMMgt: Codeunit "Unit of Measure Management";
    begin
        if (ConsignmentLine.Quantity <> 0) and (ConsignmentLine."Quantity (Kg)" <> 0) then
            exit((ConsignmentLine."Quantity (Kg)" / ConsignmentLine.Quantity) * OriginalQty);

        if ConsignmentLine."Quantity (Kg)" <> 0 then
            exit(ConsignmentLine."Quantity (Kg)");

        if SalesInvoiceLine."Original Item No." <> '' then
            if Item.Get(SalesInvoiceLine."Original Item No.") then
                exit(OriginalQty * UOMMgt.GetQtyPerUnitOfMeasure(Item, 'KG'));

        exit(OriginalQty);
    end;

    local procedure WriteFruitPayment(var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line"; var ConsignmentLine: Record "TAC Consignment Line"; PoolCode: Code[20]; OriginalQty: Decimal; OriginalQtyKg: Decimal; AmountLCY: Decimal)
    var
        FruitPayment: Record "TAC Consignment Fruit Payment";
        NextLineNo: Integer;
    begin
        NextLineNo := NextFruitPaymentLineNo(ConsignmentLine."Consignment No.");

        FruitPayment.Init();
        FruitPayment."Consignment No." := ConsignmentLine."Consignment No.";
        FruitPayment."Line No." := NextLineNo;
        FruitPayment."Sales Invoice No." := SalesInvoiceHeader."No.";
        FruitPayment."Customer Invoice Reference" := SalesInvoiceHeader."Your Reference";
        FruitPayment."Item No." := SalesInvoiceLine."No.";
        FruitPayment.Quantity := SalesInvoiceLine.Quantity;
        FruitPayment."Unit Price" := SalesInvoiceLine."Unit Price";
        if SalesInvoiceLine."Original Item No." <> '' then
            FruitPayment."Original Item No." := SalesInvoiceLine."Original Item No."
        else
            FruitPayment."Original Item No." := ConsignmentLine."Item No.";
        FruitPayment."Original Quantity" := OriginalQty;
        FruitPayment."Original Quantity (Kg)" := OriginalQtyKg;
        FruitPayment."Pool Week" := ConsignmentLine."Pool Week";
        FruitPayment."Pool Code" := PoolCode;
        FruitPayment.Amount := SalesInvoiceLine.Amount;
        FruitPayment."Amount (LCY)" := AmountLCY;
        FruitPayment."Currency Code" := SalesInvoiceHeader."Currency Code";
        FruitPayment.Status := FruitPayment.Status::Posted;
        FruitPayment.Insert(true);
    end;

    local procedure NextFruitPaymentLineNo(ConsignmentNo: Code[20]): Integer
    var
        FruitPayment: Record "TAC Consignment Fruit Payment";
    begin
        FruitPayment.SetRange("Consignment No.", ConsignmentNo);
        if FruitPayment.FindLast() then
            exit(FruitPayment."Line No." + 10000);
        exit(10000);
    end;

    local procedure WriteInvoiceRevenue(
        var SalesInvoiceHeader: Record "Sales Invoice Header";
        var SalesInvoiceLine: Record "Sales Invoice Line";
        var ConsignmentLine: Record "TAC Consignment Line";
        PoolCode: Code[20];
        PoolGroupID: Integer;
        GrowerCode: Code[20];
        OriginalQty: Decimal;
        OriginalQtyKg: Decimal;
        AmountLCY: Decimal)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        ShipmentConsignmentLine: Record "TAC Consignment Line";
        TmpShipmentLine: Record "Sales Shipment Line" temporary;
        ItemLedger: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PoolRec: Record "TAC Pool";
        TotalBasisQty: Decimal;
        CurrentBasisQty: Decimal;
        RevenueQty: Decimal;
        RevenueQtyKg: Decimal;
        RevenueAmountLCY: Decimal;
        PostedQty: Decimal;
        PostedQtyKg: Decimal;
        PostedAmountLCY: Decimal;
        EntryPoolCode: Code[20];
        EntryGrowerCode: Code[20];
        EntryPoolGroupID: Integer;
        CurrentLineNo: Integer;
        LineCount: Integer;
    begin
        TmpShipmentLine.DeleteAll();
        ValueEntry.SetRange("Document Type", ValueEntry."Document Type"::"Sales Invoice");
        ValueEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
        ValueEntry.SetRange("Document Line No.", SalesInvoiceLine."Line No.");
        if ValueEntry.FindSet() then
            repeat
                Itemledger.Get(ValueEntry."Item Ledger Entry No.");
                if ItemLedger."Document Type" = ItemLedger."Document Type"::"Sales Shipment" then begin
                    if not TmpShipmentLine.Get(ItemLedger."Document No.", ItemLedger."Document Line No.") then begin
                        TmpShipmentLine.Init();
                        TmpShipmentLine."Document No." := ItemLedger."Document No.";
                        TmpShipmentLine."Line No." := ItemLedger."Document Line No.";
                        TmpShipmentLine.Insert();
                    end;
                end;
            until ValueEntry.Next() = 0;
        tmpshipmentline.Reset();
        if TmpShipmentLine.FindSet() then
            repeat
                ShipmentConsignmentLine.Reset();
                ShipmentConsignmentLine.SetRange("Source No.", TmpShipmentLine."Document No.");
                ShipmentConsignmentLine.SetRange("Source Line No.", TmpShipmentLine."Line No.");
                //if SalesInvoiceLine."Consignment No." <> '' then
                ShipmentConsignmentLine.SetRange("Consignment No.", SalesInvoiceLine."Consignment No.");
                ShipmentConsignmentLine.CalcSums("Quantity (Kg)");
                TotalBasisQty := ShipmentConsignmentLine."Quantity (Kg)";
                LineCount := ShipmentConsignmentLine.Count();

                if ShipmentConsignmentLine.findset then begin
                    CurrentLineNo := 0;
                    repeat
                        CurrentBasisQty := Abs(ShipmentConsignmentLine."Quantity (Kg)");

                        if CurrentLineNo < LineCount then begin
                            RevenueQty := OriginalQty * CurrentBasisQty / TotalBasisQty;
                            RevenueQtyKg := OriginalQtyKg * CurrentBasisQty / TotalBasisQty;
                            RevenueAmountLCY := AmountLCY * CurrentBasisQty / TotalBasisQty;
                        end else begin
                            RevenueQty := OriginalQty - PostedQty;
                            RevenueQtyKg := OriginalQtyKg - PostedQtyKg;
                            RevenueAmountLCY := AmountLCY - PostedAmountLCY;
                        end;
                        CurrentLineNo += 1;

                        PostedQty += RevenueQty;
                        PostedQtyKg += RevenueQtyKg;
                        PostedAmountLCY += RevenueAmountLCY;

                        if ShipmentConsignmentLine."Pool Code" <> '' then
                            EntryPoolCode := ShipmentConsignmentLine."Pool Code"
                        else
                            EntryPoolCode := PoolCode;

                        EntryPoolGroupID := PoolGroupID;
                        if (EntryPoolCode <> '') and PoolRec.Get(EntryPoolCode) then
                            EntryPoolGroupID := PoolRec."Pool Group ID";

                        if ShipmentConsignmentLine."Grower No." <> '' then
                            EntryGrowerCode := ShipmentConsignmentLine."Grower No."
                        else
                            EntryGrowerCode := GrowerCode;

                        PoolLedgerEntry.Init();
                        PoolLedgerEntry."Pool Code" := EntryPoolCode;
                        PoolLedgerEntry."Pool Group ID" := EntryPoolGroupID;
                        PoolLedgerEntry."Entry Type" := PoolLedgerEntry."Entry Type"::Revenue;
                        PoolLedgerEntry."Trans Type Code" := PRCodeTok;
                        PoolLedgerEntry."Document Type" := PoolLedgerEntry."Document Type"::"Sales Invoice";
                        PoolLedgerEntry."Document No." := SalesInvoiceHeader."No.";
                        PoolLedgerEntry."Source Consignment No." := ShipmentConsignmentLine."Consignment No.";
                        PoolLedgerEntry."Grower No." := ShipmentConsignmentLine."Grower No.";
                        PoolLedgerEntry."Grower Code" := EntryGrowerCode;
                        if SalesInvoiceLine."Original Item No." <> '' then
                            PoolLedgerEntry."Item No." := SalesInvoiceLine."Original Item No."
                        else
                            PoolLedgerEntry."Item No." := SalesInvoiceLine."No.";
                        PoolLedgerEntry.Quantity := RevenueQty;
                        PoolLedgerEntry."Quantity (Kg)" := RevenueQtyKg;
                        PoolLedgerEntry.Amount := RevenueAmountLCY;
                        PoolLedgerEntry."Dimension Set ID" := ShipmentConsignmentLine."Dimension Set ID";
                        PoolLedgerEntry."Transaction Date" := SalesInvoiceHeader."Posting Date";
                        PoolLedgerEntry."Posting Date" := Today();
                        PoolLedgerEntry."Source Document No." := SalesInvoiceHeader."No.";
                        PoolLedgerEntry."Source Line No." := SalesInvoiceLine."Line No.";
                        PoolLedgerEntry."Source Type" := PoolLedgerEntry."Source Type"::"Sales Invoice";
                        PoolLedgerEntry."Source System ID" := SalesInvoiceLine.SystemId;
                        PoolLedgerEntry.Insert(true);

                        PostPoolLedger2GL(PoolLedgerEntry);
                    until ShipmentConsignmentLine.Next() = 0;
                end;
            until TmpShipmentLine.Next() = 0;
    end;

    local procedure BuildInvoicePostContext(
        var ChargeContext: Record "TAC Pool Charge Context" temporary;
        var SalesInvoiceHeader: Record "Sales Invoice Header";
        var SalesInvoiceLine: Record "Sales Invoice Line";
        var ConsignmentLine: Record "TAC Consignment Line";
        PoolCode: Code[20];
        PoolGroupID:
        Integer;
        GrowerCode: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        PackTypeCode: Code[20];
        PackTypeCategoryCode: Code[20];
        OriginalQty: Decimal;
        OriginalQtyKg: Decimal;
        AmountLCY: Decimal)
    begin
        ChargeContext.Init();
        ChargeContext."Pool Code" := PoolCode;
        ChargeContext."Pool Group ID" := PoolGroupID;
        ChargeContext."Grower Code" := GrowerCode;
        ChargeContext."Supplier Type" := GrowerPoolType;
        ChargeContext."Grower Type" := MapGrowerType(GrowerPoolType);
        ChargeContext."Variety Code" := CopyStr(VarietyCode, 1, 10);
        ChargeContext."Grade Code" := CopyStr(GradeCode, 1, 10);
        ChargeContext."Size Code" := CopyStr(SizeCode, 1, 10);
        ChargeContext."Pack Type Code" := PackTypeCode;
        ChargeContext."Pack Type Category Code" := PackTypeCategoryCode;
        ChargeContext.Kgs := OriginalQtyKg;
        ChargeContext.Units := OriginalQty;
        ChargeContext.Value := AmountLCY;
        ChargeContext."Customer No." := SalesInvoiceHeader."Sell-to Customer No.";
        ChargeContext."Transaction Date" := SalesInvoiceHeader."Posting Date";
        ChargeContext."Posting Date" := Today();
        ChargeContext."Source Document No." := SalesInvoiceHeader."No.";
        ChargeContext."Source Line No." := SalesInvoiceLine."Line No.";
        if SalesInvoiceLine."Original Item No." <> '' then
            ChargeContext."Source Item No." := SalesInvoiceLine."Original Item No."
        else
            ChargeContext."Source Item No." := SalesInvoiceLine."No.";
        ChargeContext."UOM Code" := SalesInvoiceLine."Unit of Measure Code";
        ChargeContext."Source Type" := ChargeContext."Source Type"::"Sales Invoice";
        ChargeContext."Source System ID" := SalesInvoiceLine.SystemId;
    end;

    local procedure RevenueAlreadyPosted(PoolCode: Code[20]; SourceDocumentNo: Code[20]; SourceLineNo: Integer): Boolean
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Source Document No.", SourceDocumentNo);
        PoolLedgerEntry.SetRange("Source Line No.", SourceLineNo);
        PoolLedgerEntry.SetRange("Trans Type Code", PRCodeTok);
        exit(not PoolLedgerEntry.IsEmpty());
    end;

    local procedure WriteCreditRevenue(var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var SalesCrMemoLine: Record "Sales Cr.Memo Line"; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; Proceeds: Decimal; AppliedInvoiceNo: Code[20])
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := PoolCode;
        PoolLedgerEntry."Pool Group ID" := PoolGroupID;
        PoolLedgerEntry."Entry Type" := PoolLedgerEntry."Entry Type"::Revenue;
        PoolLedgerEntry."Trans Type Code" := PRCodeTok;
        PoolLedgerEntry."Document Type" := PoolLedgerEntry."Document Type"::"Sales Invoice";
        PoolLedgerEntry."Document No." := SalesCrMemoHeader."No.";
        PoolLedgerEntry."Grower Code" := GrowerCode;
        PoolLedgerEntry."Item No." := SalesCrMemoLine."No.";
        PoolLedgerEntry."Product Code" := SalesCrMemoLine."No.";
        PoolLedgerEntry.Quantity := -Abs(SalesCrMemoLine.Quantity);
        PoolLedgerEntry.Amount := Proceeds;
        PoolLedgerEntry."Dimension Set ID" := SalesCrMemoLine."Dimension Set ID";
        PoolLedgerEntry."Transaction Date" := SalesCrMemoHeader."Posting Date";
        PoolLedgerEntry."Posting Date" := Today();
        PoolLedgerEntry."Source Document No." := SalesCrMemoHeader."No.";
        PoolLedgerEntry."Source Line No." := SalesCrMemoLine."Line No.";
        PoolLedgerEntry."Source Type" := PoolLedgerEntry."Source Type"::"Sales Credit Memo";
        PoolLedgerEntry."Source System ID" := SalesCrMemoLine.SystemId;
        PoolLedgerEntry.Comment := CopyStr(StrSubstNo('Applied credit to invoice %1', AppliedInvoiceNo), 1, MaxStrLen(PoolLedgerEntry.Comment));
        PoolLedgerEntry.Insert(true);
        PostPoolLedger2GL(PoolLedgerEntry);
    end;

    local procedure BuildCreditContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var SalesCrMemoLine: Record "Sales Cr.Memo Line"; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; VarietyCode: Code[20];
                                                                                                                                                                                                                                                                                                  GradeCode: Code[20];
                                                                                                                                                                                                                                                                                                  SizeCode: Code[20];
                                                                                                                                                                                                                                                                                                  PackTypeCode: Code[20];
                                                                                                                                                                                                                                                                                                  PackTypeCategoryCode: Code[20];
                                                                                                                                                                                                                                                                                                  Proceeds: Decimal)
    begin
        ChargeContext.Init();
        ChargeContext."Pool Code" := PoolCode;
        ChargeContext."Pool Group ID" := PoolGroupID;
        ChargeContext."Grower Code" := GrowerCode;
        ChargeContext."Supplier Type" := GrowerPoolType;
        ChargeContext."Grower Type" := MapGrowerType(GrowerPoolType);
        ChargeContext."Variety Code" := CopyStr(VarietyCode, 1, 10);
        ChargeContext."Grade Code" := CopyStr(GradeCode, 1, 10);
        ChargeContext."Size Code" := CopyStr(SizeCode, 1, 10);
        ChargeContext."Pack Type Code" := PackTypeCode;
        ChargeContext."Pack Type Category Code" := PackTypeCategoryCode;
        ChargeContext.Kgs := Abs(SalesCrMemoLine.Quantity);
        ChargeContext.Units := Abs(SalesCrMemoLine.Quantity);
        ChargeContext.Value := Abs(Proceeds);
        ChargeContext."Customer No." := SalesCrMemoHeader."Sell-to Customer No.";
        ChargeContext."Transaction Date" := SalesCrMemoHeader."Posting Date";
        ChargeContext."Posting Date" := Today();
        ChargeContext."Source Document No." := SalesCrMemoHeader."No.";
        ChargeContext."Source Line No." := SalesCrMemoLine."Line No.";
        ChargeContext."Source Item No." := SalesCrMemoLine."No.";
        ChargeContext."UOM Code" := SalesCrMemoLine."Unit of Measure Code";
        ChargeContext.Reversal := true;
        ChargeContext."Source Type" := ChargeContext."Source Type"::"Sales Credit Memo";
        ChargeContext."Source System ID" := SalesCrMemoLine.SystemId;
    end;

    local procedure LastPoolLedgerEntryNo(): Integer
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        if PoolLedgerEntry.FindLast() then
            exit(PoolLedgerEntry."Entry No.");
        exit(0);
    end;

    local procedure PostNewChargeEntriesToGL(EntryNoFloor: Integer; SalesInvoiceNo: Code[20])
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetFilter("Entry No.", '>%1', EntryNoFloor);
        PoolLedgerEntry.SetRange("Source Document No.", SalesInvoiceNo);
        if PoolLedgerEntry.FindSet() then
            repeat
                if (PoolLedgerEntry."Document No." = '') and (PoolLedgerEntry."Document Type" = PoolLedgerEntry."Document Type"::Consignment) then begin
                    PoolLedgerEntry."Document Type" := PoolLedgerEntry."Document Type"::"Sales Invoice";
                    PoolLedgerEntry."Document No." := SalesInvoiceNo;
                    PoolLedgerEntry.Modify();
                end;
                PostPoolLedger2GL(PoolLedgerEntry);
            until PoolLedgerEntry.Next() = 0;
    end;

    local procedure LineAmountLCY(var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line"): Decimal
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
    begin
        if SalesInvoiceHeader."Currency Code" = '' then
            exit(SalesInvoiceLine.Amount);
        if SalesInvoiceHeader."Currency Factor" = 0 then
            exit(SalesInvoiceLine.Amount);
        exit(CurrencyExchangeRate.ExchangeAmtFCYToLCY(SalesInvoiceHeader."Posting Date", SalesInvoiceHeader."Currency Code", SalesInvoiceLine.Amount, SalesInvoiceHeader."Currency Factor"));
    end;

    local procedure WriteProceeds(var SalesInvoiceHeader: Record "Sales Invoice Header"; PoolCode: Code[20]; PoolGroupID: Integer; Proceeds: Decimal)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";

    begin
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := PoolCode;
        PoolLedgerEntry."Pool Group ID" := PoolGroupID;
        PoolLedgerEntry."Trans Type Code" := PRCodeTok;
        //PoolLedgerEntry."Grower Code" := GrowerCode;
        PoolLedgerEntry.Amount := Proceeds; // positive: proceeds into the pool
        PoolLedgerEntry."Transaction Date" := SalesInvoiceHeader."Posting Date";
        PoolLedgerEntry."Posting Date" := Today();
        PoolLedgerEntry."Source Document No." := SalesInvoiceHeader."No.";
        PoolLedgerEntry.Insert(true);
    end;

    local procedure BuildContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line"; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; VarietyCode: Code[20];
                                                                                                                                                                                                                                                                                              GradeCode: Code[20];
                                                                                                                                                                                                                                                                                              SizeCode: Code[20];
                                                                                                                                                                                                                                                                                              Proceeds: Decimal)
    begin
        ChargeContext.Init();
        ChargeContext."Pool Code" := PoolCode;
        ChargeContext."Pool Group ID" := PoolGroupID;
        ChargeContext."Grower Code" := GrowerCode;
        ChargeContext."Supplier Type" := GrowerPoolType;
        ChargeContext."Variety Code" := CopyStr(VarietyCode, 1, 10);
        ChargeContext."Grade Code" := CopyStr(GradeCode, 1, 10);
        ChargeContext."Size Code" := CopyStr(SizeCode, 1, 10);
        ChargeContext.Kgs := SalesInvoiceLine.Quantity; // assumes kg UOM
        ChargeContext.Value := Proceeds;
        ChargeContext."Customer No." := SalesInvoiceHeader."Sell-to Customer No.";
        // Pack Type / Category needed for the ripener condition (RIP/RAD) are
        // not yet resolved onto the line context — sales-execution-stock seam.
        ChargeContext."Transaction Date" := SalesInvoiceHeader."Posting Date";
        ChargeContext."Posting Date" := Today();
        ChargeContext."Source Document No." := SalesInvoiceHeader."No.";
    end;
}
