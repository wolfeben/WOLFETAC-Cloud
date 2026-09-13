codeunit 50282 "TAC Pool Post Diagnostic"
{
    // "Why didn't this pool?" — walks the Run Close gates read-only and reports
    // the first one that blocked the order, with the values it actually found.
    // Most of those gates are silent no-ops in normal operation, which is what
    // made a non-pooling production order hard to explain.
    //
    // It calls 50271's and 50276's own public checks rather than re-implementing
    // them, so the diagnostic cannot drift from the behaviour it is explaining.
    // Nothing here writes, and nothing here errors: an unconfigured system is a
    // finding to report, not a reason to fall over.
    var HeadingTxt: Label 'Pool posting diagnostic for %1', Comment = '%1 = Production Order No.';
    NoOrderTxt: Label 'No production order %1 exists (in any status).', Comment = '%1 = Production Order No.';
    StatusTxt: Label 'Status: %1', Comment = '%1 = Production Order Status';
    PackedOutputTxt: Label 'Packed output (%1 prefix): %2', Comment = '%1 = prefix, %2 = Yes/No';
    PrefixNotSetTxt: Label 'Packed item prefix: (not set)';
    OutputItemsTxt: Label 'Output items posted: %1', Comment = '%1 = comma separated item numbers';
    AlreadyPooledTxt: Label 'Already pooled: %1', Comment = '%1 = Yes/No';
    DimensionSetupTxt: Label 'Pool dimensions configured: %1', Comment = '%1 = Yes/No';
    UomSetupTxt: Label 'Pool units of measure configured: %1', Comment = '%1 = Yes/No';
    OutputEntriesTxt: Label 'Posted output entries: %1', Comment = '%1 = count';
    OutputItemTxt: Label 'Output item: %1', Comment = '%1 = Item No.';
    UnitsTxt: Label 'Tray equivalents: %1', Comment = '%1 = quantity';
    KgsTxt: Label 'Kilograms: %1', Comment = '%1 = quantity';
    BinsTxt: Label 'Bins consumed: %1', Comment = '%1 = quantity';
    DimensionsTxt: Label 'Dimensions — week %1, variety %2, grade %3, size %4, grower %5, pool type %6', Comment = '%1 = Pool Week, %2 = Variety, %3 = Grade, %4 = Size, %5 = Grower, %6 = Grower Pool Type';
    VerdictOkTxt: Label 'This order meets every condition and will pool when it is finished.';
    VerdictPooledTxt: Label 'This order has already pooled. Its kilos are in the pool ledger; finishing it again writes nothing (by design).';
    VerdictBlockedTxt: Label 'This order will NOT pool. %1', Comment = '%1 = the reason and what to do';
    YesTxt: Label 'Yes';
    NoTxt: Label 'No';
    // Blockers, each naming the fix rather than just the symptom.
    NotFinishedFix: Label 'Pooling runs when the order is FINISHED, not when output is posted. Finish the order.';
    NoPrefixFix: Label 'The Packed Item No. Prefix is not set on Pool Payment Setup, so no production order pools at all. Set it to the number prefix of the packed items, for example PKD.';
    NoOutputAtAllFix: Label 'No posted output entries were found for this order. A packing run is identified by output of an item whose number starts with %1, so post the output before finishing the order, and check that it was posted against this production order rather than through a plain item journal.', Comment = '%1 = the configured packed item prefix';
    NotPackedFix: Label 'Output was posted, but no output item''s number starts with %1, so this is not a packing run. Either this is genuinely not a packing order, or the Packed Item No. Prefix on Pool Payment Setup does not match how the packed items are numbered.', Comment = '%1 = the configured packed item prefix';
    NoDimensionSetupFix: Label 'The pool dimension codes are not all set on Pool Payment Setup. Fill in all seven.';
    NoUomSetupFix: Label 'The pool units of measure are not all set on Pool Payment Setup. Fill in all three.';
    NoUnitsFix: Label 'Packed output was found but resolved to zero tray equivalents. Check the output item''s unit of measure conversions.';
    NoBinsFix: Label 'No consumption was found for an item whose Base Unit of Measure is %1. Either consumption has not been posted, or the bin item''s base unit of measure is not %1 — an order that consumes no bins is treated as a repack and never pools.', Comment = '%1 = the configured Bin UoM code';
    NoWeekDimFix: Label 'The pool week dimension is blank on this order, so there is no Pool Group to pool into. Set it on the order''s dimensions.';
    NoWeekFix: Label 'Pool week %1 is not loaded in the Pool Week table (Sheet 3.1). Load it before pooling into that week.', Comment = '%1 = Pool Week Code';
    NoGrowerDimFix: Label 'The grower dimension is blank on this order. The pool entry would have no grower and the group could never be closed.';
    NoGrowerVendorFix: Label 'Grower %1 has no vendor carrying that grower dimension value, so the close could not pay them. Set the grower dimension on the grower''s vendor card.', Comment = '%1 = Grower Code';
    /// <summary>Run the checks and show the report.</summary>
    procedure ShowExplanation(ProductionOrderNo: Code[20])
    begin
        Message(Explain(ProductionOrderNo));
    end;
    /// <summary>Run the checks and return the report as text.</summary>
    procedure Explain(ProductionOrderNo: Code[20]): Text var
        ProductionOrder: Record "Production Order";
        Builder: TextBuilder;
        Blocker: Text;
        AlreadyPooled: Boolean;
    begin
        Builder.AppendLine(StrSubstNo(HeadingTxt, ProductionOrderNo));
        Builder.AppendLine('');
        if not FindOrder(ProductionOrderNo, ProductionOrder)then begin
            Builder.AppendLine(StrSubstNo(NoOrderTxt, ProductionOrderNo));
            exit(Builder.ToText());
        end;
        Blocker:=AppendChecks(Builder, ProductionOrder, AlreadyPooled);
        Builder.AppendLine('');
        case true of AlreadyPooled: Builder.AppendLine(VerdictPooledTxt);
        Blocker <> '': Builder.AppendLine(StrSubstNo(VerdictBlockedTxt, Blocker));
        else
            Builder.AppendLine(VerdictOkTxt);
        end;
        exit(Builder.ToText());
    end;
    local procedure AppendChecks(var Builder: TextBuilder; var ProductionOrder: Record "Production Order"; var AlreadyPooled: Boolean)Blocker: Text var
        ProdOrderPost: Codeunit "TAC Pool Prod Order Post";
        Prefix: Code[20];
        PackedItemNo: Code[20];
        IsPacking: Boolean;
        DimensionsReady: Boolean;
        UomReady: Boolean;
        OutputCount: Integer;
    begin
        Builder.AppendLine(StrSubstNo(StatusTxt, Format(ProductionOrder.Status)));
        // Mirrors the Run Close gate order in 50271: already-pooled first,
        // because a re-finished order is a no-op to explain rather than a fault
        // to diagnose, and the question is answerable without any setup at all.
        AlreadyPooled:=ProdOrderPost.AlreadyPooled(ProductionOrder."No.");
        Builder.AppendLine(StrSubstNo(AlreadyPooledTxt, YesNo(AlreadyPooled)));
        if AlreadyPooled then exit('');
        // The prefix gate fails closed when unset, so an unconfigured system
        // looks exactly like "this is not a packing order". Separate the two.
        Prefix:=ProdOrderPost.PackedItemPrefix();
        if Prefix = '' then begin
            Builder.AppendLine(PrefixNotSetTxt);
            exit(NoPrefixFix);
        end;
        // "Not a packing order" is now answered from the output items, so the
        // two ways of failing it are worth separating: nothing posted at all,
        // versus output posted for items that are not packed items.
        OutputCount:=ProdOrderPost.CountOutputEntries(ProductionOrder."No.");
        Builder.AppendLine(StrSubstNo(OutputEntriesTxt, OutputCount));
        if OutputCount = 0 then exit(StrSubstNo(NoOutputAtAllFix, Prefix));
        Builder.AppendLine(StrSubstNo(OutputItemsTxt, ProdOrderPost.OutputItemList(ProductionOrder."No.")));
        IsPacking:=ProdOrderPost.HasPackedOutput(ProductionOrder."No.", PackedItemNo);
        Builder.AppendLine(StrSubstNo(PackedOutputTxt, Prefix, YesNo(IsPacking)));
        if not IsPacking then exit(StrSubstNo(NotPackedFix, Prefix));
        // Setup is reported before the quantities, because the quantities are
        // meaningless (and would error) without it.
        DimensionsReady:=DimensionSetupComplete();
        UomReady:=ProdOrderPost.UomSetupComplete();
        Builder.AppendLine(StrSubstNo(DimensionSetupTxt, YesNo(DimensionsReady)));
        Builder.AppendLine(StrSubstNo(UomSetupTxt, YesNo(UomReady)));
        if not UomReady then exit(NoUomSetupFix);
        if not DimensionsReady then exit(NoDimensionSetupFix);
        Blocker:=AppendQuantities(Builder, ProductionOrder."No.");
        if Blocker <> '' then exit(Blocker);
        Blocker:=AppendDimensions(Builder, ProductionOrder);
        if Blocker <> '' then exit(Blocker);
        // Everything a finished order needs is present; the remaining question
        // is whether it has actually been finished yet.
        if ProductionOrder.Status <> ProductionOrder.Status::Finished then exit(NotFinishedFix);
        exit('');
    end;
    local procedure AppendQuantities(var Builder: TextBuilder; ProductionOrderNo: Code[20])Blocker: Text var
        ProdOrderPost: Codeunit "TAC Pool Prod Order Post";
        OutputItemNo: Code[20];
        Kgs: Decimal;
        Units: Decimal;
        Bins: Decimal;
    begin
        // The output-entry checks already ran in AppendChecks — reaching here
        // means the order has packed output and the setup to measure it.
        ProdOrderPost.CalcPackedQuantities(ProductionOrderNo, Kgs, Units, Bins, OutputItemNo);
        Builder.AppendLine(StrSubstNo(OutputItemTxt, OutputItemNo));
        Builder.AppendLine(StrSubstNo(UnitsTxt, Units));
        Builder.AppendLine(StrSubstNo(KgsTxt, Kgs));
        Builder.AppendLine(StrSubstNo(BinsTxt, Bins));
        if Units <= 0 then exit(NoUnitsFix);
        if Bins <= 0 then exit(StrSubstNo(NoBinsFix, ProdOrderPost.BinUoMCode()));
        exit('');
    end;
    local procedure AppendDimensions(var Builder: TextBuilder; var ProductionOrder: Record "Production Order")Blocker: Text var
        PoolWeek: Record "TAC Pool Week";
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
        //SeasonCode: Code[20];
        //PoolWeekCode: Code[20];
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        GrowerCode: Code[20];
        VendorNo: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
    begin
        DimensionMgt.ResolveFromProductionOrder(ProductionOrder, //SeasonCode, PoolWeekCode, 
 VarietyCode, GradeCode, SizeCode, GrowerCode, GrowerPoolType);
        Builder.AppendLine(StrSubstNo(DimensionsTxt, //Blank(PoolWeekCode), 
 Blank(VarietyCode), Blank(GradeCode), Blank(SizeCode), Blank(GrowerCode), Format(GrowerPoolType)));
        //if PoolWeekCode = '' then
        //exit(NoWeekDimFix);
        //if not PoolWeek.Get(CopyStr(PoolWeekCode, 1, 10)) then
        //exit(StrSubstNo(NoWeekFix, PoolWeekCode));
        if GrowerCode = '' then exit(NoGrowerDimFix);
        if not GrowerMgt.FindVendorNoForGrower(GrowerCode, VendorNo)then exit(StrSubstNo(NoGrowerVendorFix, GrowerCode));
        exit('');
    end;
    local procedure FindOrder(ProductionOrderNo: Code[20]; var ProductionOrder: Record "Production Order"): Boolean begin
        // The Production Order PK is (Status, No.), so the order is found by
        // number across whatever status it currently sits at.
        ProductionOrder.Reset();
        ProductionOrder.SetRange("No.", ProductionOrderNo);
        exit(ProductionOrder.FindFirst());
    end;
    local procedure DimensionSetupComplete(): Boolean var
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    begin
        exit(DimensionMgt.DimensionSetupComplete());
    end;
    local procedure YesNo(Value: Boolean): Text begin
        if Value then exit(YesTxt);
        exit(NoTxt);
    end;
    local procedure Blank(Value: Code[20]): Text begin
        if Value = '' then exit('(blank)');
        exit(Value);
    end;
}
