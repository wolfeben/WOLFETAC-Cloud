codeunit 59351 "WLF Pool E2E Execute"
{
    TableNo = "WLF Pool E2E Case";
    trigger OnRun()
    var Mgt: Codeunit "WLF Pool E2E Management";
    begin
        Mgt.CheckTarget();
        case Rec.Operation of
            Rec.Operation::Pack: Pack(Rec);
            Rec.Operation::Sale: Sale(Rec);
            Rec.Operation::Expense: Expense(Rec);
            Rec.Operation::Adjustment: Adjustment(Rec);
            Rec.Operation::Provisional, Rec.Operation::Final: CloseGroup(Rec);
            Rec.Operation::RepeatProduction: RepeatProduction(Rec);
            Rec.Operation::RepeatInvoice: RepeatInvoice(Rec);
            else Error('This scenario requires manual review.');
        end;
        Rec."Last Run" := CurrentDateTime(); Rec.Modify();
    end;

    local procedure Pack(var C: Record "WLF Pool E2E Case")
    var H: Record "Purchase Header"; PurchaseLine: Record "Purchase Line"; Receipt: Record "Purch. Rcpt. Header"; PO: Record "Production Order";
        PurchPost: Codeunit "Purch.-Post"; StatusMgt: Codeunit "Prod. Order Status Management"; LE: Record "TAC Pool Ledger Entry";
        Qty: Decimal; Rows: Integer;
    begin
        if CopyStr(C."Source No.", 1, 2) <> 'Z2' then Error('Unexpected production test ID.');
        if C."Step No." <> 110 then begin
            Receipt.SetRange("Order No.", C."Related No.");
            if Receipt.IsEmpty() then begin
                H.Get(H."Document Type"::Order, C."Related No."); H.TestField("Buy-from Vendor No.", C."Grower No."); H.TestField("Location Code", 'ZE2E');
                PurchaseLine.SetRange("Document Type", H."Document Type"); PurchaseLine.SetRange("Document No.", H."No.");
                if PurchaseLine.FindSet(true) then repeat
                    PurchaseLine.Validate("Qty. to Receive", PurchaseLine."Outstanding Quantity"); PurchaseLine.Modify(true);
                until PurchaseLine.Next() = 0;
                H.Receive := true; H.Invoice := false; PurchPost.SetSuppressCommit(true); PurchPost.Run(H);
            end;
            Qty := InventoryQuantity(C."Source No.", Enum::"Item Ledger Entry Type"::Consumption);
            if Qty = 0 then PostItem(C, false)
            else if Abs(Qty + C.Quantity / 100) > 0.00001 then Error('Partial consumption exists (%1). Review source before retrying.', Qty);
        end;
        Qty := InventoryQuantity(C."Source No.", Enum::"Item Ledger Entry Type"::Output);
        if Qty = 0 then PostItem(C, true)
        else if Abs(Qty - C.Quantity) > 0.00001 then Error('Partial output exists (%1). Review source before retrying.', Qty);
        if not PO.Get(PO.Status::Finished, C."Source No.") then begin
            PO.Get(PO.Status::Released, C."Source No."); StatusMgt.ChangeProdOrderStatus(PO, PO.Status::Finished, Today(), false);
        end;
        LE.SetRange("Source Document No.", C."Source No."); LE.SetRange("Trans Type Code", 'TR');
        Rows := LE.Count(); LE.CalcSums("Quantity (Kg)", Amount); C."Actual Kg" := LE."Quantity (Kg)"; C."Actual Amount" := LE.Amount;
        C.Status := C.Status::Completed;
        if C."Step No." = 110 then begin
            if Rows <> 0 then C.Status := C.Status::Mismatch;
        end else if (Rows <> 1) or (Abs(C."Actual Kg" - C.Quantity) > 0.00001) or C."Expect Rejection" then C.Status := C.Status::Mismatch;
        LE.Reset(); LE.SetRange("Source Document No.", C."Source No."); LE.SetRange("Trans Type Code", 'PKG'); LE.CalcSums(Amount); C."Actual Amount" := LE.Amount;
        if C."Step No." = 110 then begin
            if LE.Count() <> 0 then C.Status := C.Status::Mismatch;
        end else if (LE.Count() <> 1) or (Abs(LE.Amount + C.Quantity / 10) > 0.01) then C.Status := C.Status::Mismatch;
        C."Actual Result" := CopyStr(StrSubstNo('Production %1 finished through BC. Output %2 kg; %3 TR rows totaling %4 kg. Test PKG charge %5; expected %6 except the repack (zero). Other charges require separate reconciliation. %7', C."Source No.", InventoryQuantity(C."Source No.", Enum::"Item Ledger Entry Type"::Output), Rows, C."Actual Kg", C."Actual Amount", -C.Quantity / 10, Format(C.Status)), 1, 2048);
    end;

    local procedure InventoryQuantity(OrderNo: Code[20]; EntryType: Enum "Item Ledger Entry Type"): Decimal
    var ILE: Record "Item Ledger Entry";
    begin
        ILE.SetRange("Order Type", ILE."Order Type"::Production); ILE.SetRange("Order No.", OrderNo); ILE.SetRange("Entry Type", EntryType);
        ILE.CalcSums(Quantity); exit(ILE.Quantity);
    end;

    local procedure PostItem(C: Record "WLF Pool E2E Case"; Output: Boolean)
    var J: Record "Item Journal Line"; Template: Record "Item Journal Template"; PostLine: Codeunit "Item Jnl.-Post Line";
        Tracking: Record "Reservation Entry"; CreateTracking: Codeunit "Create Reserv. Entry";
    begin
        J.Init(); J."Journal Batch Name" := 'ZE2E'; J."Line No." := C."Step No." * 10000;
        J.Validate("Posting Date", Today()); J."Document No." := 'ZE2E-' + C."Source No.";
        if Output then begin J."Journal Template Name" := 'ZE2E-O'; J.Validate("Entry Type", J."Entry Type"::Output); end
        else begin J."Journal Template Name" := 'ZE2E-C'; J.Validate("Entry Type", J."Entry Type"::Consumption); end;
        Template.Get(J."Journal Template Name"); J."Source Code" := Template."Source Code";
        J.Validate("Order Type", J."Order Type"::Production); J.Validate("Order No.", C."Source No."); J.Validate("Order Line No.", 10000);
        if Output then begin
            J.Validate("Item No.", 'PKD-ZE2E'); J.Validate("Location Code", 'ZE2E'); J.Validate("Output Quantity", C.Quantity); J."Lot No." := C."Source No.";
        end else begin
            J.Validate("Item No.", 'ZE2E-BIN'); J."Prod. Order Comp. Line No." := 10000; J.Validate("Location Code", 'ZE2E'); J.Validate(Quantity, C.Quantity / 100); J."Lot No." := 'ZE2E-R-' + C."Source No.";
        end;
        J."Dimension Set ID" := C."Dimension Set ID";
        J.Insert(true);
        Tracking.Init(); Tracking."Lot No." := J."Lot No.";
        CreateTracking.CreateReservEntryFor(Database::"Item Journal Line", J."Entry Type".AsInteger(), J."Journal Template Name", J."Journal Batch Name", 0, J."Line No.", J."Qty. per Unit of Measure", J.Quantity, J."Quantity (Base)", Tracking);
        CreateTracking.CreateEntry(J."Item No.", J."Variant Code", J."Location Code", 'TEST ONLY - ZE2E production', Today(), Today(), 0, Tracking."Reservation Status"::Prospect);
        // The posting engine splits the line from its tracking specification.
        // Lot numbers belong on that specification, not on the unsplit journal line.
        J."Lot No." := ''; J.Modify(true);
        PostLine.RunWithCheck(J);
        J.Delete(true);
    end;

    local procedure Sale(var C: Record "WLF Pool E2E Case")
    var H: Record "Sales Header"; SalesLine: Record "Sales Line"; I: Record "Sales Invoice Header"; LE: Record "TAC Pool Ledger Entry"; FreightLE: Record "TAC Pool Ledger Entry"; PostSales: Codeunit "Sales-Post";
        CL: Record "TAC Consignment Line"; FirstKg: Decimal; SecondKg: Decimal; FirstAmount: Decimal; SecondAmount: Decimal;
        Mgt: Codeunit "WLF Pool E2E Management"; DimMgt: Codeunit DimensionManagement;
    begin
        if CopyStr(C."Source No.", 1, 7) <> 'ZE2E-S0' then Error('Unexpected sales test ID.');
        I.SetRange("Order No.", C."Source No."); I.SetRange("Sell-to Customer No.", 'ZE2E-CUST');
        if not I.FindFirst() then begin
            if InventoryQuantity(C."Related No.", Enum::"Item Ledger Entry Type"::Output) < C.Quantity - C."Second Quantity" then Error('First batch output is incomplete.');
            if C."Second Quantity" <> 0 then
                if InventoryQuantity(C."Second Source No.", Enum::"Item Ledger Entry Type"::Output) < C."Second Quantity" then Error('Second batch output is incomplete.');
            H.Get(H."Document Type"::Order, C."Source No."); H.TestField("Sell-to Customer No.", 'ZE2E-CUST'); H.TestField("Location Code", 'ZE2E');
            Mgt.PrepareCustomerDimension();
            H."Dimension Set ID" := Mgt.WithCustomerDimension(H."Dimension Set ID");
            DimMgt.UpdateGlobalDimFromDimSetID(H."Dimension Set ID", H."Shortcut Dimension 1 Code", H."Shortcut Dimension 2 Code"); H.Modify(true);
            SalesLine.SetRange("Document Type", H."Document Type"); SalesLine.SetRange("Document No.", H."No.");
            if SalesLine.FindSet(true) then repeat
                SalesLine.Validate("Qty. to Ship", SalesLine."Outstanding Quantity"); SalesLine.Validate("Qty. to Invoice", SalesLine."Outstanding Quantity");
                SalesLine."Dimension Set ID" := Mgt.WithCustomerDimension(SalesLine."Dimension Set ID");
                DimMgt.UpdateGlobalDimFromDimSetID(SalesLine."Dimension Set ID", SalesLine."Shortcut Dimension 1 Code", SalesLine."Shortcut Dimension 2 Code"); SalesLine.Modify(true);
            until SalesLine.Next() = 0;
            H.Ship := true; H.Invoice := true; PostSales.SetSuppressCommit(true); PostSales.Run(H);
            I.FindFirst();
        end;
        C."Posted Document No." := I."No.";
        LE.SetRange("Source Document No.", I."No."); LE.SetRange("Trans Type Code", 'PR');
        LE.CalcSums(Amount, "Quantity (Kg)"); C."Actual Amount" := LE.Amount; C."Actual Kg" := LE."Quantity (Kg)";
        C.Status := C.Status::Completed;
        if (Abs(C."Actual Amount" - C.Quantity * C.Price) > 0.01) or (Abs(C."Actual Kg" - C.Quantity) > 0.00001) then C.Status := C.Status::Mismatch;
        CL.SetRange("Consignment No.", C."Source No."); CL.CalcSums("Quantity (Kg)");
        if Abs(CL."Quantity (Kg)" - C.Quantity) > 0.00001 then C.Status := C.Status::Mismatch;
        FreightLE.SetRange("Source Consignment No.", C."Source No."); FreightLE.SetRange("Trans Type Code", 'FR'); FreightLE.CalcSums(Amount);
        if Abs(FreightLE.Amount + 55) > 0.01 then C.Status := C.Status::Mismatch;
        if C."Second Quantity" <> 0 then begin
            LE.SetRange("Pool Code", LogicalPoolCode(4, 'ZE05')); LE.CalcSums(Amount, "Quantity (Kg)"); FirstAmount := LE.Amount; FirstKg := LE."Quantity (Kg)";
            LE.SetRange("Pool Code", LogicalPoolCode(5, 'ZE06')); LE.CalcSums(Amount, "Quantity (Kg)"); SecondAmount := LE.Amount; SecondKg := LE."Quantity (Kg)";
            if (Abs(FirstAmount - 1200) > 0.01) or (Abs(SecondAmount - 1800) > 0.01) or (FirstKg <> 240) or (SecondKg <> 360) then C.Status := C.Status::Mismatch;
        end;
        C."Actual Result" := CopyStr(StrSubstNo('Posted invoice %1. Expected PR %2 kg / %3 ex tax; observed %4 kg / %5. Consignment allocation kg %6; FR amount %7 (expected -55). No ledger rows or source links were patched by this helper.', I."No.", C.Quantity, C.Quantity * C.Price, C."Actual Kg", C."Actual Amount", CL."Quantity (Kg)", FreightLE.Amount), 1, 2048);
    end;

    local procedure LogicalPoolCode(WeekNo: Integer; Grower: Code[20]): Code[20]
    var P: Record "TAC Pool";
    begin
        P.SetRange("Season Code", 'ZE2E'); P.SetRange("Pool Week", WeekNo); P.SetRange("Pool Type", P."Pool Type"::Internal);
        P.SetRange("Grower No.", Grower); P.SetRange("Variety Code", 'ZE'); P.SetRange("Grade Code", 'ZE1'); P.SetRange("Size Code", 'ZE25');
        if P.Count() <> 1 then Error('Expected exactly one test pool for week %1 / grower %2.', WeekNo, Grower);
        P.FindFirst(); exit(P."Pool Code");
    end;

    local procedure GetGroup(var C: Record "WLF Pool E2E Case"; var G: Record "TAC Pool Group Header")
    var Mgt: Codeunit "WLF Pool E2E Management";
    begin
        G.SetRange("Pool Week Code", Mgt.WeekCode(C."Week No.")); G.SetRange("Grower Pool Type", C."Pool Type");
        if not G.FindFirst() then Error('The test pool group has not been generated yet.');
        C."Engine Group ID" := G."Pool Group ID";
    end;

    local procedure Expense(var C: Record "WLF Pool E2E Case")
    var G: Record "TAC Pool Group Header"; H: Record "TAC Pool Expense Header"; D: Record "TAC Pool Expense Detail";
        T: Record "TAC Pool Trans Type"; P: Record "TAC Pool"; PostExpense: Codeunit "TAC Pool Expense Post"; Amount: Decimal; N: Integer;
    begin
        GetGroup(C, G); H.SetRange(Comment, 'TEST ZE2E expense step 300');
        if H.FindFirst() then Error('Expense %1 already exists. Review it before retrying.', H."Expense ID");
        T.SetRange(Active, true); T.SetRange("Charge Action", T."Charge Action"::RunClose);
        T.SetFilter("GL Account Internal", '<>%1', ''); if not T.FindFirst() then Error('No active packing expense transaction type with a G/L account is configured.');
        H.Init(); H."Pool Group ID" := G."Pool Group ID"; H.Date := Today(); H."Trans Type" := T.Code; H.Amount := -100; H.Comment := 'TEST ZE2E expense step 300'; H.Insert(true);
        P.SetRange("Pool Group ID", G."Pool Group ID"); if not P.FindSet() then Error('No internal test pools.');
        repeat
            case P."Grower No." of 'ZE01': Amount := -60; 'ZE02': Amount := -40; else Error('Unexpected grower in isolated test group.'); end;
            N += 10000; D.Init(); D."Expense ID" := H."Expense ID"; D."Line No." := N; D."Pool Code" := P."Pool Code"; D.Amount := Amount; D.Insert(true);
        until P.Next() = 0;
        D.SetRange("Expense ID", H."Expense ID"); D.CalcSums(Amount); if D.Amount <> -100 then Error('Expected exactly two test pools totaling -100.');
        PostExpense.PostExpense(H); C.Status := C.Status::Completed; C."Actual Amount" := -100;
        C."Actual Result" := StrSubstNo('Expense %1 posted by engine: -60 / -40 using transaction type %2. Verify expense and pool ledger sources.', H."Expense ID", T.Code);
    end;

    local procedure Adjustment(var C: Record "WLF Pool E2E Case")
    var G: Record "TAC Pool Group Header"; A: Record "TAC Pool Adjustment"; P: Record "TAC Pool"; PostAdjustment: Codeunit "TAC Pool Adjustment Post";
        LE: Record "TAC Pool Ledger Entry";
    begin
        GetGroup(C, G); A.SetRange(Comment, 'TEST ZE2E adjustment step 310');
        if A.FindFirst() then Error('Adjustment %1 already exists. Review it before retrying.', A."Adjustment ID");
        A.Init(); A."Pool Group ID" := G."Pool Group ID"; A.Date := Today(); A.Validate("Grower Code", 'ZE01'); A.Kgs := 10;
        P.SetRange("Pool Group ID", G."Pool Group ID"); P.SetRange("Grower No.", 'ZE01'); P.FindFirst(); A."From Pool Code" := P."Pool Code";
        P.SetRange("Grower No.", 'ZE02'); P.FindFirst(); A."To Pool Code" := P."Pool Code";
        A.Comment := 'TEST ZE2E adjustment step 310'; A.Insert(true); PostAdjustment.PostAdjustment(A);
        LE.SetRange("Source Type", LE."Source Type"::Adjustment); LE.SetRange("Source System ID", A.SystemId); LE.CalcSums("Quantity (Kg)");
        C.Status := C.Status::Completed; C."Actual Kg" := LE."Quantity (Kg)";
        if (LE.Count() <> 2) or (C."Actual Kg" <> 0) then C.Status := C.Status::Mismatch;
        C."Actual Result" := StrSubstNo('Adjustment %1 posted; %2 linked rows with net %3 kg. Expected TRA +10, TRD -10.', A."Adjustment ID", LE.Count(), C."Actual Kg");
    end;

    local procedure CloseGroup(var C: Record "WLF Pool E2E Case")
    var G: Record "TAC Pool Group Header"; PH: Record "TAC Pool Payment Header"; CloseMgt: Codeunit "TAC Pool Group Close";
        PT: Enum "TAC Pool Payment Type"; ExpectedPrior: Integer; Before: Integer; S: Record "WLF Pool E2E Case";
    begin
        GetGroup(C, G);
        if not C."Expect Rejection" then begin
            S.SetRange(Operation, S.Operation::Sale); S.SetRange("Week No.", C."Week No.");
            if S.FindSet() then repeat if S.Status <> S.Status::Completed then Error('Sales test %1 has not reconciled. Closing is stopped to preserve the failing evidence.', S."Step No."); until S.Next() = 0;
        end;
        case C."Step No." of 410, 440: ExpectedPrior := 1; 420: ExpectedPrior := 2; else ExpectedPrior := 0; end;
        PH.SetRange("Pool Group ID", G."Pool Group ID"); Before := PH.Count();
        if Before <> ExpectedPrior then Error('Found %1 payment headers; this step expects %2. Review any partial/previous close before retrying.', Before, ExpectedPrior);
        if C.Operation = C.Operation::Final then PT := PT::Final else PT := PT::Provisional;
        CloseMgt.Close(G."Pool Group ID", PT);
        PH.FindLast(); C."Actual Result" := StrSubstNo('Engine returned from close; payment %1, completed %2, purchase documents %3. Verify dollar reconciliation before accepting.', PH."Pool Payment ID", PH."Completed DateTime", PH."Created Purchase Invoice Nos.");
        C.Status := C.Status::Completed;
        if (PH.Count() <> Before + 1) or (PH."Completed DateTime" = 0DT) or C."Expect Rejection" then C.Status := C.Status::Mismatch;
    end;

    local procedure RepeatProduction(var C: Record "WLF Pool E2E Case")
    var P: Record "Production Order"; LE: Record "TAC Pool Ledger Entry"; Post: Codeunit "TAC Pool Prod Order Post"; CountBefore: Integer; KgBefore: Decimal; AmountBefore: Decimal;
    begin
        P.Get(P.Status::Finished, C."Source No."); LE.SetRange("Source Document No.", P."No.");
        CountBefore := LE.Count(); LE.CalcSums(Amount, "Quantity (Kg)"); KgBefore := LE."Quantity (Kg)"; AmountBefore := LE.Amount;
        Post.RunCloseFromProductionOrder(P, Today()); LE.CalcSums(Amount, "Quantity (Kg)");
        C.Status := C.Status::Completed; C."Actual Kg" := LE."Quantity (Kg)"; C."Actual Amount" := LE.Amount;
        if (LE.Count() <> CountBefore) or (LE.Amount <> AmountBefore) or (LE."Quantity (Kg)" <> KgBefore) then C.Status := C.Status::Mismatch;
        C."Actual Result" := StrSubstNo('Before %1 rows / %2 kg / %3; after %4 rows / %5 kg / %6.', CountBefore, KgBefore, AmountBefore, LE.Count(), LE."Quantity (Kg)", LE.Amount);
    end;

    local procedure RepeatInvoice(var C: Record "WLF Pool E2E Case")
    var S: Record "WLF Pool E2E Case"; LE: Record "TAC Pool Ledger Entry"; Post: Codeunit "TAC Pool Consignment Post"; Before: Integer; AmountBefore: Decimal;
    begin
        S.Get(200); S.TestField("Posted Document No."); LE.SetRange("Source Document No.", S."Posted Document No."); Before := LE.Count(); LE.CalcSums(Amount); AmountBefore := LE.Amount;
        Post.ProcessPostedSalesInvoice(S."Posted Document No."); LE.CalcSums(Amount); C.Status := C.Status::Completed;
        if (LE.Count() <> Before) or (LE.Amount <> AmountBefore) then C.Status := C.Status::Mismatch;
        C."Actual Result" := StrSubstNo('Invoice %1 reprocessed. Before %2 rows / %3; after %4 rows / %5.', S."Posted Document No.", Before, AmountBefore, LE.Count(), LE.Amount);
    end;
}
