codeunit 58006 "SAL Allocation Management"
{
    procedure AutoFillPallets(var PlanHeader: Record "SAL Plan Header"; AllowMixed: Boolean; var CreatedPallets: Integer; var SkippedLines: Integer)
    var
        PendingSource: Record "SAL Plan Source" temporary;
        PlanSource: Record "SAL Plan Source";
        StandardPalletType: Enum "SAL Pallet Type";
        PalletCapacity: Decimal;
        Remaining: Decimal;
    begin
        CreatedPallets := 0;
        SkippedLines := 0;
        LockAndGetPlan(PlanHeader);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(DraftRequiredErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);

        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        if PlanSource.FindSet() then
            repeat
                PlanSource.CalcFields("Exact Planned Quantity");
                Remaining := PlanSource.Quantity - PlanSource."Fill Target Quantity" - PlanSource."Exact Planned Quantity";
                if Remaining > 0 then
                    if FindPalletCapacity(PlanSource, PalletCapacity) then begin
                        while Remaining >= PalletCapacity do begin
                            CreateExactPallet(PlanHeader, PlanSource, PalletCapacity, StandardPalletType::Standard, CreatedPallets);
                            Remaining -= PalletCapacity;
                        end;
                        if Remaining > 0 then begin
                            PendingSource.Init();
                            PendingSource.TransferFields(PlanSource);
                            PendingSource.Quantity := Remaining;
                            PendingSource."Allocated Pallet Quantity" := PalletCapacity;
                            PendingSource.Insert();
                        end;
                    end else
                        SkippedLines += 1;
            until PlanSource.Next() = 0;

        if PendingSource.FindSet() then
            repeat
                if PendingSource.Quantity > 0 then
                    CreateShortPallet(PlanHeader, PendingSource, AllowMixed, CreatedPallets);
            until PendingSource.Next() = 0;

        if CreatedPallets > 0 then
            LogEvent(PlanHeader, AutoFilledEventTypeTxt,
                StrSubstNo(AutoFilledDescriptionTxt, CreatedPallets, SkippedLines, AllowMixed));
    end;

    local procedure FindPalletCapacity(PlanSource: Record "SAL Plan Source"; var PalletCapacity: Decimal): Boolean
    var
        TemplateRule: Record "SAL Template Rule";
        BestScore: Integer;
        RuleScore: Integer;
        FoundRule: Boolean;
    begin
        PalletCapacity := 0;
        TemplateRule.SetRange(Active, true);
        TemplateRule.SetRange("Unit of Measure Code", PlanSource."Unit of Measure Code");
        if TemplateRule.FindSet() then
            repeat
                if ((TemplateRule."Customer No." = '') or (TemplateRule."Customer No." = PlanSource."Customer No.")) and
                   ((TemplateRule."Ship-to Code" = '') or (TemplateRule."Ship-to Code" = PlanSource."Destination Code")) and
                   ((TemplateRule."Item No." = '') or (TemplateRule."Item No." = PlanSource."Item No.")) and
                   ((StrPos(UpperCase(PlanSource."Item No."), 'BKBN') = 0) or (TemplateRule."Item No." = PlanSource."Item No."))
                then begin
                    RuleScore := 0;
                    if TemplateRule."Customer No." <> '' then
                        RuleScore += 1;
                    if TemplateRule."Ship-to Code" <> '' then
                        RuleScore += 2;
                    if TemplateRule."Item No." <> '' then
                        RuleScore += 4;
                    if FoundRule and (RuleScore = BestScore) then
                        Error(AmbiguousRuleErr, PlanSource."Item No.", PlanSource."Customer No.", PlanSource."Destination Code");
                    if not FoundRule or (RuleScore > BestScore) then begin
                        FoundRule := true;
                        BestScore := RuleScore;
                        PalletCapacity := TemplateRule."Units per Pallet";
                    end;
                end;
            until TemplateRule.Next() = 0;
        exit(FoundRule);
    end;

    local procedure CreateExactPallet(PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; Quantity: Decimal; PalletType: Enum "SAL Pallet Type"; var CreatedPallets: Integer)
    var
        PlanPallet: Record "SAL Plan Pallet";
    begin
        if CreatedPallets >= 1000 then
            Error(AutoFillLimitErr);
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet."Version No." := PlanHeader."Version No.";
        PlanPallet."Pallet Type" := PalletType;
        PlanPallet."Target Quantity" := Quantity;
        PlanPallet.Description := CopyStr(PlanSource."Item Description", 1, MaxStrLen(PlanPallet.Description));
        PlanPallet.Insert(true);
        AddExactComponent(PlanPallet, PlanSource, Quantity);
        CreatedPallets += 1;
    end;

    local procedure CreateShortPallet(PlanHeader: Record "SAL Plan Header"; var PendingSource: Record "SAL Plan Source" temporary; AllowMixed: Boolean; var CreatedPallets: Integer)
    var
        OtherSource: Record "SAL Plan Source" temporary;
        PlanPallet: Record "SAL Plan Pallet";
        Capacity: Decimal;
        TakeQuantity: Decimal;
    begin
        if CreatedPallets >= 1000 then
            Error(AutoFillLimitErr);
        Capacity := PendingSource."Allocated Pallet Quantity";
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet."Version No." := PlanHeader."Version No.";
        PlanPallet."Pallet Type" := PlanPallet."Pallet Type"::Custom;
        PlanPallet."Target Quantity" := PendingSource.Quantity;
        PlanPallet.Description := CopyStr(ShortPalletDescriptionTxt, 1, MaxStrLen(PlanPallet.Description));
        PlanPallet.Insert(true);
        AddExactComponent(PlanPallet, PendingSource, PendingSource.Quantity);
        PendingSource.Quantity := 0;
        PendingSource.Modify();
        CreatedPallets += 1;

        if not AllowMixed then
            exit;
        OtherSource.Copy(PendingSource, true);
        if OtherSource.FindSet() then
            repeat
                if (OtherSource."Line No." <> PendingSource."Line No.") and (OtherSource.Quantity > 0) and
                   ((OtherSource."Item No." <> PendingSource."Item No.") or
                    (OtherSource."Variant Code" <> PendingSource."Variant Code")) and
                   (OtherSource."Source Type" = PendingSource."Source Type") and
                   (OtherSource."Source Document No." = PendingSource."Source Document No.") and
                   (OtherSource."Customer No." = PendingSource."Customer No.") and
                   (OtherSource."Destination Code" = PendingSource."Destination Code") and
                   (OtherSource."Execution Route" = PendingSource."Execution Route") and
                   (OtherSource."Facility Work Type" = PendingSource."Facility Work Type") and
                   (OtherSource."Unit of Measure Code" = PendingSource."Unit of Measure Code") and
                   (OtherSource."Allocated Pallet Quantity" = Capacity) and
                   (PlanPallet."Target Quantity" < Capacity)
                then begin
                    TakeQuantity := OtherSource.Quantity;
                    if TakeQuantity > Capacity - PlanPallet."Target Quantity" then
                        TakeQuantity := Capacity - PlanPallet."Target Quantity";
                    PlanPallet."Pallet Type" := PlanPallet."Pallet Type"::Mixed;
                    PlanPallet."Target Quantity" += TakeQuantity;
                    PlanPallet.Modify(true);
                    AddExactComponent(PlanPallet, OtherSource, TakeQuantity);
                    OtherSource.Quantity -= TakeQuantity;
                    OtherSource.Modify();
                end;
            until OtherSource.Next() = 0;
    end;

    local procedure AddExactComponent(PlanPallet: Record "SAL Plan Pallet"; PlanSource: Record "SAL Plan Source"; Quantity: Decimal)
    var
        PlanComponent: Record "SAL Plan Component";
    begin
        PlanComponent.Init();
        PlanComponent."Plan No." := PlanPallet."Plan No.";
        PlanComponent."Version No." := PlanPallet."Version No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent.Validate("Source Line No.", PlanSource."Line No.");
        PlanComponent.Validate(Quantity, Quantity);
        PlanComponent.Insert(true);
    end;

    procedure ConvertRemainingToFill(var CurrentPlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; FillGroupCode: Code[20]; ConvertQuantity: Decimal; AllowMixed: Boolean; MembersJson: Text; Reason: Text; var ResultPlanHeader: Record "SAL Plan Header")
    var
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        AvailableExactQuantity: Decimal;
    begin
        LockAndGetPlan(CurrentPlanHeader);
        if CurrentPlanHeader.Status <> CurrentPlanHeader.Status::Draft then
            Error(PlanStatusErr, CurrentPlanHeader."No.", CurrentPlanHeader."Version No.", CurrentPlanHeader.Status);
        if Reason.Trim() = '' then
            Error(ReasonRequiredErr);

        ValidateFillConversion(
            CurrentPlanHeader, SourceLineNo, FillGroupCode, ConvertQuantity, ProductGroup, PlanSource, AvailableExactQuantity);

        if (PlanSource."Fill Target Quantity" > 0) and (PlanSource."Fill Group Code" <> FillGroupCode) then
            Error(SourceAlreadyFillErr, SourceLineNo, PlanSource."Fill Group Code");
        if AllowMixed and not ProductGroup."Allow Mixed Pallets" then
            Error(MixedNotAllowedErr, FillGroupCode);

        ValidateGroupPalletCapacity(
            CurrentPlanHeader, PlanSource, ProductGroup, PlanSource."Fill Target Quantity" + ConvertQuantity);
        ApplyMemberSelection(CurrentPlanHeader, PlanSource, ProductGroup, MembersJson);
        ValidateSelectedCapacity(CurrentPlanHeader, PlanSource, PlanSource."Fill Target Quantity" + ConvertQuantity);

        if PlanSource."Fill Target Quantity" + ConvertQuantity = PlanSource.Quantity then
            PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::FillGroup
        else
            PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::Hybrid;
        PlanSource."Fill Group Code" := ProductGroup.Code;
        PlanSource."Fill Marketer Customer No." := ProductGroup."Marketer Customer No.";
        if PlanSource."Fill Target Quantity" = 0 then begin
            PlanSource."Fill Group Default Pallet Qty." := ProductGroup."Default Pallet Quantity";
            PlanSource."Fill Maximum Total Pallets" := ProductGroup."Maximum Total Pallets";
        end;
        PlanSource."Fill Target Quantity" += ConvertQuantity;
        PlanSource."Fill Allows Mixed Pallets" := AllowMixed;
        PlanSource."Fill Conversion Reason" := CopyStr(Reason, 1, MaxStrLen(PlanSource."Fill Conversion Reason"));
        PlanSource."Fill Converted At" := CurrentDateTime();
        PlanSource."Fill Converted By" := CopyStr(UserId(), 1, MaxStrLen(PlanSource."Fill Converted By"));
        PlanSource.Modify(true);

        LogEvent(
            CurrentPlanHeader,
            FillConvertedEventTypeTxt,
            StrSubstNo(FillConvertedDescriptionTxt, ConvertQuantity, SourceLineNo, ProductGroup.Code, Reason));

        ResultPlanHeader := CurrentPlanHeader;
    end;

    procedure AddFillComponent(var PlanHeader: Record "SAL Plan Header"; PalletNo: Integer; SourceLineNo: Integer; FillMemberLineNo: Integer; Quantity: Decimal)
    var
        FillMember: Record "SAL Plan Fill Member";
        PlanComponent: Record "SAL Plan Component";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        AggregatePlannedQuantity: Decimal;
        EffectiveMaximum: Decimal;
    begin
        LockAndGetPlan(PlanHeader);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(DraftRequiredErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);
        if Quantity <= 0 then
            Error(PositiveQuantityErr);
        if not PlanPallet.Get(PlanHeader."No.", PlanHeader."Version No.", PalletNo) then
            Error(PalletNotFoundErr, PalletNo);
        PlanPallet.CalcFields("Planned Quantity", "No. of Components");
        if PlanPallet."Planned Quantity" + Quantity > PlanPallet."Target Quantity" then
            Error(PalletTargetExceededErr, PalletNo, PlanPallet."Target Quantity", PlanPallet."Planned Quantity" + Quantity);
        if (PlanPallet."Pallet Type" = PlanPallet."Pallet Type"::Standard) and (PlanPallet."No. of Components" > 0) then
            Error(StandardPalletComponentErr, PalletNo);
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);
        if PlanSource."Fill Target Quantity" <= 0 then
            Error(SourceNotFillErr, SourceLineNo);
        if not FillMember.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo, FillMemberLineNo) then
            Error(FillMemberNotFoundErr, FillMemberLineNo, SourceLineNo);

        PlanSource.CalcFields("Fill Planned Quantity");
        if PlanSource."Fill Planned Quantity" + Quantity > PlanSource."Fill Target Quantity" then
            Error(FillTargetExceededErr, SourceLineNo, PlanSource."Fill Target Quantity", PlanSource."Fill Planned Quantity" + Quantity);

        FillMember.CalcFields("Planned Quantity");
        EffectiveMaximum := GetEffectiveMaximum(FillMember);
        AggregatePlannedQuantity := GetAggregateProductPlannedQuantity(FillMember);
        if (EffectiveMaximum > 0) and (AggregatePlannedQuantity + Quantity > EffectiveMaximum) then
            Error(MemberMaximumExceededErr, FillMember."Item No.", EffectiveMaximum);

        ValidatePalletMix(PlanSource, PlanPallet, FillMember);

        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := PlanHeader."Version No.";
        PlanComponent."Pallet No." := PalletNo;
        PlanComponent.Validate("Source Line No.", SourceLineNo);
        PlanComponent.Validate("Fill Member Line No.", FillMemberLineNo);
        PlanComponent.Validate(Quantity, Quantity);
        PlanComponent.Insert(true);
    end;

    procedure AddFlexibleFillComponent(var PlanHeader: Record "SAL Plan Header"; PalletNo: Integer; SourceLineNo: Integer; Quantity: Decimal)
    var
        PlanComponent: Record "SAL Plan Component";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
    begin
        LockAndGetPlan(PlanHeader);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(DraftRequiredErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);
        if Quantity <= 0 then
            Error(PositiveQuantityErr);
        if not PlanPallet.Get(PlanHeader."No.", PlanHeader."Version No.", PalletNo) then
            Error(PalletNotFoundErr, PalletNo);
        if PlanPallet."Pallet Type" <> PlanPallet."Pallet Type"::Standard then
            Error(FlexibleFillStandardPalletErr, PalletNo);
        PlanPallet.CalcFields("Planned Quantity", "No. of Components");
        if PlanPallet."No. of Components" > 0 then
            Error(FlexibleFillEmptyPalletErr, PalletNo);
        if PlanPallet."Planned Quantity" + Quantity > PlanPallet."Target Quantity" then
            Error(PalletTargetExceededErr, PalletNo, PlanPallet."Target Quantity", PlanPallet."Planned Quantity" + Quantity);
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);
        if PlanSource."Fill Target Quantity" <= 0 then
            Error(SourceNotFillErr, SourceLineNo);

        PlanSource.CalcFields("Fill Planned Quantity");
        if PlanSource."Fill Planned Quantity" + Quantity > PlanSource."Fill Target Quantity" then
            Error(FillTargetExceededErr, SourceLineNo, PlanSource."Fill Target Quantity", PlanSource."Fill Planned Quantity" + Quantity);

        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := PlanHeader."Version No.";
        PlanComponent."Pallet No." := PalletNo;
        PlanComponent.Validate("Source Line No.", SourceLineNo);
        PlanComponent."Fulfilment Mode" := PlanComponent."Fulfilment Mode"::FillGroup;
        PlanComponent."Fill Member Line No." := 0;
        PlanComponent."Item No." := '';
        PlanComponent."Variant Code" := '';
        PlanComponent."Unit of Measure Code" := PlanSource."Unit of Measure Code";
        PlanComponent.Description := CopyStr(
            StrSubstNo(FlexibleFillDescriptionTxt, PlanSource."Fill Group Code"),
            1,
            MaxStrLen(PlanComponent.Description));
        PlanComponent.Validate(Quantity, Quantity);
        PlanComponent.Insert(true);
    end;

    procedure AdjustFillTarget(var PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; NewFillTarget: Decimal; Reason: Text)
    var
        FillMember: Record "SAL Plan Fill Member";
        PlanSource: Record "SAL Plan Source";
        OldFillTarget: Decimal;
    begin
        LockAndGetPlan(PlanHeader);
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(DraftRequiredErr, PlanHeader."No.", PlanHeader."Version No.", PlanHeader.Status);
        if Reason.Trim() = '' then
            Error(ReasonRequiredErr);
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);
        OldFillTarget := PlanSource."Fill Target Quantity";
        if OldFillTarget <= 0 then
            Error(SourceNotFillErr, SourceLineNo);
        if (NewFillTarget < 0) or (NewFillTarget >= OldFillTarget) then
            Error(AdjustTargetRangeErr, OldFillTarget);

        PlanSource.CalcFields("Exact Planned Quantity", "Fill Planned Quantity");
        if NewFillTarget < PlanSource."Fill Planned Quantity" then
            Error(AdjustBelowPlannedErr, NewFillTarget, PlanSource."Fill Planned Quantity");
        if PlanSource."Exact Planned Quantity" > PlanSource.Quantity - NewFillTarget then
            Error(AdjustExactConflictErr, NewFillTarget, PlanSource."Exact Planned Quantity");
        if NewFillTarget > 0 then
            ValidateSelectedCapacity(PlanHeader, PlanSource, NewFillTarget);

        PlanSource."Fill Target Quantity" := NewFillTarget;
        PlanSource."Fill Conversion Reason" := CopyStr(Reason, 1, MaxStrLen(PlanSource."Fill Conversion Reason"));
        PlanSource."Fill Converted At" := CurrentDateTime();
        PlanSource."Fill Converted By" := CopyStr(UserId(), 1, MaxStrLen(PlanSource."Fill Converted By"));
        if NewFillTarget = 0 then begin
            PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::ExactSKU;
            PlanSource."Fill Group Code" := '';
            PlanSource."Fill Marketer Customer No." := '';
            PlanSource."Fill Allows Mixed Pallets" := false;
            PlanSource."Fill Group Default Pallet Qty." := 0;
            PlanSource."Fill Maximum Total Pallets" := 0;
            FillMember.SetRange("Plan No.", PlanHeader."No.");
            FillMember.SetRange("Version No.", PlanHeader."Version No.");
            FillMember.SetRange("Source Line No.", SourceLineNo);
            FillMember.DeleteAll(true);
        end else
            if NewFillTarget = PlanSource.Quantity then
                PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::FillGroup
            else
                PlanSource."Fulfilment Mode" := PlanSource."Fulfilment Mode"::Hybrid;
        PlanSource.Modify(true);

        LogEvent(
            PlanHeader,
            FillAdjustedEventTypeTxt,
            StrSubstNo(FillAdjustedDescriptionTxt, SourceLineNo, OldFillTarget, NewFillTarget, Reason));
    end;

    local procedure ValidateFillConversion(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; FillGroupCode: Code[20]; ConvertQuantity: Decimal; var ProductGroup: Record "SAL Product Group"; var PlanSource: Record "SAL Plan Source"; var AvailableExactQuantity: Decimal)
    begin
        if ConvertQuantity <= 0 then
            Error(PositiveQuantityErr);
        PlanHeader.TestField("Marketer Confirmed", true);
        PlanHeader.TestField("Marketer Customer No.");
        if not PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", SourceLineNo) then
            Error(SourceNotFoundErr, SourceLineNo);
        if not ProductGroup.Get(FillGroupCode) then
            Error(FillGroupNotFoundErr, FillGroupCode);
        ProductGroup.TestField(Active, true);
        ProductGroup.TestField("Marketer Customer No.");
        if ProductGroup."Marketer Customer No." <> PlanHeader."Marketer Customer No." then
            Error(MarketerMismatchErr, ProductGroup.Code, ProductGroup."Marketer Customer No.", PlanHeader."Marketer Customer No.");
        if (PlanSource."Fill Target Quantity" > 0) and (PlanSource."Fill Group Code" <> FillGroupCode) then
            Error(SourceAlreadyFillErr, SourceLineNo, PlanSource."Fill Group Code");

        PlanSource.CalcFields("Exact Planned Quantity");
        AvailableExactQuantity := PlanSource.Quantity - PlanSource."Fill Target Quantity" - PlanSource."Exact Planned Quantity";
        if ConvertQuantity > AvailableExactQuantity then
            Error(ConvertQuantityExceededErr, ConvertQuantity, AvailableExactQuantity, SourceLineNo);
    end;

    local procedure ApplyMemberSelection(PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; ProductGroup: Record "SAL Product Group"; MembersJson: Text)
    var
        ExistingFillMember: Record "SAL Plan Fill Member";
        GroupMember: Record "SAL Product Group Member";
        SeenMemberLines: Dictionary of [Integer, Boolean];
        SelectionArray: JsonArray;
        SelectionObject: JsonObject;
        SelectionToken: JsonToken;
        ValueToken: JsonToken;
        MemberLineNo: Integer;
        SelectedCount: Integer;
        Selected: Boolean;
        MinimumQuantity: Decimal;
        MaximumQuantity: Decimal;
        MaximumPallets: Decimal;
    begin
        if MembersJson = '' then begin
            GroupMember.SetRange("Group Code", ProductGroup.Code);
            GroupMember.SetRange(Active, true);
            if not GroupMember.FindSet() then
                Error(NoActiveMembersErr, ProductGroup.Code);
            repeat
                UpsertFillMember(PlanHeader, PlanSource, GroupMember, GroupMember."Minimum Quantity", GroupMember."Maximum Quantity", GroupMember."Maximum Pallets");
                SelectedCount += 1;
            until GroupMember.Next() = 0;
            exit;
        end;

        if not SelectionArray.ReadFrom(MembersJson) then
            Error(MemberSelectionJsonErr);
        foreach SelectionToken in SelectionArray do begin
            if not SelectionToken.IsObject() then
                Error(MemberSelectionJsonErr);
            SelectionObject := SelectionToken.AsObject();
            if not SelectionObject.Get('lineNo', ValueToken) then
                Error(MemberSelectionJsonErr);
            MemberLineNo := ValueToken.AsValue().AsInteger();
            if SeenMemberLines.ContainsKey(MemberLineNo) then
                Error(DuplicateMemberSelectionErr, MemberLineNo);
            Selected := true;
            if SelectionObject.Get('selected', ValueToken) then
                Selected := ValueToken.AsValue().AsBoolean();
            SeenMemberLines.Add(MemberLineNo, Selected);
            if Selected then begin
                if not GroupMember.Get(ProductGroup.Code, MemberLineNo) then
                    Error(GroupMemberNotFoundErr, MemberLineNo, ProductGroup.Code);
                GroupMember.TestField(Active, true);
                if GroupMember."Unit of Measure Code" <> PlanSource."Unit of Measure Code" then
                    Error(
                        FillMemberUOMMismatchErr,
                        GroupMember."Item No.", GroupMember."Unit of Measure Code", PlanSource."Unit of Measure Code");
                MinimumQuantity := GroupMember."Minimum Quantity";
                MaximumQuantity := GroupMember."Maximum Quantity";
                MaximumPallets := GroupMember."Maximum Pallets";
                ExistingFillMember.Reset();
                ExistingFillMember.SetRange("Plan No.", PlanHeader."No.");
                ExistingFillMember.SetRange("Version No.", PlanHeader."Version No.");
                ExistingFillMember.SetRange("Source Line No.", PlanSource."Line No.");
                ExistingFillMember.SetRange("Template Member Line No.", MemberLineNo);
                if ExistingFillMember.FindFirst() then begin
                    MinimumQuantity := ExistingFillMember."Minimum Quantity";
                    MaximumQuantity := ExistingFillMember."Maximum Quantity";
                    MaximumPallets := ExistingFillMember."Maximum Pallets";
                end;
                if SelectionObject.Get('minQuantity', ValueToken) then
                    MinimumQuantity := ValueToken.AsValue().AsDecimal();
                if SelectionObject.Get('maxQuantity', ValueToken) then
                    MaximumQuantity := ValueToken.AsValue().AsDecimal();
                if SelectionObject.Get('maxPallets', ValueToken) then
                    MaximumPallets := ValueToken.AsValue().AsDecimal();
                ValidateOverrides(MinimumQuantity, MaximumQuantity, MaximumPallets);
                UpsertFillMember(PlanHeader, PlanSource, GroupMember, MinimumQuantity, MaximumQuantity, MaximumPallets);
                SelectedCount += 1;
            end;
        end;

        if SelectedCount = 0 then
            Error(NoSelectedMembersErr, ProductGroup.Code);
        RemoveUnselectedMembers(PlanHeader, PlanSource, SeenMemberLines);
    end;

    local procedure RemoveUnselectedMembers(PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; SelectedMemberLines: Dictionary of [Integer, Boolean])
    var
        FillMember: Record "SAL Plan Fill Member";
        IsSelected: Boolean;
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", PlanSource."Line No.");
        if FillMember.FindSet(true) then
            repeat
                if SelectedMemberLines.Get(FillMember."Template Member Line No.", IsSelected) and not IsSelected then begin
                    FillMember.CalcFields("Planned Quantity");
                    if FillMember."Planned Quantity" > 0 then
                        Error(MemberDeselectionInUseErr, FillMember."Item No.", FillMember."Planned Quantity");
                    FillMember.Delete(true);
                end;
            until FillMember.Next() = 0;
    end;

    local procedure UpsertFillMember(PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; GroupMember: Record "SAL Product Group Member"; MinimumQuantity: Decimal; MaximumQuantity: Decimal; MaximumPallets: Decimal)
    var
        FillMember: Record "SAL Plan Fill Member";
        ProductGroup: Record "SAL Product Group";
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", PlanSource."Line No.");
        FillMember.SetRange("Template Member Line No.", GroupMember."Line No.");
        if not FillMember.FindFirst() then begin
            FillMember.Init();
            FillMember."Plan No." := PlanHeader."No.";
            FillMember."Version No." := PlanHeader."Version No.";
            FillMember."Source Line No." := PlanSource."Line No.";
            FillMember."Group Code" := GroupMember."Group Code";
            FillMember."Template Member Line No." := GroupMember."Line No.";
            FillMember."Item No." := GroupMember."Item No.";
            FillMember."Variant Code" := GroupMember."Variant Code";
            FillMember."Unit of Measure Code" := GroupMember."Unit of Measure Code";
            FillMember.Description := GroupMember.Description;
            FillMember."Default Pallet Quantity" := GroupMember."Default Pallet Quantity";
            if FillMember."Default Pallet Quantity" = 0 then
                if ProductGroup.Get(GroupMember."Group Code") then
                    FillMember."Default Pallet Quantity" := ProductGroup."Default Pallet Quantity";
            FillMember.Preference := GroupMember.Preference;
            FillMember."Minimum Quantity" := MinimumQuantity;
            FillMember."Maximum Quantity" := MaximumQuantity;
            FillMember."Maximum Pallets" := MaximumPallets;
            FillMember.Insert(true);
        end else begin
            if (FillMember."Item No." <> GroupMember."Item No.") or
               (FillMember."Variant Code" <> GroupMember."Variant Code") or
               (FillMember."Unit of Measure Code" <> GroupMember."Unit of Measure Code")
            then
                Error(TemplateIdentityChangedErr, GroupMember."Line No.", GroupMember."Group Code");
            FillMember."Minimum Quantity" := MinimumQuantity;
            FillMember."Maximum Quantity" := MaximumQuantity;
            FillMember."Maximum Pallets" := MaximumPallets;
            FillMember.CalcFields("Planned Quantity");
            if (GetEffectiveMaximum(FillMember) > 0) and (FillMember."Planned Quantity" > GetEffectiveMaximum(FillMember)) then
                Error(MemberMaximumBelowPlannedErr, FillMember."Item No.", FillMember."Planned Quantity");
            FillMember.Modify(true);
        end;
    end;

    local procedure ValidateSelectedCapacity(PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; ProposedFillTarget: Decimal)
    var
        FillMember: Record "SAL Plan Fill Member";
        EffectiveMaximum: Decimal;
        MaximumCapacity: Decimal;
        MinimumCommitment: Decimal;
        UnlimitedCapacity: Boolean;
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", PlanSource."Line No.");
        if not FillMember.FindSet() then
            Error(NoSelectedMembersErr, PlanSource."Fill Group Code");
        repeat
            MinimumCommitment += FillMember."Minimum Quantity";
            EffectiveMaximum := GetEffectiveMaximum(FillMember);
            if EffectiveMaximum = 0 then
                UnlimitedCapacity := true
            else
                MaximumCapacity += EffectiveMaximum;
        until FillMember.Next() = 0;

        if MinimumCommitment > ProposedFillTarget then
            Error(MemberMinimumCapacityErr, MinimumCommitment, ProposedFillTarget);
        if not UnlimitedCapacity and (MaximumCapacity < ProposedFillTarget) then
            Error(MemberMaximumCapacityErr, MaximumCapacity, ProposedFillTarget);
    end;

    local procedure ValidateOverrides(MinimumQuantity: Decimal; MaximumQuantity: Decimal; MaximumPallets: Decimal)
    begin
        if (MinimumQuantity < 0) or (MaximumQuantity < 0) or (MaximumPallets < 0) then
            Error(NegativeOverrideErr);
        if (MaximumQuantity > 0) and (MinimumQuantity > MaximumQuantity) then
            Error(MinimumExceedsMaximumErr, MinimumQuantity, MaximumQuantity);
    end;

    local procedure ValidatePalletMix(PlanSource: Record "SAL Plan Source"; PlanPallet: Record "SAL Plan Pallet"; FillMember: Record "SAL Plan Fill Member")
    var
        ExistingComponent: Record "SAL Plan Component";
        ExistingSource: Record "SAL Plan Source";
        HasDifferentProduct: Boolean;
    begin
        ExistingComponent.SetRange("Plan No.", PlanPallet."Plan No.");
        ExistingComponent.SetRange("Version No.", PlanPallet."Version No.");
        ExistingComponent.SetRange("Pallet No.", PlanPallet."Pallet No.");
        if ExistingComponent.FindSet() then
            repeat
                if (ExistingComponent."Item No." <> FillMember."Item No.") or
                   (ExistingComponent."Variant Code" <> FillMember."Variant Code")
                then
                    HasDifferentProduct := true;
            until (ExistingComponent.Next() = 0) or HasDifferentProduct;

        if HasDifferentProduct then begin
            if not PlanSource."Fill Allows Mixed Pallets" then
                Error(SourceMixedNotAllowedErr, PlanSource."Line No.");
            ExistingComponent.SetRange("Fulfilment Mode", ExistingComponent."Fulfilment Mode"::FillGroup);
            if ExistingComponent.FindSet() then
                repeat
                    ExistingSource.Get(
                        ExistingComponent."Plan No.", ExistingComponent."Version No.", ExistingComponent."Source Line No.");
                    if not ExistingSource."Fill Allows Mixed Pallets" then
                        Error(SourceMixedNotAllowedErr, ExistingSource."Line No.");
                until ExistingComponent.Next() = 0;
            if PlanPallet."Pallet Type" <> PlanPallet."Pallet Type"::Mixed then
                Error(PalletMustBeMixedErr, PlanPallet."Pallet No.");
        end;
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

    local procedure GetAggregateProductPlannedQuantity(CurrentFillMember: Record "SAL Plan Fill Member") AggregateQuantity: Decimal
    var
        FillMember: Record "SAL Plan Fill Member";
    begin
        FillMember.SetRange("Plan No.", CurrentFillMember."Plan No.");
        FillMember.SetRange("Version No.", CurrentFillMember."Version No.");
        FillMember.SetRange("Group Code", CurrentFillMember."Group Code");
        FillMember.SetRange("Item No.", CurrentFillMember."Item No.");
        FillMember.SetRange("Variant Code", CurrentFillMember."Variant Code");
        FillMember.SetRange("Unit of Measure Code", CurrentFillMember."Unit of Measure Code");
        if FillMember.FindSet() then
            repeat
                FillMember.CalcFields("Planned Quantity");
                AggregateQuantity += FillMember."Planned Quantity";
            until FillMember.Next() = 0;
    end;

    local procedure ValidateGroupPalletCapacity(PlanHeader: Record "SAL Plan Header"; CurrentPlanSource: Record "SAL Plan Source"; ProductGroup: Record "SAL Product Group"; ProposedFillTarget: Decimal)
    var
        PlanSource: Record "SAL Plan Source";
        DefaultPalletQuantity: Decimal;
        MaximumTotalPallets: Decimal;
        SourcePalletQuantity: Decimal;
        TotalPalletEquivalents: Decimal;
    begin
        MaximumTotalPallets := ProductGroup."Maximum Total Pallets";
        DefaultPalletQuantity := ProductGroup."Default Pallet Quantity";
        if (CurrentPlanSource."Fill Target Quantity" > 0) and
           (CurrentPlanSource."Fill Group Default Pallet Qty." > 0)
        then begin
            MaximumTotalPallets := CurrentPlanSource."Fill Maximum Total Pallets";
            DefaultPalletQuantity := CurrentPlanSource."Fill Group Default Pallet Qty.";
        end;
        if MaximumTotalPallets <= 0 then
            exit;
        if DefaultPalletQuantity <= 0 then
            Error(GroupPalletQuantityRequiredErr, ProductGroup.Code);

        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Fill Group Code", ProductGroup.Code);
        if PlanSource.FindSet() then
            repeat
                if PlanSource."Line No." = CurrentPlanSource."Line No." then begin
                    SourcePalletQuantity := DefaultPalletQuantity;
                    TotalPalletEquivalents += ProposedFillTarget / SourcePalletQuantity;
                end else
                    if PlanSource."Fill Target Quantity" > 0 then begin
                        SourcePalletQuantity := PlanSource."Fill Group Default Pallet Qty.";
                        if SourcePalletQuantity <= 0 then
                            SourcePalletQuantity := DefaultPalletQuantity;
                        TotalPalletEquivalents += PlanSource."Fill Target Quantity" / SourcePalletQuantity;
                    end;
            until PlanSource.Next() = 0;

        if CurrentPlanSource."Fill Group Code" = '' then
            TotalPalletEquivalents += ProposedFillTarget / DefaultPalletQuantity;
        if TotalPalletEquivalents > MaximumTotalPallets then
            Error(GroupPalletLimitExceededErr, ProductGroup.Code, MaximumTotalPallets, TotalPalletEquivalents);
    end;

    local procedure LockAndGetPlan(var PlanHeader: Record "SAL Plan Header")
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
    end;

    local procedure LogEvent(PlanHeader: Record "SAL Plan Header"; EventType: Text[50]; EventDescription: Text)
    var
        PlanEvent: Record "SAL Plan Event";
    begin
        PlanEvent.Init();
        PlanEvent."Plan No." := PlanHeader."No.";
        PlanEvent."Version No." := PlanHeader."Version No.";
        PlanEvent."Event Type" := EventType;
        PlanEvent.Description := CopyStr(EventDescription, 1, MaxStrLen(PlanEvent.Description));
        PlanEvent.Insert(true);
    end;

    var
        AmbiguousRuleErr: Label 'More than one equally specific pallet rule matches item %1, customer %2 and destination %3. Resolve duplicate rules before auto-filling.', Comment = '%1 = item, %2 = customer, %3 = destination';
        AutoFilledDescriptionTxt: Label '%1 pallets auto-filled; %2 exact source lines skipped without a matching rule. Mixed short pallets allowed: %3.', Comment = '%1 = pallet count, %2 = skipped line count, %3 = mixed choice';
        AutoFilledEventTypeTxt: Label 'Pallets Auto-filled', Locked = true;
        AutoFillLimitErr: Label 'Auto-fill would create more than 1,000 pallets. Split the demand or review the pallet rules.';
        ShortPalletDescriptionTxt: Label 'Short or mixed pallet';
        AdjustBelowPlannedErr: Label 'The new fill target of %1 cannot be below the %2 units already planned to fill members.', Comment = '%1 = proposed target, %2 = fill planned';
        AdjustExactConflictErr: Label 'The new fill target of %1 would leave less exact demand than the %2 exact units already planned.', Comment = '%1 = proposed target, %2 = exact planned';
        AdjustTargetRangeErr: Label 'Enter a new fill target from zero up to, but not including, the current target of %1. Use Convert remaining to fill when increasing it.', Comment = '%1 = current target';
        ConvertQuantityExceededErr: Label 'Cannot convert %1 units. Only %2 unplanned exact units remain on source line %3.', Comment = '%1 = requested, %2 = available, %3 = source line';
        DraftRequiredErr: Label 'Plan %1 version %2 is %3. Fill components can only be added to a Draft plan.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        FillConvertedDescriptionTxt: Label '%1 units on source line %2 converted to fill group %3. Reason: %4', Comment = '%1 = quantity, %2 = source line, %3 = group code, %4 = reason';
        FillConvertedEventTypeTxt: Label 'Fill Converted', Locked = true;
        FillAdjustedDescriptionTxt: Label 'Source line %1 fill target reduced from %2 to %3. Reason: %4', Comment = '%1 = source line, %2 = old target, %3 = new target, %4 = reason';
        FillAdjustedEventTypeTxt: Label 'Fill Adjusted', Locked = true;
        FillGroupNotFoundErr: Label 'Fill group %1 does not exist.', Comment = '%1 = fill group code';
        FlexibleFillDescriptionTxt: Label 'Fill %1 - any eligible product or size', Comment = '%1 = fill group code';
        FlexibleFillEmptyPalletErr: Label 'Pallet %1 already has a component. A flexible fill instruction must be the only component on its pallet.', Comment = '%1 = pallet no.';
        FlexibleFillStandardPalletErr: Label 'Pallet %1 must be Standard to use an unresolved flexible fill instruction. Use explicit products for Custom or Mixed pallets.', Comment = '%1 = pallet no.';
        FillMemberNotFoundErr: Label 'Fill member line %1 does not exist for source line %2.', Comment = '%1 = member line no., %2 = source line no.';
        FillMemberUOMMismatchErr: Label 'Fill member %1 uses unit %2, but the source demand uses %3. Fill quantities must use the same unit.', Comment = '%1 = item, %2 = member UOM, %3 = source UOM';
        FillTargetExceededErr: Label 'Source line %1 fill target is %2 units, but this component would bring the fill allocation to %3.', Comment = '%1 = source line, %2 = target, %3 = new planned total';
        DuplicateMemberSelectionErr: Label 'Fill member line %1 was supplied more than once.', Comment = '%1 = member line no.';
        GroupMemberNotFoundErr: Label 'Fill group member line %1 does not exist in group %2.', Comment = '%1 = member line, %2 = group code';
        GroupPalletLimitExceededErr: Label 'Fill group %1 allows at most %2 pallets in total, but this change would allocate %3 pallet equivalents across its fill lines.', Comment = '%1 = fill group code, %2 = maximum pallets, %3 = proposed pallet equivalents';
        GroupPalletQuantityRequiredErr: Label 'Fill group %1 needs a default pallet quantity before its overall pallet limit can be enforced.', Comment = '%1 = fill group code';
        MarketerMismatchErr: Label 'Fill group %1 is for marketer %2 and cannot be used on a plan for marketer %3.', Comment = '%1 = group code, %2 = group marketer, %3 = plan marketer';
        MemberMaximumExceededErr: Label 'Fill member %1 exceeds its maximum allocation of %2 units.', Comment = '%1 = item, %2 = maximum';
        MemberMaximumBelowPlannedErr: Label 'The maximum for fill member %1 cannot be reduced below its already planned quantity of %2.', Comment = '%1 = item, %2 = planned';
        MemberMaximumCapacityErr: Label 'The selected fill members can supply at most %1 units, less than the fill target of %2.', Comment = '%1 = maximum capacity, %2 = target';
        MemberDeselectionInUseErr: Label 'Fill member %1 cannot be deselected because %2 units are already planned against it.', Comment = '%1 = item, %2 = planned quantity';
        MemberMinimumCapacityErr: Label 'The selected fill member minimums total %1 units, more than the fill target of %2.', Comment = '%1 = minimum total, %2 = target';
        MemberSelectionJsonErr: Label 'The fill member selection is invalid. Reopen the fill dialog and try again.';
        MinimumExceedsMaximumErr: Label 'Minimum quantity %1 cannot exceed maximum quantity %2.', Comment = '%1 = minimum, %2 = maximum';
        MixedNotAllowedErr: Label 'Fill group %1 does not allow mixed pallets.', Comment = '%1 = group code';
        NegativeOverrideErr: Label 'Fill member minimums, maximums and pallet limits cannot be negative.';
        NoActiveMembersErr: Label 'Fill group %1 has no active products or sizes.', Comment = '%1 = group code';
        NoSelectedMembersErr: Label 'Select at least one product or size from fill group %1.', Comment = '%1 = group code';
        PalletMustBeMixedErr: Label 'Pallet %1 contains different products or sizes and must be set to Mixed.', Comment = '%1 = pallet no.';
        PalletNotFoundErr: Label 'Pallet %1 does not exist on the selected plan.', Comment = '%1 = pallet no.';
        PalletTargetExceededErr: Label 'Pallet %1 target is %2 units, but this component would bring it to %3.', Comment = '%1 = pallet no., %2 = target, %3 = new planned total';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
        PlanStatusErr: Label 'Plan %1 version %2 is %3. Only a Draft plan can convert unplanned exact demand to fill.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PositiveQuantityErr: Label 'Enter a quantity greater than zero.';
        ReasonRequiredErr: Label 'Enter a reason for converting the remaining demand to a fill group.';
        SourceAlreadyFillErr: Label 'Source line %1 already uses fill group %2. Additional fill must use the same group.', Comment = '%1 = source line, %2 = group code';
        SourceMixedNotAllowedErr: Label 'Source line %1 does not allow mixed fill pallets.', Comment = '%1 = source line no.';
        SourceNotFillErr: Label 'Source line %1 has not been converted to a fill group.', Comment = '%1 = source line no.';
        SourceNotFoundErr: Label 'Source line %1 does not exist on the selected plan.', Comment = '%1 = source line no.';
        StandardPalletComponentErr: Label 'Standard pallet %1 already has its one exact component. Use a Custom or Mixed pallet for additional components.', Comment = '%1 = pallet no.';
        TemplateIdentityChangedErr: Label 'Fill group member line %1 in group %2 no longer matches the plan snapshot. Add a new template member instead of changing product identity.', Comment = '%1 = member line no., %2 = group code';
}
