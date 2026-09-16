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
        ExactTargetQuantity: Decimal;
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

        if (PlanSource."Fill Target Quantity" < 0) or (PlanSource."Fill Target Quantity" > PlanSource.Quantity) then
            Error(FillTargetInvalidErr, PlanSource."Line No.", PlanSource."Fill Target Quantity", PlanSource.Quantity);

        PlanSource.CalcFields("Exact Planned Quantity", "Fill Planned Quantity");
        ExactTargetQuantity := PlanSource.Quantity - PlanSource."Fill Target Quantity";
        if not QuantitiesEqual(PlanSource."Exact Planned Quantity", ExactTargetQuantity) then
            Error(ExactSourceTotalErr, PlanSource."Line No.", ExactTargetQuantity, PlanSource."Exact Planned Quantity");
        if not QuantitiesEqual(PlanSource."Fill Planned Quantity", PlanSource."Fill Target Quantity") then
            Error(FillSourceTotalErr, PlanSource."Line No.", PlanSource."Fill Target Quantity", PlanSource."Fill Planned Quantity");

        if PlanSource."Fill Target Quantity" > 0 then
            ValidateFillSource(PlanSource)
        else
            if PlanSource."Fulfilment Mode" <> PlanSource."Fulfilment Mode"::ExactSKU then
                Error(ExactModeErr, PlanSource."Line No.");
    end;

    local procedure ValidateFillSource(PlanSource: Record "SAL Plan Source")
    var
        FillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        EffectiveMaximum: Decimal;
    begin
        PlanSource.TestField("Fill Group Code");
        PlanSource.TestField("Fill Marketer Customer No.");
        if PlanSource."Fill Target Quantity" = PlanSource.Quantity then begin
            if PlanSource."Fulfilment Mode" <> PlanSource."Fulfilment Mode"::FillGroup then
                Error(FillModeErr, PlanSource."Line No.");
        end else
            if PlanSource."Fulfilment Mode" <> PlanSource."Fulfilment Mode"::Hybrid then
                Error(HybridModeErr, PlanSource."Line No.");

        PlanHeader.Get(PlanSource."Plan No.", PlanSource."Version No.");
        if PlanSource."Fill Marketer Customer No." <> PlanHeader."Marketer Customer No." then
            Error(FillMarketerMismatchErr, PlanSource."Line No.", PlanSource."Fill Marketer Customer No.", PlanHeader."Marketer Customer No.");

        FillMember.SetRange("Plan No.", PlanSource."Plan No.");
        FillMember.SetRange("Version No.", PlanSource."Version No.");
        FillMember.SetRange("Source Line No.", PlanSource."Line No.");
        if not FillMember.FindSet() then
            Error(NoFillMembersErr, PlanSource."Line No.");
        repeat
            if FillMember."Group Code" <> PlanSource."Fill Group Code" then
                Error(FillMemberGroupErr, FillMember."Line No.", PlanSource."Line No.");
            if FillMember."Unit of Measure Code" <> PlanSource."Unit of Measure Code" then
                Error(
                    FillMemberUOMMismatchErr,
                    FillMember."Item No.", FillMember."Unit of Measure Code", PlanSource."Unit of Measure Code");
            FillMember.CalcFields("Planned Quantity");
            if (FillMember."Minimum Quantity" > 0) and (FillMember."Planned Quantity" < FillMember."Minimum Quantity") then
                Error(FillMemberMinimumErr, FillMember."Item No.", FillMember."Minimum Quantity", FillMember."Planned Quantity");
            EffectiveMaximum := GetEffectiveMaximum(FillMember);
            if (EffectiveMaximum > 0) and (FillMember."Planned Quantity" > EffectiveMaximum) then
                Error(FillMemberMaximumErr, FillMember."Item No.", EffectiveMaximum, FillMember."Planned Quantity");
        until FillMember.Next() = 0;
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

        if HasDifferentProduct then
            ValidateFillMixPermissions(PlanPallet);

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
        FillMember: Record "SAL Plan Fill Member";
        PlanSource: Record "SAL Plan Source";
    begin
        if not PlanSource.Get(PlanComponent."Plan No.", PlanComponent."Version No.", PlanComponent."Source Line No.") then
            Error(ComponentSourceErr, PlanComponent."Pallet No.", PlanComponent."Line No.");
        case PlanComponent."Fulfilment Mode" of
            PlanComponent."Fulfilment Mode"::ExactSKU:
                begin
                    if PlanComponent."Fill Member Line No." <> 0 then
                        Error(ExactComponentMemberErr, PlanComponent."Pallet No.", PlanComponent."Line No.");
                    if (PlanComponent."Item No." <> PlanSource."Item No.") or
                       (PlanComponent."Variant Code" <> PlanSource."Variant Code") or
                       (PlanComponent."Unit of Measure Code" <> PlanSource."Unit of Measure Code")
                    then
                        Error(ComponentSourceMismatchErr, PlanComponent."Pallet No.", PlanComponent."Line No.", PlanSource."Line No.");
                end;
            PlanComponent."Fulfilment Mode"::FillGroup:
                begin
                    if PlanSource."Fill Target Quantity" <= 0 then
                        Error(ComponentSourceNotFillErr, PlanComponent."Pallet No.", PlanComponent."Line No.", PlanSource."Line No.");
                    PlanComponent.TestField("Fill Member Line No.");
                    if not FillMember.Get(
                        PlanComponent."Plan No.", PlanComponent."Version No.", PlanComponent."Source Line No.", PlanComponent."Fill Member Line No.")
                    then
                        Error(ComponentFillMemberErr, PlanComponent."Pallet No.", PlanComponent."Line No.");
                    if (PlanComponent."Item No." <> FillMember."Item No.") or
                       (PlanComponent."Variant Code" <> FillMember."Variant Code") or
                       (PlanComponent."Unit of Measure Code" <> FillMember."Unit of Measure Code")
                    then
                        Error(ComponentFillMismatchErr, PlanComponent."Pallet No.", PlanComponent."Line No.", FillMember."Line No.");
                end;
            else
                Error(ComponentModeErr, PlanComponent."Pallet No.", PlanComponent."Line No.");
        end;
    end;

    local procedure ValidateFillMixPermissions(PlanPallet: Record "SAL Plan Pallet")
    var
        PlanComponent: Record "SAL Plan Component";
        PlanSource: Record "SAL Plan Source";
    begin
        PlanComponent.SetRange("Plan No.", PlanPallet."Plan No.");
        PlanComponent.SetRange("Version No.", PlanPallet."Version No.");
        PlanComponent.SetRange("Pallet No.", PlanPallet."Pallet No.");
        PlanComponent.SetRange("Fulfilment Mode", PlanComponent."Fulfilment Mode"::FillGroup);
        if PlanComponent.FindSet() then
            repeat
                PlanSource.Get(PlanComponent."Plan No.", PlanComponent."Version No.", PlanComponent."Source Line No.");
                if not PlanSource."Fill Allows Mixed Pallets" then
                    Error(FillMixNotAllowedErr, PlanPallet."Pallet No.", PlanSource."Line No.");
            until PlanComponent.Next() = 0;
    end;

    local procedure GetEffectiveMaximum(FillMember: Record "SAL Plan Fill Member") EffectiveMaximum: Decimal
    var
        PalletMaximum: Decimal;
    begin
        EffectiveMaximum := FillMember."Maximum Quantity";
        if FillMember."Maximum Pallets" > 0 then begin
            FillMember.TestField("Default Pallet Quantity");
            PalletMaximum := FillMember."Maximum Pallets" * FillMember."Default Pallet Quantity";
            if (EffectiveMaximum = 0) or (PalletMaximum < EffectiveMaximum) then
                EffectiveMaximum := PalletMaximum;
        end;
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
        ComponentFillMemberErr: Label 'Pallet %1 component line %2 is not linked to a valid fill member.', Comment = '%1 = pallet no., %2 = component line no.';
        ComponentFillMismatchErr: Label 'Pallet %1 component line %2 does not match fill member line %3 item, variant and unit of measure.', Comment = '%1 = pallet no., %2 = component line no., %3 = fill member line no.';
        ComponentModeErr: Label 'Pallet %1 component line %2 has an invalid fulfilment mode.', Comment = '%1 = pallet no., %2 = component line no.';
        ComponentSourceErr: Label 'Pallet %1 component line %2 is not linked to a valid source line.', Comment = '%1 = pallet no., %2 = component line no.';
        ComponentSourceMismatchErr: Label 'Pallet %1 component line %2 does not match source line %3 item, variant and unit of measure.', Comment = '%1 = pallet no., %2 = component line no., %3 = source line no.';
        ComponentSourceNotFillErr: Label 'Pallet %1 component line %2 is marked as fill, but source line %3 has no fill target.', Comment = '%1 = pallet no., %2 = component line no., %3 = source line no.';
        CustomPalletErr: Label 'Custom pallet %1 must contain at least one component.', Comment = '%1 = pallet no.';
        DemandNoLongerAvailableErr: Label 'Demand %1 line %2 is no longer available in the active consignment lines.', Comment = '%1 = document no., %2 = line no.';
        DemandNotReleasedErr: Label 'Demand %1 line %2 is no longer Released.', Comment = '%1 = document no., %2 = line no.';
        DemandProductChangedErr: Label 'Demand %1 line %2 now has a different item, variant or unit of measure. Refresh the demand and rebuild the affected pallet components.', Comment = '%1 = document no., %2 = line no.';
        DispatchBeforeFinishErr: Label 'Dispatch Date cannot be earlier than Required Finish Date.';
        ExactComponentMemberErr: Label 'Pallet %1 exact component line %2 cannot reference a fill member.', Comment = '%1 = pallet no., %2 = component line no.';
        ExactModeErr: Label 'Source line %1 has no fill target and must remain Exact SKU.', Comment = '%1 = source line no.';
        ExactSourceTotalErr: Label 'Source line %1 requires %2 exact units but its exact pallet components total %3.', Comment = '%1 = source line, %2 = exact target, %3 = exact planned';
        FillMarketerMismatchErr: Label 'Source line %1 fill marketer %2 does not match plan marketer %3.', Comment = '%1 = source line, %2 = fill marketer, %3 = plan marketer';
        FillMemberGroupErr: Label 'Fill member line %1 does not match the fill group on source line %2.', Comment = '%1 = member line, %2 = source line';
        FillMemberMaximumErr: Label 'Fill member %1 allows at most %2 units but %3 are planned.', Comment = '%1 = item, %2 = maximum, %3 = planned';
        FillMemberMinimumErr: Label 'Fill member %1 requires at least %2 units but only %3 are planned.', Comment = '%1 = item, %2 = minimum, %3 = planned';
        FillMemberUOMMismatchErr: Label 'Fill member %1 uses unit %2, but source demand uses %3. Fill quantities must use the same unit.', Comment = '%1 = item, %2 = member UOM, %3 = source UOM';
        FillMixNotAllowedErr: Label 'Pallet %1 mixes products or sizes, but source line %2 does not allow a mixed fill pallet.', Comment = '%1 = pallet no., %2 = source line';
        FillModeErr: Label 'Source line %1 is entirely flexible and must use Fill Group mode.', Comment = '%1 = source line no.';
        FillSourceTotalErr: Label 'Source line %1 requires %2 fill units but its fill pallet components total %3.', Comment = '%1 = source line, %2 = fill target, %3 = fill planned';
        FillTargetInvalidErr: Label 'Source line %1 has fill target %2, which cannot exceed its total quantity of %3.', Comment = '%1 = source line, %2 = fill target, %3 = total';
        HybridModeErr: Label 'Source line %1 contains both exact and fill demand and must use Exact + Fill mode.', Comment = '%1 = source line no.';
        MarketerCustomerNotFoundErr: Label 'Marketer customer %1 does not exist.', Comment = '%1 = customer no.';
        MarketerNotConfirmedErr: Label 'Confirm the commercial marketer before releasing the plan.';
        MixedPalletErr: Label 'Mixed pallet %1 must contain at least two components with different items or variants.', Comment = '%1 = pallet no.';
        NoFillMembersErr: Label 'Source line %1 has a fill target but no eligible products or sizes.', Comment = '%1 = source line no.';
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
