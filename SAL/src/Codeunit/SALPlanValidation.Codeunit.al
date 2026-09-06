codeunit 58002 "SAL Plan Validation"
{
    procedure ValidatePlan(var PlanHeader: Record "SAL Plan Header")
    var
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
    begin
        PlanHeader.TestField("No.");
        PlanHeader.TestField("Version No.");
        LockAndRefreshPlan(PlanHeader);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(PlanMustBeDraftErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);
        if (PlanHeader.Priority < 1) or (PlanHeader.Priority > 10) then
            Error(PriorityErr);
        PlanHeader.TestField("Required Finish Date");
        PlanHeader.TestField("Dispatch Date");
        if PlanHeader."Dispatch Date" < PlanHeader."Required Finish Date" then
            Error(DispatchBeforeFinishErr);
        if not PlanHeader."Marketer Confirmed" then
            Error(MarketerNotConfirmedErr);
        PlanHeader.TestField("Marketer Description");
        if PlanHeader."Marketer Customer No." <> '' then
            ValidateMarketerCustomer(PlanHeader."Marketer Customer No.");

        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        if not PlanSource.FindSet() then
            Error(NoSourcesErr);
        repeat
            ValidateSource(PlanSource);
        until PlanSource.Next() = 0;

        PlanPallet.SetRange("Plan No.", PlanHeader."No.");
        PlanPallet.SetRange("Version No.", PlanHeader."Version No.");
        if not PlanPallet.FindSet() then
            Error(NoPalletsErr);
        repeat
            ValidatePallet(PlanPallet);
        until PlanPallet.Next() = 0;
    end;

    local procedure LockAndRefreshPlan(var PlanHeader: Record "SAL Plan Header")
    var
        PlanNo: Code[20];
        VersionNo: Integer;
    begin
        PlanNo := PlanHeader."No.";
        VersionNo := PlanHeader."Version No.";
        PlanHeader.LockTable();
        if not PlanHeader.Get(PlanNo, VersionNo) then
            Error(PlanNotFoundErr, PlanNo, VersionNo);
    end;

    local procedure ValidateSource(var PlanSource: Record "SAL Plan Source")
    var
        PlanComponent: Record "SAL Plan Component";
        PlannedQuantity: Decimal;
    begin
        PlanSource.TestField("Source Document No.");
        PlanSource.TestField("Source Document Line No.");
        PlanSource.TestField("Item No.");
        PlanSource.TestField("Unit of Measure Code");
        if PlanSource.Quantity <= 0 then
            Error(SourceQuantityErr, PlanSource."Line No.");
        if not PlanSource."Routing Confirmed" then
            Error(RoutingNotConfirmedErr, PlanSource."Line No.");
        ValidateRouteAndWorkType(PlanSource);
        ValidateSourceDocument(PlanSource);
        ValidateSourceSnapshot(PlanSource);

        PlanComponent.SetRange("Plan No.", PlanSource."Plan No.");
        PlanComponent.SetRange("Version No.", PlanSource."Version No.");
        PlanComponent.SetRange("Source Line No.", PlanSource."Line No.");
        PlanComponent.CalcSums(Quantity);
        PlannedQuantity := PlanComponent.Quantity;
        if not QuantitiesEqual(PlannedQuantity, PlanSource.Quantity) then
            Error(SourceTotalErr, PlanSource."Line No.", PlanSource.Quantity, PlannedQuantity);
    end;

    local procedure ValidateRouteAndWorkType(PlanSource: Record "SAL Plan Source")
    begin
        case PlanSource."Execution Route" of
            PlanSource."Execution Route"::ManjimupPack:
                if not (PlanSource."Facility Work Type" in
                    [PlanSource."Facility Work Type"::PackNew, PlanSource."Facility Work Type"::RepackOrRelabel])
                then
                    Error(RouteWorkTypeErr, PlanSource."Line No.", PlanSource."Execution Route", PlanSource."Facility Work Type");
            PlanSource."Execution Route"::ManjimupExistingStock:
                if PlanSource."Facility Work Type" <> PlanSource."Facility Work Type"::MatchExisting then
                    Error(RouteWorkTypeErr, PlanSource."Line No.", PlanSource."Execution Route", PlanSource."Facility Work Type");
            PlanSource."Execution Route"::ExternalDCFulfilment,
            PlanSource."Execution Route"::InterDCTransfer,
            PlanSource."Execution Route"::NoFacilityAction:
                if PlanSource."Facility Work Type" <> PlanSource."Facility Work Type"::None then
                    Error(RouteWorkTypeErr, PlanSource."Line No.", PlanSource."Execution Route", PlanSource."Facility Work Type");
        end;
    end;

    local procedure ValidateSourceDocument(PlanSource: Record "SAL Plan Source")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
    begin
        case PlanSource."Source Type" of
            PlanSource."Source Type"::SalesOrder:
                begin
                    if not SalesHeader.Get(SalesHeader."Document Type"::Order, PlanSource."Source Document No.") then
                        Error(SalesOrderNotFoundErr, PlanSource."Source Document No.");
                    if SalesHeader.Status <> SalesHeader.Status::Released then
                        Error(SourceNotReleasedErr, PlanSource."Source Document No.");
                    if not SalesLine.Get(SalesLine."Document Type"::Order, PlanSource."Source Document No.", PlanSource."Source Document Line No.") then
                        Error(SourceLineNotFoundErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if (SalesLine.Type <> SalesLine.Type::Item) or (SalesLine."No." <> PlanSource."Item No.") or
                       (SalesLine."Variant Code" <> PlanSource."Variant Code") or
                       (SalesLine."Unit of Measure Code" <> PlanSource."Unit of Measure Code")
                    then
                        Error(SourceLineChangedErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                end;
            PlanSource."Source Type"::TransferOrder:
                begin
                    if not TransferHeader.Get(PlanSource."Source Document No.") then
                        Error(TransferOrderNotFoundErr, PlanSource."Source Document No.");
                    if TransferHeader.Status <> TransferHeader.Status::Released then
                        Error(SourceNotReleasedErr, PlanSource."Source Document No.");
                    if not TransferLine.Get(PlanSource."Source Document No.", PlanSource."Source Document Line No.") then
                        Error(SourceLineNotFoundErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if (TransferLine."Item No." <> PlanSource."Item No.") or
                       (TransferLine."Variant Code" <> PlanSource."Variant Code") or
                       (TransferLine."Unit of Measure Code" <> PlanSource."Unit of Measure Code")
                    then
                        Error(SourceLineChangedErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                end;
        end;
    end;

    local procedure ValidateSourceSnapshot(PlanSource: Record "SAL Plan Source")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
    begin
        case PlanSource."Source Type" of
            PlanSource."Source Type"::SalesOrder:
                begin
                    SalesHeader.LockTable();
                    SalesLine.LockTable();
                    if not SalesHeader.Get(SalesHeader."Document Type"::Order, PlanSource."Source Document No.") then
                        Error(DemandNoLongerAvailableErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if SalesHeader.Status <> SalesHeader.Status::Released then
                        Error(DemandNotReleasedErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if not SalesLine.Get(SalesLine."Document Type"::Order, PlanSource."Source Document No.", PlanSource."Source Document Line No.") then
                        Error(DemandNoLongerAvailableErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if (SalesLine.Type <> SalesLine.Type::Item) or
                       (SalesLine."No." <> PlanSource."Item No.") or
                       (SalesLine."Variant Code" <> PlanSource."Variant Code") or
                       (SalesLine."Unit of Measure Code" <> PlanSource."Unit of Measure Code")
                    then
                        Error(DemandProductChangedErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if PlanSource.Quantity > SalesLine."Outstanding Quantity" then
                        Error(SourceExceedsDemandErr, PlanSource."Line No.", PlanSource.Quantity, SalesLine."Outstanding Quantity");
                end;
            PlanSource."Source Type"::TransferOrder:
                begin
                    TransferHeader.LockTable();
                    TransferLine.LockTable();
                    if not TransferHeader.Get(PlanSource."Source Document No.") then
                        Error(DemandNoLongerAvailableErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if TransferHeader.Status <> TransferHeader.Status::Released then
                        Error(DemandNotReleasedErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if not TransferLine.Get(PlanSource."Source Document No.", PlanSource."Source Document Line No.") then
                        Error(DemandNoLongerAvailableErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if (TransferLine."Item No." <> PlanSource."Item No.") or
                       (TransferLine."Variant Code" <> PlanSource."Variant Code") or
                       (TransferLine."Unit of Measure Code" <> PlanSource."Unit of Measure Code")
                    then
                        Error(DemandProductChangedErr, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
                    if PlanSource.Quantity > TransferLine."Outstanding Quantity" then
                        Error(SourceExceedsDemandErr, PlanSource."Line No.", PlanSource.Quantity, TransferLine."Outstanding Quantity");
                end;
        end;
    end;

    local procedure ValidatePallet(var PlanPallet: Record "SAL Plan Pallet")
    var
        PlanComponent: Record "SAL Plan Component";
        ComponentCount: Integer;
        FirstItemNo: Code[20];
        FirstVariantCode: Code[10];
        HasDifferentProduct: Boolean;
        PlannedQuantity: Decimal;
    begin
        if PlanPallet."Target Quantity" <= 0 then
            Error(PalletTargetErr, PlanPallet."Pallet No.");

        PlanComponent.SetRange("Plan No.", PlanPallet."Plan No.");
        PlanComponent.SetRange("Version No.", PlanPallet."Version No.");
        PlanComponent.SetRange("Pallet No.", PlanPallet."Pallet No.");
        if not PlanComponent.FindSet() then
            Error(PalletNoComponentsErr, PlanPallet."Pallet No.");
        repeat
            PlanComponent.TestField("Source Line No.");
            PlanComponent.TestField("Item No.");
            PlanComponent.TestField("Unit of Measure Code");
            if PlanComponent.Quantity <= 0 then
                Error(ComponentQuantityErr, PlanPallet."Pallet No.", PlanComponent."Line No.");
            ValidateComponentMatchesSource(PlanComponent);
            ComponentCount += 1;
            PlannedQuantity += PlanComponent.Quantity;
            if ComponentCount = 1 then begin
                FirstItemNo := PlanComponent."Item No.";
                FirstVariantCode := PlanComponent."Variant Code";
            end else
                if (PlanComponent."Item No." <> FirstItemNo) or (PlanComponent."Variant Code" <> FirstVariantCode) then
                    HasDifferentProduct := true;
        until PlanComponent.Next() = 0;

        if not QuantitiesEqual(PlannedQuantity, PlanPallet."Target Quantity") then
            Error(PalletTotalErr, PlanPallet."Pallet No.", PlanPallet."Target Quantity", PlannedQuantity);

        case PlanPallet."Pallet Type" of
            PlanPallet."Pallet Type"::Standard:
                if ComponentCount <> 1 then
                    Error(StandardPalletErr, PlanPallet."Pallet No.");
            PlanPallet."Pallet Type"::Custom:
                if ComponentCount < 1 then
                    Error(CustomPalletErr, PlanPallet."Pallet No.");
            PlanPallet."Pallet Type"::Mixed:
                if (ComponentCount < 2) or not HasDifferentProduct then
                    Error(MixedPalletErr, PlanPallet."Pallet No.");
        end;
    end;

    local procedure ValidateComponentMatchesSource(PlanComponent: Record "SAL Plan Component")
    var
        PlanSource: Record "SAL Plan Source";
    begin
        if not PlanSource.Get(PlanComponent."Plan No.", PlanComponent."Version No.", PlanComponent."Source Line No.") then
            Error(ComponentSourceErr, PlanComponent."Pallet No.", PlanComponent."Line No.");
        if (PlanComponent."Item No." <> PlanSource."Item No.") or
           (PlanComponent."Variant Code" <> PlanSource."Variant Code") or
           (PlanComponent."Unit of Measure Code" <> PlanSource."Unit of Measure Code")
        then
            Error(ComponentSourceMismatchErr, PlanComponent."Pallet No.", PlanComponent."Line No.", PlanSource."Line No.");
    end;

    local procedure ValidateMarketerCustomer(MarketerCustomerNo: Code[20])
    var
        Customer: Record Customer;
    begin
        if not Customer.Get(MarketerCustomerNo) then
            Error(MarketerCustomerNotFoundErr, MarketerCustomerNo);
    end;

    local procedure QuantitiesEqual(FirstQuantity: Decimal; SecondQuantity: Decimal): Boolean
    begin
        exit(Abs(FirstQuantity - SecondQuantity) < 0.00001);
    end;

    var
        ComponentQuantityErr: Label 'Pallet %1 component line %2 must have a quantity greater than zero.', Comment = '%1 = pallet no., %2 = component line no.';
        ComponentSourceErr: Label 'Pallet %1 component line %2 is not linked to a valid source line.', Comment = '%1 = pallet no., %2 = component line no.';
        ComponentSourceMismatchErr: Label 'Pallet %1 component line %2 does not match source line %3 item, variant and unit of measure.', Comment = '%1 = pallet no., %2 = component line no., %3 = source line no.';
        CustomPalletErr: Label 'Custom pallet %1 must contain at least one exact component.', Comment = '%1 = pallet no.';
        DemandNoLongerAvailableErr: Label 'Demand %1 line %2 is no longer available in the active consignment lines.', Comment = '%1 = document no., %2 = line no.';
        DemandNotReleasedErr: Label 'Demand %1 line %2 is no longer Released.', Comment = '%1 = document no., %2 = line no.';
        DemandProductChangedErr: Label 'Demand %1 line %2 now has a different item, variant or unit of measure. Refresh the demand and rebuild the affected pallet components.', Comment = '%1 = document no., %2 = line no.';
        DispatchBeforeFinishErr: Label 'Dispatch Date cannot be earlier than Required Finish Date.';
        MarketerCustomerNotFoundErr: Label 'Marketer customer %1 does not exist.', Comment = '%1 = customer no.';
        MarketerNotConfirmedErr: Label 'Confirm the commercial marketer before releasing the plan.';
        MixedPalletErr: Label 'Mixed pallet %1 must contain at least two components with different items or variants.', Comment = '%1 = pallet no.';
        NoPalletsErr: Label 'Add at least one physical pallet before releasing the plan.';
        NoSourcesErr: Label 'Add at least one source demand line before releasing the plan.';
        PalletNoComponentsErr: Label 'Pallet %1 has no components.', Comment = '%1 = pallet no.';
        PalletTargetErr: Label 'Pallet %1 must have a target quantity greater than zero.', Comment = '%1 = pallet no.';
        PalletTotalErr: Label 'Pallet %1 requires %2 units but its components total %3.', Comment = '%1 = pallet no., %2 = target quantity, %3 = planned quantity';
        PlanMustBeDraftErr: Label 'Plan %1 version %2 is %3. Only Draft plans can be validated for release.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
        PriorityErr: Label 'Priority must be between 1 and 10.';
        RouteWorkTypeErr: Label 'Source line %1 route %2 is not compatible with facility work type %3.', Comment = '%1 = source line no., %2 = route, %3 = work type';
        RoutingNotConfirmedErr: Label 'Confirm the route and facility work type for source line %1.', Comment = '%1 = source line no.';
        SalesOrderNotFoundErr: Label 'Sales Order %1 does not exist.', Comment = '%1 = sales order no.';
        SourceLineChangedErr: Label 'Source document %1 line %2 no longer matches the item, variant or unit of measure saved in the plan.', Comment = '%1 = document no., %2 = line no.';
        SourceLineNotFoundErr: Label 'Source document %1 line %2 does not exist.', Comment = '%1 = document no., %2 = line no.';
        SourceNotReleasedErr: Label 'Source document %1 is not Released.', Comment = '%1 = document no.';
        SourceExceedsDemandErr: Label 'Source line %1 plans %2 units, but current remaining demand is only %3. Reduce the plan quantity or refresh the demand.', Comment = '%1 = source line no., %2 = plan quantity, %3 = remaining demand';
        SourceQuantityErr: Label 'Source line %1 must have a required quantity greater than zero.', Comment = '%1 = source line no.';
        SourceTotalErr: Label 'Source line %1 requires %2 units but its pallet components total %3.', Comment = '%1 = source line no., %2 = required quantity, %3 = planned quantity';
        StandardPalletErr: Label 'Standard pallet %1 must contain exactly one component.', Comment = '%1 = pallet no.';
        TransferOrderNotFoundErr: Label 'Transfer Order %1 does not exist.', Comment = '%1 = transfer order no.';
}
