codeunit 59350 "WLF Pool E2E Management"
{
    var Setup: Record "TAC Pool Setup";
        RefItem: Record Item;
        RefVendor: Record Vendor;
        RefCustomer: Record Customer;
        StartDate: Date;

    procedure CheckTarget()
    var Environment: Codeunit "Environment Information";
    begin
        if not Environment.IsSandbox() then Error('Test data writes require a sandbox.');
        if (UpperCase(Environment.GetEnvironmentName()) <> 'POOL_SANDBOX') or (CompanyName() <> 'LIVE APMS') then
            Error('This test pack is restricted to Pool_Sandbox / LIVE APMS.');
    end;

    procedure Seed()
    var C: Record "WLF Pool E2E Case"; Week: Record "TAC Pool Week"; I: Integer;
    begin
        CheckTarget();
        if not C.IsEmpty() then Error('The ZE2E dataset already exists. Use its existing steps; it will not be overwritten.');
        Setup.Get();
        Setup.TestField("Packed Item No. Prefix", 'PKD');
        Setup.TestField("Kg UoM Code", 'KG'); Setup.TestField("Bin UoM Code", 'BIN'); Setup.TestField("Tray Equiv. UoM Code", 'TE');
        RefItem.SetFilter("No.", 'PKD*'); RefItem.SetRange(Blocked, false);
        RefItem.SetFilter("Inventory Posting Group", '<>%1', ''); RefItem.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        if not RefItem.FindFirst() then Error('A configured packed reference item is required.');
        RefVendor.SetRange(Blocked, RefVendor.Blocked::" "); RefVendor.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
        RefVendor.SetRange("Vendor Posting Group", Setup."Grower Posting Group");
        if not RefVendor.FindFirst() then Error('A configured internal grower vendor is required as a posting-group reference.');
        RefCustomer.SetRange(Blocked, RefCustomer.Blocked::" "); RefCustomer.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
        RefCustomer.SetFilter("Customer Posting Group", '<>%1', ''); RefCustomer.SetRange("Currency Code", '');
        if not RefCustomer.FindFirst() then Error('A configured local-currency customer is required as a posting-group reference.');
        StartDate := Today();
        if Week.FindSet() then repeat if Week."End Date" >= StartDate then StartDate := Week."End Date" + 1; until Week.Next() = 0;
        StartDate := StartDate + ((8 - Date2DWY(StartDate, 1)) mod 7);
        if StartDate > DMY2Date(1, 1, 2035) then Error('Existing pool dates extend beyond 2034. Choose a test range before seeding.');
        for I := 1 to 9 do CreateWeek(I);
        CreateMasters();
        PackCase(10, 'Internal grower A: 600 kg / 100 TE', 'Z201', 'ZE01', 1, 0, 600, 'ZE1', false);
        PackCase(20, 'Internal grower B: 400 kg / 66.66667 TE', 'Z202', 'ZE02', 1, 0, 400, 'ZE1', false);
        PackCase(30, 'External grower: 300 kg / 50 TE', 'Z203', 'ZE03', 2, 1, 300, 'ZE1', false);
        PackCase(40, 'Contract pack: 120 kg / 20 TE', 'Z204', 'ZE04', 3, 2, 120, 'ZE1', false);
        PackCase(50, 'Split invoice batch A: 240 kg', 'Z205', 'ZE05', 4, 0, 240, 'ZE1', false);
        PackCase(60, 'Split invoice batch B: 360 kg, different week', 'Z206', 'ZE06', 5, 0, 360, 'ZE1', false);
        PackCase(70, 'Classification baseline: 100 kg, grade ZE1', 'Z207', 'ZE07', 6, 0, 100, 'ZE1', false);
        PackCase(80, 'Second grade same grower/week: 80 kg, grade ZE2', 'Z208', 'ZE07', 6, 0, 80, 'ZE2', false);
        PackCase(90, 'Unpriced pool: 60 kg with no sales invoice', 'Z209', 'ZE08', 7, 0, 60, 'ZE1', false);
        PackCase(100, 'Missing size dimension: finish must reject', 'Z210', 'ZE09', 8, 0, 60, 'ZE1', true);
        PackCase(110, 'Repack: output without bin consumption must not pool', 'Z211', 'ZE10', 9, 0, 60, 'ZE1', false);
        C.Get(80); C."Expected Result" := 'Create a distinct 80 kg pool for grade ZE2 without overwriting grade ZE1. Known candidate defect: generated pool key omits grade/size and may collide. A rejection is a failed positive case.'; C.Modify();
        C.Get(100); C."Expect Rejection" := true; C."Expected Result" := 'Finishing must reject the missing SIZE dimension and must write no TR/charges. A different error does not prove this validation works.'; C.Modify();
        C.Get(110); C."Expected Result" := 'Normal output posting and finish, but no bin consumption; the pooling engine must write zero TR entries for this repack.'; C.Modify();
        SaleCase(200, 'Internal grower A: shipment and $1,800 invoice', 'ZE2E-S01', 10, 600, 3, '', 0);
        SaleCase(210, 'Internal grower B: shipment and $1,200 invoice', 'ZE2E-S02', 20, 400, 3, '', 0);
        SaleCase(220, 'External: shipment and $1,200 invoice', 'ZE2E-S03', 30, 300, 4, '', 0);
        SaleCase(230, 'Mixed weeks: one 600 kg invoice line, $3,000', 'ZE2E-S04', 50, 240, 5, 'Z206', 360);
        AddCase(300, 'Pool expense: allocate -$100 across internal pools', C.Operation::Expense, 20, 1, 0,
            'Post a test expense with -$60 to ZE01 and -$40 to ZE02. Expense total -$100, zero extra kg, and source drill-down retained.');
        AddCase(310, 'Quantity correction between test pools: 10 kg', C.Operation::Adjustment, 20, 1, 0,
            'Post -10 kg from ZE01 pool and +10 kg to ZE02 pool. Net group kg change zero; TRA/TRD rows and source reference retained.');
        AddCase(400, 'Internal provisional 1', C.Operation::Provisional, 300, 1, 0,
            'After both internal invoices reconcile, pay cumulative 40% under current setup. Verify charges, PPV recovery sign, G/L, grower invoices and completed payment timestamp.');
        AddCase(410, 'Internal provisional 2', C.Operation::Provisional, 400, 1, 0,
            'Cumulative internal entitlement 80% under current setup. Incremental settlement must recover the first payment, avoiding double payment.');
        AddCase(420, 'Internal final close', C.Operation::Final, 410, 1, 0,
            'Settle remaining entitlement, recover prior PPV, reconcile all grower purchase documents and close group. Residual follows configured tolerance.');
        AddCase(430, 'External provisional', C.Operation::Provisional, 220, 2, 1,
            'Cumulative external provisional entitlement 50% under current setup; verify external posting-group/account selection.');
        AddCase(440, 'External final close', C.Operation::Final, 430, 2, 1,
            'Settle remaining external entitlement with no duplicate recovery or grower invoices.');
        AddCase(450, 'Contract-pack close must reject', C.Operation::Final, 40, 3, 2,
            'Engine must reject grower settlement for Contract Pack. Verify the reason and no payment header/financial entries were created.');
        C.Get(450); C."Expect Rejection" := true; C.Modify();
        AddCase(460, 'Unpriced provisional must reject', C.Operation::Provisional, 90, 7, 0,
            'With Allow Provisional with Unpriced Kg OFF, this 60 kg pool must not create a provisional payment. Verify exact error and absence of financial entries.');
        C.Get(460); C."Expect Rejection" := true; C.Modify();
        AddCase(500, 'Duplicate production processing', C.Operation::RepeatProduction, 10, 1, 0,
            'Reprocess finished Z201 through the public pooling API; TR and charge row counts and amounts must remain identical.');
        C.Get(500); C."Source No." := 'Z201'; C.Modify();
        AddCase(510, 'Duplicate invoice processing', C.Operation::RepeatInvoice, 200, 1, 0,
            'Reprocess the posted ZE2E-S01 invoice. Pool row count and total must remain identical; a processed marker without PR is still a failure.');
        AddCase(600, 'Credit memo / reversal coverage', C.Operation::Manual, 200, 1, 0,
            'Current setup has Allow Invoice Credits OFF. Create a correcting credit from the test invoice in BC, confirm handling under that policy, then test the documented supported reversal path. This step is not executed or passed automatically.');
        AddCase(610, 'Customer receipt / grower payment application', C.Operation::Manual, 420, 1, 0,
            'Use the generated test customer/vendor entries in a dedicated journal to test settlement and applications. No bank/export or real transfer is initiated by this helper. Reconcile posted invoices, outstanding balance and payments.');
        AddCase(620, 'Reports and source drill-downs', C.Operation::Manual, 0, 1, 0,
            'Filter Pooling Overview to season ZE2E. Compare kg/dollars, findings, payments, overview/findings exports and native document links against this test bench. Full shipping allocation support remains a review coverage limit.');
        Message('ZE2E dataset created: 10 synthetic growers, 2 items, 9 non-overlapping test weeks, 11 production orders, 10 receipt orders, 4 sales orders and 29 test steps. Source documents are drafts/released orders; no ledger entries were fabricated. Use Run packing cases, then individual steps. Synthetic batch dates start %1; financial posting uses the current permitted posting date.', StartDate);
    end;

    local procedure CreateWeek(N: Integer)
    var W: Record "TAC Pool Week";
    begin
        W.Init(); W.Code := WeekCode(N); W.Description := 'TEST ONLY - ZE2E pooling acceptance';
        W."Season Code" := 'ZE2E'; W."Week No." := N; W."Start Date" := StartDate + (N - 1) * 7; W."End Date" := W."Start Date" + 6;
        W.Insert(true);
    end;

    procedure WeekCode(N: Integer): Code[10]
    begin exit(CopyStr('ZE2E-W' + Format(N, 0, '<Integer,2><Filler Character,0>'), 1, 10)); end;

    local procedure CreateMasters()
    var V: Record Vendor; C: Record Customer; Item: Record Item; Track: Record "Item Tracking Code";
        Loc: Record Location; IPS: Record "Inventory Posting Setup"; RefIPS: Record "Inventory Posting Setup";
        JTemplate: Record "Item Journal Template"; JBatch: Record "Item Journal Batch";
        SC: Record "Source Code Setup"; N: Integer; Id: Code[20]; GroupCode: Code[20];
    begin
        Loc.Init(); Loc.Code := 'ZE2E'; Loc.Name := 'TEST ONLY - Pool end-to-end'; Loc.Insert(true);
        RefIPS.SetRange("Invt. Posting Group Code", RefItem."Inventory Posting Group");
        RefIPS.SetFilter("Inventory Account", '<>%1', '');
        if not RefIPS.FindFirst() then Error('No inventory posting setup exists for %1.', RefItem."Inventory Posting Group");
        IPS := RefIPS; IPS."Location Code" := Loc.Code; IPS.Insert(true);
        Track.Init(); Track.Code := 'ZE2E-LOT'; Track.Description := 'TEST ONLY - E2E lot tracking';
        Track."Lot Specific Tracking" := true; Track."Lot Purchase Inbound Tracking" := true;
        Track."Lot Sales Outbound Tracking" := true; Track."Lot Pos. Adjmt. Inb. Tracking" := true;
        Track."Lot Neg. Adjmt. Outb. Tracking" := true; Track.Insert(true);
        CreateItem('ZE2E-BIN', 'BIN', false);
        CreateItem('PKD-ZE2E', 'KG', true);
        for N := 1 to 10 do begin
            Id := CopyStr('ZE' + Format(N, 0, '<Integer,2><Filler Character,0>'), 1, 20);
            GroupCode := Setup."Grower Posting Group"; if N = 3 then GroupCode := Setup."Grower Ext. Posting Group";
            V.Init(); V."No." := Id; V.Name := CopyStr('TEST ONLY - Pool grower ' + Format(N), 1, 100);
            V.Insert(true); V.Validate("Gen. Bus. Posting Group", RefVendor."Gen. Bus. Posting Group");
            V.Validate("VAT Bus. Posting Group", RefVendor."VAT Bus. Posting Group");
            V.Validate("Vendor Posting Group", GroupCode); V.Validate("Country/Region Code", RefVendor."Country/Region Code");
            V.Modify(true); AddDefaultDim(Database::Vendor, V."No.", Setup."Grower Dimension Code", Id);
        end;
        C.Init(); C."No." := 'ZE2E-CUST'; C.Name := 'TEST ONLY - Pool E2E buyer'; C."DIY_Consignment No. Prefix" := 'ZE'; C.Insert(true);
        C.Validate("Gen. Bus. Posting Group", RefCustomer."Gen. Bus. Posting Group");
        C.Validate("VAT Bus. Posting Group", RefCustomer."VAT Bus. Posting Group"); C.Validate("Customer Posting Group", RefCustomer."Customer Posting Group");
        C.Validate("Country/Region Code", RefCustomer."Country/Region Code"); C.Modify(true);
        PrepareCustomerDimension();
        SC.Get();
        for N := 1 to 2 do begin
            JTemplate.Init();
            if N = 1 then begin JTemplate.Name := 'ZE2E-C'; JTemplate.Type := JTemplate.Type::Consumption; JTemplate."Source Code" := SC."Consumption Journal"; end
            else begin JTemplate.Name := 'ZE2E-O'; JTemplate.Type := JTemplate.Type::Output; JTemplate."Source Code" := SC."Output Journal"; end;
            JTemplate.Description := 'TEST ONLY - Pool E2E'; JTemplate.Insert(true);
            JBatch.Init(); JBatch."Journal Template Name" := JTemplate.Name; JBatch.Name := 'ZE2E'; JBatch.Description := JTemplate.Description; JBatch.Insert(true);
        end;
        CreateTestChargesAndFreight();
    end;

    procedure PrepareCustomerDimension()
    var D: Record "Default Dimension"; C: Record Customer;
    begin
        CheckTarget(); C.Get('ZE2E-CUST'); C.TestField(Name, 'TEST ONLY - Pool E2E buyer');
        EnsureDim('CUSTOMERGROUP', 'ZE2E');
        if D.Get(Database::Customer, C."No.", 'CUSTOMERGROUP') then begin
            D.Validate("Dimension Value Code", 'ZE2E'); D.Modify(true);
        end else AddDefaultDim(Database::Customer, C."No.", 'CUSTOMERGROUP', 'ZE2E');
    end;

    procedure WithCustomerDimension(OldSetID: Integer): Integer
    var D: Record "Dimension Set Entry" temporary; V: Record "Dimension Value"; Mgt: Codeunit DimensionManagement;
    begin
        Mgt.GetDimensionSet(D, OldSetID); V.Get('CUSTOMERGROUP', 'ZE2E');
        D.SetRange("Dimension Code", V."Dimension Code");
        if D.FindFirst() then begin D."Dimension Value Code" := V.Code; D."Dimension Value ID" := V."Dimension Value ID"; D.Modify(); end
        else begin D.Init(); D."Dimension Set ID" := OldSetID; D."Dimension Code" := V."Dimension Code"; D."Dimension Value Code" := V.Code; D."Dimension Value ID" := V."Dimension Value ID"; D.Insert(); end;
        D.Reset(); exit(Mgt.GetDimensionSetID(D));
    end;

    local procedure CreateTestChargesAndFreight()
    var T: Record "TAC Pool Trans Type"; CT: Record "TAC Pool Charge Template"; Carrier: Record "Shipping Agent";
        F: Record "TAC Freight Location"; Rate: Record "TAC Freight Rate";
    begin
        // A controlled test rate, eligible only for the newly created ZE variety and ZE2E packing.
        T.Get('PKG'); T.TestField("Rate Source", T."Rate Source"::Fixed); T.TestField("Charge Rate Type", T."Charge Rate Type"::Unit);
        CT.Init(); CT.ID := 593501; CT."Trans Type Code" := T.Code; CT."Charge Action" := T."Charge Action";
        CT.Rate := 0.60; CT."Rate Source" := T."Rate Source"; CT."Rate Type" := T."Charge Rate Type"; CT."Charge Level" := T."Charge Level";
        CT."Variety Filter" := 'ZE'; CT."Pack Type Filter" := 'ZE2E'; CT.Active := true; CT.Insert(true);
        Carrier.Init(); Carrier.Code := 'ZE2E'; Carrier.Name := 'TEST ONLY - Synthetic carrier'; Carrier."Fuel Surcharge %" := 10; Carrier.Insert(true);
        F.Init(); F.Code := 'ZE2E-FROM'; F.Description := 'TEST ONLY - Packing shed'; F."BC Location Code" := 'ZE2E'; F.Insert(true);
        F.Init(); F.Code := 'ZE2E-TO'; F.Description := 'TEST ONLY - Buyer'; F."Location Type" := F."Location Type"::Destination; F.Insert(true);
        Rate.Init(); Rate."Shipping Agent Code" := 'ZE2E'; Rate."From Freight Location" := 'ZE2E-FROM'; Rate."To Freight Location" := 'ZE2E-TO';
        Rate."Starting Date" := Today(); Rate."Pallet Space Rate" := 50; Rate.Insert(true);
    end;

    local procedure CreateItem(Id: Code[20]; BaseUOM: Code[10]; Manufactured: Boolean)
    var I: Record Item; U: Record "Item Unit of Measure";
    begin
        I.Init(); I."No." := Id; I.Description := 'TEST ONLY - Pool E2E ' + BaseUOM; I.Insert(true);
        U.Init(); U."Item No." := Id; U.Code := BaseUOM; U."Qty. per Unit of Measure" := 1; U.Insert(true);
        I.Validate("Base Unit of Measure", BaseUOM);
        I.Validate("Gen. Prod. Posting Group", RefItem."Gen. Prod. Posting Group");
        I.Validate("VAT Prod. Posting Group", RefItem."VAT Prod. Posting Group");
        I.Validate("Inventory Posting Group", RefItem."Inventory Posting Group");
        I.Validate("Costing Method", I."Costing Method"::FIFO); I.Validate("Item Tracking Code", 'ZE2E-LOT');
        if Manufactured then I.Validate("Replenishment System", I."Replenishment System"::"Prod. Order");
        I.Modify(true);
        if Manufactured then begin U.Init(); U."Item No." := Id; U.Code := 'TE'; U."Qty. per Unit of Measure" := 6; U.Insert(true); end;
    end;

    local procedure EnsureDim(DimCode: Code[20]; ValueCode: Code[20])
    var D: Record Dimension; V: Record "Dimension Value";
    begin
        D.Get(DimCode); D.TestField(Blocked, false);
        if V.Get(DimCode, ValueCode) then begin V.TestField(Blocked, false); exit; end;
        V.Init(); V."Dimension Code" := DimCode; V.Code := ValueCode; V.Name := 'TEST ONLY - ' + ValueCode; V.Insert(true);
    end;

    local procedure AddDefaultDim(TableID: Integer; Id: Code[20]; DimCode: Code[20]; ValueCode: Code[20])
    var D: Record "Default Dimension";
    begin
        EnsureDim(DimCode, ValueCode); D.Init(); D."Table ID" := TableID; D."No." := Id; D."Dimension Code" := DimCode;
        D.Validate("Dimension Value Code", ValueCode); D.Insert(true);
    end;

    local procedure AddDimension(var D: Record "Dimension Set Entry" temporary; DimCode: Code[20]; ValueCode: Code[20])
    var V: Record "Dimension Value";
    begin
        EnsureDim(DimCode, ValueCode); V.Get(DimCode, ValueCode); D.Init(); D."Dimension Set ID" := 0;
        D."Dimension Code" := DimCode; D."Dimension Value Code" := ValueCode; D."Dimension Value ID" := V."Dimension Value ID"; D.Insert();
    end;

    local procedure MakeDimensions(Grower: Code[20]; W: Integer; TypeNo: Integer; Grade: Code[10]; MissingSize: Boolean): Integer
    var D: Record "Dimension Set Entry" temporary; Mgt: Codeunit DimensionManagement; TypeCode: Code[20];
    begin
        case TypeNo of 0: TypeCode := 'I'; 1: TypeCode := 'E'; 2: TypeCode := 'G'; end;
        AddDimension(D, Setup."Season Dimension Code", 'ZE2E'); AddDimension(D, Setup."Pool Week Dimension Code", WeekCode(W));
        AddDimension(D, Setup."Variety Dimension Code", 'ZE'); AddDimension(D, Setup."Grade Dimension Code", Grade);
        if not MissingSize then AddDimension(D, Setup."Size Dimension Code", 'ZE25');
        AddDimension(D, Setup."Grower Dimension Code", Grower); AddDimension(D, Setup."Grower Pool Type Dim. Code", TypeCode);
        AddDimension(D, Setup."Pack Type Dimension Code", 'ZE2E'); AddDimension(D, Setup."Pack Type Category Dim. Code", 'ZE2E');
        exit(Mgt.GetDimensionSetID(D));
    end;

    local procedure PackCase(No: Integer; Title: Text[100]; Batch: Code[20]; Grower: Code[20]; W: Integer; TypeNo: Integer; Kg: Decimal; Grade: Code[10]; MissingSize: Boolean)
    var C: Record "WLF Pool E2E Case"; P: Record "Production Order"; L: Record "Prod. Order Line"; Comp: Record "Prod. Order Component";
        Plan: Record "TAC Batch Plan Header"; G: Record "TAC Batch Plan Grower"; Lot: Record "TAC Batch Plan Lot";
        DimMgt: Codeunit DimensionManagement;
    begin
        C.Init(); C."Step No." := No; C.Scenario := Title; C.Operation := C.Operation::Pack; C."Source No." := Batch;
        C."Related No." := CopyStr('ZE2E-P' + Format(No div 10, 0, '<Integer,2><Filler Character,0>'), 1, 20);
        C."Grower No." := Grower; C."Week No." := W; C."Pool Type" := Enum::"TAC Grower Pool Type".FromInteger(TypeNo);
        C.Quantity := Kg; C."Dimension Set ID" := MakeDimensions(Grower, W, TypeNo, Grade, MissingSize);
        C."Test Date" := StartDate + (W - 1) * 7;
        C."Expected Result" := CopyStr(StrSubstNo('Receive %1 bins from %2; consume bins; post %3 kg (%4 TE) output, then finish. Exactly one TR for %5 with %3 kg. Test PKG rate $0.60 per TE gives -$%6; other existing eligible charge rules remain active. All inventory entries come from normal BC posting.', Kg / 100, Grower, Kg, Kg / 6, Batch, Kg / 10), 1, 2048);
        C.Insert();
        P.Init(); P.Status := P.Status::Released; P."No." := Batch; P.Insert(true);
        P.Validate("Source Type", P."Source Type"::Item); P.Validate("Source No.", 'PKD-ZE2E');
        P.Validate("Location Code", 'ZE2E'); P.Validate(Quantity, Kg); P.Validate("Due Date", Today());
        P.Description := 'TEST ONLY - ' + Title; P."Dimension Set ID" := C."Dimension Set ID";
        DimMgt.UpdateGlobalDimFromDimSetID(P."Dimension Set ID", P."Shortcut Dimension 1 Code", P."Shortcut Dimension 2 Code"); P.Modify(true);
        L.Init(); L.Status := P.Status; L."Prod. Order No." := Batch; L."Line No." := 10000;
        L.Validate("Item No.", 'PKD-ZE2E'); L.Validate("Location Code", 'ZE2E'); L.Validate(Quantity, Kg);
        L."Due Date" := Today(); L."Starting Date" := Today(); L."Ending Date" := Today();
        L."Dimension Set ID" := C."Dimension Set ID";
        DimMgt.UpdateGlobalDimFromDimSetID(L."Dimension Set ID", L."Shortcut Dimension 1 Code", L."Shortcut Dimension 2 Code"); L.Insert(true);
        if No <> 110 then begin
            Comp.Init(); Comp.Status := P.Status; Comp."Prod. Order No." := Batch; Comp."Prod. Order Line No." := 10000; Comp."Line No." := 10000;
            Comp.Validate("Item No.", 'ZE2E-BIN'); Comp.Validate("Location Code", 'ZE2E'); Comp.Validate("Quantity per", 0.01); Comp."Due Date" := Today(); Comp.Insert(true);
            CreateReceipt(C);
        end;
        Plan.Init(); Plan."No." := 'ZE2E-' + Batch; Plan."Plan Date" := C."Test Date"; Plan.Insert(false);
        G.Init(); G."Batch Plan No." := Plan."No."; G."Line No." := 10000; G."Vendor No." := Grower; G."Batch No." := Batch;
        G."Prod. Order No." := Batch; G."Prod. Order Created" := true; G."Sequence No." := No; G.Insert(false);
        Lot.Init(); Lot."Batch Plan No." := Plan."No."; Lot."Line No." := 10000; Lot."Grower Line No." := 10000;
        Lot."Vendor No." := Grower; Lot."Batch No." := Batch; Lot."Lot No." := 'ZE2E-R-' + Batch; Lot."Item No." := 'ZE2E-BIN';
        Lot."Sequence No." := No; Lot."Location Code" := 'ZE2E'; Lot."Bin Activated DateTime" := CreateDateTime(C."Test Date", 080000T); Lot.Insert(false);
    end;

    local procedure CreateReceipt(C: Record "WLF Pool E2E Case")
    var H: Record "Purchase Header"; L: Record "Purchase Line";
    begin
        H.Init(); H."Document Type" := H."Document Type"::Order; H."No." := C."Related No."; H.Insert(true);
        H.SetHideValidationDialog(true);
        H.Validate("Buy-from Vendor No.", C."Grower No."); H.Validate("Posting Date", Today()); H.Validate("Location Code", 'ZE2E');
        H."Your Reference" := 'TEST ZE2E'; H.Modify(true);
        L.Init(); L."Document Type" := H."Document Type"; L."Document No." := H."No."; L."Line No." := 10000;
        L.Validate(Type, L.Type::Item); L.Validate("No.", 'ZE2E-BIN'); L.Validate("Location Code", 'ZE2E'); L.Validate(Quantity, C.Quantity / 100);
        L.Validate("Direct Unit Cost", 10); L."Dimension Set ID" := C."Dimension Set ID"; L.Insert(true);
        AddTracking(Database::"Purchase Line", L."Document Type".AsInteger(), H."No.", L."Line No.", L."No.", 'ZE2E-R-' + C."Source No.", L.Quantity, true);
    end;

    local procedure SaleCase(No: Integer; Title: Text[100]; Id: Code[20]; PackStep: Integer; Qty: Decimal; UnitPrice: Decimal; OtherBatch: Code[20]; OtherQty: Decimal)
    var C: Record "WLF Pool E2E Case"; P: Record "WLF Pool E2E Case"; H: Record "Sales Header"; L: Record "Sales Line";
        Cons: Record "TAC Consignment Header"; Manifest: Record "TAC Carrier Manifest"; Leg: Record "TAC Consignment Freight Leg";
    begin
        P.Get(PackStep); C.Init(); C."Step No." := No; C.Scenario := Title; C.Operation := C.Operation::Sale;
        C."Source No." := Id; C."Related No." := P."Source No."; C."Second Source No." := OtherBatch; C."Second Quantity" := OtherQty;
        C.Quantity := Qty + OtherQty; C.Price := UnitPrice; C."Week No." := P."Week No."; C."Pool Type" := P."Pool Type"; C."Grower No." := P."Grower No.";
        C."Dimension Set ID" := P."Dimension Set ID"; C."Prerequisite Step" := PackStep;
        C."Expected Result" := CopyStr(StrSubstNo('Ship and invoice %1 kg at %2 ex tax: PR revenue must total %3. Consignment allocation must equal shipped kg and retain invoice/shipment links. Known candidate defect: shipment allocation source line 0 may not match the invoice shipment line.', C.Quantity, UnitPrice, C.Quantity * UnitPrice), 1, 2048);
        C."Expected Result" := C."Expected Result" + ' Freight: 1 pallet space x $50 plus 10% fuel = $55; FR allocations must total -$55.';
        if OtherQty <> 0 then C."Expected Result" := C."Expected Result" + ' Split expected: $1,200 to week 4 / ZE05; $1,800 to week 5 / ZE06. Do not attribute all revenue to the first week.';
        C.Insert();
        H.Init(); H."Document Type" := H."Document Type"::Order; H."No." := Id; H.Insert(true);
        H.Validate("Sell-to Customer No.", 'ZE2E-CUST'); H.Validate("Posting Date", Today()); H.Validate("Location Code", 'ZE2E');
        H.Validate("Shipment Date", Today()); H."External Document No." := Id; H."Your Reference" := 'TEST ZE2E';
        H."DIY_Consignment No." := Id; H.Modify(true);
        L.Init(); L."Document Type" := H."Document Type"; L."Document No." := Id; L."Line No." := 10000;
        L.Validate(Type, L.Type::Item); L.Validate("No.", 'PKD-ZE2E'); L.Validate("Location Code", 'ZE2E'); L.Validate(Quantity, C.Quantity);
        L.Validate("Unit Price", UnitPrice); L."Dimension Set ID" := C."Dimension Set ID"; L."Consignment No." := Id; L.Insert(true);
        Cons.Init(); Cons."Consignment No." := Id; Cons."Sales Order No." := Id; Cons."Sell-to Customer No." := 'ZE2E-CUST';
        Cons."Despatch Date" := Today(); Cons."Final Destination" := 'ZE2E-TO'; Cons.Insert(true);
        Manifest.Init(); Manifest."No." := Id; Manifest."Shipping Agent Code" := 'ZE2E'; Manifest."From Freight Location" := 'ZE2E-FROM';
        Manifest."To Freight Location" := 'ZE2E-TO'; Manifest.Validate("Manifest Date", Today()); Manifest.Insert(true);
        Leg.Init(); Leg."Consignment No." := Id; Leg."Leg No." := 1; Leg.Validate("Manifest No.", Id); Leg.Validate("Pallet Spaces", 1); Leg.Insert(true);
        AddTracking(Database::"Sales Line", L."Document Type".AsInteger(), Id, 10000, 'PKD-ZE2E', P."Source No.", Qty, false);
        if OtherQty <> 0 then AddTracking(Database::"Sales Line", L."Document Type".AsInteger(), Id, 10000, 'PKD-ZE2E', OtherBatch, OtherQty, false);
    end;

    local procedure AddTracking(TableID: Integer; Subtype: Integer; DocNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; LotNo: Code[50]; Qty: Decimal; Inbound: Boolean)
    var R: Record "Reservation Entry"; CreateR: Codeunit "Create Reserv. Entry";
    begin
        R.Init(); R."Lot No." := LotNo;
        CreateR.CreateReservEntryFor(TableID, Subtype, DocNo, '', 0, LineNo, 1, Qty, Qty, R);
        if Inbound then CreateR.CreateEntry(ItemNo, '', 'ZE2E', 'TEST ONLY - ZE2E lot', Today(), 0D, 0, R."Reservation Status"::Surplus)
        else CreateR.CreateEntry(ItemNo, '', 'ZE2E', 'TEST ONLY - ZE2E lot', 0D, Today(), 0, R."Reservation Status"::Surplus);
    end;

    local procedure AddCase(No: Integer; Title: Text[100]; Op: Option; Prerequisite: Integer; W: Integer; TypeNo: Integer; Expected: Text)
    var C: Record "WLF Pool E2E Case";
    begin
        C.Init(); C."Step No." := No; C.Scenario := Title; C.Operation := Op; C."Prerequisite Step" := Prerequisite;
        C."Week No." := W; C."Pool Type" := Enum::"TAC Grower Pool Type".FromInteger(TypeNo); C."Expected Result" := CopyStr(Expected, 1, 2048);
        if C.Operation = C.Operation::Manual then C.Status := C.Status::"Manual check";
        C.Insert();
    end;

    procedure RunStep(No: Integer)
    var C: Record "WLF Pool E2E Case"; P: Record "WLF Pool E2E Case"; Failure: Text;
    begin
        CheckTarget(); C.Get(No);
        if (C.Operation = C.Operation::Expense) and (C."Prerequisite Step" = 200) then begin C."Prerequisite Step" := 20; C.Modify(); end;
        if C.Operation = C.Operation::Manual then begin Message('%1', C."Expected Result"); exit; end;
        if C.Status = C.Status::Completed then Error('This step is already completed. No posting will be repeated.');
        if C."Prerequisite Step" <> 0 then begin
            P.Get(C."Prerequisite Step");
            if P.Status <> P.Status::Completed then begin C.Status := C.Status::Blocked; C."Actual Result" := StrSubstNo('Prerequisite step %1 is %2. Complete and reconcile it first.', P."Step No.", P.Status); C.Modify(); exit; end;
        end;
        Commit(); ClearLastError();
        if not Codeunit.Run(Codeunit::"WLF Pool E2E Execute", C) then begin
            Failure := GetLastErrorText() + ' | ' + GetLastErrorCallStack(); C.Get(No); C.Status := C.Status::Blocked;
            C."Actual Result" := CopyStr(Failure, 1, 2048); C."Last Run" := CurrentDateTime(); C.Modify();
        end;
        Commit();
    end;

    procedure RunPacking()
    var C: Record "WLF Pool E2E Case"; Steps: List of [Integer]; N: Integer;
    begin
        CheckTarget(); C.SetRange(Operation, C.Operation::Pack); C.SetRange(Status, C.Status::Ready);
        if C.FindSet() then repeat Steps.Add(C."Step No."); until C.Next() = 0;
        foreach N in Steps do RunStep(N);
    end;

    procedure OpenSource(C: Record "WLF Pool E2E Case")
    var P: Record "Production Order"; S: Record "Sales Header"; I: Record "Sales Invoice Header"; G: Record "TAC Pool Group Header"; PageNo: Integer;
    begin
        if C.Operation in [C.Operation::Pack, C.Operation::RepeatProduction] then begin
            P.SetRange("No.", C."Source No."); P.FindFirst();
            if P.Status = P.Status::Finished then PageNo := Page::"Finished Production Order" else PageNo := Page::"Released Production Order";
            P.SetRecFilter();
            Hyperlink(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, PageNo, P, true)); exit;
        end;
        if C.Operation = C.Operation::Sale then begin
            if C."Posted Document No." <> '' then begin I.Get(C."Posted Document No."); I.SetRecFilter(); Hyperlink(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Posted Sales Invoice", I, true)); end
            else begin S.Get(S."Document Type"::Order, C."Source No."); S.SetRecFilter(); Hyperlink(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Sales Order", S, true)); end; exit;
        end;
        G.SetRange("Pool Week Code", WeekCode(C."Week No.")); G.SetRange("Grower Pool Type", C."Pool Type");
        Page.Run(Page::"TAC Pool Group List", G);
    end;

    procedure ExportResults()
    var C: Record "WLF Pool E2E Case"; Blob: Codeunit "Temp Blob"; OutS: OutStream; InS: InStream; FileName: Text; J: JsonObject; Rows: JsonArray; Root: JsonObject;
    begin
        CheckTarget();
        if C.FindSet() then repeat
            Clear(J); J.Add('step', C."Step No."); J.Add('scenario', C.Scenario); J.Add('status', Format(C.Status));
            J.Add('source', C."Source No."); J.Add('related', C."Related No."); J.Add('postedDocument', C."Posted Document No.");
            J.Add('operation', Format(C.Operation)); J.Add('secondSource', C."Second Source No."); J.Add('secondQuantity', C."Second Quantity");
            J.Add('week', C."Week No."); J.Add('grower', C."Grower No."); J.Add('poolType', Format(C."Pool Type"));
            J.Add('quantity', C.Quantity); J.Add('price', C.Price); J.Add('testDate', Format(C."Test Date", 0, 9)); J.Add('prerequisite', C."Prerequisite Step");
            J.Add('expected', C."Expected Result"); J.Add('observed', C."Actual Result"); J.Add('kg', C."Actual Kg"); J.Add('amount', C."Actual Amount");
            J.Add('lastRun', Format(C."Last Run", 0, 9)); Rows.Add(J);
        until C.Next() = 0;
        Root.Add('environment', 'Pool_Sandbox'); Root.Add('company', CompanyName()); Root.Add('season', 'ZE2E'); Root.Add('steps', Rows);
        Blob.CreateOutStream(OutS, TextEncoding::UTF8); Root.WriteTo(OutS); Blob.CreateInStream(InS, TextEncoding::UTF8);
        FileName := 'ZE2E-pooling-test-results.json'; DownloadFromStream(InS, '', '', '', FileName);
    end;
}
