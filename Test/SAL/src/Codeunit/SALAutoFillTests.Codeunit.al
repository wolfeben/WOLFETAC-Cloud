codeunit 58802 "SAL Auto Fill Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure AutoFillCreatesFullAndCustomShortPalletsWithoutRepeating()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateRule('TRAY', '', '', '', 160);
        CreateSource(Plan, 10000, 'ITEM-A', 322, 'TRAY', Source);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 3) and (Skipped = 0), 'two standard pallets and one custom short pallet expected');
        Pallet.Get(Plan."No.", Plan."Version No.", 3);
        Pallet.CalcFields("Planned Quantity", "No. of Components");
        AssertThat(Pallet."Pallet Type" = Pallet."Pallet Type"::Custom, 'short balance must be Custom');
        AssertThat((Pallet."Target Quantity" = 2) and (Pallet."Planned Quantity" = 2), 'short pallet target must match the two remaining units');
        Source.CalcFields("Exact Planned Quantity");
        AssertThat(Source."Exact Planned Quantity" = 322, 'all exact demand must be allocated');

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);
        AssertThat((Created = 0) and (Skipped = 0), 'repeating auto-fill must not duplicate existing allocation');
    end;

    [Test]
    procedure MixedShortBalancesKeepSeparateComponentsOnOnePallet()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Component: Record "SAL Plan Component";
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateRule('MIX-TEST', '', '', '', 160);
        CreateSource(Plan, 10000, 'ITEM-A', 100, 'MIX-TEST', Source);
        CreateSource(Plan, 20000, 'ITEM-B', 60, 'MIX-TEST', Source);

        Allocation.AutoFillPallets(Plan, true, Created, Updated, Skipped);

        AssertThat((Created = 1) and (Skipped = 0), 'one mixed pallet expected');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        Pallet.CalcFields("Planned Quantity", "No. of Components");
        AssertThat(Pallet."Pallet Type" = Pallet."Pallet Type"::Mixed, 'pallet must be Mixed');
        AssertThat((Pallet."Target Quantity" = 160) and (Pallet."Planned Quantity" = 160), 'mixed pallet must total 160');
        AssertThat(Pallet."No. of Components" = 2, 'mixed pallet must retain two exact product components');
        Component.SetRange("Plan No.", Plan."No.");
        Component.SetRange("Version No.", Plan."Version No.");
        Component.SetRange("Pallet No.", 1);
        AssertThat(Component.Count() = 2, 'two component rows expected');
    end;

    [Test]
    procedure CustomerShipToOverrideBeatsGeneralRuleAndUnknownUnitIsSkipped()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateRule('WA-TEST', '', '', '', 160);
        CreateRule('WA-TEST', 'WOOLIES', 'WA', '', 152);
        CreateSource(Plan, 10000, 'ITEM-A', 304, 'WA-TEST', Source);
        Source."Customer No." := 'WOOLIES';
        Source."Destination Code" := 'WA';
        Source.Modify(true);
        CreateSource(Plan, 20000, 'ITEM-B', 1, 'BKBN', Source);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 1), 'two WA pallets and one skipped unknown line expected');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Target Quantity" = 152, 'customer and destination rule must override general quantity');
    end;

    [Test]
    procedure SetupProvidesStandardPackedAndBulkFallbacks()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreateSetupDefaults('TE', 160, 'BK', 96);
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-PACKED', 160, 'TE', Source);
        CreateSource(Plan, 20000, 'ITEM-BULK', 96, 'BK', Source);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 0), 'setup defaults must allocate packed and bulk demand');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Target Quantity" = 160, 'packed fallback must use 160');
        Pallet.Get(Plan."No.", Plan."Version No.", 2);
        AssertThat(Pallet."Target Quantity" = 96, 'bulk fallback must use 96');
    end;

    [Test]
    procedure CustomerRuleSnapshotsTemplateAndMixedPolicy()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Rule: Record "SAL Template Rule";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePalletTemplate('WA-152', 'CHEP', 'TE', 152, Enum::"SAL Mixed Pallet Policy"::NotAllowed);
        CreateCustomer('WOOLIES-RULE', '', 0, Customer);
        CreateRule('TE', Customer."No.", 'WA', '', 152);
        Rule.SetRange("Customer No.", Customer."No.");
        Rule.SetRange("Ship-to Code", 'WA');
        Rule.FindFirst();
        Rule.Validate("Pallet Template Code", 'WA-152');
        Rule.Modify(true);
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-A', 152, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source."Destination Code" := 'WA';
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, true, Created, Updated, Skipped);

        AssertThat((Created = 1) and (Skipped = 0), 'the customer rule must create one 152-unit pallet');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Pallet Template Code" = 'WA-152', 'rule template must be snapshotted');
        AssertThat(Pallet."Physical Pallet Type" = 'CHEP', 'rule physical pallet type must be snapshotted');
        AssertThat(Pallet."Mixed Pallet Policy" = Pallet."Mixed Pallet Policy"::NotAllowed, 'rule mixed policy must be snapshotted');
    end;

    [Test]
    procedure ExplicitOrderOverrideBeatsCustomerAndGlobalRules()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreateSetupDefaults('TE', 160, 'BK', 96);
        CreateCustomer('OVERRIDE-CUST', 'TE', 152, Customer);
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-OVERRIDE', 168, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source."Pallet Quantity Override" := 84;
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 0), 'the explicit order override must create two pallets');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Target Quantity" = 84, 'explicit order override must beat customer and global quantities');
    end;

    [Test]
    procedure CustomerPackedAndBulkDefaultsBeatGlobalFallbacks()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreateSetupDefaults('TE', 160, 'BK', 96);
        CreateCustomer('DUAL-DEFAULTS', '', 0, Customer);
        Customer."SAL Default Packed Qty." := 152;
        Customer."SAL Default Bulk Qty." := 88;
        Customer.Modify(true);
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-PACKED-CUST', 152, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);
        CreateSource(Plan, 20000, 'ITEM-BULK-CUST', 88, 'BK', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 0), 'customer packed and bulk defaults must allocate both lines');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Target Quantity" = 152, 'customer packed default must beat 160');
        Pallet.Get(Plan."No.", Plan."Version No.", 2);
        AssertThat(Pallet."Target Quantity" = 88, 'customer bulk default must beat 96');
    end;

    [Test]
    procedure CustomerCardCapacityOverridesGenericRuleForMatchingUnit()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateRule('TE', '', '', '', 160);
        CreateCustomer('WOOLIES-CARD', 'TE', 152, Customer);
        CreateSource(Plan, 10000, 'ITEM-A', 304, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 0), 'two customer-card pallets expected');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Target Quantity" = 152, 'customer-card quantity must override the generic rule');
    end;

    [Test]
    procedure DetailedCustomerRuleOverridesCustomerCardCapacity()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateCustomer('CUSTOMER-RULE', 'TE', 152, Customer);
        CreateRule('TE', Customer."No.", 'SPECIAL', 'ITEM-A', 84);
        CreateSource(Plan, 10000, 'ITEM-A', 168, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source."Destination Code" := 'SPECIAL';
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 0), 'two detailed-rule pallets expected');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Target Quantity" = 84, 'detailed customer rule must override Customer Card capacity');
    end;

    [Test]
    procedure CustomerCardCapacityDoesNotCrossUnits()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateCustomer('CUSTOMER-UOM', 'TE', 152, Customer);
        CreateSource(Plan, 10000, 'ITEM-A', 96, 'BK', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 0) and (Skipped = 1), 'a TE customer default must not allocate BK demand');
    end;

    [Test]
    procedure CustomerCardCapacityDoesNotReplaceExactBKBNRule()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateCustomer('CUSTOMER-BKBN', 'BKBN', 20, Customer);
        CreateSource(Plan, 10000, 'PKD-BKBN-TEST', 20, 'BKBN', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        AssertThat((Created = 0) and (Skipped = 1), 'BKBN must retain its exact-item rule requirement');
    end;

    [Test]
    procedure CustomerPalletTemplateIsSnapshottedAndBlocksMixedPallets()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Customer: Record Customer;
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePalletTemplate('WOOLIES-152', 'CHEP', 'TE', 152, Enum::"SAL Mixed Pallet Policy"::NotAllowed);
        CreateTemplateCustomer('WOOLIES-TEMPLATE', 'WOOLIES-152', Customer);
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-A', 80, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);
        CreateSource(Plan, 20000, 'ITEM-B', 72, 'TE', Source);
        Source."Customer No." := Customer."No.";
        Source.Modify(true);

        Allocation.AutoFillPallets(Plan, true, Created, Updated, Skipped);

        AssertThat((Created = 2) and (Skipped = 0), 'customer policy must prevent one mixed pallet');
        Pallet.Get(Plan."No.", Plan."Version No.", 1);
        AssertThat(Pallet."Pallet Template Code" = 'WOOLIES-152', 'template code must be copied onto the plan pallet');
        AssertThat(Pallet."Physical Pallet Type" = 'CHEP', 'physical pallet type must be copied onto the plan pallet');
        AssertThat(Pallet."Mixed Pallet Policy" = Pallet."Mixed Pallet Policy"::NotAllowed, 'mixed policy must be copied onto the plan pallet');
    end;

    [Test]
    procedure ExistingMixedPalletFillsRemainingOrderLinesWithoutAnyRule()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-A', 2, 'TE', Source);
        CreateSource(Plan, 20000, 'ITEM-B', 1, 'TE', Source);
        CreateSource(Plan, 30000, 'ITEM-C', 2, 'TE', Source);
        CreateSource(Plan, 40000, 'ITEM-D', 3, 'TE', Source);
        CreateSource(Plan, 50000, 'ITEM-E', 2, 'TE', Source);
        Pallet.Init();
        Pallet."Plan No." := Plan."No.";
        Pallet."Version No." := Plan."Version No.";
        Pallet."Pallet Type" := Pallet."Pallet Type"::Mixed;
        Pallet."Target Quantity" := 20;
        Pallet.Insert(true);
        AddExistingComponent(Plan, Pallet, 10000, 2);
        AddExistingComponent(Plan, Pallet, 20000, 1);
        AddExistingComponent(Plan, Pallet, 30000, 2);
        AddExistingComponent(Plan, Pallet, 40000, 3);

        Allocation.AutoFillPallets(Plan, false, Created, Updated, Skipped);

        Pallet.Get(Plan."No.", Plan."Version No.", Pallet."Pallet No.");
        Pallet.CalcFields("Planned Quantity", "No. of Components");
        AssertThat((Created = 0) and (Updated = 1) and (Skipped = 0), 'existing mixed pallet should fill without any rule');
        AssertThat((Pallet."Target Quantity" = 10) and (Pallet."Planned Quantity" = 10), 'target should match all ten ordered units');
        AssertThat(Pallet."No. of Components" = 5, 'each exact size should remain a separate component');
    end;

    [Test]
    procedure BlankPalletFillsAllCompatibleSizesWhenMixedExplicitlyAllowed()
    var
        Allocation: Codeunit "SAL Allocation Management";
        Plan: Record "SAL Plan Header";
        Pallet: Record "SAL Plan Pallet";
        Source: Record "SAL Plan Source";
        Created: Integer;
        Updated: Integer;
        Skipped: Integer;
    begin
        CreatePlan(Plan);
        CreateSource(Plan, 10000, 'ITEM-A', 2, 'TE', Source);
        CreateSource(Plan, 20000, 'ITEM-B', 1, 'TE', Source);
        CreateSource(Plan, 30000, 'ITEM-C', 2, 'TE', Source);
        CreateSource(Plan, 40000, 'ITEM-D', 3, 'TE', Source);
        CreateSource(Plan, 50000, 'ITEM-E', 2, 'TE', Source);
        Pallet.Init();
        Pallet."Plan No." := Plan."No.";
        Pallet."Version No." := Plan."Version No.";
        Pallet."Pallet Type" := Pallet."Pallet Type"::Standard;
        Pallet."Target Quantity" := 160;
        Pallet.Insert(true);

        Allocation.AutoFillPallets(Plan, true, Created, Updated, Skipped);

        Pallet.Get(Plan."No.", Plan."Version No.", Pallet."Pallet No.");
        Pallet.CalcFields("Planned Quantity", "No. of Components");
        AssertThat((Created = 0) and (Updated = 1) and (Skipped = 0), 'one blank pallet should fill without pallet rules');
        AssertThat(Pallet."Pallet Type" = Pallet."Pallet Type"::Mixed, 'multiple sizes require a Mixed pallet');
        AssertThat((Pallet."Target Quantity" = 10) and (Pallet."Planned Quantity" = 10), 'target must equal ten ordered TE units');
        AssertThat(Pallet."No. of Components" = 5, 'all five sizes should be separate components');
    end;

    local procedure AddExistingComponent(Plan: Record "SAL Plan Header"; Pallet: Record "SAL Plan Pallet"; SourceLineNo: Integer; Quantity: Decimal)
    var
        Component: Record "SAL Plan Component";
    begin
        Component.Init();
        Component."Plan No." := Plan."No.";
        Component."Version No." := Plan."Version No.";
        Component."Pallet No." := Pallet."Pallet No.";
        Component.Validate("Source Line No.", SourceLineNo);
        Component.Validate(Quantity, Quantity);
        Component.Insert(true);
    end;

    local procedure CreatePlan(var Plan: Record "SAL Plan Header")
    begin
        Plan.Init();
        Plan."No." := CopyStr('SAL' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Plan.Insert(true);
    end;

    local procedure CreateRule(Uom: Code[10]; CustomerNo: Code[20]; ShipToCode: Code[20]; ItemNo: Code[20]; Capacity: Decimal)
    var
        Rule: Record "SAL Template Rule";
    begin
        Rule.Init();
        Rule.Code := CopyStr('R' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Rule.Active := true;
        Rule."Unit of Measure Code" := Uom;
        Rule."Customer No." := CustomerNo;
        Rule."Ship-to Code" := ShipToCode;
        Rule."Item No." := ItemNo;
        Rule."Units per Pallet" := Capacity;
        Rule.Insert(true);
    end;

    local procedure CreateCustomer(CustomerNo: Code[20]; Uom: Code[10]; Capacity: Decimal; var Customer: Record Customer)
    begin
        if Customer.Get(CustomerNo) then
            Customer.Delete(true);
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Name := CustomerNo;
        Customer."SAL Pallet Quantity UOM" := Uom;
        Customer."SAL Units per Pallet" := Capacity;
        Customer.Insert(true);
    end;

    local procedure CreateSetupDefaults(PackedUom: Code[10]; PackedQuantity: Decimal; BulkUom: Code[10]; BulkQuantity: Decimal)
    var
        Setup: Record "SAL Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Setup.Insert(true);
        end;
        Setup."Default Packed UOM" := PackedUom;
        Setup."Default Packed Qty. per Pallet" := PackedQuantity;
        Setup."Default Bulk UOM" := BulkUom;
        Setup."Default Bulk Qty. per Pallet" := BulkQuantity;
        Setup.Modify(true);
    end;

    local procedure CreatePalletTemplate(TemplateCode: Code[20]; PhysicalPalletType: Code[20]; Uom: Code[10]; Capacity: Decimal; MixedPolicy: Enum "SAL Mixed Pallet Policy")
    var
        PalletTemplate: Record "SAL Pallet Template";
    begin
        if PalletTemplate.Get(TemplateCode) then
            PalletTemplate.Delete(true);
        PalletTemplate.Init();
        PalletTemplate.Code := TemplateCode;
        PalletTemplate.Description := TemplateCode;
        PalletTemplate."Physical Pallet Type" := PhysicalPalletType;
        PalletTemplate."Unit of Measure Code" := Uom;
        PalletTemplate."Units per Pallet" := Capacity;
        PalletTemplate."Mixed Pallet Policy" := MixedPolicy;
        PalletTemplate.Active := true;
        PalletTemplate.Insert(true);
    end;

    local procedure CreateTemplateCustomer(CustomerNo: Code[20]; TemplateCode: Code[20]; var Customer: Record Customer)
    begin
        if Customer.Get(CustomerNo) then
            Customer.Delete(true);
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Name := CustomerNo;
        Customer.Insert(true);
        Customer.Validate("SAL Pallet Template Code", TemplateCode);
        Customer.Modify(true);
    end;

    local procedure CreateSource(Plan: Record "SAL Plan Header"; LineNo: Integer; ItemNo: Code[20]; Quantity: Decimal; Uom: Code[10]; var Source: Record "SAL Plan Source")
    var
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
    begin
        if not Item.Get(ItemNo) then begin
            Item.Init();
            Item."No." := ItemNo;
            Item.Description := ItemNo;
            Item.Insert(false);
        end;
        if not ItemUnit.Get(ItemNo, Uom) then begin
            ItemUnit.Init();
            ItemUnit."Item No." := ItemNo;
            ItemUnit.Code := Uom;
            ItemUnit."Qty. per Unit of Measure" := 1;
            ItemUnit.Insert(false);
        end;
        Source.Init();
        Source."Plan No." := Plan."No.";
        Source."Version No." := Plan."Version No.";
        Source."Line No." := LineNo;
        Source."Source Type" := Source."Source Type"::SalesOrder;
        Source."Source Document No." := Plan."No.";
        Source."Source Document Line No." := LineNo;
        Source."Item No." := ItemNo;
        Source."Item Description" := ItemNo;
        Source."Unit of Measure Code" := Uom;
        Source.Quantity := Quantity;
        Source.Insert(true);
    end;

    local procedure AssertThat(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error('Assertion failed: %1', Message);
    end;
}
