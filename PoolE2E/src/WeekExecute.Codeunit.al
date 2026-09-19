codeunit 59354 "WLF Pool Week Execute"
{
    TableNo = "WLF Pool Week Run";
    trigger OnRun()
    begin
        M.CheckTarget();
        if (Rec."Order Index" < 1) or (Rec."Order Index" > 50) then Error('Unexpected order index.');
        if Rec."Test Date" <> DMY2Date(21, 9, 2026) + ((Rec."Order Index" - 1) div 10) then Error('Unexpected test date.');
        case Rec."Operation No." of
            1: Receipt(Rec); 2: PlanDay(Rec);
            3: Production.Prepare(Rec);
            4: Production.ReleaseOrder(Rec);
            5: Production.Consume(Rec);
            6: Production.OutputNext(Rec);
            7: Production.FinishOrder(Rec);
            8: Production.CompletePoolSourceDimensions(Rec);
            9: Production.CompleteGrowerSourceDimensions(Rec);
            10: Production.ApplyProcessPackingDimensions(Rec);
            else Error('Unknown operation.');
        end;
    end;
    var M: Codeunit "WLF Pool Week Management"; Production: Codeunit "WLF Pool Week Production";

    local procedure Receipt(var R: Record "WLF Pool Week Run")
    var H: Record "Purchase Header"; L: Record "Purchase Line"; I: Record Item;
        Track: Record "Item Tracking Code"; Lot: Record "Lot No. Information"; RE: Record "Reservation Entry";
        TS: Record "Tracking Specification"; ILE: Record "Item Ledger Entry"; Loc: Record Location;
        Bin: Record Bin; WarehouseEntry: Record "Warehouse Entry";
        DimMgt: Codeunit DimensionManagement; BinNo: Codeunit "TAC Bin Delivery No. Mgt.";
        CreateR: Codeunit "Create Reserv. Entry"; Post: Codeunit "Purch.-Post"; Expiration: Date;
    begin
        if R."Receipt Verified" then Error('Receipt already verified.');
        if R."Purchase Order No." <> '' then Error('A source order is already linked. Inspect it before retrying.');
        I.Get('BIN-HASS'); I.TestField("Base Unit of Measure", 'BIN'); I.TestField(Blocked, false);
        I.TestField("Purchasing Blocked", false); M.CheckBlock(R."Grower No.", R."Block Code");
        Loc.Get('MANJIMUP'); Loc.TestField("Require Receive", false);
        Loc.TestField("Require Put-away", false); Loc.TestField("Directed Put-away and Pick", false);
        if Loc."Bin Mandatory" then begin
            // Use the location's existing production input bin for these synthetic deliveries.
            Loc.TestField("To-Production Bin Code"); Bin.Get(Loc.Code, Loc."To-Production Bin Code");
            R."Receipt Bin Code" := Bin.Code;
        end;
        Track.Get(I."Item Tracking Code");
        if Format(I."Expiration Calculation") <> '' then Expiration := CalcDate(I."Expiration Calculation", R."Test Date");
        // These are synthetic deliveries. When the item has no shelf-life formula,
        // give only the new test lots an explicit 30-day expiry; leave item setup unchanged.
        if Track."Man. Expir. Date Entry Reqd." and (Expiration = 0D) then Expiration := R."Test Date" + 30;
        H.Init(); H."Document Type" := H."Document Type"::Order; H.Insert(true); H.SetHideValidationDialog(true);
        H.Validate("Buy-from Vendor No.", R."Grower No."); H.Validate("Posting Date", R."Test Date");
        H.Validate("Expected Receipt Date", R."Test Date"); H.Validate("Location Code", 'MANJIMUP');
        H."Your Reference" := 'TEST W26S21'; H."Vendor Order No." := CopyStr(StrSubstNo('W26S21-%1', R."Order Index"), 1, MaxStrLen(H."Vendor Order No.")); H.Modify(true);
        L.Init(); L."Document Type" := H."Document Type"; L."Document No." := H."No."; L."Line No." := 10000;
        L.Validate(Type, L.Type::Item); L.Validate("No.", I."No."); L.Validate("Location Code", 'MANJIMUP'); L.Validate(Quantity, 10);
        if R."Receipt Bin Code" <> '' then L.Validate("Bin Code", R."Receipt Bin Code");
        L.Validate("Expected Receipt Date", R."Test Date");
        L."Dimension Set ID" := M.WithDimension(L."Dimension Set ID", 'BLOCK', R."Block Code");
        DimMgt.UpdateGlobalDimFromDimSetID(L."Dimension Set ID", L."Shortcut Dimension 1 Code", L."Shortcut Dimension 2 Code");
        L.Insert(true);
        // Purchase setup can default Qty. to Receive to blank even when Quantity is ten.
        L.Validate("Qty. to Receive", 10); L.Modify(true);
        TS.Init(); TS."Source Type" := Database::"Purchase Line"; TS."Source Subtype" := H."Document Type".AsInteger(); TS."Source ID" := H."No.";
        R."Delivery Lot No." := BinNo.GetBinDeliveryNo(TS);
        ILE.SetRange("Item No.", I."No."); ILE.SetRange("Lot No.", R."Delivery Lot No.");
        if not ILE.IsEmpty() then Error('Allocated delivery lot already has item entries.');
        Lot.Init(); Lot."Item No." := I."No."; Lot."Lot No." := R."Delivery Lot No.";
        Lot.Description := CopyStr(StrSubstNo('TEST W26S21 %1 %2', R."Grower No.", R."Block Code"), 1, MaxStrLen(Lot.Description));
        Lot."TAC Harvest Date" := R."Test Date"; Lot."TAC Bin Delivery Receival Time" := CreateDateTime(R."Test Date", 080000T);
        Lot.Insert(true);
        RE.Init(); RE."Lot No." := R."Delivery Lot No."; RE."Expiration Date" := Expiration;
        RE."TAC Harvest Date" := R."Test Date"; RE."TAC Harvest Start Time" := CreateDateTime(R."Test Date", 060000T);
        RE."TAC Harvest Finish Time" := CreateDateTime(R."Test Date", 073000T); RE."TAC Bin Delivery Receival Time" := CreateDateTime(R."Test Date", 080000T);
        CreateR.SetDates(0D, Expiration);
        CreateR.CreateReservEntryFor(Database::"Purchase Line", H."Document Type".AsInteger(), H."No.", '', 0, L."Line No.", L."Qty. per Unit of Measure", 10, 10, RE);
        CreateR.CreateEntry(I."No.", '', 'MANJIMUP', 'TEST W26S21 bin delivery', R."Test Date", 0D, 0, RE."Reservation Status"::Surplus);
        H.Receive := true; H.Invoice := false; Post.SetSuppressCommit(true); Post.Run(H);
        ILE.Reset(); ILE.SetRange("Item No.", I."No."); ILE.SetRange("Lot No.", R."Delivery Lot No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase); ILE.SetRange("Location Code", 'MANJIMUP');
        if ILE.Count() <> 1 then Error('Expected exactly one purchase entry for the 10-bin delivery.');
        ILE.FindFirst(); ILE.TestField(Quantity, 10); ILE.TestField("Remaining Quantity", 10); ILE.TestField("Posting Date", R."Test Date");
        ILE.TestField("Source No.", R."Grower No.");
        if R."Receipt Bin Code" <> '' then begin
            WarehouseEntry.SetRange("Location Code", Loc.Code); WarehouseEntry.SetRange("Bin Code", R."Receipt Bin Code");
            WarehouseEntry.SetRange("Item No.", I."No.");
            // LOTALL tracks lots in inventory but currently not in warehouse entries.
            // Reconcile the exact purchase source and posted receipt instead of a blank warehouse lot.
            WarehouseEntry.SetRange("Source Type", Database::"Purchase Line");
            WarehouseEntry.SetRange("Source Subtype", H."Document Type".AsInteger());
            WarehouseEntry.SetRange("Source No.", H."No."); WarehouseEntry.SetRange("Source Line No.", L."Line No.");
            WarehouseEntry.SetRange("Reference No.", ILE."Document No.");
            if Track."Lot Warehouse Tracking" then WarehouseEntry.SetRange("Lot No.", R."Delivery Lot No.");
            WarehouseEntry.CalcSums("Qty. (Base)"); WarehouseEntry.TestField("Qty. (Base)", 10);
        end;
        R."Purchase Order No." := H."No."; R."Receipt Entry No." := ILE."Entry No."; R."Receipt Verified" := true;
        R."Last Result" := '10 bins received through Purchase posting; quantity, grower, lot, location and date verified.';
        R."Last Run" := CurrentDateTime(); R.Modify();
    end;

    local procedure PlanDay(var First: Record "WLF Pool Week Run")
    var R: Record "WLF Pool Week Run"; H: Record "TAC Batch Plan Header"; G: Record "TAC Batch Plan Grower";
        Lot: Record "TAC Batch Plan Lot"; Available: Record "TAC Batch Plan Lot" temporary; Lane: Record "TAC Batch Plan Lane";
        PlanMgt: Codeunit "TAC Batch Plan Mgt."; ILE: Record "Item Ledger Entry"; I: Record Item;
        LineNo: Integer; N: Integer; BatchSuffix: Integer; Last4: Text; BlockMap: RecordRef;
    begin
        R.SetRange("Test Date", First."Test Date"); R.SetRange("Receipt Verified", true);
        if R.Count() <> 10 then Error('Expected ten verified deliveries for this day.');
        R.SetRange("Plan Prepared", true); if not R.IsEmpty() then Error('A plan is already linked for this day.'); R.SetRange("Plan Prepared");
        H.Init(); H."Plan Date" := First."Test Date"; H.Insert(true);
        if R.FindSet(true) then repeat
            ILE.Get(R."Receipt Entry No."); ILE.TestField("Remaining Quantity", 10);
            Available.Reset(); Available.DeleteAll();
            PlanMgt.BuildAvailableBuffer(H, Available, R."Grower No.", R."Block Code");
            Available.SetRange("ILE Entry No.", R."Receipt Entry No.");
            if Available.Count() <> 1 then Error('The normal batch-plan selector did not return delivery %1 for grower/block %2/%3.', R."Delivery Lot No.", R."Grower No.", R."Block Code");
            Available.FindFirst(); Available.TestField("Remaining Quantity", 10);
            LineNo += 10000; G.Init(); G."Batch Plan No." := H."No."; G."Line No." := LineNo;
            G."Sequence No." := LineNo div 10000;
            G.Validate("Vendor No.", R."Grower No."); G."Block Code" := R."Block Code"; G.Insert(true);
            Lot := Available; Lot."Batch Plan No." := H."No."; Lot."Line No." := LineNo;
            Lot."Item No." := H."Item No.";
            BlockMap.Open(50905); BlockMap.Field(1).SetRange(R."Grower No."); BlockMap.Field(2).SetRange(R."Block Code"); BlockMap.FindFirst();
            Lot."AV No." := CopyStr(Format(BlockMap.Field(4).Value), 1, MaxStrLen(Lot."AV No.")); BlockMap.Close();
            Lot."Grower Line No." := G."Line No."; Lot."Sequence No." := G."Sequence No."; Lot.Insert(true);
            R."Plan No." := H."No."; R.Modify();
        until R.Next() = 0;
        PlanMgt.AssignBatchNumbers(H);
        R.FindSet(true); repeat
            G.Reset(); G.SetRange("Batch Plan No.", H."No."); G.SetRange("Vendor No.", R."Grower No."); G.SetRange("Block Code", R."Block Code");
            if G.Count() <> 1 then Error('Ambiguous grower/block batch mapping.'); G.FindFirst();
            if StrLen(G."Batch No.") < 4 then Error('Allocated batch %1 does not have a four-digit suffix.', G."Batch No.");
            Last4 := CopyStr(G."Batch No.", StrLen(G."Batch No.") - 3, 4);
            if not Evaluate(BatchSuffix, Last4) then Error('Allocated batch %1 cannot be encoded in numeric unit serials.', G."Batch No.");
            for N := 1 to 9 do begin
                I.Get(M.ItemNo(N)); I.TestField(Blocked, false); I.TestField("Sales Blocked", false);
                Lane.Init(); Lane."Batch Plan No." := H."No."; Lane."Sequence No." := G."Sequence No.";
                Lane."Batch No." := G."Batch No."; Lane."Lane No." := Format(N); Lane.Validate("Item No.", I."No."); Lane.Insert(true);
            end;
            R."Batch No." := G."Batch No."; R."Plan Prepared" := true;
            R."Last Result" := 'Batch plan prepared with received bins and nine outlets. Use normal Print and Create Production Orders actions next.';
            R."Last Run" := CurrentDateTime(); R.Modify();
        until R.Next() = 0;
    end;
}
