codeunit 59353 "WLF Pool Week Management"
{
    procedure CheckTarget()
    var Guard: Codeunit "WLF Pool E2E Management";
    begin
        Guard.CheckTarget();
    end;

    procedure SeedManifest()
    var R: Record "WLF Pool Week Run"; V: Record Vendor; D: Integer; G: Integer; B: Integer; N: Integer;
    begin
        CheckTarget(); R.LockTable();
        if not R.IsEmpty() then exit;
        for D := 0 to 4 do
            for G := 1 to 5 do
                for B := 1 to 2 do begin
                    N += 1;
                    R.Init(); R."Order Index" := N; R."Test Date" := DMY2Date(21, 9, 2026) + D;
                    R."Grower No." := GrowerNo(G); V.Get(R."Grower No."); V.TestField(Blocked, V.Blocked::" ");
                    R."Block Code" := BlockNo(G, B); CheckBlock(R."Grower No.", R."Block Code");
                    R."Last Result" := 'Manifest only; source documents not yet created.';
                    R.Insert(true);
                end;
    end;

    procedure RunReceipts(Maximum: Integer)
    var R: Record "WLF Pool Week Run"; IDs: List of [Integer]; N: Integer; Count: Integer;
    begin
        CheckTarget(); SeedManifest(); Commit();
        R.SetRange("Receipt Verified", false);
        if R.FindSet() then repeat
            if Count < Maximum then begin IDs.Add(R."Order Index"); Count += 1; end;
        until R.Next() = 0;
        foreach N in IDs do if not RunStep(N, 1) then exit;
    end;

    procedure RunPlans()
    var R: Record "WLF Pool Week Run"; D: Integer;
    begin
        CheckTarget(); R.SetRange("Receipt Verified", true);
        if R.Count() <> 50 then Error('All 50 receipts must reconcile before batch plans are prepared.');
        for D := 0 to 4 do begin
            R.Get(D * 10 + 1);
            if not R."Plan Prepared" then if not RunStep(R."Order Index", 2) then exit;
        end;
    end;

    local procedure RunStep(N: Integer; Operation: Integer): Boolean
    var R: Record "WLF Pool Week Run"; OldWorkDate: Date; Failure: Text; OK: Boolean;
    begin
        CheckTarget(); R.Get(N); R."Operation No." := Operation; R.Modify(); Commit();
        OldWorkDate := WorkDate(); WorkDate(R."Test Date"); ClearLastError();
        OK := Codeunit.Run(Codeunit::"WLF Pool Week Execute", R);
        Failure := GetLastErrorText() + ' | ' + GetLastErrorCallStack();
        WorkDate(OldWorkDate);
        if not OK then begin
            R.Get(N); R."Last Result" := CopyStr(Failure, 1, MaxStrLen(R."Last Result"));
            R."Last Run" := CurrentDateTime(); R.Modify();
        end;
        Commit(); exit(OK);
    end;

    procedure RunProduction(Maximum: Integer)
    var R: Record "WLF Pool Week Run"; IDs: List of [Integer]; N: Integer; Count: Integer;
    begin
        CheckTarget(); R.SetRange("Consumption Verified", false);
        if R.FindSet() then repeat
            if Count < Maximum then begin IDs.Add(R."Order Index"); Count += 1; end;
        until R.Next() = 0;
        foreach N in IDs do begin
            R.Get(N);
            if not R."Production Prepared" then if not RunStep(N, 3) then exit;
            if not RunStep(N, 4) then exit;
            if not RunStep(N, 5) then exit;
        end;
    end;

    procedure RunOutputs(Maximum: Integer)
    var O: Record "WLF Pool Week Output"; R: Record "WLF Pool Week Run"; N: Integer;
    begin
        CheckTarget();
        for N := 1 to Maximum do begin
            O.Reset(); O.SetRange(Verified, false);
            if not O.FindFirst() then exit;
            R.Get(O."Order Index"); R.TestField("Consumption Verified", true);
            if not RunStep(R."Order Index", 6) then exit;
        end;
    end;

    procedure RunFinish(Maximum: Integer)
    var R: Record "WLF Pool Week Run"; IDs: List of [Integer]; N: Integer; Count: Integer;
    begin
        CheckTarget(); R.SetRange("Finish Verified", false);
        if R.FindSet() then repeat
            if Count < Maximum then begin IDs.Add(R."Order Index"); Count += 1; end;
        until R.Next() = 0;
        foreach N in IDs do if not RunStep(N, 7) then exit;
    end;

    procedure CheckBlock(VendorNo: Code[20]; BlockCode: Code[20])
    var R: RecordRef; D: Record "Dimension Value";
    begin
        R.Open(50905); R.Field(1).SetRange(VendorNo); R.Field(2).SetRange(BlockCode);
        if R.Count() <> 1 then Error('Expected one existing block mapping for %1 / %2.', VendorNo, BlockCode);
        R.Close(); D.Get('BLOCK', BlockCode); D.TestField(Blocked, false);
    end;

    procedure GrowerNo(N: Integer): Code[20]
    begin
        case N of 1: exit('GRW-100'); 2: exit('GRW-102'); 3: exit('GRW-030'); 4: exit('GRW-064'); 5: exit('GRW-049'); end;
        Error('Invalid grower index.');
    end;

    procedure BlockNo(G: Integer; B: Integer): Code[20]
    begin
        case G of
            1: if B = 1 then exit('100-A') else exit('100-BE');
            2: if B = 1 then exit('102-A') else exit('102-B');
            3: if B = 1 then exit('030-BA') else exit('030-BB');
            4: if B = 1 then exit('064-A') else exit('064-B');
            5: if B = 1 then exit('049-A1') else exit('049-B');
        end;
        Error('Invalid block index.');
    end;

    procedure ItemNo(N: Integer): Code[20]
    begin
        case N of
            1: exit('PKD-HATYGL25PR'); 2: exit('PKD-HATYGL23PR'); 3: exit('PKD-HATYGL20PR');
            4: exit('PKD-HATYAV25C1'); 5: exit('PKD-HATYAV23C1'); 6: exit('PKD-HATYAV20C1');
            7: exit('PKD-HABKGL1KPR'); 8: exit('PKD-HAKGMXPG'); 9: exit('PKD-HABKBN1KPP');
        end;
        Error('Invalid item index.');
    end;

    procedure WithDimension(OldSet: Integer; DimCode: Code[20]; ValueCode: Code[20]): Integer
    var D: Record "Dimension Set Entry" temporary; V: Record "Dimension Value"; M: Codeunit DimensionManagement;
    begin
        V.Get(DimCode, ValueCode); V.TestField(Blocked, false); M.GetDimensionSet(D, OldSet);
        if D.Get(OldSet, DimCode) then begin
            if D."Dimension Value Code" = ValueCode then exit(OldSet);
            D.Validate("Dimension Value Code", ValueCode); D.Modify();
        end else begin
            D.Init(); D."Dimension Set ID" := OldSet; D."Dimension Code" := DimCode;
            D.Validate("Dimension Value Code", ValueCode); D.Insert();
        end;
        exit(M.GetDimensionSetID(D));
    end;

    procedure Snapshot(): Text
    var R: Record "WLF Pool Week Run"; J: JsonObject; A: JsonArray; Row: JsonObject; Result: Text;
        I: Record Item; U: Record "Item Unit of Measure"; T: Record "Item Tracking Code"; L: Record Location;
        Extra: JsonObject; Units: JsonArray; V: Record Vendor; Vs: JsonArray; N: Integer;
        ILE: Record "Item Ledger Entry"; W: Record "Warehouse Entry"; H: Record "TAC Batch Plan Header";
        G: Record "TAC Batch Plan Grower"; Lane: Record "TAC Batch Plan Lane"; PO: Record "Production Order";
        Evidence: JsonObject; O: Record "WLF Pool Week Output"; Outputs: JsonArray; Summary: JsonObject;
        PL: Record "Prod. Order Line"; Components: Record "Prod. Order Component"; Lines: JsonArray; Detail: JsonObject;
    begin
        CheckTarget(); J.Add('environment', 'Pool_Sandbox'); J.Add('company', CompanyName());
        J.Add('readAt', CurrentDateTime());
        I.Get('BIN-HASS'); Extra.Add('binItem', I."No."); Extra.Add('expirationFormula', Format(I."Expiration Calculation"));
        T.Get(I."Item Tracking Code"); Extra.Add('expirationRequired', T."Man. Expir. Date Entry Reqd.");
        Extra.Add('warehouseLotTracking', T."Lot Warehouse Tracking");
        U.SetRange("Item No.", I."No."); if U.FindSet() then repeat
            Clear(Row); Row.Add('unit', U.Code); Row.Add('baseQtyPerUnit', U."Qty. per Unit of Measure"); Units.Add(Row);
        until U.Next() = 0;
        Extra.Add('binUnits', Units); L.Get('MANJIMUP'); Extra.Add('binMandatory', L."Bin Mandatory");
        Extra.Add('requireReceive', L."Require Receive"); Extra.Add('requirePutAway', L."Require Put-away");
        Extra.Add('directedPutAwayPick', L."Directed Put-away and Pick");
        Extra.Add('toProductionBin', L."To-Production Bin Code"); Extra.Add('fromProductionBin', L."From-Production Bin Code");
        for N := 1 to 5 do begin V.Get(GrowerNo(N)); Clear(Row); Row.Add('vendor', V."No."); Row.Add('deliveryGrowerCode', V."TAC Grower Code"); Vs.Add(Row); end;
        Extra.Add('growers', Vs); J.Add('additionalSetup', Extra);
        if R.FindSet() then repeat
            Clear(Row); Row.Add('orderIndex', R."Order Index"); Row.Add('date', R."Test Date");
            Row.Add('grower', R."Grower No."); Row.Add('block', R."Block Code"); Row.Add('purchaseOrder', R."Purchase Order No.");
            Row.Add('deliveryLot', R."Delivery Lot No."); Row.Add('receiptEntry', R."Receipt Entry No.");
            Row.Add('receiptBin', R."Receipt Bin Code");
            Row.Add('receiptVerified', R."Receipt Verified"); Row.Add('plan', R."Plan No."); Row.Add('batch', R."Batch No.");
            Row.Add('planPrepared', R."Plan Prepared"); Row.Add('lastResult', R."Last Result");
            Row.Add('productionPrepared', R."Production Prepared"); Row.Add('consumptionVerified', R."Consumption Verified");
            Row.Add('outputPiecesVerified', R."Output Pieces Verified"); Row.Add('finishVerified', R."Finish Verified");
            Clear(Evidence);
            if ILE.Get(R."Receipt Entry No.") then begin
                Evidence.Add('receivedBins', ILE.Quantity); Evidence.Add('remainingBins', ILE."Remaining Quantity");
                Evidence.Add('receiptGrower', ILE."Source No."); Evidence.Add('receiptDate', ILE."Posting Date");
                W.Reset(); W.SetRange("Location Code", 'MANJIMUP'); W.SetRange("Item No.", 'BIN-HASS');
                W.SetRange("Source Type", Database::"Purchase Line"); W.SetRange("Source Subtype", 1);
                W.SetRange("Source No.", R."Purchase Order No."); W.SetRange("Source Line No.", 10000);
                W.SetRange("Reference No.", ILE."Document No."); W.SetRange("Bin Code", R."Receipt Bin Code");
                W.CalcSums("Qty. (Base)"); Evidence.Add('warehouseBinsReceived', W."Qty. (Base)");
                Evidence.Add('postedReceipt', ILE."Document No.");
            end;
            if H.Get(R."Plan No.") then begin
                Evidence.Add('planDate', H."Plan Date"); Evidence.Add('planStatus', Format(H.Status));
                G.Reset(); G.SetRange("Batch Plan No.", H."No."); G.SetRange("Batch No.", R."Batch No.");
                if G.FindFirst() then begin
                    G.CalcFields("Total Bins", "Total Lanes"); Evidence.Add('batchBins', G."Total Bins");
                    Evidence.Add('batchOutlets', G."Total Lanes");
                end;
                Lane.Reset(); Lane.SetRange("Batch Plan No.", H."No."); Lane.SetRange("Batch No.", R."Batch No.");
                Evidence.Add('outletRows', Lane.Count());
                PO.Reset(); PO.SetRange("No.", R."Batch No.");
                if PO.FindFirst() then begin
                    Evidence.Add('productionStatus', Format(PO.Status));
                    Clear(Lines); PL.Reset(); PL.SetRange(Status, PO.Status); PL.SetRange("Prod. Order No.", PO."No.");
                    if PL.FindSet() then repeat
                        Clear(Detail); Detail.Add('item', PL."Item No."); Detail.Add('quantity', PL.Quantity);
                        Detail.Add('baseQuantity', PL."Quantity (Base)"); Detail.Add('finished', PL."Finished Quantity");
                        Detail.Add('remaining', PL."Remaining Quantity"); Detail.Add('unit', PL."Unit of Measure Code"); Lines.Add(Detail);
                    until PL.Next() = 0;
                    Evidence.Add('outputLines', Lines);
                    Components.Reset(); Components.SetRange(Status, PO.Status); Components.SetRange("Prod. Order No.", PO."No.");
                    if Components.FindFirst() then begin
                        Components.CalcFields("Act. Consumption (Qty)"); Evidence.Add('expectedBins', Components."Expected Quantity");
                        Evidence.Add('consumedBins', Components."Act. Consumption (Qty)"); Evidence.Add('remainingComponentBins', Components."Remaining Quantity");
                    end;
                end;
            end;
            Row.Add('sourceEvidence', Evidence); A.Add(Row);
        until R.Next() = 0;
        J.Add('deliveries', A);
        Summary.Add('plannedContributions', O.Count()); O.SetRange(Verified, true);
        Summary.Add('verifiedContributions', O.Count()); O.CalcSums("Serial Count", "Ledger Entries");
        Summary.Add('verifiedSerials', O."Serial Count"); Summary.Add('verifiedOutputEntries', O."Ledger Entries");
        J.Add('outputSummary', Summary); O.Reset();
        if O.FindSet() then repeat
            Clear(Detail); Detail.Add('orderIndex', O."Order Index"); Detail.Add('item', O."Item No."); Detail.Add('slot', O.Slot);
            Detail.Add('palletAndLot', O."Pallet No."); Detail.Add('baseQuantity', O."Base Quantity"); Detail.Add('date', O."Posting Date");
            Detail.Add('serials', O."Serial Count"); Detail.Add('firstSerial', O."First Serial"); Detail.Add('lastSerial', O."Last Serial");
            Detail.Add('verified', O.Verified); Detail.Add('entries', O."Ledger Entries"); Detail.Add('warehouseQuantity', O."Warehouse Quantity"); Outputs.Add(Detail);
        until O.Next() = 0;
        J.Add('outputContributions', Outputs); J.WriteTo(Result); exit(Result);
    end;

    procedure OpenNextPlan()
    var R: Record "WLF Pool Week Run"; H: Record "TAC Batch Plan Header";
    begin
        CheckTarget(); R.SetRange("Plan Prepared", true);
        if R.FindSet() then repeat
            H.Get(R."Plan No.");
            if H.Status <> H.Status::"Orders Created" then begin H.SetRecFilter(); Page.Run(Page::"TAC Batch Plan", H); exit; end;
        until R.Next() = 0;
        Message('No prepared plan is waiting for production order creation.');
    end;

    procedure DownloadEvidence()
    var Blob: Codeunit "Temp Blob"; Output: OutStream; Input: InStream; FileName: Text;
    begin
        CheckTarget(); Blob.CreateOutStream(Output, TextEncoding::UTF8); Output.WriteText(Snapshot());
        Blob.CreateInStream(Input, TextEncoding::UTF8); FileName := 'Pooling-September-run-evidence.json';
        DownloadFromStream(Input, '', '', '', FileName);
    end;
}
