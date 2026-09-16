page 58007 "SAL Stock & Logistics Planner"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'Stock & Logistics Planner';
    SourceTable = "SAL Plan Header";
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Permissions =
        tabledata "Sales Header" = r,
        tabledata "Sales Line" = r,
        tabledata "Transfer Header" = r,
        tabledata "Transfer Line" = r,
        tabledata Customer = r,
        tabledata Location = r;
    AdditionalSearchTerms = 'SAL,Internal Sales,WebSAM,Order Priority,Pallet Plan,Mixed Pallet,Logistics Planner';

    layout
    {
        area(Content)
        {
            usercontrol(Workspace; "SAL Planner Workspace")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    AddInReady := true;
                    InitialiseSelection();
                    LoadScreen('SAL graphical planner loaded from Business Central.', false);
                end;

                trigger RefreshRequested()
                begin
                    LoadScreen('Planner data refreshed.', false);
                end;

                trigger PlanSelected(PlanNo: Text; VersionNo: Integer)
                begin
                    SelectPlan(PlanNo, VersionNo);
                    LoadScreen('', false);
                end;

                trigger DemandCandidateSelected(SourceType: Text; DocumentNo: Text)
                begin
                    CreatePlanFromDemandCandidate(SourceType, DocumentNo);
                end;

                trigger OpenDemandSourceRequested(SourceType: Text; DocumentNo: Text)
                begin
                    OpenDemandSource(SourceType, DocumentNo);
                end;

                trigger ReleaseAndCreateDemandRequested(SourceType: Text; DocumentNo: Text)
                begin
                    ReleaseAndCreateDemand(SourceType, DocumentNo);
                end;

                trigger NewSalesOrderRequested()
                begin
                    CreateNewSalesOrder();
                end;

                trigger NewTransferOrderRequested()
                begin
                    CreateNewTransferOrder();
                end;

                trigger OpenNativeRequested()
                begin
                    OpenNativePlan();
                end;

                trigger OpenPlansRequested()
                begin
                    Page.Run(Page::"SAL Plans");
                end;

                trigger AddDemandRequested()
                begin
                    AddDemand();
                end;

                trigger RefreshDemandRequested()
                begin
                    RefreshDemand();
                end;

                trigger ValidateRequested()
                begin
                    ValidateSelectedPlan();
                end;

                trigger ReleaseRequested()
                begin
                    ReleaseSelectedPlan();
                end;

                trigger CreateVersionRequested()
                begin
                    CreateSelectedPlanVersion();
                end;

                trigger CancelDraftRequested()
                begin
                    CancelSelectedDraft();
                end;

                trigger AddPalletRequested(PalletType: Text; PalletCount: Integer; TargetQuantity: Decimal; Description: Text)
                begin
                    AddPalletGroup(PalletType, PalletCount, TargetQuantity, Description);
                end;

                trigger DeletePalletRequested(PalletNo: Integer)
                begin
                    DeletePallet(PalletNo);
                end;

                trigger AddComponentRequested(PalletNo: Integer; SourceLineNo: Integer; Quantity: Decimal)
                begin
                    AddComponent(PalletNo, SourceLineNo, Quantity);
                end;

                trigger AddFillComponentRequested(PalletNo: Integer; SourceLineNo: Integer; FillMemberLineNo: Integer; Quantity: Decimal)
                begin
                    AddFillComponent(PalletNo, SourceLineNo, FillMemberLineNo, Quantity);
                end;

                trigger DeleteComponentRequested(PalletNo: Integer; LineNo: Integer)
                begin
                    DeleteComponent(PalletNo, LineNo);
                end;

                trigger AdjustFillTargetRequested(SourceLineNo: Integer; NewFillTarget: Decimal; Reason: Text)
                begin
                    AdjustFillTarget(SourceLineNo, NewFillTarget, Reason);
                end;

                trigger ConvertRemainingToFillRequested(SourceLineNo: Integer; FillGroupCode: Text; Quantity: Decimal; AllowMixed: Boolean; MembersJson: Text; Reason: Text)
                begin
                    ConvertRemainingToFill(SourceLineNo, FillGroupCode, Quantity, AllowMixed, MembersJson, Reason);
                end;

                trigger OpenFillGroupsRequested()
                begin
                    Page.Run(Page::"SAL Product Groups");
                end;

                trigger SavePriorityRequested(Priority: Integer)
                begin
                    SavePriority(Priority);
                end;

                trigger SelectMarketerRequested()
                begin
                    SelectMarketer();
                end;

                trigger SaveRoutingRequested(SourceLineNo: Integer; ExecutionRoute: Text; FacilityWorkType: Text)
                begin
                    SaveRouting(SourceLineNo, ExecutionRoute, FacilityWorkType);
                end;

                trigger OpenSourceRequested(SourceLineNo: Integer)
                begin
                    OpenSource(SourceLineNo);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        if Rec."No." <> '' then begin
            SelectedPlanNo := Rec."No.";
            SelectedVersionNo := Rec."Version No.";
        end;
        if AddInReady then
            LoadScreen('', false);
    end;

    local procedure LoadScreen(StatusMessage: Text; IsError: Boolean)
    var
        StateJson: Text;
    begin
        if not AddInReady then
            exit;

        BuildState(StateJson);
        CurrPage.Workspace.SetState(StateJson, StatusMessage, IsError);
    end;

    local procedure BuildState(var StateJson: Text)
    var
        Capabilities: JsonObject;
        FillGroups: JsonArray;
        Queue: JsonArray;
        Root: JsonObject;
        SelectedHeader: Record "SAL Plan Header";
        SelectedKey: JsonObject;
        SelectedPlan: JsonObject;
    begin
        InitialiseSelection();
        Root.Add('schemaVersion', 2);
        Root.Add('environment', 'Cloud · SAL planning');
        Root.Add('company', CompanyName());
        Root.Add('currentUser', UserId());

        BuildQueue(Queue);
        Root.Add('queue', Queue);

        if TryGetSelectedPlan(SelectedHeader) then begin
            SelectedKey.Add('planNo', SelectedHeader."No.");
            SelectedKey.Add('versionNo', SelectedHeader."Version No.");
            Root.Add('selectedKey', SelectedKey);
            BuildSelectedPlan(SelectedHeader, SelectedPlan);
            Root.Add('plan', SelectedPlan);
            BuildFillGroups(SelectedHeader."Marketer Customer No.", FillGroups);
            BuildCapabilities(SelectedHeader, Capabilities);
        end else begin
            Root.Add('selectedKey', SelectedKey);
            Root.Add('plan', SelectedPlan);
            BuildEmptyCapabilities(Capabilities);
        end;
        Root.Add('fillGroups', FillGroups);
        Root.Add('capabilities', Capabilities);
        Root.WriteTo(StateJson);
    end;

    local procedure BuildQueue(var Queue: JsonArray)
    var
        PlanHeader: Record "SAL Plan Header";
        QueueItem: JsonObject;
        ItemCount: Integer;
    begin
        PlanHeader.SetCurrentKey(Status, Priority, "Required Finish Date", "No.", "Version No.");
        PlanHeader.SetFilter(Status, '%1|%2', PlanHeader.Status::Draft, PlanHeader.Status::Released);
        if PlanHeader.FindSet() then
            repeat
                if IsPreferredVersion(PlanHeader) then begin
                    PlanHeader.CalcFields("No. of Sources", "No. of Pallets", "Total Required Quantity", "Total Planned Quantity");
                    Clear(QueueItem);
                    QueueItem.Add('kind', 'plan');
                    QueueItem.Add('planNo', PlanHeader."No.");
                    QueueItem.Add('versionNo', PlanHeader."Version No.");
                    QueueItem.Add('description', PlanHeader.Description);
                    QueueItem.Add('status', Format(PlanHeader.Status));
                    QueueItem.Add('priority', PlanHeader.Priority);
                    if PlanHeader."Marketer Confirmed" then
                        QueueItem.Add('marketer', PlanHeader."Marketer Description")
                    else
                        QueueItem.Add('marketer', 'Marketer not confirmed');
                    QueueItem.Add('marketerConfirmed', PlanHeader."Marketer Confirmed");
                    QueueItem.Add('requiredFinishDate', FormatDate(PlanHeader."Required Finish Date"));
                    QueueItem.Add('dispatchDate', FormatDate(PlanHeader."Dispatch Date"));
                    QueueItem.Add('sourceCount', PlanHeader."No. of Sources");
                    QueueItem.Add('palletCount', PlanHeader."No. of Pallets");
                    QueueItem.Add('requiredQuantity', PlanHeader."Total Required Quantity");
                    QueueItem.Add('plannedQuantity', PlanHeader."Total Planned Quantity");
                    Queue.Add(QueueItem);
                    ItemCount += 1;
                end;
            until (PlanHeader.Next() = 0) or (ItemCount >= 200);

        AppendSalesCandidates(Queue, ItemCount, true);
        AppendTransferCandidates(Queue, ItemCount, true);
        AppendSalesCandidates(Queue, ItemCount, false);
        AppendTransferCandidates(Queue, ItemCount, false);
    end;

    local procedure AppendSalesCandidates(var Queue: JsonArray; var ItemCount: Integer; ReleasedOnly: Boolean)
    var
        ActivePlanHeader: Record "SAL Plan Header";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SourceType: Enum "SAL Source Type";
        LineItem: JsonObject;
        Lines: JsonArray;
        QueueItem: JsonObject;
        DestinationName: Text;
        FirstShipmentDate: Date;
        HasActivePlan: Boolean;
        HasAdditionalDemand: Boolean;
        IsEligible: Boolean;
        ItemLineCount: Integer;
        OutstandingQuantity: Decimal;
    begin
        if ItemCount >= 200 then
            exit;

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if ReleasedOnly then
            SalesHeader.SetRange(Status, SalesHeader.Status::Released)
        else
            SalesHeader.SetRange(Status, SalesHeader.Status::Open);

        if not SalesHeader.FindSet() then
            exit;

        repeat
                HasActivePlan := FindActivePlanForSource(SourceType::SalesOrder, SalesHeader."No.", ActivePlanHeader);
                Clear(SalesLine);
                SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
                SalesLine.SetRange("Document No.", SalesHeader."No.");
                SalesLine.SetRange(Type, SalesLine.Type::Item);
                SalesLine.SetFilter("No.", '<>%1', '');
                SalesLine.SetFilter("Outstanding Quantity", '>0');
                ItemLineCount := 0;
                OutstandingQuantity := 0;
                HasAdditionalDemand := false;
                FirstShipmentDate := SalesHeader."Shipment Date";
                Clear(Lines);
                if SalesLine.FindSet() then
                    repeat
                        ItemLineCount += 1;
                        OutstandingQuantity += SalesLine."Outstanding Quantity";
                        Clear(LineItem);
                        LineItem.Add('lineNo', SalesLine."Line No.");
                        LineItem.Add('itemNo', SalesLine."No.");
                        LineItem.Add('description', SalesLine.Description);
                        LineItem.Add('variantCode', SalesLine."Variant Code");
                        LineItem.Add('uom', SalesLine."Unit of Measure Code");
                        LineItem.Add('outstandingQuantity', SalesLine."Outstanding Quantity");
                        LineItem.Add('shipmentDate', FormatDate(SalesLine."Shipment Date"));
                        LineItem.Add('locationCode', SalesLine."Location Code");
                        Lines.Add(LineItem);
                        if (not HasActivePlan) or SalesLineRequiresPlanning(ActivePlanHeader, SalesLine) then
                            HasAdditionalDemand := true;
                        if (FirstShipmentDate = 0D) and (SalesLine."Shipment Date" <> 0D) then
                            FirstShipmentDate := SalesLine."Shipment Date";
                    until SalesLine.Next() = 0;

                if (ItemLineCount > 0) and ((not HasActivePlan) or HasAdditionalDemand) then begin
                    IsEligible := SalesHeader.Status = SalesHeader.Status::Released;
                    DestinationName := GetSalesDestinationName(SalesHeader);
                    Clear(QueueItem);
                    QueueItem.Add('kind', 'candidate');
                    QueueItem.Add('priority', 10);
                    QueueItem.Add('sourceType', 'Sales Order');
                    QueueItem.Add('documentNo', SalesHeader."No.");
                    QueueItem.Add('customerName', SalesHeader."Sell-to Customer Name");
                    QueueItem.Add('destinationName', DestinationName);
                    QueueItem.Add('marketer', 'Marketer not confirmed');
                    QueueItem.Add('hasActivePlan', HasActivePlan);
                    if HasActivePlan then begin
                        QueueItem.Add('activePlanNo', ActivePlanHeader."No.");
                        QueueItem.Add('activePlanVersionNo', ActivePlanHeader."Version No.");
                    end;
                    QueueItem.Add('status', Format(SalesHeader.Status));
                    QueueItem.Add('eligible', IsEligible);
                    if IsEligible then
                        QueueItem.Add('blockedReason', '')
                    else
                        QueueItem.Add('blockedReason', 'Release this sales order before creating its SAL plan.');
                    QueueItem.Add('shipmentDate', FormatDate(FirstShipmentDate));
                    QueueItem.Add('outstandingQuantity', OutstandingQuantity);
                    QueueItem.Add('itemLineCount', ItemLineCount);
                    QueueItem.Add('lines', Lines);
                    Queue.Add(QueueItem);
                    ItemCount += 1;
                end;
        until (SalesHeader.Next() = 0) or (ItemCount >= 200);
    end;

    local procedure AppendTransferCandidates(var Queue: JsonArray; var ItemCount: Integer; ReleasedOnly: Boolean)
    var
        ActivePlanHeader: Record "SAL Plan Header";
        DestinationLocation: Record Location;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        SourceType: Enum "SAL Source Type";
        LineItem: JsonObject;
        Lines: JsonArray;
        QueueItem: JsonObject;
        DestinationName: Text;
        FirstShipmentDate: Date;
        HasActivePlan: Boolean;
        HasAdditionalDemand: Boolean;
        IsEligible: Boolean;
        ItemLineCount: Integer;
        OutstandingQuantity: Decimal;
    begin
        if ItemCount >= 200 then
            exit;

        if ReleasedOnly then
            TransferHeader.SetRange(Status, TransferHeader.Status::Released)
        else
            TransferHeader.SetRange(Status, TransferHeader.Status::Open);

        if not TransferHeader.FindSet() then
            exit;

        repeat
                HasActivePlan := FindActivePlanForSource(SourceType::TransferOrder, TransferHeader."No.", ActivePlanHeader);
                Clear(TransferLine);
                TransferLine.SetRange("Document No.", TransferHeader."No.");
                TransferLine.SetFilter("Item No.", '<>%1', '');
                TransferLine.SetFilter("Outstanding Quantity", '>0');
                ItemLineCount := 0;
                OutstandingQuantity := 0;
                HasAdditionalDemand := false;
                FirstShipmentDate := TransferHeader."Shipment Date";
                Clear(Lines);
                if TransferLine.FindSet() then
                    repeat
                        ItemLineCount += 1;
                        OutstandingQuantity += TransferLine."Outstanding Quantity";
                        Clear(LineItem);
                        LineItem.Add('lineNo', TransferLine."Line No.");
                        LineItem.Add('itemNo', TransferLine."Item No.");
                        LineItem.Add('description', TransferLine.Description);
                        LineItem.Add('variantCode', TransferLine."Variant Code");
                        LineItem.Add('uom', TransferLine."Unit of Measure Code");
                        LineItem.Add('outstandingQuantity', TransferLine."Outstanding Quantity");
                        LineItem.Add('shipmentDate', FormatDate(TransferLine."Shipment Date"));
                        LineItem.Add('locationCode', TransferHeader."Transfer-from Code");
                        Lines.Add(LineItem);
                        if (not HasActivePlan) or TransferLineRequiresPlanning(ActivePlanHeader, TransferLine) then
                            HasAdditionalDemand := true;
                        if (FirstShipmentDate = 0D) and (TransferLine."Shipment Date" <> 0D) then
                            FirstShipmentDate := TransferLine."Shipment Date";
                    until TransferLine.Next() = 0;

                if (ItemLineCount > 0) and ((not HasActivePlan) or HasAdditionalDemand) then begin
                    IsEligible := TransferHeader.Status = TransferHeader.Status::Released;
                    DestinationName := TransferHeader."Transfer-to Code";
                    if DestinationLocation.Get(TransferHeader."Transfer-to Code") then
                        DestinationName := DestinationLocation.Name;
                    Clear(QueueItem);
                    QueueItem.Add('kind', 'candidate');
                    QueueItem.Add('priority', 10);
                    QueueItem.Add('sourceType', 'Transfer Order');
                    QueueItem.Add('documentNo', TransferHeader."No.");
                    QueueItem.Add('customerName', StrSubstNo('%1 to %2', TransferHeader."Transfer-from Code", TransferHeader."Transfer-to Code"));
                    QueueItem.Add('destinationName', DestinationName);
                    QueueItem.Add('marketer', 'Marketer not confirmed');
                    QueueItem.Add('hasActivePlan', HasActivePlan);
                    if HasActivePlan then begin
                        QueueItem.Add('activePlanNo', ActivePlanHeader."No.");
                        QueueItem.Add('activePlanVersionNo', ActivePlanHeader."Version No.");
                    end;
                    QueueItem.Add('status', Format(TransferHeader.Status));
                    QueueItem.Add('eligible', IsEligible);
                    if IsEligible then
                        QueueItem.Add('blockedReason', '')
                    else
                        QueueItem.Add('blockedReason', 'Release this transfer order before creating its SAL plan.');
                    QueueItem.Add('shipmentDate', FormatDate(FirstShipmentDate));
                    QueueItem.Add('outstandingQuantity', OutstandingQuantity);
                    QueueItem.Add('itemLineCount', ItemLineCount);
                    QueueItem.Add('lines', Lines);
                    Queue.Add(QueueItem);
                    ItemCount += 1;
                end;
        until (TransferHeader.Next() = 0) or (ItemCount >= 200);
    end;

    local procedure SalesLineRequiresPlanning(PlanHeader: Record "SAL Plan Header"; SalesLine: Record "Sales Line"): Boolean
    var
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Source Type", PlanSource."Source Type"::SalesOrder);
        PlanSource.SetRange("Source Document No.", SalesLine."Document No.");
        PlanSource.SetRange("Source Document Line No.", SalesLine."Line No.");
        if not PlanSource.FindFirst() then
            exit(true);
        exit(PlanSource.Quantity < SalesLine."Outstanding Quantity");
    end;

    local procedure TransferLineRequiresPlanning(PlanHeader: Record "SAL Plan Header"; TransferLine: Record "Transfer Line"): Boolean
    var
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Source Type", PlanSource."Source Type"::TransferOrder);
        PlanSource.SetRange("Source Document No.", TransferLine."Document No.");
        PlanSource.SetRange("Source Document Line No.", TransferLine."Line No.");
        if not PlanSource.FindFirst() then
            exit(true);
        exit(PlanSource.Quantity < TransferLine."Outstanding Quantity");
    end;

    local procedure FindActivePlanForSource(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; var ActivePlanHeader: Record "SAL Plan Header"): Boolean
    var
        CandidatePlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        Found: Boolean;
    begin
        Clear(ActivePlanHeader);
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        if not PlanSource.FindSet() then
            exit(false);

        repeat
            if CandidatePlanHeader.Get(PlanSource."Plan No.", PlanSource."Version No.") and
               (CandidatePlanHeader.Status in [CandidatePlanHeader.Status::Draft, CandidatePlanHeader.Status::Released])
            then
                if (not Found) or IsBetterActivePlan(CandidatePlanHeader, ActivePlanHeader) then begin
                    ActivePlanHeader := CandidatePlanHeader;
                    Found := true;
                end;
        until PlanSource.Next() = 0;
        exit(Found);
    end;

    local procedure IsBetterActivePlan(CandidatePlanHeader: Record "SAL Plan Header"; ActivePlanHeader: Record "SAL Plan Header"): Boolean
    begin
        if (CandidatePlanHeader.Status = CandidatePlanHeader.Status::Draft) and
           (ActivePlanHeader.Status <> ActivePlanHeader.Status::Draft)
        then
            exit(true);
        if CandidatePlanHeader.Status <> ActivePlanHeader.Status then
            exit(false);
        exit(CandidatePlanHeader."Version No." > ActivePlanHeader."Version No.");
    end;

    local procedure GetSalesDestinationName(SalesHeader: Record "Sales Header"): Text
    begin
        if SalesHeader."Ship-to Name" <> '' then
            exit(SalesHeader."Ship-to Name");
        exit(SalesHeader."Sell-to Customer Name");
    end;

    local procedure InferCandidateMarketer(CustomerName: Text): Text
    begin
        if StrPos(LowerCase(CustomerName), 'costa') > 0 then
            exit('Costa (not confirmed)');
        exit('TAC (not confirmed)');
    end;

    local procedure IsPreferredVersion(PlanHeader: Record "SAL Plan Header"): Boolean
    var
        Candidate: Record "SAL Plan Header";
    begin
        Candidate.SetRange("No.", PlanHeader."No.");
        Candidate.SetRange(Status, Candidate.Status::Draft);
        if Candidate.FindLast() then
            exit((PlanHeader.Status = PlanHeader.Status::Draft) and
                 (PlanHeader."Version No." = Candidate."Version No."));

        Candidate.Reset();
        Candidate.SetRange("No.", PlanHeader."No.");
        Candidate.SetRange(Status, Candidate.Status::Released);
        if Candidate.FindLast() then
            exit((PlanHeader.Status = PlanHeader.Status::Released) and
                 (PlanHeader."Version No." = Candidate."Version No."));

        exit(false);
    end;

    local procedure BuildSelectedPlan(PlanHeader: Record "SAL Plan Header"; var SelectedPlan: JsonObject)
    var
        Events: JsonArray;
        Header: JsonObject;
        Pallets: JsonArray;
        Readiness: JsonObject;
        Sources: JsonArray;
    begin
        BuildHeader(PlanHeader, Header);
        BuildSources(PlanHeader, Sources);
        BuildPallets(PlanHeader, Pallets);
        BuildEvents(PlanHeader, Events);
        BuildReadiness(PlanHeader, Readiness);

        SelectedPlan.Add('header', Header);
        SelectedPlan.Add('sources', Sources);
        SelectedPlan.Add('pallets', Pallets);
        SelectedPlan.Add('events', Events);
        SelectedPlan.Add('readiness', Readiness);
    end;

    local procedure BuildFillGroups(MarketerCustomerNo: Code[20]; var FillGroups: JsonArray)
    var
        FillGroup: JsonObject;
        Members: JsonArray;
        ProductGroup: Record "SAL Product Group";
    begin
        if MarketerCustomerNo = '' then
            exit;
        ProductGroup.SetRange(Active, true);
        ProductGroup.SetRange("Marketer Customer No.", MarketerCustomerNo);
        if ProductGroup.FindSet() then
            repeat
                Clear(FillGroup);
                Clear(Members);
                ProductGroup.CalcFields("Marketer Description");
                FillGroup.Add('code', ProductGroup.Code);
                FillGroup.Add('description', ProductGroup.Description);
                FillGroup.Add('marketerCustomerNo', ProductGroup."Marketer Customer No.");
                FillGroup.Add('marketerDescription', ProductGroup."Marketer Description");
                FillGroup.Add('allowMixedPallets', ProductGroup."Allow Mixed Pallets");
                FillGroup.Add('defaultPalletQuantity', ProductGroup."Default Pallet Quantity");
                BuildFillGroupMembers(ProductGroup.Code, Members);
                FillGroup.Add('members', Members);
                FillGroups.Add(FillGroup);
            until ProductGroup.Next() = 0;
    end;

    local procedure BuildFillGroupMembers(GroupCode: Code[20]; var Members: JsonArray)
    var
        Member: JsonObject;
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        ProductGroupMember.SetCurrentKey("Group Code", Preference, "Line No.");
        ProductGroupMember.SetRange("Group Code", GroupCode);
        ProductGroupMember.SetRange(Active, true);
        if ProductGroupMember.FindSet() then
            repeat
                Clear(Member);
                Member.Add('lineNo', ProductGroupMember."Line No.");
                Member.Add('itemNo', ProductGroupMember."Item No.");
                Member.Add('variantCode', ProductGroupMember."Variant Code");
                Member.Add('uom', ProductGroupMember."Unit of Measure Code");
                Member.Add('description', ProductGroupMember.Description);
                Member.Add('minimumQuantity', ProductGroupMember."Minimum Quantity");
                Member.Add('maximumQuantity', ProductGroupMember."Maximum Quantity");
                Member.Add('maximumPallets', ProductGroupMember."Maximum Pallets");
                Member.Add('defaultPalletQuantity', ProductGroupMember."Default Pallet Quantity");
                Member.Add('preference', ProductGroupMember.Preference);
                Members.Add(Member);
            until ProductGroupMember.Next() = 0;
    end;

    local procedure BuildHeader(PlanHeader: Record "SAL Plan Header"; var Header: JsonObject)
    var
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        PlanHeader.CalcFields("No. of Sources", "No. of Pallets", "Total Required Quantity", "Total Planned Quantity");
        Header.Add('planNo', PlanHeader."No.");
        Header.Add('versionNo', PlanHeader."Version No.");
        Header.Add('previousVersionNo', PlanHeader."Previous Version No.");
        Header.Add('description', PlanHeader.Description);
        Header.Add('status', Format(PlanHeader.Status));
        Header.Add('priority', PlanHeader.Priority);
        Header.Add('requiredFinishDate', FormatDate(PlanHeader."Required Finish Date"));
        Header.Add('dispatchDate', FormatDate(PlanHeader."Dispatch Date"));
        Header.Add('marketerCustomerNo', PlanHeader."Marketer Customer No.");
        Header.Add('marketerDescription', PlanHeader."Marketer Description");
        Header.Add('marketerConfirmed', PlanHeader."Marketer Confirmed");
        Header.Add('sourceCount', PlanHeader."No. of Sources");
        Header.Add('palletCount', PlanHeader."No. of Pallets");
        Header.Add('requiredQuantity', PlanHeader."Total Required Quantity");
        Header.Add('plannedQuantity', PlanHeader."Total Planned Quantity");
        Header.Add('validatedAt', FormatDateTime(PlanHeader."Validated Date Time"));
        Header.Add('releasedAt', FormatDateTime(PlanHeader."Released Date Time"));
        Header.Add('modifiedAt', FormatDateTime(PlanHeader.SystemModifiedAt));
        Header.Add('suggestion', PlanManagement.GetPlannerSuggestion(PlanHeader));
    end;

    local procedure BuildSources(PlanHeader: Record "SAL Plan Header"; var Sources: JsonArray)
    var
        FillMembers: JsonArray;
        PlanSource: Record "SAL Plan Source";
        Source: JsonObject;
        ExactTargetQuantity: Decimal;
        ItemCount: Integer;
    begin
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        if PlanSource.FindSet() then
            repeat
                PlanSource.CalcFields("Planned Quantity", "Exact Planned Quantity", "Fill Planned Quantity");
                Clear(Source);
                Clear(FillMembers);
                ExactTargetQuantity := PlanSource.Quantity - PlanSource."Fill Target Quantity";
                Source.Add('lineNo', PlanSource."Line No.");
                Source.Add('sourceType', Format(PlanSource."Source Type"));
                Source.Add('documentNo', PlanSource."Source Document No.");
                Source.Add('documentLineNo', PlanSource."Source Document Line No.");
                Source.Add('itemNo', PlanSource."Item No.");
                Source.Add('itemDescription', PlanSource."Item Description");
                Source.Add('description', PlanSource."Item Description");
                Source.Add('variantCode', PlanSource."Variant Code");
                Source.Add('uom', PlanSource."Unit of Measure Code");
                Source.Add('requiredQuantity', PlanSource.Quantity);
                Source.Add('plannedQuantity', PlanSource."Planned Quantity");
                Source.Add('fulfilmentMode', Format(PlanSource."Fulfilment Mode"));
                Source.Add('fillGroupCode', PlanSource."Fill Group Code");
                Source.Add('fillTargetQuantity', PlanSource."Fill Target Quantity");
                Source.Add('fillPlannedQuantity', PlanSource."Fill Planned Quantity");
                Source.Add('fillRemainingQuantity', PlanSource."Fill Target Quantity" - PlanSource."Fill Planned Quantity");
                Source.Add('fillAllowsMixedPallets', PlanSource."Fill Allows Mixed Pallets");
                Source.Add('fillConversionReason', PlanSource."Fill Conversion Reason");
                Source.Add('fillConvertedAt', FormatDateTime(PlanSource."Fill Converted At"));
                Source.Add('fillConvertedBy', PlanSource."Fill Converted By");
                Source.Add('exactTargetQuantity', ExactTargetQuantity);
                Source.Add('exactPlannedQuantity', PlanSource."Exact Planned Quantity");
                Source.Add('exactRemainingQuantity', ExactTargetQuantity - PlanSource."Exact Planned Quantity");
                Source.Add('remainingQuantity', PlanSource."Remaining Quantity Snapshot");
                Source.Add('executionRoute', Format(PlanSource."Execution Route"));
                Source.Add('facilityWorkType', Format(PlanSource."Facility Work Type"));
                Source.Add('routingConfirmed', PlanSource."Routing Confirmed");
                Source.Add('customerNo', PlanSource."Customer No.");
                Source.Add('customerName', PlanSource."Customer Name");
                Source.Add('sourceLocationCode', PlanSource."Source Location Code");
                Source.Add('destinationCode', PlanSource."Destination Code");
                Source.Add('destinationName', PlanSource."Destination Name");
                Source.Add('shipmentDate', FormatDate(PlanSource."Shipment Date"));
                Source.Add('modifiedAt', FormatDateTime(PlanSource.SystemModifiedAt));
                BuildPlanFillMembers(PlanHeader, PlanSource."Line No.", FillMembers);
                Source.Add('fillMembers', FillMembers);
                Sources.Add(Source);
                ItemCount += 1;
            until (PlanSource.Next() = 0) or (ItemCount >= 250);
    end;

    local procedure BuildPlanFillMembers(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; var FillMembers: JsonArray)
    var
        FillMember: JsonObject;
        PlanFillMember: Record "SAL Plan Fill Member";
        EffectiveMaximumQuantity: Decimal;
    begin
        PlanFillMember.SetRange("Plan No.", PlanHeader."No.");
        PlanFillMember.SetRange("Version No.", PlanHeader."Version No.");
        PlanFillMember.SetRange("Source Line No.", SourceLineNo);
        if PlanFillMember.FindSet() then
            repeat
                PlanFillMember.CalcFields("Planned Quantity");
                EffectiveMaximumQuantity := PlanFillMember."Maximum Quantity";
                if (PlanFillMember."Maximum Pallets" > 0) and (PlanFillMember."Default Pallet Quantity" > 0) then
                    if (EffectiveMaximumQuantity = 0) or
                       (PlanFillMember."Maximum Pallets" * PlanFillMember."Default Pallet Quantity" < EffectiveMaximumQuantity)
                    then
                        EffectiveMaximumQuantity := PlanFillMember."Maximum Pallets" * PlanFillMember."Default Pallet Quantity";

                Clear(FillMember);
                FillMember.Add('lineNo', PlanFillMember."Line No.");
                FillMember.Add('templateLineNo', PlanFillMember."Template Member Line No.");
                FillMember.Add('groupCode', PlanFillMember."Group Code");
                FillMember.Add('itemNo', PlanFillMember."Item No.");
                FillMember.Add('variantCode', PlanFillMember."Variant Code");
                FillMember.Add('uom', PlanFillMember."Unit of Measure Code");
                FillMember.Add('description', PlanFillMember.Description);
                FillMember.Add('minimumQuantity', PlanFillMember."Minimum Quantity");
                FillMember.Add('maximumQuantity', PlanFillMember."Maximum Quantity");
                FillMember.Add('maximumPallets', PlanFillMember."Maximum Pallets");
                FillMember.Add('defaultPalletQuantity', PlanFillMember."Default Pallet Quantity");
                FillMember.Add('effectiveMaximumQuantity', EffectiveMaximumQuantity);
                FillMember.Add('preference', PlanFillMember.Preference);
                FillMember.Add('plannedQuantity', PlanFillMember."Planned Quantity");
                if EffectiveMaximumQuantity > 0 then
                    FillMember.Add('remainingAllowance', EffectiveMaximumQuantity - PlanFillMember."Planned Quantity")
                else
                    FillMember.Add('remainingAllowance', 0);
                FillMembers.Add(FillMember);
            until PlanFillMember.Next() = 0;
    end;

    local procedure BuildPallets(PlanHeader: Record "SAL Plan Header"; var Pallets: JsonArray)
    var
        Components: JsonArray;
        Pallet: JsonObject;
        PlanPallet: Record "SAL Plan Pallet";
        ItemCount: Integer;
    begin
        PlanPallet.SetRange("Plan No.", PlanHeader."No.");
        PlanPallet.SetRange("Version No.", PlanHeader."Version No.");
        if PlanPallet.FindSet() then
            repeat
                PlanPallet.CalcFields("No. of Components", "Planned Quantity");
                Clear(Pallet);
                Clear(Components);
                Pallet.Add('palletNo', PlanPallet."Pallet No.");
                Pallet.Add('palletType', Format(PlanPallet."Pallet Type"));
                Pallet.Add('description', PlanPallet.Description);
                Pallet.Add('targetQuantity', PlanPallet."Target Quantity");
                Pallet.Add('plannedQuantity', PlanPallet."Planned Quantity");
                Pallet.Add('componentCount', PlanPallet."No. of Components");
                Pallet.Add('modifiedAt', FormatDateTime(PlanPallet.SystemModifiedAt));
                BuildComponents(PlanHeader, PlanPallet."Pallet No.", Components);
                Pallet.Add('components', Components);
                Pallets.Add(Pallet);
                ItemCount += 1;
            until (PlanPallet.Next() = 0) or (ItemCount >= 250);
    end;

    local procedure BuildComponents(PlanHeader: Record "SAL Plan Header"; PalletNo: Integer; var Components: JsonArray)
    var
        Component: JsonObject;
        PlanComponent: Record "SAL Plan Component";
    begin
        PlanComponent.SetRange("Plan No.", PlanHeader."No.");
        PlanComponent.SetRange("Version No.", PlanHeader."Version No.");
        PlanComponent.SetRange("Pallet No.", PalletNo);
        if PlanComponent.FindSet() then
            repeat
                Clear(Component);
                Component.Add('lineNo', PlanComponent."Line No.");
                Component.Add('sourceLineNo', PlanComponent."Source Line No.");
                Component.Add('fulfilmentMode', Format(PlanComponent."Fulfilment Mode"));
                Component.Add('fillMemberLineNo', PlanComponent."Fill Member Line No.");
                Component.Add('itemNo', PlanComponent."Item No.");
                Component.Add('itemDescription', PlanComponent.Description);
                Component.Add('variantCode', PlanComponent."Variant Code");
                Component.Add('uom', PlanComponent."Unit of Measure Code");
                Component.Add('quantity', PlanComponent.Quantity);
                Component.Add('modifiedAt', FormatDateTime(PlanComponent.SystemModifiedAt));
                Components.Add(Component);
            until PlanComponent.Next() = 0;
    end;

    local procedure BuildEvents(PlanHeader: Record "SAL Plan Header"; var Events: JsonArray)
    var
        EventObject: JsonObject;
        EventCount: Integer;
        PlanEvent: Record "SAL Plan Event";
    begin
        PlanEvent.SetRange("Plan No.", PlanHeader."No.");
        PlanEvent.SetRange("Version No.", PlanHeader."Version No.");
        PlanEvent.SetCurrentKey("Plan No.", "Version No.", "Entry No.");
        PlanEvent.Ascending(false);
        if PlanEvent.FindSet() then
            repeat
                Clear(EventObject);
                EventObject.Add('entryNo', PlanEvent."Entry No.");
                EventObject.Add('eventAt', FormatDateTime(PlanEvent."Event Date Time"));
                EventObject.Add('eventType', PlanEvent."Event Type");
                EventObject.Add('userId', PlanEvent."User Id");
                EventObject.Add('description', PlanEvent.Description);
                Events.Add(EventObject);
                EventCount += 1;
            until (PlanEvent.Next() = 0) or (EventCount >= 40);
    end;

    local procedure BuildReadiness(PlanHeader: Record "SAL Plan Header"; var Readiness: JsonObject)
    var
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        HasDemand: Boolean;
        HasPallets: Boolean;
        QuantitiesBalanced: Boolean;
        RoutesConfirmed: Boolean;
    begin
        PlanHeader.CalcFields("Total Required Quantity", "Total Planned Quantity");
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        HasDemand := not PlanSource.IsEmpty();
        RoutesConfirmed := HasDemand;
        if HasDemand then begin
            PlanSource.SetRange("Routing Confirmed", false);
            RoutesConfirmed := PlanSource.IsEmpty();
        end;

        PlanPallet.SetRange("Plan No.", PlanHeader."No.");
        PlanPallet.SetRange("Version No.", PlanHeader."Version No.");
        HasPallets := not PlanPallet.IsEmpty();
        QuantitiesBalanced := HasDemand and HasPallets and
            (PlanHeader."Total Required Quantity" = PlanHeader."Total Planned Quantity");

        Readiness.Add('hasDemand', HasDemand);
        Readiness.Add('marketerConfirmed', PlanHeader."Marketer Confirmed");
        Readiness.Add('routesConfirmed', RoutesConfirmed);
        Readiness.Add('hasPallets', HasPallets);
        Readiness.Add('quantitiesBalanced', QuantitiesBalanced);
        Readiness.Add('validated', PlanHeader."Validated Date Time" <> 0DT);
        Readiness.Add('readyToRelease',
            (PlanHeader.Status = PlanHeader.Status::Draft) and
            HasDemand and PlanHeader."Marketer Confirmed" and RoutesConfirmed and
            HasPallets and QuantitiesBalanced);
    end;

    local procedure BuildCapabilities(PlanHeader: Record "SAL Plan Header"; var Capabilities: JsonObject)
    var
        IsDraft: Boolean;
        ProductGroup: Record "SAL Product Group";
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        IsDraft := PlanHeader.Status = PlanHeader.Status::Draft;
        Capabilities.Add('canCreate', true);
        Capabilities.Add('canEdit', IsDraft);
        Capabilities.Add('canAddDemand', IsDraft);
        Capabilities.Add('canRefreshDemand', IsDraft);
        Capabilities.Add('canValidate', IsDraft);
        Capabilities.Add('canRelease', IsDraft);
        Capabilities.Add('canCreateVersion', PlanHeader.Status = PlanHeader.Status::Released);
        Capabilities.Add('canCancelDraft', IsDraft);
        Capabilities.Add('canConvertToFill', IsDraft and PlanHeader."Marketer Confirmed" and (PlanHeader."Marketer Customer No." <> ''));
        Capabilities.Add('canAddFillComponent', IsDraft);
        Capabilities.Add('canManageFillGroups', ProductGroup.WritePermission() and ProductGroupMember.WritePermission());
        Capabilities.Add('publishImplemented', false);
        Capabilities.Add('finishShortImplemented', false);
        Capabilities.Add('facilityFeedbackAvailable', false);
    end;

    local procedure BuildEmptyCapabilities(var Capabilities: JsonObject)
    var
        ProductGroup: Record "SAL Product Group";
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        Capabilities.Add('canCreate', true);
        Capabilities.Add('canEdit', false);
        Capabilities.Add('canAddDemand', false);
        Capabilities.Add('canRefreshDemand', false);
        Capabilities.Add('canValidate', false);
        Capabilities.Add('canRelease', false);
        Capabilities.Add('canCreateVersion', false);
        Capabilities.Add('canCancelDraft', false);
        Capabilities.Add('canConvertToFill', false);
        Capabilities.Add('canAddFillComponent', false);
        Capabilities.Add('canManageFillGroups', ProductGroup.WritePermission() and ProductGroupMember.WritePermission());
        Capabilities.Add('publishImplemented', false);
        Capabilities.Add('finishShortImplemented', false);
        Capabilities.Add('facilityFeedbackAvailable', false);
    end;

    local procedure InitialiseSelection()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        if (SelectedPlanNo <> '') and PlanHeader.Get(SelectedPlanNo, SelectedVersionNo) then
            exit;

        if (Rec."No." <> '') and PlanHeader.Get(Rec."No.", Rec."Version No.") then begin
            SelectedPlanNo := Rec."No.";
            SelectedVersionNo := Rec."Version No.";
            exit;
        end;

        PlanHeader.SetCurrentKey(Status, Priority, "Required Finish Date", "No.", "Version No.");
        PlanHeader.SetRange(Status, PlanHeader.Status::Draft);
        if not PlanHeader.FindFirst() then begin
            PlanHeader.SetRange(Status, PlanHeader.Status::Released);
            if not PlanHeader.FindFirst() then begin
                PlanHeader.Reset();
                if not PlanHeader.FindFirst() then
                    exit;
            end;
        end;
        SelectedPlanNo := PlanHeader."No.";
        SelectedVersionNo := PlanHeader."Version No.";
    end;

    local procedure TryGetSelectedPlan(var PlanHeader: Record "SAL Plan Header"): Boolean
    begin
        if SelectedPlanNo = '' then
            exit(false);
        exit(PlanHeader.Get(SelectedPlanNo, SelectedVersionNo));
    end;

    local procedure SelectPlan(PlanNo: Text; VersionNo: Integer)
    var
        PlanHeader: Record "SAL Plan Header";
        SafePlanNo: Code[20];
    begin
        SafePlanNo := CopyStr(PlanNo, 1, MaxStrLen(SafePlanNo));
        if not PlanHeader.Get(SafePlanNo, VersionNo) then
            Error(PlanNotFoundErr, SafePlanNo, VersionNo);
        SelectedPlanNo := PlanHeader."No.";
        SelectedVersionNo := PlanHeader."Version No.";
    end;

    local procedure CreatePlanFromDemandCandidate(SourceTypeText: Text; DocumentNoText: Text)
    var
        ActivePlanHeader: Record "SAL Plan Header";
        DemandManagement: Codeunit "SAL Demand Management";
        NewPlanHeader: Record "SAL Plan Header";
        PlanHeader: Record "SAL Plan Header";
        PlanManagement: Codeunit "SAL Plan Management";
        SourceType: Enum "SAL Source Type";
        AddedCount: Integer;
        DocumentNo: Code[20];
        SkippedCount: Integer;
    begin
        DocumentNo := CopyStr(DocumentNoText, 1, MaxStrLen(DocumentNo));
        if DocumentNo = '' then
            Error(DemandDocumentRequiredErr);

        case LowerCase(SourceTypeText) of
            'sales order':
                SourceType := SourceType::SalesOrder;
            'transfer order':
                SourceType := SourceType::TransferOrder;
            else
                Error(DemandSourceTypeErr, SourceTypeText);
        end;

        if FindActivePlanForSource(SourceType, DocumentNo, ActivePlanHeader) then begin
            if ActivePlanHeader.Status = ActivePlanHeader.Status::Released then begin
                PlanManagement.CreateNewVersion(ActivePlanHeader, NewPlanHeader);
                ActivePlanHeader := NewPlanHeader;
            end;
            DemandManagement.RefreshDemand(ActivePlanHeader);
            AddDocumentDemand(ActivePlanHeader, SourceType, DocumentNo, AddedCount, SkippedCount);
            SelectedPlanNo := ActivePlanHeader."No.";
            SelectedVersionNo := ActivePlanHeader."Version No.";
            LoadScreen(StrSubstNo(ExistingPlanUpdatedMsg, ActivePlanHeader."No.", ActivePlanHeader."Version No."), false);
            exit;
        end;

        PlanHeader.Init();
        PlanHeader.Status := PlanHeader.Status::Draft;
        PlanHeader."Version No." := 1;
        PlanHeader.Priority := 10;
        AssignFallbackPlanNoIfRequired(PlanHeader, SourceType, DocumentNo);
        PlanHeader.Insert(true);
        AddDocumentDemand(PlanHeader, SourceType, DocumentNo, AddedCount, SkippedCount);
        if AddedCount = 0 then
            Error(NoCandidateDemandErr, SourceTypeText, DocumentNo);

        SelectedPlanNo := PlanHeader."No.";
        SelectedVersionNo := PlanHeader."Version No.";
        LoadScreen(StrSubstNo(CandidatePlanCreatedMsg, PlanHeader."No.", AddedCount), false);
    end;

    local procedure OpenDemandSource(SourceTypeText: Text; DocumentNoText: Text)
    var
        SalesHeader: Record "Sales Header";
        TransferHeader: Record "Transfer Header";
        DocumentNo: Code[20];
    begin
        DocumentNo := CopyStr(DocumentNoText, 1, MaxStrLen(DocumentNo));
        if DocumentNo = '' then
            Error(DemandDocumentRequiredErr);

        case LowerCase(SourceTypeText) of
            'sales order':
                begin
                    SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo);
                    Page.Run(Page::"Sales Order", SalesHeader);
                end;
            'transfer order':
                begin
                    TransferHeader.Get(DocumentNo);
                    Page.Run(Page::"Transfer Order", TransferHeader);
                end;
            else
                Error(DemandSourceTypeErr, SourceTypeText);
        end;
    end;

    local procedure ReleaseAndCreateDemand(SourceTypeText: Text; DocumentNoText: Text)
    var
        ReleaseSalesDocument: Codeunit "Release Sales Document";
        ReleaseTransferDocument: Codeunit "Release Transfer Document";
        SalesHeader: Record "Sales Header";
        TransferHeader: Record "Transfer Header";
        DocumentNo: Code[20];
    begin
        DocumentNo := CopyStr(DocumentNoText, 1, MaxStrLen(DocumentNo));
        if DocumentNo = '' then
            Error(DemandDocumentRequiredErr);

        case LowerCase(SourceTypeText) of
            'sales order':
                begin
                    SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo);
                    if SalesHeader.Status = SalesHeader.Status::Open then
                        ReleaseSalesDocument.PerformManualRelease(SalesHeader);
                    SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo);
                    if SalesHeader.Status <> SalesHeader.Status::Released then
                        Error(DemandReleaseFailedErr, SourceTypeText, DocumentNo, SalesHeader.Status);
                end;
            'transfer order':
                begin
                    TransferHeader.Get(DocumentNo);
                    if TransferHeader.Status = TransferHeader.Status::Open then
                        ReleaseTransferDocument.Release(TransferHeader);
                    TransferHeader.Get(DocumentNo);
                    if TransferHeader.Status <> TransferHeader.Status::Released then
                        Error(DemandReleaseFailedErr, SourceTypeText, DocumentNo, TransferHeader.Status);
                end;
            else
                Error(DemandSourceTypeErr, SourceTypeText);
        end;

        CreatePlanFromDemandCandidate(SourceTypeText, DocumentNo);
    end;

    local procedure CreateNewSalesOrder()
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Init();
        SalesHeader.Validate("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.Insert(true);
        Page.Run(Page::"Sales Order", SalesHeader);
    end;

    local procedure CreateNewTransferOrder()
    var
        TransferHeader: Record "Transfer Header";
    begin
        TransferHeader.Init();
        TransferHeader.Insert(true);
        Page.Run(Page::"Transfer Order", TransferHeader);
    end;

    local procedure AddDocumentDemand(var PlanHeader: Record "SAL Plan Header"; SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; var AddedCount: Integer; var SkippedCount: Integer)
    var
        DemandManagement: Codeunit "SAL Demand Management";
    begin
        case SourceType of
            SourceType::SalesOrder:
                DemandManagement.AddSalesOrderDemand(PlanHeader, DocumentNo, AddedCount, SkippedCount);
            SourceType::TransferOrder:
                DemandManagement.AddTransferOrderDemand(PlanHeader, DocumentNo, AddedCount, SkippedCount);
        end;
    end;

    local procedure AssignFallbackPlanNoIfRequired(var PlanHeader: Record "SAL Plan Header"; SourceType: Enum "SAL Source Type"; DocumentNo: Code[20])
    var
        SALSetup: Record "SAL Setup";
    begin
        if SALSetup.Get() and (SALSetup."Plan Nos." <> '') then
            exit;
        PlanHeader."No." := GetAvailableFallbackPlanNo(SourceType, DocumentNo);
    end;

    local procedure GetAvailableFallbackPlanNo(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]): Code[20]
    var
        PlanHeader: Record "SAL Plan Header";
        BasePlanNo: Code[20];
        CandidatePlanNo: Code[20];
        SequenceNo: Integer;
        Suffix: Text;
    begin
        case SourceType of
            SourceType::SalesOrder:
                BasePlanNo := CopyStr('SAL-SO-' + DocumentNo, 1, MaxStrLen(BasePlanNo));
            SourceType::TransferOrder:
                BasePlanNo := CopyStr('SAL-TO-' + DocumentNo, 1, MaxStrLen(BasePlanNo));
        end;
        CandidatePlanNo := BasePlanNo;
        SequenceNo := 2;
        while PlanNoExists(PlanHeader, CandidatePlanNo) do begin
            Suffix := '-' + Format(SequenceNo);
            CandidatePlanNo := CopyStr(BasePlanNo, 1, MaxStrLen(CandidatePlanNo) - StrLen(Suffix)) + Suffix;
            SequenceNo += 1;
            if SequenceNo > 9999 then
                Error(FallbackPlanNoErr, DocumentNo);
        end;
        exit(CandidatePlanNo);
    end;

    local procedure PlanNoExists(var PlanHeader: Record "SAL Plan Header"; PlanNo: Code[20]): Boolean
    begin
        PlanHeader.Reset();
        PlanHeader.SetRange("No.", PlanNo);
        exit(not PlanHeader.IsEmpty());
    end;

    local procedure GetSelectedPlan(var PlanHeader: Record "SAL Plan Header")
    begin
        if not TryGetSelectedPlan(PlanHeader) then
            Error(NoPlanSelectedErr);
    end;

    local procedure GetSelectedDraft(var PlanHeader: Record "SAL Plan Header")
    begin
        GetSelectedPlan(PlanHeader);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(PlanNotDraftErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);
    end;

    local procedure OpenNativePlan()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        if TryGetSelectedPlan(PlanHeader) then
            Page.Run(Page::"SAL Plan Details", PlanHeader)
        else
            Page.Run(Page::"SAL Plan Details");
    end;

    local procedure AddDemand()
    var
        DemandManagement: Codeunit "SAL Demand Management";
        PlanHeader: Record "SAL Plan Header";
    begin
        GetSelectedDraft(PlanHeader);
        DemandManagement.AddDemand(PlanHeader);
        LoadScreen('Demand selection updated.', false);
    end;

    local procedure RefreshDemand()
    var
        DemandManagement: Codeunit "SAL Demand Management";
        PlanHeader: Record "SAL Plan Header";
    begin
        GetSelectedDraft(PlanHeader);
        DemandManagement.RefreshDemand(PlanHeader);
        LoadScreen('Demand refreshed from Business Central.', false);
    end;

    local procedure ValidateSelectedPlan()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        GetSelectedDraft(PlanHeader);
        PlanManagement.ValidatePlan(PlanHeader);
        LoadScreen('Plan validation passed.', false);
    end;

    local procedure ReleaseSelectedPlan()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        GetSelectedDraft(PlanHeader);
        PlanManagement.ReleasePlan(PlanHeader);
        LoadScreen('Plan released in Cloud. No Packing Facility instruction has been sent yet.', false);
    end;

    local procedure CreateSelectedPlanVersion()
    var
        CurrentPlanHeader: Record "SAL Plan Header";
        NewPlanHeader: Record "SAL Plan Header";
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        GetSelectedPlan(CurrentPlanHeader);
        PlanManagement.CreateNewVersion(CurrentPlanHeader, NewPlanHeader);
        SelectedPlanNo := NewPlanHeader."No.";
        SelectedVersionNo := NewPlanHeader."Version No.";
        LoadScreen('New draft version created.', false);
    end;

    local procedure CancelSelectedDraft()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        GetSelectedDraft(PlanHeader);
        PlanManagement.CancelDraft(PlanHeader);
        Clear(SelectedPlanNo);
        SelectedVersionNo := 0;
        InitialiseSelection();
        LoadScreen('Draft cancelled.', false);
    end;

    local procedure AddPalletGroup(PalletTypeText: Text; PalletCount: Integer; TargetQuantity: Decimal; Description: Text)
    var
        Index: Integer;
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        SelectedPalletType: Enum "SAL Pallet Type";
    begin
        GetSelectedDraft(PlanHeader);
        if (PalletCount < 1) or (PalletCount > 50) then
            Error(PalletCountErr);
        if TargetQuantity <= 0 then
            Error(PalletTargetErr);
        if not Evaluate(SelectedPalletType, PalletTypeText) then
            Error(PalletTypeErr, PalletTypeText);
        if (SelectedPalletType <> SelectedPalletType::Standard) and (PalletCount <> 1) then
            Error(CustomPalletCountErr);

        for Index := 1 to PalletCount do begin
            Clear(PlanPallet);
            PlanPallet.Init();
            PlanPallet."Plan No." := PlanHeader."No.";
            PlanPallet."Version No." := PlanHeader."Version No.";
            PlanPallet."Pallet Type" := SelectedPalletType;
            PlanPallet.Description := CopyStr(Description, 1, MaxStrLen(PlanPallet.Description));
            PlanPallet."Target Quantity" := TargetQuantity;
            PlanPallet.Insert(true);
        end;
        LoadScreen(StrSubstNo(PalletsAddedMsg, PalletCount), false);
    end;

    local procedure DeletePallet(PalletNo: Integer)
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
    begin
        GetSelectedDraft(PlanHeader);
        if not PlanPallet.Get(PlanHeader."No.", PlanHeader."Version No.", PalletNo) then
            Error(PalletNotFoundErr, PalletNo);
        PlanComponent.SetRange("Plan No.", PlanHeader."No.");
        PlanComponent.SetRange("Version No.", PlanHeader."Version No.");
        PlanComponent.SetRange("Pallet No.", PalletNo);
        PlanComponent.DeleteAll(true);
        PlanPallet.Delete(true);
        LoadScreen(StrSubstNo(PalletDeletedMsg, PalletNo), false);
    end;

    local procedure AddComponent(PalletNo: Integer; SourceLineNo: Integer; Quantity: Decimal)
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
    begin
        GetSelectedDraft(PlanHeader);
        if Quantity <= 0 then
            Error(ComponentQuantityErr);
        if not PlanPallet.Get(PlanHeader."No.", PlanHeader."Version No.", PalletNo) then
            Error(PalletNotFoundErr, PalletNo);
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);
        PlanPallet.CalcFields("Planned Quantity", "No. of Components");
        if PlanPallet."Planned Quantity" + Quantity > PlanPallet."Target Quantity" then
            Error(PalletAllocationExceededErr, PalletNo, PlanPallet."Target Quantity", PlanPallet."Planned Quantity" + Quantity);
        if (PlanPallet."Pallet Type" = PlanPallet."Pallet Type"::Standard) and (PlanPallet."No. of Components" > 0) then
            Error(StandardPalletAllocationErr, PalletNo);
        PlanSource.CalcFields("Exact Planned Quantity");
        if PlanSource."Exact Planned Quantity" + Quantity > PlanSource.Quantity - PlanSource."Fill Target Quantity" then
            Error(ExactAllocationExceededErr, SourceLineNo, PlanSource.Quantity - PlanSource."Fill Target Quantity");

        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := PlanHeader."Version No.";
        PlanComponent."Pallet No." := PalletNo;
        PlanComponent.Validate("Source Line No.", SourceLineNo);
        PlanComponent.Validate(Quantity, Quantity);
        PlanComponent.Insert(true);
        LoadScreen(StrSubstNo(ComponentAddedMsg, PalletNo), false);
    end;

    local procedure AddFillComponent(PalletNo: Integer; SourceLineNo: Integer; FillMemberLineNo: Integer; Quantity: Decimal)
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
        PlanHeader: Record "SAL Plan Header";
    begin
        GetSelectedDraft(PlanHeader);
        AllocationManagement.AddFillComponent(PlanHeader, PalletNo, SourceLineNo, FillMemberLineNo, Quantity);
        LoadScreen(StrSubstNo(FillComponentAddedMsg, PalletNo), false);
    end;

    local procedure ConvertRemainingToFill(SourceLineNo: Integer; FillGroupCodeText: Text; Quantity: Decimal; AllowMixed: Boolean; MembersJson: Text; Reason: Text)
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
        CurrentPlanHeader: Record "SAL Plan Header";
        ResultPlanHeader: Record "SAL Plan Header";
        FillGroupCode: Code[20];
    begin
        GetSelectedPlan(CurrentPlanHeader);
        FillGroupCode := CopyStr(FillGroupCodeText, 1, MaxStrLen(FillGroupCode));
        AllocationManagement.ConvertRemainingToFill(
            CurrentPlanHeader, SourceLineNo, FillGroupCode, Quantity, AllowMixed, MembersJson, Reason, ResultPlanHeader);
        SelectedPlanNo := ResultPlanHeader."No.";
        SelectedVersionNo := ResultPlanHeader."Version No.";
        LoadScreen(StrSubstNo(FillConvertedMsg, Quantity, FillGroupCode), false);
    end;

    local procedure AdjustFillTarget(SourceLineNo: Integer; NewFillTarget: Decimal; Reason: Text)
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
        PlanHeader: Record "SAL Plan Header";
    begin
        GetSelectedDraft(PlanHeader);
        AllocationManagement.AdjustFillTarget(PlanHeader, SourceLineNo, NewFillTarget, Reason);
        LoadScreen(StrSubstNo(FillTargetAdjustedMsg, NewFillTarget), false);
    end;

    local procedure DeleteComponent(PalletNo: Integer; LineNo: Integer)
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
    begin
        GetSelectedDraft(PlanHeader);
        if not PlanComponent.Get(PlanHeader."No.", PlanHeader."Version No.", PalletNo, LineNo) then
            Error(ComponentNotFoundErr, PalletNo, LineNo);
        PlanComponent.Delete(true);
        LoadScreen('Pallet component removed.', false);
    end;

    local procedure SaveRouting(SourceLineNo: Integer; ExecutionRouteText: Text; FacilityWorkTypeText: Text)
    var
        ExecutionRoute: Enum "SAL Execution Route";
        FacilityWorkType: Enum "SAL Facility Work Type";
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        GetSelectedDraft(PlanHeader);
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);
        if not Evaluate(ExecutionRoute, ExecutionRouteText) then
            Error(RouteErr, ExecutionRouteText);
        if not Evaluate(FacilityWorkType, FacilityWorkTypeText) then
            Error(WorkTypeErr, FacilityWorkTypeText);

        PlanSource.Validate("Execution Route", ExecutionRoute);
        PlanSource.Validate("Facility Work Type", FacilityWorkType);
        PlanSource."Routing Confirmed" := true;
        PlanSource.Modify(true);
        LoadScreen('Route confirmed for the selected demand line.', false);
    end;

    local procedure SavePriority(NewPriority: Integer)
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        GetSelectedDraft(PlanHeader);
        PlanHeader.Validate(Priority, NewPriority);
        PlanHeader.Modify(true);

        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        if PlanSource.FindSet(true) then
            repeat
                PlanSource.Validate(Priority, NewPriority);
                PlanSource.Modify(true);
            until PlanSource.Next() = 0;

        LoadScreen(StrSubstNo(PriorityUpdatedMsg, NewPriority), false);
    end;

    local procedure SelectMarketer()
    var
        MarketerCustomer: Record Customer;
        PlanHeader: Record "SAL Plan Header";
        CustomerList: Page "Customer List";
    begin
        GetSelectedDraft(PlanHeader);

        if (PlanHeader."Marketer Customer No." <> '') and MarketerCustomer.Get(PlanHeader."Marketer Customer No.") then
            CustomerList.SetRecord(MarketerCustomer);
        CustomerList.LookupMode(true);
        if CustomerList.RunModal() <> Action::LookupOK then begin
            LoadScreen('', false);
            exit;
        end;

        CustomerList.GetRecord(MarketerCustomer);
        PlanHeader.Validate("Marketer Customer No.", MarketerCustomer."No.");
        PlanHeader."Marketer Confirmed" := true;
        PlanHeader.Modify(true);
        LoadScreen(StrSubstNo(MarketerUpdatedMsg, MarketerCustomer.Name), false);
    end;

    local procedure OpenSource(SourceLineNo: Integer)
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        SalesHeader: Record "Sales Header";
        TransferHeader: Record "Transfer Header";
    begin
        GetSelectedPlan(PlanHeader);
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);

        case PlanSource."Source Type" of
            PlanSource."Source Type"::SalesOrder:
                begin
                    SalesHeader.Get(SalesHeader."Document Type"::Order, PlanSource."Source Document No.");
                    Page.Run(Page::"Sales Order", SalesHeader);
                end;
            PlanSource."Source Type"::TransferOrder:
                begin
                    TransferHeader.Get(PlanSource."Source Document No.");
                    Page.Run(Page::"Transfer Order", TransferHeader);
                end;
        end;
    end;

    local procedure FormatDate(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    local procedure FormatDateTime(Value: DateTime): Text
    begin
        if Value = 0DT then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    var
        AddInReady: Boolean;
        SelectedPlanNo: Code[20];
        SelectedVersionNo: Integer;
        ComponentAddedMsg: Label 'Component added to pallet %1.', Comment = '%1 = pallet number';
        FillComponentAddedMsg: Label 'Fill component added to pallet %1.', Comment = '%1 = pallet number';
        FillConvertedMsg: Label '%1 units converted to fill group %2.', Comment = '%1 = quantity, %2 = fill group code';
        FillTargetAdjustedMsg: Label 'Fill target adjusted to %1 units.', Comment = '%1 = new fill target quantity';
        ComponentNotFoundErr: Label 'Pallet %1 component line %2 no longer exists.', Comment = '%1 = pallet number, %2 = line number';
        ComponentQuantityErr: Label 'Component quantity must be greater than zero.';
        CustomPalletCountErr: Label 'Add Custom or Mixed pallets one physical pallet at a time.';
        CandidatePlanCreatedMsg: Label 'SAL plan %1 created with %2 outstanding demand line(s).', Comment = '%1 = plan no., %2 = number of demand lines';
        DemandDocumentRequiredErr: Label 'The demand document number is required.';
        DemandReleaseFailedErr: Label '%1 %2 could not be released. Its current status is %3.', Comment = '%1 = source type, %2 = document no., %3 = current status';
        DemandSourceTypeErr: Label '%1 is not a supported SAL demand source type.', Comment = '%1 = supplied source type';
        ExistingPlanUpdatedMsg: Label 'SAL plan %1 version %2 selected and refreshed with the latest outstanding demand.', Comment = '%1 = plan no., %2 = version no.';
        ExactAllocationExceededErr: Label 'Source line %1 has only %2 exact units available after its fill conversion.', Comment = '%1 = source line, %2 = available exact target';
        FallbackPlanNoErr: Label 'A unique SAL plan number could not be generated for demand document %1. Configure SAL Plan Nos. and try again.', Comment = '%1 = source document no.';
        NoCandidateDemandErr: Label '%1 %2 no longer has eligible outstanding item demand to add.', Comment = '%1 = source type, %2 = source document no.';
        NoPlanSelectedErr: Label 'Select a SAL plan first.';
        PalletCountErr: Label 'Pallet count must be between 1 and 50.';
        PalletDeletedMsg: Label 'Pallet %1 removed.', Comment = '%1 = pallet number';
        PalletNotFoundErr: Label 'Pallet %1 no longer exists.', Comment = '%1 = pallet number';
        PalletAllocationExceededErr: Label 'Pallet %1 target is %2 units, but this component would bring it to %3.', Comment = '%1 = pallet no., %2 = target, %3 = proposed total';
        PalletTargetErr: Label 'Target quantity must be greater than zero.';
        PalletsAddedMsg: Label '%1 physical pallet(s) added.', Comment = '%1 = pallet count';
        PriorityUpdatedMsg: Label 'Plan priority updated to %1 (1 is highest).', Comment = '%1 = priority';
        MarketerUpdatedMsg: Label 'Plan marketer confirmed as %1.', Comment = '%1 = marketer customer name';
        PalletTypeErr: Label '%1 is not a valid SAL pallet type.', Comment = '%1 = supplied pallet type';
        PlanNotDraftErr: Label 'Plan %1 version %2 is %3. Only Draft plans can be changed.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 no longer exists.', Comment = '%1 = plan no., %2 = version no.';
        RouteErr: Label '%1 is not a valid execution route.', Comment = '%1 = supplied route';
        SourceNotFoundErr: Label 'Source line %1 no longer exists.', Comment = '%1 = source line number';
        StandardPalletAllocationErr: Label 'Standard pallet %1 already has its one component. Use a Custom or Mixed pallet for additional components.', Comment = '%1 = pallet no.';
        WorkTypeErr: Label '%1 is not a valid facility work type.', Comment = '%1 = supplied work type';
}
