codeunit 58800 "SAL Plan Model Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        AssertFailedErr: Label 'Assertion failed: %1', Comment = '%1 = message';

    [Test]
    procedure PlanSourceLineNoAutoIncrements()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        // [GIVEN] a plan header
        CreatePlan(PlanHeader);

        // [WHEN] two sources are inserted without an explicit line no.
        PlanSource.Init();
        PlanSource."Plan No." := PlanHeader."No.";
        PlanSource."Source Document No." := 'SO0001';
        PlanSource.Insert(true);

        PlanSource.Init();
        PlanSource."Plan No." := PlanHeader."No.";
        PlanSource."Source Document No." := 'SO0002';
        PlanSource.Insert(true);

        // [THEN] line numbers increment by 10000
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.FindSet();
        AssertThat(PlanSource."Line No." = 10000, 'expected first source line no. to be 10000');
        PlanSource.Next();
        AssertThat(PlanSource."Line No." = 20000, 'expected second source line no. to be 20000');
    end;

    [Test]
    procedure PlanPalletNoAutoIncrements()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
    begin
        // [GIVEN] a plan header
        CreatePlan(PlanHeader);

        // [WHEN] two pallets are inserted without an explicit pallet no.
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet.Insert(true);

        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet.Insert(true);

        // [THEN] pallet numbers increment by 1
        PlanPallet.SetRange("Plan No.", PlanHeader."No.");
        PlanPallet.FindSet();
        AssertThat(PlanPallet."Pallet No." = 1, 'expected first pallet no. to be 1');
        PlanPallet.Next();
        AssertThat(PlanPallet."Pallet No." = 2, 'expected second pallet no. to be 2');
    end;

    [Test]
    procedure PlanComponentRejectsUnknownSourceLine()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanComponent: Record "SAL Plan Component";
    begin
        // [GIVEN] a plan with one pallet and no source lines
        CreatePlan(PlanHeader);
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet.Insert(true);

        // [WHEN] a component references a source line that does not exist
        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent."Source Line No." := 99999;

        // [THEN] the insert fails
        AssertThat(not TryInsertComponent(PlanComponent), 'expected insert to fail for an unknown source line');
    end;

    [Test]
    procedure PlanComponentQuantitiesRollUpToPallet()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanComponent: Record "SAL Plan Component";
    begin
        // [GIVEN] a plan with one pallet and two components
        CreatePlan(PlanHeader);
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet.Insert(true);

        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent.Quantity := 5;
        PlanComponent.Insert(true);

        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent.Quantity := 7;
        PlanComponent.Insert(true);

        // [WHEN] the component quantities are summed for the pallet
        PlanComponent.SetRange("Plan No.", PlanHeader."No.");
        PlanComponent.SetRange("Pallet No.", PlanPallet."Pallet No.");
        PlanComponent.CalcSums(Quantity);

        // [THEN] the total matches the sum of both components
        AssertThat(PlanComponent.Quantity = 12, 'expected total quantity of 12');
    end;

    local procedure CreatePlan(var PlanHeader: Record "SAL Plan Header")
    begin
        PlanHeader.Init();
        PlanHeader."No." := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(PlanHeader."No."));
        PlanHeader.Insert(true);
    end;

    [TryFunction]
    local procedure TryInsertComponent(var PlanComponent: Record "SAL Plan Component")
    begin
        PlanComponent.Insert(true);
    end;

    local procedure AssertThat(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(AssertFailedErr, Message);
    end;
}
