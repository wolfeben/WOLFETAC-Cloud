codeunit 59355 "WLF Pool Week Production"
{
    var M: Codeunit "WLF Pool Week Management";

    procedure Prepare(var R: Record "WLF Pool Week Run")
    var P: Record "Production Order"; L: Record "Prod. Order Line"; C: Record "Prod. Order Component";
        I: Record Item; O: Record "WLF Pool Week Output"; E: Record "Item Ledger Entry";
        RE: Record "Reservation Entry"; CreateR: Codeunit "Create Reserv. Entry";
        D: Record "Default Dimension"; DS: Record "Dimension Set Entry";
        ItemIndex: Integer; S: Integer; Total: Decimal; DimCode: Text;
    begin
        CheckOrder(R); R.TestField("Production Prepared", false);
        P.Get(P.Status::"Firm Planned", R."Batch No.");
        P.CalcFields("Grower ID", "Batch Plan No."); P.TestField("Grower ID", R."Grower No."); P.TestField("Batch Plan No.", R."Plan No.");
        E.SetRange("Order Type", E."Order Type"::Production); E.SetRange("Order No.", P."No.");
        if not E.IsEmpty() then Error('Production entries already exist before preparation.');
        L.SetRange(Status, P.Status); L.SetRange("Prod. Order No.", P."No.");
        if L.Count() <> 9 then Error('Expected exactly nine native output lines.');
        C.SetRange(Status, P.Status); C.SetRange("Prod. Order No.", P."No.");
        if C.Count() <> 1 then Error('Expected one native bin component.');
        C.FindFirst(); C.TestField("Item No.", 'BIN-HASS'); C.TestField("Unit of Measure Code", 'BIN');
        C.TestField("Location Code", 'MANJIMUP'); C.TestField("Bin Code", R."Receipt Bin Code");
        C.TestField("Flushing Method", C."Flushing Method"::"Pick + Manual");
        // Prevent the native initial 10-per-output-unit placeholder from scaling with output.
        // These documents represent one fixed ten-bin delivery, shared across nine outlets.
        C.Validate("Quantity per", 0); C.Modify(true);
        for ItemIndex := 1 to 9 do begin
            I.Get(M.ItemNo(ItemIndex)); I.TestField(Blocked, false);
            L.SetRange("Item No.", I."No."); if L.Count() <> 1 then Error('Missing or duplicate output item %1.', I."No.");
            L.FindFirst(); L.TestField(Quantity, 0); L.TestField("Finished Quantity", 0);
            L.TestField("Unit of Measure Code", I."Base Unit of Measure"); L.TestField("Qty. per Unit of Measure", 1);
            foreach DimCode in 'VARIETY|GRADE|SIZE'.Split('|') do begin
                D.Get(Database::Item, I."No.", DimCode); D.TestField("Dimension Value Code");
                DS.Get(L."Dimension Set ID", DimCode); DS.TestField("Dimension Value Code", D."Dimension Value Code");
            end;
            Total := 0;
            for S := 1 to 3 do begin
                O.Init(); O."Order Index" := R."Order Index"; O."Item Index" := ItemIndex; O.Slot := S;
                O."Item No." := I."No."; O."Pallet No." := PalletNo(R."Order Index", ItemIndex, S);
                O."Base Quantity" := PieceQuantity(R."Order Index", ItemIndex, S);
                if S = 3 then O."Posting Date" := DMY2Date(25, 9, 2026) else O."Posting Date" := R."Test Date";
                if ItemIndex <= 7 then begin
                    O."Serial Count" := O."Base Quantity";
                    O."First Serial" := SerialNo(R, O, 1); O."Last Serial" := SerialNo(R, O, O."Serial Count");
                end;
                CheckNewPiece(O); O.Insert(); Total += O."Base Quantity";
            end;
            L.Validate(Quantity, Total); L.TestField("Quantity (Base)", Total);
            L.Validate("Starting Date", R."Test Date"); L.Validate("Starting Time", 080000T);
            // Every order contributes to mixed pallets completed on the final packing day.
            L.Validate("Ending Date", DMY2Date(25, 9, 2026)); L.Validate("Ending Time", 170000T);
            L.Validate("Bin Code", R."Receipt Bin Code"); L.Modify(true);
        end;
        C.FindFirst(); L.Get(P.Status, P."No.", C."Prod. Order Line No.");
        C.Validate("Quantity per", 10 / L.Quantity); C.Validate("Expected Quantity", 10);
        C.TestField("Expected Qty. (Base)", 10); C.Modify(true);
        RE.SetRange("Source Type", Database::"Prod. Order Component"); RE.SetRange("Source ID", P."No.");
        if not RE.IsEmpty() then Error('Unexpected existing component tracking; inspect before assigning the receipt.');
        E.Get(R."Receipt Entry No."); E.TestField("Remaining Quantity", 10);
        RE.Init(); RE."Lot No." := R."Delivery Lot No."; RE."Expiration Date" := E."Expiration Date";
        RE."Appl.-to Item Entry" := E."Entry No.";
        CreateR.SetDates(0D, E."Expiration Date");
        CreateR.CreateReservEntryFor(Database::"Prod. Order Component", P.Status.AsInteger(), P."No.", '', C."Prod. Order Line No.", C."Line No.", 1, 10, 10, RE);
        CreateR.CreateEntry('BIN-HASS', '', 'MANJIMUP', 'TEST W26S21 exact receipt', R."Test Date", 0D, 0, RE."Reservation Status"::Surplus);
        R."Production Prepared" := true;
        SaveResult(R, 'Nine output quantities and 27 pallet contributions prepared; exact ten-bin receipt assigned to component tracking.');
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    procedure ReleaseOrder(var R: Record "WLF Pool Week Run")
    var P: Record "Production Order"; StatusMgt: Codeunit "Prod. Order Status Management";
    begin
        CheckOrder(R); R.TestField("Production Prepared", true);
        if P.Get(P.Status::Released, R."Batch No.") then exit;
        P.Get(P.Status::"Firm Planned", R."Batch No.");
        StatusMgt.ChangeProdOrderStatus(P, P.Status::Released, R."Test Date", false);
        P.Get(P.Status::Released, R."Batch No."); SaveResult(R, 'Released through standard production status management.');
    end;

    procedure Consume(var R: Record "WLF Pool Week Run")
    var P: Record "Production Order"; C: Record "Prod. Order Component"; J: Record "Item Journal Line";
        E: Record "Item Ledger Entry"; W: Record "Warehouse Entry";
        Tracking: Codeunit "Item Tracking Management"; Post: Codeunit "Item Jnl.-Post Line";
    begin
        CheckOrder(R); R.TestField("Production Prepared", true); R.TestField("Consumption Verified", false);
        P.Get(P.Status::Released, R."Batch No.");
        E.SetRange("Order Type", E."Order Type"::Production); E.SetRange("Order No.", P."No.");
        E.SetRange("Entry Type", E."Entry Type"::Consumption);
        if not E.IsEmpty() then Error('Consumption already exists. Inspect before retrying.');
        C.SetRange(Status, P.Status); C.SetRange("Prod. Order No.", P."No.");
        if C.Count() <> 1 then Error('Expected exactly one component.'); C.FindFirst();
        C.TestField("Expected Quantity", 10); C.TestField("Remaining Quantity", 10);
        ApplyReceiptDimensions(R, C);
        InitJournal(J, R, false, C."Prod. Order Line No.");
        J.Validate("Item No.", 'BIN-HASS'); J.Validate("Prod. Order Comp. Line No.", C."Line No.");
        J.Validate("Location Code", 'MANJIMUP'); J.Validate("Bin Code", R."Receipt Bin Code");
        J.Validate("Unit of Measure Code", 'BIN'); J.Validate(Quantity, 10);
        J.Validate("Dimension Set ID", C."Dimension Set ID"); J.Insert(true);
        Tracking.CopyItemTracking(C.RowID1(), J.RowID1(), false);
        Post.RunWithCheck(J); J.Delete(true);
        E.FindFirst(); if E.Count() <> 1 then Error('Expected one consumption entry.');
        E.TestField(Quantity, -10); E.TestField("Lot No.", R."Delivery Lot No."); E.TestField("Posting Date", R."Test Date");
        E.Get(R."Receipt Entry No."); E.TestField("Remaining Quantity", 0);
        FilterWarehouse(W, R, 'BIN-HASS', false); W.CalcSums("Qty. (Base)"); W.TestField("Qty. (Base)", -10);
        C.FindFirst(); C.CalcFields("Act. Consumption (Qty)"); C.TestField("Act. Consumption (Qty)", 10); C.TestField("Remaining Quantity", 0);
        R."Consumption Verified" := true;
        SaveResult(R, 'Ten bins consumed through normal journal posting; exact receipt exhausted and warehouse quantity reconciled.');
    end;

    local procedure ApplyReceiptDimensions(R: Record "WLF Pool Week Run"; var C: Record "Prod. Order Component")
    var E: Record "Item Ledger Entry"; D: Record "Dimension Set Entry"; L: Record "Prod. Order Line";
        S: Record "Inventory Setup"; NewSet: Integer;
    begin
        // A native batch component need not inherit the selected receipt's dimensions.
        // Carry the actual receipt dimensions into consumption; never guess a block/value.
        E.Get(R."Receipt Entry No."); NewSet := C."Dimension Set ID";
        D.SetRange("Dimension Set ID", E."Dimension Set ID");
        if D.FindSet() then repeat NewSet := M.WithDimension(NewSet, D."Dimension Code", D."Dimension Value Code"); until D.Next() = 0;
        C.Validate("Dimension Set ID", NewSet); C.Modify(true);
        S.Get(); S.TestField("TAC Block Dimension Code"); S.TestField("TAC Grower Dimension Code");
        L.SetRange(Status, C.Status); L.SetRange("Prod. Order No.", C."Prod. Order No.");
        if L.FindSet(true) then repeat
            D.Get(E."Dimension Set ID", S."TAC Block Dimension Code");
            D.TestField("Dimension Value Code", R."Block Code");
            NewSet := M.WithDimension(L."Dimension Set ID", D."Dimension Code", D."Dimension Value Code");
            D.Get(E."Dimension Set ID", S."TAC Grower Dimension Code");
            NewSet := M.WithDimension(NewSet, D."Dimension Code", D."Dimension Value Code");
            L.Validate("Dimension Set ID", NewSet); L.Modify(true);
        until L.Next() = 0;
    end;

    procedure OutputNext(var R: Record "WLF Pool Week Run")
    var O: Record "WLF Pool Week Output"; P: Record "Production Order"; L: Record "Prod. Order Line";
        J: Record "Item Journal Line"; E: Record "Item Ledger Entry"; W: Record "Warehouse Entry";
        Lot: Record "Lot No. Information"; RE: Record "Reservation Entry"; PL: RecordRef;
        PI: Record "DIY_Pallet Information"; CreateR: Codeunit "Create Reserv. Entry";
        Parser: Codeunit "DIY_Pallet Scan Mgt."; Post: Codeunit "Item Jnl.-Post Line";
        Json: JsonObject; Trays: JsonArray; Request: Text; IgnoredPost: Boolean; ParsedPallet: Code[20];
        Serial: Code[50]; N: Integer; ExpectedEntries: Integer; ExpectedQty: Decimal; BeforeWhse: Decimal;
    begin
        CheckOrder(R); R.TestField("Consumption Verified", true); P.Get(P.Status::Released, R."Batch No.");
        O.SetRange("Order Index", R."Order Index"); O.SetRange(Verified, false);
        if not O.FindFirst() then Error('All output pieces already verified.');
        O."Pallet Detail Serials Only" := R."Pallet Detail Serials Only";
        CheckNewPiece(O);
        E.SetRange("Order Type", E."Order Type"::Production); E.SetRange("Order No.", R."Batch No.");
        E.SetRange("Entry Type", E."Entry Type"::Output); E.SetRange("Item No.", O."Item No."); E.SetRange("Lot No.", O."Pallet No.");
        if not E.IsEmpty() then Error('Output for this order/item/pallet already exists; inspect before retrying.');
        L.SetRange(Status, P.Status); L.SetRange("Prod. Order No.", P."No."); L.SetRange("Item No.", O."Item No."); L.FindFirst();
        if L."Remaining Qty. (Base)" < O."Base Quantity" then Error('Remaining output is below the planned contribution.');
        if not Lot.Get(O."Item No.", '', O."Pallet No.") then begin
            Lot.Init(); Lot."Item No." := O."Item No."; Lot."Lot No." := O."Pallet No.";
            Lot.Description := 'TEST W26S21 output pallet'; Lot.Insert(true);
        end;
        for N := 1 to O."Serial Count" do Trays.Add(SerialNo(R, O, N));
        Json.Add('PalletNo', O."Pallet No."); Json.Add('PostOutput', false); Json.Add('PartPallet', false);
        Json.Add('MixedPallet', O.Slot = 3); Json.Add('Trays', Trays); Json.WriteTo(Request);
        ParsedPallet := Parser.ParsePalletData(Request, IgnoredPost);
        if (ParsedPallet <> O."Pallet No.") or IgnoredPost then Error('Unexpected pallet parser response.');
        PL.Open(50117);
        for N := 1 to O."Serial Count" do begin
            Serial := SerialNo(R, O, N); PL.Reset(); PL.Field(1).SetRange(O."Pallet No."); PL.Field(2).SetRange(Serial); PL.FindFirst();
            PL.Field(5).TestField(false); PL.Field(9).TestField(R."Batch No."); PL.Field(6).CalcField(); PL.Field(8).CalcField();
            PL.Field(6).TestField(O."Item No."); PL.Field(8).TestField(R."Grower No.");
        end;
        InitJournal(J, R, true, L."Line No."); J.Validate("Posting Date", O."Posting Date");
        J.Validate("Item No.", O."Item No."); J.Validate("Unit of Measure Code", L."Unit of Measure Code");
        J.Validate("Location Code", 'MANJIMUP'); J.Validate("Bin Code", R."Receipt Bin Code");
        J.Validate("Output Quantity", O."Base Quantity"); J.TestField("Output Quantity (Base)", O."Base Quantity");
        J.Validate("Dimension Set ID", L."Dimension Set ID"); J.Validate("DIY_Pallet No.", O."Pallet No."); J.Insert(true);
        ExpectedEntries := O."Serial Count";
        if (ExpectedEntries = 0) or O."Pallet Detail Serials Only" then ExpectedEntries := 1;
        for N := 1 to ExpectedEntries do begin
            Clear(CreateR); RE.Init(); RE."Lot No." := O."Pallet No."; RE."Package No." := O."Pallet No.";
            RE."Expiration Date" := DMY2Date(21, 10, 2026); RE."Serial No." := '';
            ExpectedQty := O."Base Quantity";
            if (O."Serial Count" > 0) and not O."Pallet Detail Serials Only" then begin RE."Serial No." := SerialNo(R, O, N); ExpectedQty := 1; end;
            CreateR.SetDates(0D, RE."Expiration Date");
            CreateR.CreateReservEntryFor(Database::"Item Journal Line", J."Entry Type".AsInteger(), J."Journal Template Name", J."Journal Batch Name", 0, J."Line No.", 1, ExpectedQty, ExpectedQty, RE);
            CreateR.CreateEntry(O."Item No.", '', 'MANJIMUP', 'TEST W26S21 pallet output', O."Posting Date", O."Posting Date", 0, RE."Reservation Status"::Prospect);
        end;
        FilterWarehouse(W, R, O."Item No.", true); W.CalcSums("Qty. (Base)"); BeforeWhse := W."Qty. (Base)";
        Post.RunWithCheck(J); J.Delete(true);
        O."Ledger Entries" := E.Count(); if O."Ledger Entries" <> ExpectedEntries then Error('Expected %1 output entries, found %2.', ExpectedEntries, O."Ledger Entries");
        E.CalcSums(Quantity); E.TestField(Quantity, O."Base Quantity");
        if E.FindSet() then repeat
            E.TestField("Posting Date", O."Posting Date"); E.TestField("DIY_Pallet No.", O."Pallet No.");
            E.TestField("Package No.", O."Pallet No."); E.TestField("Expiration Date", DMY2Date(21, 10, 2026));
            if (O."Serial Count" > 0) and not O."Pallet Detail Serials Only" then begin
                E.TestField(Quantity, 1); PL.Reset(); PL.Field(1).SetRange(O."Pallet No."); PL.Field(2).SetRange(E."Serial No."); PL.FindFirst(); PL.Field(9).TestField(R."Batch No.");
                if (E."Serial No." < O."First Serial") or (E."Serial No." > O."Last Serial") then Error('Unexpected posted serial.');
            end else E.TestField("Serial No.", '');
        until E.Next() = 0;
        FilterWarehouse(W, R, O."Item No.", true); W.CalcSums("Qty. (Base)");
        O."Warehouse Quantity" := W."Qty. (Base)" - BeforeWhse; O.TestField("Warehouse Quantity", O."Base Quantity");
        PL.Close(); PI.Get(O."Item No.", '', O."Pallet No."); PI.TestField("Lot No.", O."Pallet No.");
        O.Verified := true; O."Verified At" := CurrentDateTime(); O.Modify();
        R."Output Pieces Verified" += 1;
        SaveResult(R, CopyStr(StrSubstNo('Output %1/27 verified: %2, %3 base units, %4 serials.', R."Output Pieces Verified", O."Pallet No.", O."Base Quantity", O."Serial Count"), 1, 2048));
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    procedure FinishOrder(var R: Record "WLF Pool Week Run")
    var P: Record "Production Order"; L: Record "Prod. Order Line"; O: Record "WLF Pool Week Output";
        StatusMgt: Codeunit "Prod. Order Status Management"; LE: Record "TAC Pool Ledger Entry";
    begin
        CheckOrder(R); R.TestField("Consumption Verified", true); R.TestField("Output Pieces Verified", 27);
        if O.Count() <> 1350 then Error('Expected 1,350 order/pallet contributions.');
        O.SetRange(Verified, false); if not O.IsEmpty() then Error('All regular and mixed-pallet contributions must reconcile before finishing.');
        P.Get(P.Status::Released, R."Batch No."); L.SetRange(Status, P.Status); L.SetRange("Prod. Order No.", P."No.");
        if L.FindSet() then repeat L.TestField("Remaining Quantity", 0); L.TestField("Finished Quantity", L.Quantity); until L.Next() = 0;
        StatusMgt.ChangeProdOrderStatus(P, P.Status::Finished, DMY2Date(25, 9, 2026), false);
        P.Get(P.Status::Finished, R."Batch No.");
        LE.SetRange("Source Document No.", R."Batch No."); if LE.IsEmpty() then Error('Order finished but no linked pooling entries were created.');
        R."Finish Verified" := true; SaveResult(R, 'Finished through the installed status handler; pooling entries exist and require financial reconciliation.');
    end;

    local procedure CheckOrder(R: Record "WLF Pool Week Run")
    var H: Record "TAC Batch Plan Header";
    begin
        M.CheckTarget(); R.TestField("Receipt Verified", true); R.TestField("Plan Prepared", true); R.TestField("Batch No.");
        H.Get(R."Plan No."); H.TestField(Status, H.Status::"Orders Created"); H.TestField("Plan Date", R."Test Date");
    end;

    local procedure InitJournal(var J: Record "Item Journal Line"; R: Record "WLF Pool Week Run"; Output: Boolean; OrderLineNo: Integer)
    var T: Record "Item Journal Template"; B: Record "Item Journal Batch";
    begin
        if Output then T.SetRange(Type, T.Type::Output) else T.SetRange(Type, T.Type::Consumption);
        if not T.FindFirst() then Error('A standard journal template is required.');
        if not B.Get(T.Name, 'W26S21') then begin
            B.Init(); B."Journal Template Name" := T.Name; B.Name := 'W26S21';
            B.Description := 'September pooling fixture only'; B.Insert(true);
        end;
        J.SetRange("Journal Template Name", T.Name); J.SetRange("Journal Batch Name", B.Name);
        if not J.IsEmpty() then Error('The dedicated test journal is not empty. Inspect it before retrying.');
        J.Reset(); J.Init(); J."Journal Template Name" := T.Name; J."Journal Batch Name" := B.Name; J."Line No." := 10000;
        if Output then J.Validate("Entry Type", J."Entry Type"::Output) else J.Validate("Entry Type", J."Entry Type"::Consumption);
        J.Validate("Posting Date", R."Test Date"); J."Document No." := R."Batch No."; J."Source Code" := T."Source Code";
        J.Validate("Order Type", J."Order Type"::Production); J.Validate("Order No.", R."Batch No."); J.Validate("Order Line No.", OrderLineNo);
    end;

    local procedure FilterWarehouse(var W: Record "Warehouse Entry"; R: Record "WLF Pool Week Run"; ItemNo: Code[20]; Output: Boolean)
    begin
        W.Reset(); W.SetRange("Location Code", 'MANJIMUP'); W.SetRange("Bin Code", R."Receipt Bin Code");
        W.SetRange("Item No.", ItemNo); W.SetRange("Source No.", R."Batch No.");
        W.SetRange("Source Type", Database::"Item Journal Line");
        if Output then W.SetRange("Source Subtype", 5) else W.SetRange("Source Subtype", 4);
    end;

    local procedure PalletNo(OrderIndex: Integer; ItemIndex: Integer; Slot: Integer): Code[20]
    var N: Integer;
    begin
        if Slot = 3 then N := 900 + ItemIndex else N := (OrderIndex - 1) * 18 + (ItemIndex - 1) * 2 + Slot;
        exit('W26S21P' + Pad(N, 4));
    end;

    local procedure PieceQuantity(OrderIndex: Integer; ItemIndex: Integer; Slot: Integer): Decimal
    var I: Record Item; U: Record "Item Unit of Measure"; Full: Decimal; Prior: Decimal; Current: Decimal; Position: Integer;
    begin
        if ItemIndex <= 6 then Full := 160 else if ItemIndex = 7 then Full := 96 else begin
            I.Get(M.ItemNo(ItemIndex)); U.Get(I."No.", 'KG');
            if ItemIndex = 8 then U.TestField("Qty. per Unit of Measure", 1) else U.TestField("Qty. per Unit of Measure", 9.8);
            // Match the installed pooling engine's physical-kg conversion without changing item setup.
            // At five decimal base precision this gives 440.000008 kg for the 9.8-kg basket.
            Full := Round(440 / U."Qty. per Unit of Measure", 0.00001);
        end;
        if Slot < 3 then exit(Full);
        if ItemIndex <= 7 then begin
            Position := ((OrderIndex - 1 + (ItemIndex - 1) * 10) mod 50) + 1;
            if ItemIndex <= 6 then begin if Position <= 10 then exit(4) else exit(3); end;
            if Position <= 46 then exit(2) else exit(1);
        end;
        Prior := Round(Full * (OrderIndex - 1) / 50, 0.00001);
        Current := Round(Full * OrderIndex / 50, 0.00001); exit(Current - Prior);
    end;

    local procedure SerialNo(R: Record "WLF Pool Week Run"; O: Record "WLF Pool Week Output"; UnitIndex: Integer): Code[50]
    var I: Record Item; Matches: Record Item; Julian: Integer; Sequence: Integer; S: Text; FirstSequence: Integer;
    begin
        // The persisted range was allocated and checked during preparation.
        // Reuse it without repeating the identical item/tag lookup for every tray.
        if O."First Serial" <> '' then begin
            if (StrLen(O."First Serial") <> 24) or (CopyStr(O."First Serial", 5, 4) <> R."Batch No.") or
               (UnitIndex < 1) or (UnitIndex > O."Serial Count") then Error('Invalid prepared serial range.');
            Evaluate(FirstSequence, CopyStr(O."First Serial", 17, 8));
            exit(CopyStr(O."First Serial", 1, 16) + Pad(FirstSequence + UnitIndex - 1, 8));
        end;
        I.Get(O."Item No."); I.TestField("DIY_Label Tag No.");
        if (StrLen(I."DIY_Label Tag No.") <> 4) or (DelChr(I."DIY_Label Tag No.", '=', '0123456789') <> '') then Error('The item needs its existing four-digit label tag.');
        Matches.SetRange("DIY_Label Tag No.", I."DIY_Label Tag No."); if Matches.Count() <> 1 then Error('Item label tag is ambiguous.');
        if (StrLen(R."Batch No.") <> 4) or (DelChr(R."Batch No.", '=', '0123456789') <> '') then Error('Unexpected batch identifier.');
        Julian := O."Posting Date" - DMY2Date(1, 1, 2026) + 1;
        Sequence := (((R."Order Index" - 1) * 9 + O."Item Index" - 1) * 3 + O.Slot - 1) * 200 + UnitIndex;
        S := I."DIY_Label Tag No." + R."Batch No." + '26092' + Pad(Julian, 3) + Pad(Sequence, 8);
        if (StrLen(S) <> 24) or (DelChr(S, '=', '0123456789') <> '') then Error('Invalid generated serial.');
        exit(CopyStr(S, 1, 50));
    end;

    local procedure CheckNewPiece(O: Record "WLF Pool Week Output")
    var E: Record "Item Ledger Entry"; RE: Record "Reservation Entry"; PL: RecordRef;
        PH: RecordRef; PI: Record "DIY_Pallet Information"; Lot: Record "Lot No. Information";
        Other: Record "WLF Pool Week Output";
    begin
        Other.SetRange("Pallet No.", O."Pallet No."); Other.SetRange(Verified, true);
        // A mixed pallet can legitimately already contain other verified order contributions.
        if (O.Slot <> 3) or Other.IsEmpty() then begin
            PH.Open(50118); PH.Field(1).SetRange(O."Pallet No."); if not PH.IsEmpty() then Error('Pallet ID %1 already exists.', O."Pallet No."); PH.Close();
            PI.SetRange("Pallet No.", O."Pallet No."); if not PI.IsEmpty() then Error('Pallet information ID already exists.');
            Lot.SetRange("Lot No.", O."Pallet No."); if not Lot.IsEmpty() then Error('Output lot already exists.');
            E.SetRange("Lot No.", O."Pallet No."); if not E.IsEmpty() then Error('Output lot has existing inventory entries.');
            E.Reset(); RE.SetRange("Lot No.", O."Pallet No."); if not RE.IsEmpty() then Error('Output lot has existing tracking.'); RE.Reset();
        end;
        if O."Serial Count" = 0 then exit;
        E.SetRange("Serial No.", O."First Serial", O."Last Serial"); if not E.IsEmpty() then Error('Generated serial range already has inventory entries.');
        RE.SetRange("Serial No.", O."First Serial", O."Last Serial"); if not RE.IsEmpty() then Error('Generated serial range already has reservation entries.');
        PL.Open(50117); PL.Field(2).SetRange(O."First Serial", O."Last Serial"); if not PL.IsEmpty() then Error('Generated serial range already appears on a pallet.'); PL.Close();
    end;

    local procedure Pad(N: Integer; Width: Integer): Text
    var S: Text;
    begin
        S := Format(N, 0, 9); if StrLen(S) > Width then Error('Identifier allocation overflow.');
        exit(PadStr('', Width - StrLen(S), '0') + S);
    end;

    local procedure SaveResult(var R: Record "WLF Pool Week Run"; Result: Text)
    begin R."Last Result" := CopyStr(Result, 1, MaxStrLen(R."Last Result")); R."Last Run" := CurrentDateTime(); R.Modify(); end;
}
