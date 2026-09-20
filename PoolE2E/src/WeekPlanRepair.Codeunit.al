codeunit 59356 "WLF Pool Week Plan Repair"
{
    // Data correction for the explicitly identified September fixture only.
    // No posting, status transition, ledger write, deletion or batch renumbering.
    [CommitBehavior(CommitBehavior::Error)]
    procedure SeparatePlans()
    var
        R: Record "WLF Pool Week Run";
        H: Record "TAC Batch Plan Header";
        G: Record "TAC Batch Plan Grower";
        Lot: Record "TAC Batch Plan Lot";
        Lane: Record "TAC Batch Plan Lane";
        P: Record "Production Order";
        M: Codeunit "WLF Pool Week Management";
        N: Integer;
        OriginalPlan: Code[20];
        Grouped: Boolean;
    begin
        M.CheckTarget();
        R.LockTable(); H.LockTable(); G.LockTable(); Lot.LockTable(); Lane.LockTable(); P.LockTable();
        if R.Count() <> 50 then Error('Expected exactly the 50 September delivery records.');
        for N := 1 to 50 do begin
            R.Get(N);
            CheckDelivery(R);
            H.Get(R."Plan No."); H.CalcFields("No. of Batches");
            if H."No. of Batches" <> 1 then Grouped := true;
        end;
        if not Grouped then begin
            CheckSeparatedPlans();
            Message('All 50 September deliveries already have separate grower/block/day plans. No records changed.');
            exit;
        end;

        // Reject partially rearranged or manually changed plans before any write.
        for N := 1 to 50 do begin
            R.Get(N); OriginalPlan := OriginalPlanNo(N);
            R.TestField("Plan No.", OriginalPlan);
            if ((N - 1) mod 10) = 0 then CheckOriginalPlan(OriginalPlan);
        end;
        // Keep each day's first existing plan, and move the other nine batches
        // with their lot/outlet rows. Rename preserves their SystemIds.
        for N := 1 to 50 do
            if ((N - 1) mod 10) <> 0 then begin
                R.Get(N); MoveDelivery(R);
            end;
        for N := 0 to 4 do begin
            H.Get(OriginalPlanNo(N * 10 + 1));
            H."Version No." += 1; H."Version DateTime" := CurrentDateTime(); H.Modify(true);
        end;
        CheckSeparatedPlans();
        Message('September dataset corrected to 50 plans: one grower, one block and one day per plan. Existing batch/order numbers, posted entries, pallets and serials are retained. No orders were finished.');
    end;

    local procedure CheckDelivery(R: Record "WLF Pool Week Run")
    var
        H: Record "TAC Batch Plan Header";
        G: Record "TAC Batch Plan Grower";
        Lot: Record "TAC Batch Plan Lot";
        Lane: Record "TAC Batch Plan Lane";
        P: Record "Production Order";
        E: Record "Item Ledger Entry";
        PoolEntry: Record "TAC Pool Ledger Entry";
        M: Codeunit "WLF Pool Week Management";
        GrowerIndex: Integer;
    begin
        R.TestField("Test Date", DMY2Date(21, 9, 2026) + ((R."Order Index" - 1) div 10));
        GrowerIndex := (((R."Order Index" - 1) mod 10) div 2) + 1;
        R.TestField("Grower No.", M.GrowerNo(GrowerIndex));
        R.TestField("Batch No.", Format(1206 + R."Order Index", 0, 9));
        R.TestField("Receipt Entry No.", 41119 + R."Order Index");
        R.TestField("Receipt Verified", true); R.TestField("Plan Prepared", true);
        R.TestField("Consumption Verified", true); R.TestField("Finish Verified", false);
        M.CheckBlock(R."Grower No.", R."Block Code");
        H.Get(R."Plan No."); H.TestField("Plan Date", R."Test Date");
        H.TestField("Item No.", 'BIN-HASS'); H.TestField(Status, H.Status::"Orders Created");
        P.SetRange("No.", R."Batch No.");
        if P.Count() <> 1 then Error('Expected one production order for batch %1.', R."Batch No.");
        P.FindFirst(); P.TestField(Status, P.Status::Released);
        P.CalcFields("Grower ID", "Batch Plan No.");
        P.TestField("Grower ID", R."Grower No."); P.TestField("Batch Plan No.", R."Plan No.");
        PoolEntry.SetRange("Source Document No.", P."No.");
        if not PoolEntry.IsEmpty() then Error('Batch %1 already has pooling entries. Review before changing its plan.', P."No.");
        G.SetRange("Batch No.", R."Batch No.");
        if G.Count() <> 1 then Error('Batch %1 has an ambiguous plan mapping.', R."Batch No.");
        G.FindFirst(); G.TestField("Batch Plan No.", R."Plan No.");
        G.TestField("Vendor No.", R."Grower No."); G.TestField("Block Code", R."Block Code");
        G.TestField("Prod. Order No.", P."No."); G.TestField("Prod. Order Created", true);
        G.CalcFields("Total Bins", "Total Lanes"); G.TestField("Total Bins", 10); G.TestField("Total Lanes", 9);
        Lot.SetRange("Batch No.", R."Batch No.");
        if Lot.Count() <> 1 then Error('Expected one original bin delivery for batch %1.', R."Batch No.");
        Lot.FindFirst(); Lot.TestField("Batch Plan No.", R."Plan No.");
        Lot.TestField("Grower Line No.", G."Line No."); Lot.TestField("Sequence No.", G."Sequence No.");
        Lot.TestField("Vendor No.", R."Grower No."); Lot.TestField("Block Code", R."Block Code");
        Lot.TestField("Lot No.", R."Delivery Lot No."); Lot.TestField("ILE Entry No.", R."Receipt Entry No.");
        E.Get(R."Receipt Entry No."); E.TestField("Source No.", R."Grower No."); E.TestField(Quantity, 10);
        E.TestField("Lot No.", R."Delivery Lot No.");
        Lane.SetRange("Batch No.", R."Batch No.");
        if Lane.Count() <> 9 then Error('Expected nine outlet rows for batch %1.', R."Batch No.");
        Lane.FindSet(); repeat
            Lane.TestField("Batch Plan No.", R."Plan No."); Lane.TestField("Sequence No.", G."Sequence No.");
        until Lane.Next() = 0;
    end;

    local procedure CheckOriginalPlan(PlanNo: Code[20])
    var G: Record "TAC Batch Plan Grower"; Lot: Record "TAC Batch Plan Lot"; Lane: Record "TAC Batch Plan Lane";
    begin
        G.SetRange("Batch Plan No.", PlanNo); Lot.SetRange("Batch Plan No.", PlanNo); Lane.SetRange("Batch Plan No.", PlanNo);
        if (G.Count() <> 10) or (Lot.Count() <> 10) or (Lane.Count() <> 90) then
            Error('Original plan %1 no longer has its expected 10 batches, 10 lots and 90 outlets. No correction applied.', PlanNo);
    end;

    local procedure MoveDelivery(var R: Record "WLF Pool Week Run")
    var
        OldHeader: Record "TAC Batch Plan Header";
        NewHeader: Record "TAC Batch Plan Header";
        G: Record "TAC Batch Plan Grower";
        Lot: Record "TAC Batch Plan Lot";
        Lane: Record "TAC Batch Plan Lane";
        TempLane: Record "TAC Batch Plan Lane" temporary;
        OriginalPlan: Code[20];
    begin
        OriginalPlan := R."Plan No."; OldHeader.Get(OriginalPlan);
        NewHeader.Init(); NewHeader."Plan Date" := OldHeader."Plan Date"; NewHeader.Insert(true);
        NewHeader.Validate("Item No.", OldHeader."Item No."); NewHeader.Shift := OldHeader.Shift;
        NewHeader.Status := OldHeader.Status;
        NewHeader."Version No." := 1; NewHeader."Version DateTime" := CurrentDateTime(); NewHeader.Modify(true);
        G.SetRange("Batch No.", R."Batch No."); G.FindFirst();
        G.Rename(NewHeader."No.", G."Line No.");
        // Re-read by immutable batch after Rename, allowing BC's related-field
        // propagation if it moved the lot's composite parent reference itself.
        Lot.SetRange("Batch No.", R."Batch No."); Lot.FindFirst();
        if Lot."Batch Plan No." = OriginalPlan then Lot.Rename(NewHeader."No.", Lot."Line No.")
        else Lot.TestField("Batch Plan No.", NewHeader."No.");
        Lane.SetRange("Batch No.", R."Batch No.");
        Lane.FindSet(); repeat TempLane := Lane; TempLane.Insert(); until Lane.Next() = 0;
        TempLane.FindSet(); repeat
            Lane.Get(TempLane."Batch Plan No.", TempLane."Item No.", TempLane."Lane No.", TempLane."Sequence No.");
            if Lane."Batch Plan No." = OriginalPlan then
                Lane.Rename(NewHeader."No.", Lane."Item No.", Lane."Lane No.", Lane."Sequence No.")
            else Lane.TestField("Batch Plan No.", NewHeader."No.");
        until TempLane.Next() = 0;
        R."Plan No." := NewHeader."No.";
        R."Last Result" := CopyStr(StrSubstNo('Plan grouping corrected from %1 to %2 for %3 / %4 / %5. Batch and production order %6 retained; posted entries unchanged.', OriginalPlan, R."Plan No.", R."Grower No.", R."Block Code", R."Test Date", R."Batch No."), 1, MaxStrLen(R."Last Result"));
        R."Last Run" := CurrentDateTime(); R.Modify(true);
    end;

    local procedure CheckSeparatedPlans()
    var R: Record "WLF Pool Week Run"; H: Record "TAC Batch Plan Header"; Plans: List of [Code[20]];
    begin
        R.FindSet(); repeat
            CheckDelivery(R);
            if Plans.Contains(R."Plan No.") then Error('Two deliveries still share plan %1.', R."Plan No.");
            Plans.Add(R."Plan No.");
            H.Get(R."Plan No."); H.CalcFields("No. of Batches", "Total Bins");
            H.TestField("No. of Batches", 1); H.TestField("Total Bins", 10);
        until R.Next() = 0;
        if Plans.Count() <> 50 then Error('Expected 50 unique corrected plans.');
    end;

    local procedure OriginalPlanNo(OrderIndex: Integer): Code[20]
    begin
        exit('BP00' + Format(68 + ((OrderIndex - 1) div 10), 0, 9));
    end;
}
