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
