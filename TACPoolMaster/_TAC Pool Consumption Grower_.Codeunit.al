codeunit 50285 "TAC Pool Consumption Grower"
{
    // Consumption is posted before packed output. The posted consumption ILE
    // is applied to the inbound purchase ILE for the selected lot, which gives
    // us the authoritative receipt vendor and therefore the Grower dimension.
    var MixedGrowerErr: Label 'Production order %1 consumes lots from more than one grower (%2 and %3). A production order can carry only one Grower Code dimension.', Comment = '%1 = Production Order No., %2 = first Grower Code, %3 = second Grower Code';
    procedure UpdateProductionOrderFromConsumption(ItemLedgerEntry: Record "Item Ledger Entry")
    var
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        GrowerCode: Code[20];
    begin
        if not DimensionMgt.DimensionSetupComplete()then exit;
        if ItemLedgerEntry."Entry Type" <> ItemLedgerEntry."Entry Type"::Consumption then exit;
        if ItemLedgerEntry."Order Type" <> ItemLedgerEntry."Order Type"::Production then exit;
        if(ItemLedgerEntry."Order No." = '') or (ItemLedgerEntry."Lot No." = '')then exit;
        if not IsPoolProductionOrder(ItemLedgerEntry."Order No.", DimensionMgt)then exit;
        if not FindReceiptGrower(ItemLedgerEntry, GrowerCode)then exit;
        GrowerCode:=FindProductionOrderGrower(ItemLedgerEntry."Order No.", GrowerCode);
        ApplyGrowerDimension(ItemLedgerEntry."Order No.", GrowerCode, DimensionMgt.GrowerDimensionCode());
    end;
    local procedure IsPoolProductionOrder(ProductionOrderNo: Code[20]; var DimensionMgt: Codeunit "TAC Pool Dimension Mgt"): Boolean var
        ProductionOrder: Record "Production Order";
        ProductionOrderLine: Record "Prod. Order Line";
    begin
        ProductionOrder.SetRange("No.", ProductionOrderNo);
        if not ProductionOrder.FindFirst()then exit(false);
        if DimensionMgt.HasPoolDimensions(ProductionOrder."Dimension Set ID")then exit(true);
        ProductionOrderLine.SetRange(Status, ProductionOrder.Status);
        ProductionOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProductionOrderLine.FindSet()then repeat if DimensionMgt.HasPoolDimensions(ProductionOrderLine."Dimension Set ID")then exit(true);
            until ProductionOrderLine.Next() = 0;
        exit(false);
    end;
    local procedure FindProductionOrderGrower(ProductionOrderNo: Code[20]; CurrentGrowerCode: Code[20])GrowerCode: Code[20]var
        ConsumptionItemLedgerEntry: Record "Item Ledger Entry";
        ConsumedGrowerCode: Code[20];
    begin
        GrowerCode:=CurrentGrowerCode;
        ConsumptionItemLedgerEntry.SetRange("Entry Type", ConsumptionItemLedgerEntry."Entry Type"::Consumption);
        ConsumptionItemLedgerEntry.SetRange("Order Type", ConsumptionItemLedgerEntry."Order Type"::Production);
        ConsumptionItemLedgerEntry.SetRange("Order No.", ProductionOrderNo);
        ConsumptionItemLedgerEntry.SetFilter("Lot No.", '<>%1', '');
        if ConsumptionItemLedgerEntry.FindSet()then repeat if FindReceiptGrower(ConsumptionItemLedgerEntry, ConsumedGrowerCode)then if ConsumedGrowerCode <> GrowerCode then Error(MixedGrowerErr, ProductionOrderNo, GrowerCode, ConsumedGrowerCode);
            until ConsumptionItemLedgerEntry.Next() = 0;
    end;
    local procedure FindReceiptGrower(ConsumptionItemLedgerEntry: Record "Item Ledger Entry"; var GrowerCode: Code[20]): Boolean var
        ItemApplicationEntry: Record "Item Application Entry";
        ReceiptItemLedgerEntry: Record "Item Ledger Entry";
    begin
        GrowerCode:='';
        ItemApplicationEntry.SetCurrentKey("Outbound Item Entry No.", "Item Ledger Entry No.", "Cost Application");
        ItemApplicationEntry.SetRange("Outbound Item Entry No.", ConsumptionItemLedgerEntry."Entry No.");
        ItemApplicationEntry.SetRange("Item Ledger Entry No.", ConsumptionItemLedgerEntry."Entry No.");
        ItemApplicationEntry.SetRange("Cost Application", true);
        if not ItemApplicationEntry.FindSet()then exit(false);
        repeat if ReceiptItemLedgerEntry.Get(ItemApplicationEntry."Inbound Item Entry No.")then if(ReceiptItemLedgerEntry."Entry Type" = ReceiptItemLedgerEntry."Entry Type"::Purchase) and (ReceiptItemLedgerEntry."Source Type" = ReceiptItemLedgerEntry."Source Type"::Vendor)then begin
                    GrowerCode:=GrowerCodeForVendor(ReceiptItemLedgerEntry."Source No.");
                    exit(true);
                end;
        until ItemApplicationEntry.Next() = 0;
        exit(false);
    end;
    local procedure GrowerCodeForVendor(VendorNo: Code[20]): Code[20]var
        DefaultDimension: Record "Default Dimension";
        DimensionValue: Record "Dimension Value";
        PoolSetup: Record "TAC Pool Setup";
        GrowerDimensionCode: Code[20];
        GrowerCode: Code[20];
    begin
        if not PoolSetup.Get()then Error('Pool Payment Setup must be configured before consumption can resolve a grower.');
        GrowerDimensionCode:=PoolSetup."Grower Dimension Code";
        if GrowerDimensionCode = '' then Error('Grower Dimension Code must be configured in Pool Payment Setup before consumption can resolve a grower.');
        if not DefaultDimension.Get(Database::Vendor, VendorNo, GrowerDimensionCode)then Error('Vendor %1 has no %2 default dimension. Set the Grower Code on the vendor card before consuming the received lot.', VendorNo, GrowerDimensionCode);
        GrowerCode:=DefaultDimension."Dimension Value Code";
        if(GrowerCode = '') or not DimensionValue.Get(GrowerDimensionCode, GrowerCode)then Error('Vendor %1 has an invalid %2 default dimension value.', VendorNo, GrowerDimensionCode);
        exit(GrowerCode);
    end;
    local procedure ApplyGrowerDimension(ProductionOrderNo: Code[20]; GrowerCode: Code[20]; GrowerDimensionCode: Code[20])
    var
        ProductionOrder: Record "Production Order";
        ProductionOrderLine: Record "Prod. Order Line";
    begin
        ProductionOrder.SetRange("No.", ProductionOrderNo);
        if not ProductionOrder.FindFirst()then exit;
        UpdateProductionOrderDimension(ProductionOrder, GrowerCode, GrowerDimensionCode);
        ProductionOrderLine.SetRange(Status, ProductionOrder.Status);
        ProductionOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProductionOrderLine.FindSet()then repeat UpdateProductionOrderLineDimension(ProductionOrderLine, GrowerCode, GrowerDimensionCode);
            until ProductionOrderLine.Next() = 0;
    end;
    local procedure UpdateProductionOrderDimension(var ProductionOrder: Record "Production Order"; GrowerCode: Code[20]; GrowerDimensionCode: Code[20])
    var
        NewDimensionSetID: Integer;
    begin
        NewDimensionSetID:=DimensionSetWithGrower(ProductionOrder."Dimension Set ID", GrowerDimensionCode, GrowerCode);
        if ProductionOrder."Dimension Set ID" = NewDimensionSetID then exit;
        ProductionOrder.Validate("Dimension Set ID", NewDimensionSetID);
        ProductionOrder.Modify(true);
    end;
    local procedure UpdateProductionOrderLineDimension(var ProductionOrderLine: Record "Prod. Order Line"; GrowerCode: Code[20]; GrowerDimensionCode: Code[20])
    var
        NewDimensionSetID: Integer;
    begin
        NewDimensionSetID:=DimensionSetWithGrower(ProductionOrderLine."Dimension Set ID", GrowerDimensionCode, GrowerCode);
        if ProductionOrderLine."Dimension Set ID" = NewDimensionSetID then exit;
        ProductionOrderLine.Validate("Dimension Set ID", NewDimensionSetID);
        ProductionOrderLine.Modify(true);
    end;
    local procedure DimensionSetWithGrower(OldDimensionSetID: Integer; GrowerDimensionCode: Code[20]; GrowerCode: Code[20])NewDimensionSetID: Integer var
        DimensionManagement: Codeunit DimensionManagement;
        DimensionValue: Record "Dimension Value";
        TempDimensionSetEntry: Record "Dimension Set Entry" temporary;
    begin
        DimensionValue.Get(GrowerDimensionCode, GrowerCode);
        DimensionManagement.GetDimensionSet(TempDimensionSetEntry, OldDimensionSetID);
        TempDimensionSetEntry.SetRange("Dimension Code", GrowerDimensionCode);
        if TempDimensionSetEntry.FindFirst()then begin
            TempDimensionSetEntry."Dimension Value Code":=GrowerCode;
            TempDimensionSetEntry."Dimension Value ID":=DimensionValue."Dimension Value ID";
            TempDimensionSetEntry.Modify();
        end
        else
        begin
            TempDimensionSetEntry.Init();
            TempDimensionSetEntry."Dimension Set ID":=OldDimensionSetID;
            TempDimensionSetEntry."Dimension Code":=GrowerDimensionCode;
            TempDimensionSetEntry."Dimension Value Code":=GrowerCode;
            TempDimensionSetEntry."Dimension Value ID":=DimensionValue."Dimension Value ID";
            TempDimensionSetEntry.Insert();
        end;
        TempDimensionSetEntry.Reset();
        NewDimensionSetID:=DimensionManagement.GetDimensionSetID(TempDimensionSetEntry);
    end;
}
