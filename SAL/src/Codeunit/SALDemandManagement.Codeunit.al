codeunit 58000 "SAL Demand Management"
{
    Permissions =
        tabledata "Sales Header" = r,
        tabledata "Sales Line" = r,
        tabledata "Transfer Header" = r,
        tabledata "Transfer Line" = r,
        tabledata Customer = r,
        tabledata Item = r,
        tabledata Location = r;

    procedure AddDemand(var PlanHeader: Record "SAL Plan Header")
    var
        DemandTypeChoice: Integer;
    begin
        RefreshDraftPlan(PlanHeader);
        DemandTypeChoice := StrMenu(DemandTypeOptionsTxt, 1, DemandTypeInstructionTxt);
        case DemandTypeChoice of
            1:
                AddSalesDemand(PlanHeader);
            2:
                AddTransferDemand(PlanHeader);
        end;
    end;

    procedure RefreshDemand(var PlanHeader: Record "SAL Plan Header")
    var
        PlanSource: Record "SAL Plan Source";
        RefreshedCount: Integer;
    begin
        PlanHeader.LockTable();
        RefreshDraftPlan(PlanHeader);
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        if not PlanSource.FindSet(true) then
            Error(NoDemandToRefreshErr);

        repeat
            case PlanSource."Source Type" of
                PlanSource."Source Type"::SalesOrder:
                    RefreshSalesSource(PlanSource);
                PlanSource."Source Type"::TransferOrder:
                    RefreshTransferSource(PlanSource);
            end;
            ValidateProtectedAllocationAfterRefresh(PlanSource);
            NormaliseFulfilmentMode(PlanSource);
            PlanSource.Modify(true);
            RefreshedCount += 1;
        until PlanSource.Next() = 0;

        PlanHeader.Get(PlanHeader."No.", PlanHeader."Version No.");
        Message(DemandRefreshedMsg, RefreshedCount);
    end;

    local procedure ValidateProtectedAllocationAfterRefresh(var PlanSource: Record "SAL Plan Source")
    begin
        PlanSource.CalcFields("Exact Planned Quantity", "Fill Planned Quantity");
        if PlanSource."Fill Target Quantity" > PlanSource.Quantity then
            Error(RefreshedBelowFillTargetErr, PlanSource."Line No.", PlanSource.Quantity, PlanSource."Fill Target Quantity");
        if PlanSource."Exact Planned Quantity" > PlanSource.Quantity - PlanSource."Fill Target Quantity" then
            Error(
                RefreshedBelowExactAllocationErr,
                PlanSource."Line No.", PlanSource.Quantity, PlanSource."Exact Planned Quantity", PlanSource."Fill Target Quantity");
        if PlanSource."Fill Planned Quantity" > PlanSource."Fill Target Quantity" then
            Error(RefreshedBelowFillAllocationErr, PlanSource."Line No.", PlanSource."Fill Target Quantity", PlanSource."Fill Planned Quantity");
    end;

    local procedure NormaliseFulfilmentMode(var PlanSource: Record "SAL Plan Source")
    begin
        if PlanSource."Fill Target Quantity" = 0 then
            PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::ExactSKU
        else
            if PlanSource."Fill Target Quantity" = PlanSource.Quantity then
                PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::FillGroup
            else
                PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::Hybrid;
    end;

    procedure AddSalesOrderDemand(var PlanHeader: Record "SAL Plan Header"; SalesOrderNo: Code[20]; var AddedCount: Integer; var SkippedCount: Integer)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        AddedCount := 0;
        SkippedCount := 0;
        RefreshDraftPlan(PlanHeader);
        GetSalesHeader(SalesOrderNo, SalesHeader);
        SalesHeader.TestField(Status, SalesHeader.Status::Released);

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesOrderNo);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        if SalesLine.FindSet() then
            repeat
                if AddSalesLine(PlanHeader, SalesLine) then
                    AddedCount += 1
                else
                    SkippedCount += 1;
            until SalesLine.Next() = 0;

        PlanHeader.Get(PlanHeader."No.", PlanHeader."Version No.");
    end;

    procedure AddTransferOrderDemand(var PlanHeader: Record "SAL Plan Header"; TransferOrderNo: Code[20]; var AddedCount: Integer; var SkippedCount: Integer)
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
    begin
        AddedCount := 0;
        SkippedCount := 0;
        RefreshDraftPlan(PlanHeader);
        GetTransferHeader(TransferOrderNo, TransferHeader);
        TransferHeader.TestField(Status, TransferHeader.Status::Released);

        TransferLine.SetRange("Document No.", TransferOrderNo);
        TransferLine.SetFilter("Item No.", '<>%1', '');
        TransferLine.SetFilter("Outstanding Quantity", '>0');
        if TransferLine.FindSet() then
            repeat
                if AddTransferLine(PlanHeader, TransferLine) then
                    AddedCount += 1
                else
                    SkippedCount += 1;
            until TransferLine.Next() = 0;

        PlanHeader.Get(PlanHeader."No.", PlanHeader."Version No.");
    end;

    local procedure AddSalesDemand(var PlanHeader: Record "SAL Plan Header")
    var
        SalesLine: Record "Sales Line";
        SalesLines: Page "Sales Lines";
        AddedCount: Integer;
        SkippedCount: Integer;
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetFilter("Outstanding Quantity", '>0');
        SalesLines.SetTableView(SalesLine);
        SalesLines.LookupMode(true);
        if SalesLines.RunModal() <> Action::LookupOK then
            exit;

        SalesLines.SetSelectionFilter(SalesLine);
        if SalesLine.FindSet() then
            repeat
                if AddSalesLine(PlanHeader, SalesLine) then
                    AddedCount += 1
                else
                    SkippedCount += 1;
            until SalesLine.Next() = 0;

        PlanHeader.Get(PlanHeader."No.", PlanHeader."Version No.");
        Message(DemandAddedMsg, AddedCount, SkippedCount);
    end;

    local procedure AddTransferDemand(var PlanHeader: Record "SAL Plan Header")
    var
        TransferLine: Record "Transfer Line";
        TransferLines: Page "Transfer Lines";
        AddedCount: Integer;
        SkippedCount: Integer;
    begin
        TransferLine.SetFilter("Item No.", '<>%1', '');
        TransferLine.SetFilter("Outstanding Quantity", '>0');
        TransferLines.SetTableView(TransferLine);
        TransferLines.LookupMode(true);
        if TransferLines.RunModal() <> Action::LookupOK then
            exit;

        TransferLines.SetSelectionFilter(TransferLine);
        if TransferLine.FindSet() then
            repeat
                if AddTransferLine(PlanHeader, TransferLine) then
                    AddedCount += 1
                else
                    SkippedCount += 1;
            until TransferLine.Next() = 0;

        PlanHeader.Get(PlanHeader."No.", PlanHeader."Version No.");
        Message(DemandAddedMsg, AddedCount, SkippedCount);
    end;

    local procedure AddSalesLine(var PlanHeader: Record "SAL Plan Header"; SalesLine: Record "Sales Line"): Boolean
    var
        PlanSource: Record "SAL Plan Source";
        SalesHeader: Record "Sales Header";
    begin
        PlanHeader.LockTable();
        RefreshDraftPlan(PlanHeader);
        GetSalesHeader(SalesLine."Document No.", SalesHeader);
        ValidateSalesDemandIsAvailable(SalesHeader, SalesLine);
        if SourceAlreadyExists(PlanHeader, PlanSource."Source Type"::SalesOrder, SalesLine."Document No.", SalesLine."Line No.") then
            exit(false);

        PlanSource.Init();
        PlanSource."Plan No." := PlanHeader."No.";
        PlanSource."Version No." := PlanHeader."Version No.";
        PlanSource."Source Type" := PlanSource."Source Type"::SalesOrder;
        PlanSource."Source Document No." := SalesLine."Document No.";
        PlanSource."Source Document Line No." := SalesLine."Line No.";
        PlanSource.Priority := PlanHeader.Priority;
        ApplySalesSnapshot(PlanSource, SalesHeader, SalesLine);
        PlanSource.Insert(true);
        ApplyFirstDemandDefaults(PlanHeader, PlanSource);
        exit(true);
    end;

    local procedure AddTransferLine(var PlanHeader: Record "SAL Plan Header"; TransferLine: Record "Transfer Line"): Boolean
    var
        PlanSource: Record "SAL Plan Source";
        TransferHeader: Record "Transfer Header";
    begin
        PlanHeader.LockTable();
        RefreshDraftPlan(PlanHeader);
        GetTransferHeader(TransferLine."Document No.", TransferHeader);
        ValidateTransferDemandIsAvailable(TransferHeader, TransferLine);
        if SourceAlreadyExists(PlanHeader, PlanSource."Source Type"::TransferOrder, TransferLine."Document No.", TransferLine."Line No.") then
            exit(false);

        PlanSource.Init();
        PlanSource."Plan No." := PlanHeader."No.";
        PlanSource."Version No." := PlanHeader."Version No.";
        PlanSource."Source Type" := PlanSource."Source Type"::TransferOrder;
        PlanSource."Source Document No." := TransferLine."Document No.";
        PlanSource."Source Document Line No." := TransferLine."Line No.";
        PlanSource.Priority := PlanHeader.Priority;
        ApplyTransferSnapshot(PlanSource, TransferHeader, TransferLine);
        PlanSource.Insert(true);
        ApplyFirstDemandDefaults(PlanHeader, PlanSource);
        exit(true);
    end;

    local procedure RefreshSalesSource(var PlanSource: Record "SAL Plan Source")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        GetSalesHeader(PlanSource."Source Document No.", SalesHeader);
        if not SalesLine.Get(SalesLine."Document Type"::Order, PlanSource."Source Document No.", PlanSource."Source Document Line No.") then
            Error(SourceLineNotFoundErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
        ValidateSalesDemandIsAvailable(SalesHeader, SalesLine);
        ApplySalesSnapshot(PlanSource, SalesHeader, SalesLine);
    end;

    local procedure RefreshTransferSource(var PlanSource: Record "SAL Plan Source")
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
    begin
        GetTransferHeader(PlanSource."Source Document No.", TransferHeader);
        if not TransferLine.Get(PlanSource."Source Document No.", PlanSource."Source Document Line No.") then
            Error(SourceLineNotFoundErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
        ValidateTransferDemandIsAvailable(TransferHeader, TransferLine);
        ApplyTransferSnapshot(PlanSource, TransferHeader, TransferLine);
    end;

    local procedure ApplySalesSnapshot(var PlanSource: Record "SAL Plan Source"; SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line")
    var
        Customer: Record Customer;
    begin
        PlanSource."Item No." := SalesLine."No.";
        PlanSource."Variant Code" := SalesLine."Variant Code";
        PlanSource."Unit of Measure Code" := SalesLine."Unit of Measure Code";
        PlanSource.Quantity := SalesLine."Outstanding Quantity";
        PlanSource."Consignment No." := SalesHeader."No.";
        PlanSource."Customer No." := SalesHeader."Sell-to Customer No.";
        PlanSource.Priority := NormalisePriority(0, PlanSource.Priority);
        PlanSource."Shipment Date" := SalesLine."Shipment Date";
        if PlanSource."Shipment Date" = 0D then
            PlanSource."Shipment Date" := SalesHeader."Shipment Date";
        PlanSource."Allocated Pallet Quantity" := 0;
        PlanSource."Allocated Quantity" := SalesLine.Quantity - SalesLine."Outstanding Quantity";
        PlanSource."Remaining Quantity Snapshot" := SalesLine."Outstanding Quantity";
        PlanSource."Source System Modified At" := SalesLine.SystemModifiedAt;
        PlanSource."Routing Confirmed" := false;
        AddItemSnapshot(PlanSource);

        if (PlanSource."Customer No." <> '') and Customer.Get(PlanSource."Customer No.") then
            PlanSource."Customer Name" := CopyStr(Customer.Name, 1, MaxStrLen(PlanSource."Customer Name"))
        else
            PlanSource."Customer Name" := CopyStr(SalesHeader."Sell-to Customer Name", 1, MaxStrLen(PlanSource."Customer Name"));
        PlanSource."Source Location Code" := SalesLine."Location Code";
        PlanSource."Destination Code" := SalesHeader."Ship-to Code";
        PlanSource."Destination Name" := CopyStr(SalesHeader."Ship-to Name", 1, MaxStrLen(PlanSource."Destination Name"));
        if PlanSource."Destination Name" = '' then
            PlanSource."Destination Name" := CopyStr(SalesHeader."Sell-to Customer Name", 1, MaxStrLen(PlanSource."Destination Name"));

        if SalesLine."Location Code" <> '' then
            PlanSource."Execution Route" := PlanSource."Execution Route"::ExternalDCFulfilment
        else
            PlanSource."Execution Route" := PlanSource."Execution Route"::NoFacilityAction;
        PlanSource."Facility Work Type" := PlanSource."Facility Work Type"::None;
    end;

    local procedure ApplyTransferSnapshot(var PlanSource: Record "SAL Plan Source"; TransferHeader: Record "Transfer Header"; TransferLine: Record "Transfer Line")
    var
        DestinationLocation: Record Location;
    begin
        PlanSource."Item No." := TransferLine."Item No.";
        PlanSource."Variant Code" := TransferLine."Variant Code";
        PlanSource."Unit of Measure Code" := TransferLine."Unit of Measure Code";
        PlanSource.Quantity := TransferLine."Outstanding Quantity";
        PlanSource."Consignment No." := TransferHeader."No.";
        PlanSource."Customer No." := '';
        PlanSource.Priority := NormalisePriority(0, PlanSource.Priority);
        PlanSource."Shipment Date" := TransferLine."Shipment Date";
        if PlanSource."Shipment Date" = 0D then
            PlanSource."Shipment Date" := TransferHeader."Shipment Date";
        PlanSource."Allocated Pallet Quantity" := 0;
        PlanSource."Allocated Quantity" := TransferLine.Quantity - TransferLine."Outstanding Quantity";
        PlanSource."Remaining Quantity Snapshot" := TransferLine."Outstanding Quantity";
        PlanSource."Source System Modified At" := TransferLine.SystemModifiedAt;
        PlanSource."Routing Confirmed" := false;
        AddItemSnapshot(PlanSource);

        PlanSource."Source Location Code" := TransferHeader."Transfer-from Code";
        PlanSource."Destination Code" := TransferHeader."Transfer-to Code";
        if DestinationLocation.Get(TransferHeader."Transfer-to Code") then
            PlanSource."Destination Name" := CopyStr(DestinationLocation.Name, 1, MaxStrLen(PlanSource."Destination Name"))
        else
            PlanSource."Destination Name" := TransferHeader."Transfer-to Code";
        PlanSource."Execution Route" := PlanSource."Execution Route"::InterDCTransfer;
        PlanSource."Facility Work Type" := PlanSource."Facility Work Type"::None;
    end;

    local procedure SourceAlreadyExists(PlanHeader: Record "SAL Plan Header"; SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; DocumentLineNo: Integer): Boolean
    var
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        PlanSource.SetRange("Source Document Line No.", DocumentLineNo);
        exit(not PlanSource.IsEmpty());
    end;

    local procedure GetSalesHeader(DocumentNo: Code[20]; var SalesHeader: Record "Sales Header")
    begin
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo) then
            Error(SalesOrderNotFoundErr, DocumentNo);
    end;

    local procedure GetTransferHeader(DocumentNo: Code[20]; var TransferHeader: Record "Transfer Header")
    begin
        if not TransferHeader.Get(DocumentNo) then
            Error(TransferOrderNotFoundErr, DocumentNo);
    end;

    local procedure ValidateSalesDemandIsAvailable(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line")
    begin
        if SalesHeader.Status <> SalesHeader.Status::Released then
            Error(DemandNotReleasedErr, SalesLine."Document No.", SalesLine."Line No.");
        if (SalesLine.Type <> SalesLine.Type::Item) or (SalesLine."No." = '') then
            Error(DemandUnavailableErr, SalesLine."Document No.", SalesLine."Line No.");
        if SalesLine."Outstanding Quantity" <= 0 then
            Error(NoRemainingDemandErr, SalesLine."Document No.", SalesLine."Line No.");
    end;

    local procedure ValidateTransferDemandIsAvailable(TransferHeader: Record "Transfer Header"; TransferLine: Record "Transfer Line")
    begin
        if TransferHeader.Status <> TransferHeader.Status::Released then
            Error(DemandNotReleasedErr, TransferLine."Document No.", TransferLine."Line No.");
        if TransferLine."Item No." = '' then
            Error(DemandUnavailableErr, TransferLine."Document No.", TransferLine."Line No.");
        if TransferLine."Outstanding Quantity" <= 0 then
            Error(NoRemainingDemandErr, TransferLine."Document No.", TransferLine."Line No.");
    end;

    local procedure AddItemSnapshot(var PlanSource: Record "SAL Plan Source")
    var
        Item: Record Item;
    begin
        if Item.Get(PlanSource."Item No.") then
            PlanSource."Item Description" := CopyStr(Item.Description, 1, MaxStrLen(PlanSource."Item Description"));
    end;

    local procedure ApplyFirstDemandDefaults(var PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source")
    var
        HeaderChanged: Boolean;
    begin
        if PlanHeader.Priority = 0 then begin
            PlanHeader.Priority := PlanSource.Priority;
            HeaderChanged := true;
        end;
        if (PlanHeader."Required Finish Date" = 0D) and (PlanSource."Shipment Date" <> 0D) then begin
            PlanHeader."Required Finish Date" := PlanSource."Shipment Date";
            HeaderChanged := true;
        end;
        if (PlanHeader."Dispatch Date" = 0D) and (PlanSource."Shipment Date" <> 0D) then begin
            PlanHeader."Dispatch Date" := PlanSource."Shipment Date";
            HeaderChanged := true;
        end;
        if PlanHeader.Description = '' then begin
            if PlanSource."Customer Name" <> '' then
                PlanHeader.Description := CopyStr(PlanSource."Customer Name", 1, MaxStrLen(PlanHeader.Description))
            else
                PlanHeader.Description := CopyStr(PlanSource."Destination Name", 1, MaxStrLen(PlanHeader.Description));
            if PlanHeader.Description <> '' then
                HeaderChanged := true;
        end;
        if HeaderChanged then
            PlanHeader.Modify(true);
    end;

    local procedure NormalisePriority(SourcePriority: Integer; HeaderPriority: Integer): Integer
    begin
        if (SourcePriority >= 1) and (SourcePriority <= 10) then
            exit(SourcePriority);
        if (HeaderPriority >= 1) and (HeaderPriority <= 10) then
            exit(HeaderPriority);
        exit(10);
    end;

    local procedure RefreshDraftPlan(var PlanHeader: Record "SAL Plan Header")
    begin
        PlanHeader.TestField("No.");
        PlanHeader.TestField("Version No.");
        if not PlanHeader.Get(PlanHeader."No.", PlanHeader."Version No.") then
            Error(PlanNotFoundErr);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(PlanNotDraftErr, PlanHeader."No.", PlanHeader."Version No.");
    end;

    var
        DemandAddedMsg: Label '%1 demand line(s) added. %2 duplicate line(s) skipped.', Comment = '%1 = added count, %2 = skipped count';
        DemandRefreshedMsg: Label '%1 demand line(s) refreshed. Review any changed quantities, products or routing before validation.', Comment = '%1 = refreshed count';
        DemandTypeInstructionTxt: Label 'Choose the type of released BC demand to add to this plan.';
        DemandTypeOptionsTxt: Label 'Sales order lines,Transfer order lines';
        DemandNotReleasedErr: Label 'Demand %1 line %2 is not Released.', Comment = '%1 = document no., %2 = line no.';
        DemandUnavailableErr: Label 'Demand %1 line %2 is not an available item line.', Comment = '%1 = document no., %2 = line no.';
        NoRemainingDemandErr: Label 'Demand %1 line %2 has no remaining quantity to plan.', Comment = '%1 = document no., %2 = line no.';
        NoDemandToRefreshErr: Label 'This plan has no demand lines to refresh.';
        RefreshedBelowExactAllocationErr: Label 'Demand refresh would reduce source line %1 to %2 units, below its protected %3 exact units plus %4 fill target. Adjust the plan before refreshing.', Comment = '%1 = source line, %2 = refreshed quantity, %3 = exact planned, %4 = fill target';
        RefreshedBelowFillAllocationErr: Label 'Source line %1 fill target is %2 units, below the %3 units already assigned to fill members. Remove or reduce fill components first.', Comment = '%1 = source line, %2 = fill target, %3 = fill planned';
        RefreshedBelowFillTargetErr: Label 'Demand refresh would reduce source line %1 to %2 units, below its fill target of %3. Reduce the fill balance first.', Comment = '%1 = source line, %2 = refreshed quantity, %3 = fill target';
        PlanNotDraftErr: Label 'Plan %1 version %2 is not Draft.', Comment = '%1 = plan no., %2 = version no.';
        PlanNotFoundErr: Label 'The SAL plan no longer exists.';
        SalesOrderNotFoundErr: Label 'Sales Order %1 does not exist.', Comment = '%1 = sales order no.';
        SourceLineNotFoundErr: Label 'Source document %1 line %2 does not exist.', Comment = '%1 = document no., %2 = line no.';
        TransferOrderNotFoundErr: Label 'Transfer Order %1 does not exist.', Comment = '%1 = transfer order no.';
}
