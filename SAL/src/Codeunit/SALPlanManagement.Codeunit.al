codeunit 58001 "SAL Plan Management"
{
    procedure ValidatePlan(var PlanHeader: Record "SAL Plan Header")
    begin
        LockAndGetDraftPlan(PlanHeader);
        ValidateAndStamp(PlanHeader);
    end;

    procedure ReleasePlan(var PlanHeader: Record "SAL Plan Header")
    var
        PreviousPlanHeader: Record "SAL Plan Header";
    begin
        LockAndGetDraftPlan(PlanHeader);
        ValidateAndStamp(PlanHeader);

        if PlanHeader."Previous Version No." > 0 then begin
            if not PreviousPlanHeader.Get(PlanHeader."No.", PlanHeader."Previous Version No.") then
                Error(PreviousVersionNotFoundErr, PlanHeader."No.", PlanHeader."Previous Version No.");
            if PreviousPlanHeader.Status <> PreviousPlanHeader.Status::Released then
                Error(PreviousVersionNotReleasedErr, PreviousPlanHeader."No.", PreviousPlanHeader."Version No.", PreviousPlanHeader.Status);
            PreviousPlanHeader.MarkSuperseded();
            LogEvent(
                PreviousPlanHeader."No.", PreviousPlanHeader."Version No.", SupersededEventTypeTxt,
                StrSubstNo(SupersededByVersionDescriptionTxt, PlanHeader."Version No."));
        end;

        PlanHeader.MarkReleased();
        LogEvent(PlanHeader."No.", PlanHeader."Version No.", ReleasedEventTypeTxt, ReleasedDescriptionTxt);
    end;

    procedure CreateNewVersion(var CurrentPlanHeader: Record "SAL Plan Header"; var NewPlanHeader: Record "SAL Plan Header")
    var
        ExistingPlanHeader: Record "SAL Plan Header";
        NextVersionNo: Integer;
        PlanNo: Code[20];
        VersionNo: Integer;
    begin
        CurrentPlanHeader.TestField("No.");
        CurrentPlanHeader.TestField("Version No.");
        PlanNo := CurrentPlanHeader."No.";
        VersionNo := CurrentPlanHeader."Version No.";

        CurrentPlanHeader.LockTable();
        if not CurrentPlanHeader.Get(PlanNo, VersionNo) then
            Error(PlanNotFoundErr, PlanNo, VersionNo);
        if CurrentPlanHeader.Status <> CurrentPlanHeader.Status::Released then
            Error(ReleasedVersionRequiredErr, CurrentPlanHeader."No.", CurrentPlanHeader."Version No.", CurrentPlanHeader.Status);

        ExistingPlanHeader.SetRange("No.", CurrentPlanHeader."No.");
        ExistingPlanHeader.SetRange(Status, ExistingPlanHeader.Status::Draft);
        if ExistingPlanHeader.FindFirst() then
            Error(DraftVersionExistsErr, ExistingPlanHeader."No.", ExistingPlanHeader."Version No.");

        ExistingPlanHeader.Reset();
        ExistingPlanHeader.SetRange("No.", CurrentPlanHeader."No.");
        if not ExistingPlanHeader.FindLast() then
            Error(PlanNotFoundErr, CurrentPlanHeader."No.", CurrentPlanHeader."Version No.");
        NextVersionNo := ExistingPlanHeader."Version No." + 1;

        InitialiseNewVersion(CurrentPlanHeader, NextVersionNo, NewPlanHeader);
        CopySources(CurrentPlanHeader, NewPlanHeader);
        CopyFillMembers(CurrentPlanHeader, NewPlanHeader);
        CopyPallets(CurrentPlanHeader, NewPlanHeader);
        CopyComponents(CurrentPlanHeader, NewPlanHeader);

        LogEvent(
            NewPlanHeader."No.", NewPlanHeader."Version No.", VersionCreatedEventTypeTxt,
            StrSubstNo(VersionCreatedDescriptionTxt, CurrentPlanHeader."Version No."));
    end;

    procedure CancelDraft(var PlanHeader: Record "SAL Plan Header")
    begin
        LockAndGetDraftPlan(PlanHeader);
        PlanHeader.MarkCancelled();
        LogEvent(PlanHeader."No.", PlanHeader."Version No.", CancelledEventTypeTxt, CancelledDescriptionTxt);
    end;

    procedure GetPlannerSuggestion(PlanHeader: Record "SAL Plan Header"): Text[250]
    var
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        PlannedQuantity: Decimal;
        RequiredQuantity: Decimal;
    begin
        if (PlanHeader."No." = '') or (PlanHeader."Version No." = 0) then
            exit(AddPlanDetailsSuggestionTxt);

        case PlanHeader.Status of
            PlanHeader.Status::Released:
                exit(ReleasedSuggestionTxt);
            PlanHeader.Status::Superseded:
                exit(SupersededSuggestionTxt);
            PlanHeader.Status::Cancelled:
                exit(CancelledSuggestionTxt);
        end;

        if not PlanHeader."Marketer Confirmed" then
            exit(ConfirmMarketerSuggestionTxt);

        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        if PlanSource.IsEmpty() then
            exit(AddDemandSuggestionTxt);

        PlanSource.SetRange("Routing Confirmed", false);
        if not PlanSource.IsEmpty() then
            exit(ConfirmRoutingSuggestionTxt);
        PlanSource.SetRange("Routing Confirmed");

        PlanPallet.SetRange("Plan No.", PlanHeader."No.");
        PlanPallet.SetRange("Version No.", PlanHeader."Version No.");
        if PlanPallet.IsEmpty() then
            exit(BuildPalletPlanSuggestionTxt);

        PlanSource.CalcSums(Quantity);
        RequiredQuantity := PlanSource.Quantity;
        CalculatePlannedQuantity(PlanHeader, PlannedQuantity);
        if PlannedQuantity < RequiredQuantity then
            exit(StrSubstNo(AllocateBalanceSuggestionTxt, RequiredQuantity - PlannedQuantity));
        if PlannedQuantity > RequiredQuantity then
            exit(StrSubstNo(ReduceAllocationSuggestionTxt, PlannedQuantity - RequiredQuantity));

        exit(ReadyToValidateSuggestionTxt);
    end;

    local procedure ValidateAndStamp(var PlanHeader: Record "SAL Plan Header")
    var
        PlanValidation: Codeunit "SAL Plan Validation";
    begin
        PlanValidation.ValidatePlan(PlanHeader);
        PlanHeader."Validated Date Time" := CurrentDateTime();
        PlanHeader."Validated By User Id" := CopyStr(UserId(), 1, MaxStrLen(PlanHeader."Validated By User Id"));
        PlanHeader.Modify(true);
        LogEvent(PlanHeader."No.", PlanHeader."Version No.", ValidatedEventTypeTxt, ValidatedDescriptionTxt);
    end;

    local procedure LockAndGetDraftPlan(var PlanHeader: Record "SAL Plan Header")
    var
        PlanNo: Code[20];
        VersionNo: Integer;
    begin
        PlanHeader.TestField("No.");
        PlanHeader.TestField("Version No.");
        PlanNo := PlanHeader."No.";
        VersionNo := PlanHeader."Version No.";
        PlanHeader.LockTable();
        if not PlanHeader.Get(PlanNo, VersionNo) then
            Error(PlanNotFoundErr, PlanNo, VersionNo);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(DraftPlanRequiredErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);
    end;

    local procedure InitialiseNewVersion(CurrentPlanHeader: Record "SAL Plan Header"; NextVersionNo: Integer; var NewPlanHeader: Record "SAL Plan Header")
    begin
        Clear(NewPlanHeader);
        NewPlanHeader.Init();
        NewPlanHeader."No." := CurrentPlanHeader."No.";
        NewPlanHeader."Version No." := NextVersionNo;
        NewPlanHeader.Description := CurrentPlanHeader.Description;
        NewPlanHeader.Status := NewPlanHeader.Status::Draft;
        NewPlanHeader."Previous Version No." := CurrentPlanHeader."Version No.";
        NewPlanHeader.Priority := CurrentPlanHeader.Priority;
        NewPlanHeader."Required Finish Date" := CurrentPlanHeader."Required Finish Date";
        NewPlanHeader."Dispatch Date" := CurrentPlanHeader."Dispatch Date";
        NewPlanHeader."Marketer Customer No." := CurrentPlanHeader."Marketer Customer No.";
        NewPlanHeader."Marketer Description" := CurrentPlanHeader."Marketer Description";
        NewPlanHeader."Marketer Confirmed" := false;
        NewPlanHeader."Created Date Time" := CurrentDateTime();
        NewPlanHeader."Created By User Id" := CopyStr(UserId(), 1, MaxStrLen(NewPlanHeader."Created By User Id"));
        NewPlanHeader.InsertRevision();
    end;

    local procedure CopySources(CurrentPlanHeader: Record "SAL Plan Header"; NewPlanHeader: Record "SAL Plan Header")
    var
        NewPlanSource: Record "SAL Plan Source";
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Plan No.", CurrentPlanHeader."No.");
        PlanSource.SetRange("Version No.", CurrentPlanHeader."Version No.");
        if PlanSource.FindSet() then
            repeat
                NewPlanSource.Init();
                NewPlanSource.TransferFields(PlanSource, true);
                NewPlanSource."Version No." := NewPlanHeader."Version No.";
                NewPlanSource."Routing Confirmed" := false;
                NewPlanSource.Insert(true);
            until PlanSource.Next() = 0;
    end;

    local procedure CopyPallets(CurrentPlanHeader: Record "SAL Plan Header"; NewPlanHeader: Record "SAL Plan Header")
    var
        NewPlanPallet: Record "SAL Plan Pallet";
        PlanPallet: Record "SAL Plan Pallet";
    begin
        PlanPallet.SetRange("Plan No.", CurrentPlanHeader."No.");
        PlanPallet.SetRange("Version No.", CurrentPlanHeader."Version No.");
        if PlanPallet.FindSet() then
            repeat
                NewPlanPallet.Init();
                NewPlanPallet.TransferFields(PlanPallet, true);
                NewPlanPallet."Version No." := NewPlanHeader."Version No.";
                NewPlanPallet.Insert(true);
            until PlanPallet.Next() = 0;
    end;

    local procedure CopyFillMembers(CurrentPlanHeader: Record "SAL Plan Header"; NewPlanHeader: Record "SAL Plan Header")
    var
        NewPlanFillMember: Record "SAL Plan Fill Member";
        PlanFillMember: Record "SAL Plan Fill Member";
    begin
        PlanFillMember.SetRange("Plan No.", CurrentPlanHeader."No.");
        PlanFillMember.SetRange("Version No.", CurrentPlanHeader."Version No.");
        if PlanFillMember.FindSet() then
            repeat
                NewPlanFillMember.Init();
                NewPlanFillMember.TransferFields(PlanFillMember, true);
                NewPlanFillMember."Version No." := NewPlanHeader."Version No.";
                NewPlanFillMember.Insert(true);
            until PlanFillMember.Next() = 0;
    end;

    local procedure CopyComponents(CurrentPlanHeader: Record "SAL Plan Header"; NewPlanHeader: Record "SAL Plan Header")
    var
        NewPlanComponent: Record "SAL Plan Component";
        PlanComponent: Record "SAL Plan Component";
    begin
        PlanComponent.SetRange("Plan No.", CurrentPlanHeader."No.");
        PlanComponent.SetRange("Version No.", CurrentPlanHeader."Version No.");
        if PlanComponent.FindSet() then
            repeat
                NewPlanComponent.Init();
                NewPlanComponent.TransferFields(PlanComponent, true);
                NewPlanComponent."Version No." := NewPlanHeader."Version No.";
                NewPlanComponent.Insert(true);
            until PlanComponent.Next() = 0;
    end;

    local procedure CalculatePlannedQuantity(PlanHeader: Record "SAL Plan Header"; var PlannedQuantity: Decimal)
    var
        PlanComponent: Record "SAL Plan Component";
    begin
        PlanComponent.SetRange("Plan No.", PlanHeader."No.");
        PlanComponent.SetRange("Version No.", PlanHeader."Version No.");
        PlanComponent.CalcSums(Quantity);
        PlannedQuantity := PlanComponent.Quantity;
    end;

    local procedure LogEvent(PlanNo: Code[20]; VersionNo: Integer; EventType: Text[50]; EventDescription: Text[250])
    var
        PlanEvent: Record "SAL Plan Event";
    begin
        PlanEvent.Init();
        PlanEvent."Plan No." := PlanNo;
        PlanEvent."Version No." := VersionNo;
        PlanEvent."Event Type" := EventType;
        PlanEvent.Description := EventDescription;
        PlanEvent.Insert(true);
    end;

    var
        AddDemandSuggestionTxt: Label 'Add released sales or transfer demand to this plan.';
        AddPlanDetailsSuggestionTxt: Label 'Create or select a plan before building its pallet plan.';
        AllocateBalanceSuggestionTxt: Label 'Allocate the remaining %1 units across physical pallets.', Comment = '%1 = unplanned quantity';
        BuildPalletPlanSuggestionTxt: Label 'Build the physical pallet plan for the confirmed demand.';
        CancelledDescriptionTxt: Label 'Draft plan version cancelled.';
        CancelledEventTypeTxt: Label 'Cancelled', Locked = true;
        CancelledSuggestionTxt: Label 'This plan version is cancelled and is retained for audit history.';
        ConfirmMarketerSuggestionTxt: Label 'Confirm the commercial marketer before planning pallets.';
        ConfirmRoutingSuggestionTxt: Label 'Confirm the execution route and Packing Facility work for every demand line.';
        DraftPlanRequiredErr: Label 'Plan %1 version %2 is %3. This action requires a Draft plan.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        DraftVersionExistsErr: Label 'Plan %1 already has Draft version %2. Complete or remove that draft before creating another version.', Comment = '%1 = plan no., %2 = version no.';
        PreviousVersionNotFoundErr: Label 'Plan %1 previous version %2 does not exist.', Comment = '%1 = plan no., %2 = previous version no.';
        PreviousVersionNotReleasedErr: Label 'Plan %1 version %2 is %3. Only a Released version can be superseded.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
        ReadyToValidateSuggestionTxt: Label 'Demand and pallet quantities are balanced. Validate and release this Cloud plan version. Packing Facility publishing is not connected yet.';
        ReduceAllocationSuggestionTxt: Label 'Pallet components exceed demand by %1 units. Reduce the allocation before validation.', Comment = '%1 = excess quantity';
        ReleasedDescriptionTxt: Label 'Plan version released in Cloud. It has not been published to the Packing Facility.';
        ReleasedEventTypeTxt: Label 'Released', Locked = true;
        ReleasedSuggestionTxt: Label 'This version is released in Cloud but has not been published to the Packing Facility. Create a new version to change it.';
        ReleasedVersionRequiredErr: Label 'Plan %1 version %2 is %3. New versions can only be created from a Released version.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        SupersededByVersionDescriptionTxt: Label 'Superseded by version %1.', Comment = '%1 = replacement version no.';
        SupersededEventTypeTxt: Label 'Superseded', Locked = true;
        SupersededSuggestionTxt: Label 'This version has been superseded. Open the current released version.';
        ValidatedDescriptionTxt: Label 'Plan version passed release validation.';
        ValidatedEventTypeTxt: Label 'Validated', Locked = true;
        VersionCreatedDescriptionTxt: Label 'Draft created from released version %1.', Comment = '%1 = source version no.';
        VersionCreatedEventTypeTxt: Label 'Version Created', Locked = true;
}
