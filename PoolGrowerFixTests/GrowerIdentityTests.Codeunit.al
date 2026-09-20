codeunit 59980 "Pool Grower Identity Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Function;

    [Test]
    procedure ExistingFiveGrowersMapExactly()
    begin
        CheckMapping('GRW-100', '100');
        CheckMapping('GRW-102', '102');
        CheckMapping('GRW-030', '030');
        CheckMapping('GRW-064', '064');
        CheckMapping('GRW-049', '049');
    end;

    [Test]
    procedure ExistingOrder1221UsesGrower030()
    var
        ProductionOrder: Record "Production Order";
        ProductionLine: Record "Prod. Order Line";
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        VarietyCode: Code[20];
        GradeCode: Code[20];
        SizeCode: Code[20];
        GrowerCode: Code[20];
        PoolType: Enum "TAC Grower Pool Type";
        LineCount: Integer;
    begin
        ProductionOrder.SetRange("No.", '1221');
        ProductionOrder.FindLast();
        ProductionOrder.CalcFields("Grower ID");
        AssertCode('GRW-030', ProductionOrder."Grower ID");
        ProductionLine.SetRange(Status, ProductionOrder.Status);
        ProductionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProductionLine.FindSet();
        repeat
            DimensionMgt.ValidatePoolDimensionValues(ProductionLine."Dimension Set ID");
            AssertCode('030', GrowerMgt.GrowerCodeForSourceVendor(ProductionOrder."Grower ID", ProductionLine."Dimension Set ID"));
            LineCount += 1;
        until ProductionLine.Next() = 0;
        if LineCount <> 9 then
            Error('Expected nine source lines on order 1221; found %1.', LineCount);

        // This order's header lacks the pool-type classification. Production
        // posting reads the lines. Exercise the separate header diagnostic
        // resolver with valid dimensions in memory only; never modify the order.
        ProductionOrder."Dimension Set ID" := ProductionLine."Dimension Set ID";
        DimensionMgt.ResolveFromProductionOrder(ProductionOrder, VarietyCode, GradeCode, SizeCode, GrowerCode, PoolType);
        AssertCode('030', GrowerCode);
    end;

    [Test]
    procedure ArbitraryVendorNumberPreservesZero()
    var
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
    begin
        CreateVendor('PGFIX-ACCOUNT', '000PGFIX');
        AssertCode('000PGFIX', GrowerMgt.GrowerCodeForSourceVendor('PGFIX-ACCOUNT', 0));
        AssertCode('PGFIX-ACCOUNT', GrowerMgt.VendorNoForGrower('000PGFIX'));
    end;

    [Test]
    procedure MissingVendorDimensionIsRejected()
    var
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
    begin
        CreateVendor('PGFIX-NODIM', '');
        asserterror GrowerMgt.GrowerCodeForSourceVendor('PGFIX-NODIM', 0);
        AssertErrorContains('default dimension');
    end;

    [Test]
    procedure AmbiguousVendorMappingIsRejected()
    var
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
    begin
        CreateVendor('PGFIX-DUP-A', '000PGFIX');
        CreateVendor('PGFIX-DUP-B', '000PGFIX');
        asserterror GrowerMgt.GrowerCodeForSourceVendor('PGFIX-DUP-A', 0);
        AssertErrorContains('more than one vendor');
    end;

    [Test]
    procedure ConflictingSourceGrowerIsRejected()
    var
        TempDimensionEntry: Record "Dimension Set Entry" temporary;
        DimensionValue: Record "Dimension Value";
        PoolDimensionMgt: Codeunit "TAC Pool Dimension Mgt";
        DimensionMgt: Codeunit DimensionManagement;
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
        DimensionSetID: Integer;
    begin
        DimensionValue.Get(PoolDimensionMgt.GrowerDimensionCode(), '100');
        TempDimensionEntry.Init();
        TempDimensionEntry."Dimension Code" := DimensionValue."Dimension Code";
        TempDimensionEntry."Dimension Value Code" := DimensionValue.Code;
        TempDimensionEntry."Dimension Value ID" := DimensionValue."Dimension Value ID";
        TempDimensionEntry.Insert();
        DimensionSetID := DimensionMgt.GetDimensionSetID(TempDimensionEntry);
        asserterror GrowerMgt.GrowerCodeForSourceVendor('GRW-030', DimensionSetID);
        AssertErrorContains('does not match vendor');
    end;

    local procedure CheckMapping(VendorNo: Code[20]; ExpectedGrower: Code[20])
    var
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
    begin
        AssertCode(ExpectedGrower, GrowerMgt.GrowerCodeForSourceVendor(VendorNo, 0));
        AssertCode(VendorNo, GrowerMgt.VendorNoForGrower(ExpectedGrower));
    end;

    local procedure CreateVendor(VendorNo: Code[20]; GrowerCode: Code[20])
    var
        Vendor: Record Vendor;
        DefaultDimension: Record "Default Dimension";
        DimensionValue: Record "Dimension Value";
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    begin
        Vendor.Init();
        Vendor."No." := VendorNo;
        Vendor.Name := 'Temporary grower identity check';
        Vendor.Insert(false);
        if GrowerCode = '' then
            exit;
        if not DimensionValue.Get(DimensionMgt.GrowerDimensionCode(), GrowerCode) then begin
            DimensionValue.Init();
            DimensionValue."Dimension Code" := DimensionMgt.GrowerDimensionCode();
            DimensionValue.Code := GrowerCode;
            DimensionValue.Name := 'Temporary grower identity check';
            DimensionValue.Insert(true);
        end;
        DefaultDimension.Init();
        DefaultDimension."Table ID" := Database::Vendor;
        DefaultDimension."No." := VendorNo;
        DefaultDimension."Dimension Code" := DimensionMgt.GrowerDimensionCode();
        DefaultDimension."Dimension Value Code" := GrowerCode;
        DefaultDimension.Insert(false);
    end;

    local procedure AssertCode(Expected: Code[20]; Actual: Code[20])
    begin
        if Expected <> Actual then
            Error('Expected %1; received %2.', Expected, Actual);
    end;

    local procedure AssertErrorContains(Expected: Text)
    var
        ActualError: Text;
    begin
        ActualError := GetLastErrorText();
        ClearLastError();
        if StrPos(ActualError, Expected) = 0 then
            Error('Expected an error containing %1; received %2.', Expected, ActualError);
    end;
}
