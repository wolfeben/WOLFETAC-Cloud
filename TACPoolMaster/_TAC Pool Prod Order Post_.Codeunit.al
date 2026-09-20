codeunit 50271 "TAC Pool Prod Order Post"
{
    // AL-07A/07B: on a finished packing Production Order, find/create the Pool
    // Group + Pool, write the TR Pool Ledger Entry, then run the RunClose
    // charges through the engine (design §6.1). Invoked from 50277, not
    // subscribed directly (house rule).
    //
    // A packing order is identified by its posted OUTPUT ITEM carrying the
    // configured prefix — packing orders no longer carry a number prefix of
    // their own (OI-PE-11). The gate order below matters: this codeunit runs on
    // every finished production order in the company, so the two checks that
    // cannot error (already-pooled, then packed-output) come first and everything
    // that reads required setup comes after. Getting that backwards would let an
    // unconfigured system block unrelated production from being finished at all,
    // because an error raised in the OnAfterInsert subscriber rolls back the
    // finish.
    //
    // The gates are silent no-ops by design (a non-packing order, a repack, a
    // re-finish). That silence is what makes a non-pooling order hard to
    // explain, so the checks are public and 50282 walks the same ones to report
    // which of them stopped a given order.

    procedure RunCloseFromProductionOrder(var ProductionOrder: Record "Production Order"; PostingDate: Date)
    var
        ProdOrderLine: Record "Prod. Order Line";
        OutputItemNo: Code[20];
    begin
        // The header is only the order-level trigger/date and repack guard.
        // Every classification and quantity below comes from the finished
        // output line, because one production order can produce several pools.
        if HasLegacyHeaderTR(ProductionOrder."No.") then
            exit;
        if not HasPackedOutput(ProductionOrder."No.", OutputItemNo) then
            exit;
        if not HasConsumedBinInput(ProductionOrder."No.") then
            exit;

        ProdOrderLine.SetRange(Status, ProdOrderLine.Status::Finished);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                RunCloseFromProductionOrderLine(ProductionOrder, ProdOrderLine, PostingDate);
            until ProdOrderLine.Next() = 0;
    end;

    procedure RunCloseFromProductionOrderLine(var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line"; PostingDate: Date)
    var
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
        //SeasonCode: Code[20];
        //PoolWeekCode: Code[20];
        PoolWeek: Record "TAC Pool Week";
        BatchPlan: Record "TAC Batch Plan Header";
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        GrowerCode: Code[20];
        PackTypeCode: Code[20];
        PackTypeCategoryCode: Code[20];
        OutputItemNo: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        PoolGroupID: Integer;
        PoolCode: Code[20];
        Kgs: Decimal;
        Units: Decimal;
    begin
        if not HasPackedOutputLine(ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo) then
            exit;

        CalcPackedLineQuantities(ProductionOrder."No.", ProductionOrderLine."Line No.", Kgs, Units, OutputItemNo);
        if Units <= 0 then
            exit;

        ProductionOrder.CalcFields("Batch Plan No.", "Grower ID");
        BatchPlan.Get(ProductionOrder."Batch Plan No.");
        PoolWeek.Reset();
        PoolWeek.SetFilter("Start Date", '<=%1', BatchPlan."Plan Date");
        PoolWeek.SetFilter("End Date", '>=%1', BatchPlan."Plan Date");
        PoolWeek.FindLast();
        ProductionOrder.CalcFields("Grower ID");

        DimensionMgt.ValidatePoolDimensionValues(ProductionOrderLine."Dimension Set ID");
        DimensionMgt.ResolveFromProductionOrderLine(ProductionOrderLine, //SeasonCode, PoolWeekCode, 
            VarietyCode, GradeCode, SizeCode, //GrowerCode, 
            GrowerPoolType, PackTypeCode, PackTypeCategoryCode);

        GrowerCode := GrowerMgt.GrowerCodeForSourceVendor(ProductionOrder."Grower ID", ProductionOrderLine."Dimension Set ID");
        PoolGroupID := PoolGroup.FindOrCreate(PoolWeek.Code, GrowerPoolType);
        PoolCode := Pool.FindOrCreate(PoolGroupID, CopyStr(VarietyCode, 1, 10), CopyStr(GradeCode, 1, 10), CopyStr(SizeCode, 1, 10), ProductionOrder."Grower ID");

        WriteTransferReceipt(ProductionOrder, ProductionOrderLine, OutputItemNo, PoolCode, PoolGroupID, GrowerCode, Kgs, Units, PostingDate);
        BuildLineContext(ChargeContext, ProductionOrder, ProductionOrderLine, OutputItemNo, PoolCode, PoolGroupID, GrowerCode, GrowerPoolType, VarietyCode, GradeCode, SizeCode, PackTypeCode, PackTypeCategoryCode, Kgs, Units, PostingDate);
        ChargeEngine.ApplyCharges(Enum::"TAC Pool Charge Action"::RunClose, ChargeContext, Enum::"TAC Pool Charge Mode"::Write);
    end;

    /// <summary>True when the item number carries the configured packed-item prefix.</summary>
    procedure IsPackedItemNo(ItemNo: Code[20]): Boolean
    var
        Prefix: Code[20];
    begin
        // Unlike the other configured values this one fails CLOSED rather than
        // erroring, for two reasons. A blank prefix matches every item number,
        // so "not configured" must mean "nothing pools", never "everything
        // pools". And this gate runs on every finished production order,
        // including ones with nothing to do with packing, so erroring here
        // would block unrelated production company-wide. An unset prefix is
        // reported by the diagnostic (50282) instead.
        Prefix := PackedItemPrefix();
        if Prefix = '' then
            exit(false);
        exit(CopyStr(ItemNo, 1, StrLen(Prefix)) = Prefix);
    end;

    /// <summary>The configured packed-item prefix; blank when pooling is not set up.</summary>
    procedure PackedItemPrefix(): Code[20]
    begin
        GetSetup();
        exit(PoolSetup."Packed Item No. Prefix");
    end;

    /// <summary>
    /// True when the order posted output for a packed item, returning the first
    /// such item. This is what makes an order a packing run. Public and
    /// non-erroring so 50282 can ask the same question read-only.
    /// </summary>
    procedure HasPackedOutput(ProductionOrderNo: Code[20]; var OutputItemNo: Code[20]): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        OutputItemNo := '';
        if PackedItemPrefix() = '' then
            exit(false);

        FilterOrderEntries(ItemLedgerEntry, ProductionOrderNo, ItemLedgerEntry."Entry Type"::Output);
        if ItemLedgerEntry.FindSet() then
            repeat
                if IsPackedItemNo(ItemLedgerEntry."Item No.") then begin
                    OutputItemNo := ItemLedgerEntry."Item No.";
                    exit(true);
                end;
            until ItemLedgerEntry.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// True when this production order has already written its TR entry. Public
    /// so a future re-post or reversal path — and the tests — can ask exactly
    /// the question the guard asks.
    /// </summary>
    procedure AlreadyPooled(ProductionOrderNo: Code[20]): Boolean
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        if ProductionOrderNo = '' then
            exit(false);
        PoolLedgerEntry.SetCurrentKey("Source Document No.", "Trans Type Code");
        PoolLedgerEntry.SetRange("Source Document No.", ProductionOrderNo);
        PoolLedgerEntry.SetRange("Trans Type Code", 'TR');
        exit(not PoolLedgerEntry.IsEmpty());
    end;

    local procedure AlreadyPooledLine(ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer): Boolean
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetCurrentKey("Source Document No.", "Source Line No.", "Trans Type Code");
        PoolLedgerEntry.SetRange("Source Document No.", ProductionOrderNo);
        PoolLedgerEntry.SetRange("Source Line No.", ProductionOrderLineNo);
        PoolLedgerEntry.SetRange("Trans Type Code", 'TR');
        exit(not PoolLedgerEntry.IsEmpty());
    end;

    local procedure HasLegacyHeaderTR(ProductionOrderNo: Code[20]): Boolean
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetCurrentKey("Source Document No.", "Source Line No.", "Trans Type Code");
        PoolLedgerEntry.SetRange("Source Document No.", ProductionOrderNo);
        PoolLedgerEntry.SetRange("Source Line No.", 0);
        PoolLedgerEntry.SetRange("Trans Type Code", 'TR');
        exit(not PoolLedgerEntry.IsEmpty());
    end;

    procedure HasPackedOutputLine(ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; var OutputItemNo: Code[20]): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        OutputItemNo := '';
        FilterOrderLineEntries(ItemLedgerEntry, ProductionOrderNo, ProductionOrderLineNo, ItemLedgerEntry."Entry Type"::Output);
        if ItemLedgerEntry.FindSet() then
            repeat
                if IsPackedItemNo(ItemLedgerEntry."Item No.") then begin
                    OutputItemNo := ItemLedgerEntry."Item No.";
                    exit(true);
                end;
            until ItemLedgerEntry.Next() = 0;
        exit(false);
    end;

    /// <summary>Public read-only API for previews and reconciliation.</summary>
    procedure GetPackedOutputLine(ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; var OutputItemNo: Code[20]): Boolean
    begin
        exit(HasPackedOutputLine(ProductionOrderNo, ProductionOrderLineNo, OutputItemNo));
    end;

    /// <summary>
    /// The packed quantities the pool is built from, read from the order's
    /// posted Item Ledger Entries. Public and read-only so 50282 can report the
    /// same numbers the posting path acts on.
    /// </summary>
    procedure CalcPackedQuantities(ProductionOrderNo: Code[20]; var Kgs: Decimal; var Units: Decimal; var Bins: Decimal; var OutputItemNo: Code[20])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        Kgs := 0;
        Units := 0;
        Bins := 0;
        OutputItemNo := '';

        // Output tray equivalents come from the order's posted output ILEs
        // (assumption confirmed: based on posted, completed orders with TE
        // output). Only PACKED output counts — it is both what marks the run and
        // what the pool is measured in, so unpacked byproduct on the same order
        // must not add kilos to a grower's pool.
        //
        // Each entry is converted on its own item rather than summing base
        // quantities first: an order outputting two packed items with different
        // TE or KG conversions would otherwise be converted entirely on
        // whichever item happened to come last.
        FilterOrderEntries(ItemLedgerEntry, ProductionOrderNo, ItemLedgerEntry."Entry Type"::Output);
        if ItemLedgerEntry.FindSet() then
            repeat
                if IsPackedItemNo(ItemLedgerEntry."Item No.") then begin
                    if OutputItemNo = '' then
                        OutputItemNo := ItemLedgerEntry."Item No.";
                    // output is positive, in base UOM
                    Units += TrayEquivalents(ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
                    //Kgs += Kilograms(ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
                    Kgs += CalculateNormalisedKg(ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
                end;
            until ItemLedgerEntry.Next() = 0;

        if OutputItemNo = '' then begin
            Kgs := 0;
            Units := 0;
            exit;
        end;

        // Bins = the supplier-delivered input the order consumed.
        Bins := GetConsumedBins(ProductionOrderNo);
    end;

    procedure CalcPackedLineQuantities(ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; var Kgs: Decimal; var Units: Decimal; var OutputItemNo: Code[20])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        Kgs := 0;
        Units := 0;
        OutputItemNo := '';
        FilterOrderLineEntries(ItemLedgerEntry, ProductionOrderNo, ProductionOrderLineNo, ItemLedgerEntry."Entry Type"::Output);
        if ItemLedgerEntry.FindSet() then
            repeat
                if IsPackedItemNo(ItemLedgerEntry."Item No.") then begin
                    if OutputItemNo = '' then
                        OutputItemNo := ItemLedgerEntry."Item No.";
                    Units += TrayEquivalents(ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
                    Kgs += CalculateNormalisedKg(ItemLedgerEntry."Item No.", ItemLedgerEntry.Quantity);
                end;
            until ItemLedgerEntry.Next() = 0;
    end;

    /// <summary>Public read-only API for previews and reconciliation.</summary>
    procedure GetPackedLineQuantities(ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; var Kgs: Decimal; var Units: Decimal; var OutputItemNo: Code[20])
    begin
        CalcPackedLineQuantities(ProductionOrderNo, ProductionOrderLineNo, Kgs, Units, OutputItemNo);
    end;

    /// <summary>Number of posted output entries for the order — 0 means nothing to pool.</summary>
    procedure CountOutputEntries(ProductionOrderNo: Code[20]): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        FilterOrderEntries(ItemLedgerEntry, ProductionOrderNo, ItemLedgerEntry."Entry Type"::Output);
        exit(ItemLedgerEntry.Count());
    end;

    /// <summary>
    /// The distinct output items the order posted, comma separated. Only for the
    /// diagnostic: when none of them is packed, the item numbers are the thing
    /// the user needs to see against the configured prefix.
    /// </summary>
    procedure OutputItemList(ProductionOrderNo: Code[20]) List: Text
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Seen: Dictionary of [Code[20], Boolean];
    begin
        FilterOrderEntries(ItemLedgerEntry, ProductionOrderNo, ItemLedgerEntry."Entry Type"::Output);
        if ItemLedgerEntry.FindSet() then
            repeat
                if not Seen.ContainsKey(ItemLedgerEntry."Item No.") then begin
                    Seen.Add(ItemLedgerEntry."Item No.", true);
                    if List <> '' then
                        List += ', ';
                    List += ItemLedgerEntry."Item No.";
                end;
            until ItemLedgerEntry.Next() = 0;
    end;

    /// <summary>Base quantity as tray equivalents. TE as the base UOM needs no conversion.</summary>
    local procedure TrayEquivalents(ItemNo: Code[20]; BaseQty: Decimal): Decimal
    var
        QtyPer: Decimal;
    begin
        QtyPer := ItemUoMQtyPer(ItemNo, TrayEquivUoMCode());
        if QtyPer = 0 then
            QtyPer := 1;
        exit(BaseQty / QtyPer);
    end;

    local procedure GetConsumedBins(ProductionOrderNo: Code[20]): Decimal
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        BinUoM: Code[10];
        TotalBins: Decimal;
    begin
        BinUoM := BinUoMCode();
        FilterOrderEntries(ItemLedgerEntry, ProductionOrderNo, ItemLedgerEntry."Entry Type"::Consumption);
        if ItemLedgerEntry.FindSet() then
            repeat
                // Only count the bin input, not packaging components.
                if Item.Get(ItemLedgerEntry."Item No.") then
                    if Item."Base Unit of Measure" = BinUoM then
                        TotalBins += Abs(ItemLedgerEntry.Quantity); // consumption is negative
            until ItemLedgerEntry.Next() = 0;
        exit(TotalBins);
    end;

    procedure HasConsumedBinInput(ProductionOrderNo: Code[20]): Boolean
    begin
        // Consumed bins are no longer a pooling measure or charge basis. This
        // existing guard remains solely to distinguish an original pack run
        // from a repack order.
        exit(GetConsumedBins(ProductionOrderNo) <> 0);
    end;

    /// <summary>Public read-only API for previews and reconciliation.</summary>
    procedure IsOriginalPackRun(ProductionOrderNo: Code[20]): Boolean
    begin
        exit(HasConsumedBinInput(ProductionOrderNo));
    end;

    local procedure FilterOrderEntries(var ItemLedgerEntry: Record "Item Ledger Entry"; ProductionOrderNo: Code[20]; EntryType: Enum "Item Ledger Entry Type")
    begin
        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetRange("Order Type", ItemLedgerEntry."Order Type"::Production);
        ItemLedgerEntry.SetRange("Order No.", ProductionOrderNo);
        ItemLedgerEntry.SetRange("Entry Type", EntryType);
    end;

    local procedure FilterOrderLineEntries(var ItemLedgerEntry: Record "Item Ledger Entry"; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; EntryType: Enum "Item Ledger Entry Type")
    begin
        FilterOrderEntries(ItemLedgerEntry, ProductionOrderNo, EntryType);
        ItemLedgerEntry.SetRange("Order Line No.", ProductionOrderLineNo);
    end;

    local procedure ItemUoMQtyPer(ItemNo: Code[20]; UoMCode: Code[10]): Decimal
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if (UoMCode <> '') and ItemUnitOfMeasure.Get(ItemNo, UoMCode) then
            exit(ItemUnitOfMeasure."Qty. per Unit of Measure");
        exit(0);
    end;

    // --- configured units of measure ---

    procedure TrayEquivUoMCode(): Code[10]
    begin
        GetSetup();
        exit(RequiredUoM(PoolSetup."Tray Equiv. UoM Code", PoolSetup.FieldCaption("Tray Equiv. UoM Code")));
    end;

    procedure KgUoMCode(): Code[10]
    begin
        GetSetup();
        exit(RequiredUoM(PoolSetup."Kg UoM Code", PoolSetup.FieldCaption("Kg UoM Code")));
    end;

    procedure BinUoMCode(): Code[10]
    begin
        GetSetup();
        exit(RequiredUoM(PoolSetup."Bin UoM Code", PoolSetup.FieldCaption("Bin UoM Code")));
    end;

    /// <summary>True when all three pool units of measure are configured. Never errors.</summary>
    procedure UomSetupComplete(): Boolean
    begin
        GetSetup();
        exit(
            (PoolSetup."Tray Equiv. UoM Code" <> '') and
            (PoolSetup."Kg UoM Code" <> '') and
            (PoolSetup."Bin UoM Code" <> ''));
    end;

    /// <summary>Drop the cached setup — for tests and long-running sessions.</summary>
    procedure ClearCache()
    begin
        Clear(PoolSetup);
        SetupRead := false;
    end;

    local procedure GetSetup()
    begin
        if SetupRead then
            exit;
        if not PoolSetup.Get() then
            PoolSetup.Init();
        SetupRead := true;
    end;

    local procedure RequiredUoM(UoMCode: Code[10]; SetupFieldCaption: Text): Code[10]
    begin
        if UoMCode = '' then
            Error(UomNotSetErr, SetupFieldCaption);
        exit(UoMCode);
    end;

    // --- writing ---

    local procedure WriteTransferReceipt(var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line"; OutputItemNo: Code[20]; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; Kgs: Decimal; Units: Decimal; PostingDate: Date)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
    begin
        if AlreadyPooledLine(ProductionOrder."No.", ProductionOrderLine."Line No.") then
            exit;
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := PoolCode;
        PoolLedgerEntry."Pool Group ID" := PoolGroupID;
        PoolLedgerEntry."Entry Type" := PoolLedgerEntry."Entry Type"::Quantity;
        PoolLedgerEntry."Trans Type Code" := 'TR';
        PoolLedgerEntry."Grower Code" := GrowerCode;
        PoolLedgerEntry."Grower No." := GrowerMgt.VendorNoForGrower(GrowerCode);
        PoolLedgerEntry."Item No." := OutputItemNo;
        PoolLedgerEntry."Product Code" := OutputItemNo;
        PoolLedgerEntry.Quantity := Units;
        PoolLedgerEntry."Quantity (Kg)" := Kgs;
        PoolLedgerEntry."Document Type" := PoolLedgerEntry."Document Type"::"Run Close";
        PoolLedgerEntry."Document No." := ProductionOrder."No.";
        PoolLedgerEntry."Transaction Date" := ProductionOrder."Due Date";
        PoolLedgerEntry."Posting Date" := PostingDate;
        PoolLedgerEntry."Source Document No." := ProductionOrder."No.";
        PoolLedgerEntry."Source Line No." := ProductionOrderLine."Line No.";
        PoolLedgerEntry."Source Type" := PoolLedgerEntry."Source Type"::"Production Output";
        PoolLedgerEntry."Source System ID" := ProductionOrderLine.SystemId;
        PoolLedgerEntry."Dimension Set ID" := ProductionOrderLine."Dimension Set ID";
        PoolLedgerEntry.Insert(true);
    end;

    local procedure BuildLineContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line"; OutputItemNo: Code[20]; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; VarietyCode: Code[20]; GradeCode: Code[20]; SizeCode: Code[20]; PackTypeCode: Code[20]; PackTypeCategoryCode: Code[20]; Kgs: Decimal; Units: Decimal; PostingDate: Date)
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
        ChargeContext.Kgs := Kgs;
        ChargeContext.Units := Units;
        ChargeContext."Transaction Date" := ProductionOrder."Due Date";
        ChargeContext."Posting Date" := PostingDate;
        ChargeContext."Source Document No." := ProductionOrder."No.";
        ChargeContext."Source Line No." := ProductionOrderLine."Line No.";
        ChargeContext."Source Item No." := OutputItemNo;
        ChargeContext."UOM Code" := ProductionOrderLine."Unit of Measure Code";
        ChargeContext."Source Type" := ChargeContext."Source Type"::"Production Output";
        ChargeContext."Source System ID" := ProductionOrderLine.SystemId;
    end;

    local procedure CreatePoolLedgerFromProdOrder(var ProdOrderLine: Record "Prod. Order Line";
                                         ChargeType: Record "TAC Pool Charge Type";
                                         GrossPoolValue: Decimal;
                                         PostingDate: Date)
    var
        ProdOrder: Record "Production Order";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        Pool: Record "TAC Pool";
        Vendor: Record Vendor;
    begin
        ProdOrder.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.");
        Pool.Get(ProdOrder."Pool Code");
        Vendor.Get(Pool."Grower No.");
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := ProdOrder."Pool Code";
        PoolLedgerEntry."Entry Type" := PoolLedgerEntry."Entry Type"::Charge;
        PoolLedgerEntry."Charge Type Code" := ChargeType.Code;
        PoolLedgerEntry."Grower Code" := Pool."Grower No.";
        PoolLedgerEntry."Posting Date" := PostingDate;
        PoolLedgerEntry."Document Type" := PoolLedgerEntry."Document Type"::"Run Close";
        PoolLedgerEntry."Document No." := ProdOrder."No.";
        // how to resolve the consignment number???
        //PoolLedgerEntry."Source Consignment No." := 
        PoolLedgerEntry."Grower No." := Pool."Grower No.";
        PoolLedgerEntry."Item No." := ProdOrderLine."Item No.";
        PoolLedgerEntry.Quantity := ProdOrderLine."Finished Quantity";
        PoolLedgerEntry."Quantity (Kg)" := CalculateNormalisedKg(ProdOrderLine."Item No.", ProdOrderLine."Finished Quantity");
        case ChargeType."Rate Type" of
            ChargeType."Rate Type"::Unit:
                PoolLedgerEntry.Amount := -PoolLedgerEntry.Quantity *
                    ResolvePoolChargeRate(PostingDate, ChargeType,
                    Vendor."Grower Pool Type", Pool."Grower No.", Pool."Variety Code");
            ChargeType."Rate Type"::Kg:
                PoolLedgerEntry.Amount := -PoolLedgerEntry."Quantity (Kg)" *
                    ResolvePoolChargeRate(PostingDate, ChargeType,
                    Vendor."Grower Pool Type", Pool."Grower No.", Pool."Variety Code");
            ChargeType."Rate Type"::Bin:
                PoolLedgerEntry.Amount := -GetConsumedBins(ProdOrder."No.") *
                    ResolvePoolChargeRate(PostingDate, ChargeType,
                    Vendor."Grower Pool Type", Pool."Grower No.", Pool."Variety Code");
            ChargeType."Rate Type"::Value:
                PoolLedgerEntry.Amount := -GrossPoolValue *
                    ResolvePoolChargeRate(PostingDate, ChargeType,
                    Vendor."Grower Pool Type", Pool."Grower No.", Pool."Variety Code") / 100;
        end;
        PoolLedgerEntry.Insert();
        PostPoolLedger2GL(PoolLedgerEntry);
    end;

    local procedure PostPoolLedger2GL(PoolLedgerEntry: Record "TAC Pool Ledger Entry")
    var
        ChargeType: Record "TAC Pool Charge Type";
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        LineNo: Integer;
        AmountToPost: Decimal;
    begin
        if (PoolLedgerEntry.Amount = 0) or (PoolLedgerEntry."Charge Type Code" = '') then
            exit;

        ChargeType.Get(PoolLedgerEntry."Charge Type Code");
        ChargeType.TestField("G/L Account No.");
        ChargeType.TestField("Bal. G/L Account No.");

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
        GenJournalLine.Validate("Account No.", ChargeType."G/L Account No.");
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", ChargeType."Bal. G/L Account No.");
        GenJournalLine.Validate(Amount, AmountToPost);
        GenJournalLine.Validate("Document No.", PoolLedgerEntry."Document No.");
        GenJournalLine.Description := CopyStr(StrSubstNo('Pool charge %1', PoolLedgerEntry."Charge Type Code"), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine."Dimension Set ID" := PoolLedgerEntry."Dimension Set ID";
        GenJournalLine.Insert(true);

        GenJnlPostLine.RunWithCheck(GenJournalLine);
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

    procedure ResolvePoolChargeRate(AppliedDate: Date;
                                     ChargeType: Record "TAC Pool Charge Type";
                                     GrowerPoolType: Enum "TAC Grower Pool Type";
                                     GrowerNo: Code[20];
                                     VarietyCode: Code[20]): Decimal
    var
        ChargeRate: Record "TAC Pool Charge Rate";
    begin
        ChargeRate.SetRange("Grower No.", GrowerNo);
        ChargeRate.SetRange("Charge Type Code", ChargeType.Code);
        // The legacy charge-rate table still stores Rate Type as an Option,
        // while the charge type uses the TAC Pool Rate Type enum. Map the
        // equivalent values explicitly rather than relying on ordinal values.
        case ChargeType."Rate Type" of
            ChargeType."Rate Type"::Unit:
                ChargeRate.SetRange("Rate Type", ChargeRate."Rate Type"::Units);
            ChargeType."Rate Type"::Kg:
                ChargeRate.SetRange("Rate Type", ChargeRate."Rate Type"::Kilograms);
            ChargeType."Rate Type"::Bin:
                ChargeRate.SetRange("Rate Type", ChargeRate."Rate Type"::Bins);
            ChargeType."Rate Type"::Value:
                ChargeRate.SetRange("Rate Type", ChargeRate."Rate Type"::"Value (%)");
            else
                exit(0);
        end;
        ChargeRate.SetRange("Grower Type", GrowerPoolType);
        ChargeRate.SetRange("Variety Code", VarietyCode);
        ChargeRate.SetFilter("Starting Date", '<=%1', AppliedDate);
        ChargeRate.SetFilter("Ending Date", '>=%1|%2', AppliedDate, 0D);
        if ChargeRate.FindLast() then
            exit(ChargeRate.Rate);
        exit(0);
    end;

    local procedure BuildContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var ProductionOrder: Record "Production Order"; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; VarietyCode: Code[20]; GradeCode: Code[20]; SizeCode: Code[20]; Kgs: Decimal; Units: Decimal; Bins: Decimal)
    begin
        // The engine reads the context fields directly; no Insert needed.
        ChargeContext.Init();
        ChargeContext."Pool Code" := PoolCode;
        ChargeContext."Pool Group ID" := PoolGroupID;
        ChargeContext."Grower Code" := GrowerCode;
        ChargeContext."Supplier Type" := GrowerPoolType;
        ChargeContext."Grower Type" := MapGrowerType(GrowerPoolType);
        ChargeContext."Variety Code" := CopyStr(VarietyCode, 1, 10);
        ChargeContext."Grade Code" := CopyStr(GradeCode, 1, 10);
        ChargeContext."Size Code" := CopyStr(SizeCode, 1, 10);
        ChargeContext.Kgs := Kgs;
        ChargeContext.Units := Units;
        ChargeContext.Bins := Bins;
        ChargeContext."Transaction Date" := ProductionOrder."Due Date";
        ChargeContext."Posting Date" := Today();
        ChargeContext."Source Document No." := ProductionOrder."No.";
    end;

    local procedure MapGrowerType(GrowerPoolType: Enum "TAC Grower Pool Type"): Enum "TAC Grower Type"
    begin
        // Pack-run context carries the pool type; the individual grower's full
        // Grower Type (incl. legacy C/F) is not on the PKD- order — OI-PE-07.
        case GrowerPoolType of
            GrowerPoolType::External:
                exit(Enum::"TAC Grower Type"::External);
            GrowerPoolType::"Contract Pack":
                exit(Enum::"TAC Grower Type"::"Contract Pack");
            else
                exit(Enum::"TAC Grower Type"::Internal);
        end;
    end;

    procedure CalculateNormalisedKg(ItemNo: Code[20]; Quantity: Decimal): Decimal
    var
        Item: Record Item;
        ItemUOMRec: Record "Item Unit of Measure";
        UOMMgt: Codeunit "Unit of Measure Management";
    begin
        Item.Get(ItemNo);
        exit(Quantity * UOMMgt.GetQtyPerUnitOfMeasure(Item, 'KG'));
    end;

    var
        PoolSetup: Record "TAC Pool Setup";
        SetupRead: Boolean;
        GLJnlTemplateTok: Label 'POOLRUN', Locked = true;
        GLJnlBatchTok: Label 'RUNCLOSE', Locked = true;
        UomNotSetErr: Label 'The %1 is not set on Pool Payment Setup. Set the pool units of measure before pooling.', Comment = '%1 = the setup field caption, e.g. Bin UoM Code';
}
