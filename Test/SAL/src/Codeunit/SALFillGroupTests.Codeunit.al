codeunit 58801 "SAL Fill Group Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        AssertFailedErr: Label 'Assertion failed: %1', Comment = '%1 = message';

    [Test]
    procedure PartialConversionPreservesExactAllocationAndSnapshotsEveryMember()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] 640 trays of exact demand, of which 160 are already allocated
        CreatePlanWithSalesDemand(640, PlanHeader, PlanSource);
        CreateExactPallet(PlanHeader, PlanSource, 160);
        CreateFillGroup(PlanHeader."Marketer Customer No.", true, 4, ProductGroup);

        // [WHEN] 320 of the remaining exact demand is converted to a fill group
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 320, true, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);

        // [THEN] the prior exact allocation is untouched and 160 exact trays remain unplanned
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        PlanSource.CalcFields("Exact Planned Quantity", "Fill Planned Quantity");
        AssertThat(PlanSource."Fill Target Quantity" = 320, 'expected a 320-tray fill target');
        AssertThat(PlanSource."Exact Planned Quantity" = 160, 'expected the existing exact allocation to remain 160');
        AssertThat((PlanSource.Quantity - PlanSource."Fill Target Quantity" - PlanSource."Exact Planned Quantity") = 160, 'expected 160 exact trays to remain available');
        AssertThat(PlanSource."Fill Planned Quantity" = 0, 'expected no fill quantity to be physically planned yet');
        AssertThat(CountFillMembers(ResultPlanHeader, PlanSource."Line No.") = 4, 'expected all four eligible members to be snapshotted');
        AssertEventExists(ResultPlanHeader, 'Fill Converted');
    end;

    [Test]
    procedure FullConversionCanConvertOnlyTheUnplannedExactBalance()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] 480 trays of demand with one exact 160-tray pallet already allocated
        CreatePlanWithSalesDemand(480, PlanHeader, PlanSource);
        CreateExactPallet(PlanHeader, PlanSource, 160);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 3, ProductGroup);

        // [WHEN] the complete 320-tray unplanned balance is converted
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 320, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);

        // [THEN] the exact target now equals the existing exact allocation
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        PlanSource.CalcFields("Exact Planned Quantity");
        AssertThat((PlanSource.Quantity - PlanSource."Fill Target Quantity") = 160, 'expected the residual exact target to be 160');
        AssertThat(PlanSource."Exact Planned Quantity" = 160, 'expected the residual exact target to be fully allocated');
        AssertThat(PlanSource."Fill Target Quantity" = 320, 'expected all unplanned demand to become fill demand');
    end;

    [Test]
    procedure ConversionCannotConsumeQuantityAlreadyAllocatedAsExact()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] 320 trays of demand with 160 already allocated to an exact SKU pallet
        CreatePlanWithSalesDemand(320, PlanHeader, PlanSource);
        CreateExactPallet(PlanHeader, PlanSource, 160);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);

        // [WHEN/THEN] 161 trays cannot be converted because only 160 remain unplanned
        AssertThat(
            not TryConvertToFill(
                PlanHeader, PlanSource, ProductGroup.Code, 161, false,
                BuildMembersJson(ProductGroup.Code), ResultPlanHeader),
            'expected conversion to preserve quantity already allocated as exact');
        PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 0, 'expected a failed conversion to leave the source unchanged');
        AssertThat(CountFillMembers(PlanHeader, PlanSource."Line No.") = 0, 'expected no member snapshot after a failed conversion');
    end;

    [Test]
    procedure ReducingAndClearingFillTargetReturnsBalanceToExactAndLogsAudit()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] 320 trays with 240 converted to a fill group
        CreatePlanWithSalesDemand(320, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", true, 3, ProductGroup);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 240, true, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);

        // [WHEN] the fill target is reduced to 80
        AdjustFillTarget(ResultPlanHeader, PlanSource."Line No.", 80, 'Return 160 trays to exact demand');

        // [THEN] the unallocated balance returns to exact demand and the fill contract remains active
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 80, 'expected the reduced fill target to be 80');
        AssertThat((PlanSource.Quantity - PlanSource."Fill Target Quantity") = 240, 'expected 240 trays to return to exact demand');
        AssertThat(PlanSource."Fulfilment Mode" = PlanSource."Fulfilment Mode"::Hybrid, 'expected the reduced source to remain Exact + Fill');
        AssertThat(CountFillMembers(ResultPlanHeader, PlanSource."Line No.") = 3, 'expected fill members to remain while a fill target exists');

        // [WHEN] the remaining fill target is cleared
        AdjustFillTarget(ResultPlanHeader, PlanSource."Line No.", 0, 'Return all remaining fill demand to exact');

        // [THEN] fill metadata and snapshots are removed and both adjustments are audited
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 0, 'expected the fill target to be cleared');
        AssertThat(PlanSource."Fulfilment Mode" = PlanSource."Fulfilment Mode"::ExactSKU, 'expected the source to return to Exact SKU mode');
        AssertThat(PlanSource."Fill Group Code" = '', 'expected the fill group identity to be cleared');
        AssertThat(PlanSource."Fill Marketer Customer No." = '', 'expected the fill marketer snapshot to be cleared');
        AssertThat(not PlanSource."Fill Allows Mixed Pallets", 'expected mixed-fill permission to be cleared');
        AssertThat(CountFillMembers(ResultPlanHeader, PlanSource."Line No.") = 0, 'expected fill member snapshots to be removed');
        AssertThat(CountEvents(ResultPlanHeader, 'Fill Adjusted') = 2, 'expected both target reductions to be audited');
    end;

    [Test]
    procedure FillTargetCannotBeReducedBelowAlreadyPlannedFillQuantity()
    var
        FillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a 160-tray fill target with 100 trays already assigned to a physical pallet
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 1, FillMember);
        CreatePallet(ResultPlanHeader, 100, PlanPallet."Pallet Type"::Standard, PlanPallet);
        AddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", FillMember."Line No.", 100);

        // [WHEN/THEN] the target cannot be reduced below the 100 trays already planned
        AssertThat(
            not TryAdjustFillTarget(ResultPlanHeader, PlanSource."Line No.", 99, 'Invalid reduction below planned fill'),
            'expected a fill target below already planned fill quantity to be rejected');
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 160, 'expected the rejected adjustment to leave the fill target unchanged');
        AssertThat(CountEvents(ResultPlanHeader, 'Fill Adjusted') = 0, 'expected no adjustment audit event after a rejected change');
    end;

    [Test]
    procedure RepeatedConversionPreservesSnapshotCapsAndRemovesUnplannedDeselectedMember()
    var
        FirstFillMember: Record "SAL Plan Fill Member";
        FirstTemplateMember: Record "SAL Product Group Member";
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
        ThirdTemplateMember: Record "SAL Product Group Member";
    begin
        // [GIVEN] an initial conversion with a 90-tray order-specific cap and three snapshotted members
        CreatePlanWithSalesDemand(200, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", true, 3, ProductGroup);
        GetGroupMemberByOrdinal(ProductGroup.Code, 1, FirstTemplateMember);
        GetGroupMemberByOrdinal(ProductGroup.Code, 3, ThirdTemplateMember);
        ConvertToFill(
            PlanHeader, PlanSource, ProductGroup.Code, 80, true,
            BuildMembersJsonWithOverride(ProductGroup.Code, FirstTemplateMember."Line No.", 90, 0), ResultPlanHeader);

        // [WHEN] another 40 trays are converted, retaining members 1 and 2 but deselecting unused member 3
        ConvertToFill(
            ResultPlanHeader, PlanSource, ProductGroup.Code, 40, true,
            BuildSelectionOnlyJson(ProductGroup.Code, ThirdTemplateMember."Line No."), ResultPlanHeader);

        // [THEN] the original cap is retained and the unused deselected snapshot is removed
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberForTemplate(ResultPlanHeader, PlanSource."Line No.", FirstTemplateMember."Line No.", FirstFillMember);
        AssertThat(PlanSource."Fill Target Quantity" = 120, 'expected repeated conversion to extend the fill target to 120');
        AssertThat(FirstFillMember."Maximum Quantity" = 90, 'expected repeated conversion without an override to preserve the snapshotted cap');
        AssertThat(CountFillMembers(ResultPlanHeader, PlanSource."Line No.") = 2, 'expected the unused deselected member to be removed');
        AssertThat(
            not FillMemberExistsForTemplate(ResultPlanHeader, PlanSource."Line No.", ThirdTemplateMember."Line No."),
            'expected member 3 to be absent from the updated snapshot');
    end;

    [Test]
    procedure RepeatedConversionCannotDeselectMemberWithPlannedQuantity()
    var
        FirstTemplateMember: Record "SAL Product Group Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        PlannedFillMember: Record "SAL Plan Fill Member";
        PlannedTemplateMember: Record "SAL Product Group Member";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] one selected member already contributes 40 trays to a physical pallet
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", true, 2, ProductGroup);
        GetGroupMemberByOrdinal(ProductGroup.Code, 1, FirstTemplateMember);
        GetGroupMemberByOrdinal(ProductGroup.Code, 2, PlannedTemplateMember);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 80, true, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberForTemplate(ResultPlanHeader, PlanSource."Line No.", PlannedTemplateMember."Line No.", PlannedFillMember);
        CreatePallet(ResultPlanHeader, 40, PlanPallet."Pallet Type"::Standard, PlanPallet);
        AddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", PlannedFillMember."Line No.", 40);

        // [WHEN/THEN] a repeated conversion cannot deselect the member used by that pallet
        AssertThat(
            not TryConvertToFill(
                ResultPlanHeader, PlanSource, ProductGroup.Code, 40, true,
                BuildSelectionOnlyJson(ProductGroup.Code, PlannedTemplateMember."Line No."), ResultPlanHeader),
            'expected deselection of a planned fill member to be rejected');
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 80, 'expected the rejected repeated conversion to leave the fill target unchanged');
        AssertThat(
            FillMemberExistsForTemplate(ResultPlanHeader, PlanSource."Line No.", PlannedTemplateMember."Line No."),
            'expected the planned member snapshot to remain');
        AssertThat(
            FillMemberExistsForTemplate(ResultPlanHeader, PlanSource."Line No.", FirstTemplateMember."Line No."),
            'expected the other selected member snapshot to remain');
    end;

    [Test]
    procedure FillGroupMemberUnitOfMeasureMustMatchSourceDemand()
    var
        MismatchedMember: Record "SAL Product Group Member";
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] exact demand measured in trays and a selected group member measured in eaches
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        GetGroupMemberByOrdinal(ProductGroup.Code, 1, MismatchedMember);
        MismatchedMember."Unit of Measure Code" := 'EACH';
        MismatchedMember.Modify(true);

        // [WHEN/THEN] the incompatible member blocks conversion before a fill contract is created
        AssertThat(
            not TryConvertToFill(
                PlanHeader, PlanSource, ProductGroup.Code, 160, false,
                BuildMembersJson(ProductGroup.Code), ResultPlanHeader),
            'expected a selected member with a different unit of measure to be rejected');
        PlanSource.Get(PlanHeader."No.", PlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 0, 'expected the failed UOM conversion to leave the source exact');
        AssertThat(CountFillMembers(PlanHeader, PlanSource."Line No.") = 0, 'expected no snapshots after a UOM mismatch');
    end;

    [Test]
    procedure FillTargetCannotBeReducedBelowSelectedMemberMinimums()
    var
        MinimumMember: Record "SAL Product Group Member";
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a 160-tray fill target whose selected members commit at least 100 trays
        CreatePlanWithSalesDemand(200, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        GetGroupMemberByOrdinal(ProductGroup.Code, 1, MinimumMember);
        MinimumMember."Minimum Quantity" := 100;
        MinimumMember.Modify(true);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);

        // [WHEN/THEN] the target cannot be reduced below the selected members' combined minimum
        AssertThat(
            not TryAdjustFillTarget(ResultPlanHeader, PlanSource."Line No.", 80, 'Invalid reduction below member minimum'),
            'expected a target below selected member minimums to be rejected');
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Target Quantity" = 160, 'expected the rejected minimum adjustment to leave the target unchanged');
        AssertThat(CountEvents(ResultPlanHeader, 'Fill Adjusted') = 0, 'expected no adjustment event after a rejected minimum');
    end;

    [Test]
    procedure MaximumLengthReasonsAreStoredAndAuditDescriptionsAreSafelyTruncated()
    var
        AdjustmentEvent: Record "SAL Plan Event";
        ConversionEvent: Record "SAL Plan Event";
        LongAdjustmentReason: Text[250];
        LongConversionReason: Text[250];
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] the longest supported conversion reason
        LongConversionReason := PadStr('', MaxStrLen(LongConversionReason), 'C');
        LongAdjustmentReason := PadStr('', MaxStrLen(LongAdjustmentReason), 'A');
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);

        // [WHEN] conversion and target adjustment each receive a 250-character reason
        ConvertToFill(
            PlanHeader, PlanSource, ProductGroup.Code, 80, false,
            BuildMembersJson(ProductGroup.Code), LongConversionReason, ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Conversion Reason" = LongConversionReason, 'expected the complete conversion reason to be stored on demand');
        GetOnlyEvent(ResultPlanHeader, 'Fill Converted', ConversionEvent);

        AdjustFillTarget(ResultPlanHeader, PlanSource."Line No.", 40, LongAdjustmentReason);

        // [THEN] both actions succeed while their formatted audit descriptions fit the event field
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fill Conversion Reason" = LongAdjustmentReason, 'expected the complete adjustment reason to be stored on demand');
        GetOnlyEvent(ResultPlanHeader, 'Fill Adjusted', AdjustmentEvent);
        AssertThat(StrLen(ConversionEvent.Description) <= MaxStrLen(ConversionEvent.Description), 'expected the conversion audit description to fit its field');
        AssertThat(StrLen(AdjustmentEvent.Description) <= MaxStrLen(AdjustmentEvent.Description), 'expected the adjustment audit description to fit its field');
        AssertThat(StrLen(ConversionEvent.Description) = MaxStrLen(ConversionEvent.Description), 'expected the long conversion audit description to be safely truncated');
        AssertThat(StrLen(AdjustmentEvent.Description) = MaxStrLen(AdjustmentEvent.Description), 'expected the long adjustment audit description to be safely truncated');
    end;

    [Test]
    [HandlerFunctions('DemandRefreshedMessageHandler')]
    procedure SalesDemandRefreshNormalisesHybridSourceToFillGroup()
    var
        DemandManagement: Codeunit "SAL Demand Management";
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
        SalesLine: Record "Sales Line";
    begin
        // [GIVEN] 320 trays of demand with a 160-tray fill target, so the source is Hybrid
        CreatePlanWithSalesDemand(320, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource."Fulfilment Mode" = PlanSource."Fulfilment Mode"::Hybrid, 'expected the pre-refresh source to be Exact + Fill');

        // [WHEN] current Sales Order demand falls to exactly the protected fill target
        SalesLine.Get(SalesLine."Document Type"::Order, PlanSource."Source Document No.", PlanSource."Source Document Line No.");
        SalesLine."Outstanding Quantity" := 160;
        SalesLine.Modify(false);
        DemandManagement.RefreshDemand(ResultPlanHeader);

        // [THEN] refresh retains the fill target and normalises the mode to Fill Group
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        AssertThat(PlanSource.Quantity = 160, 'expected the refreshed demand quantity to be 160');
        AssertThat(PlanSource."Fill Target Quantity" = 160, 'expected refresh to preserve the protected fill target');
        AssertThat(PlanSource."Fulfilment Mode" = PlanSource."Fulfilment Mode"::FillGroup, 'expected refresh to normalise the source to Fill Group mode');
    end;

    [Test]
    procedure FillGroupSupportsMoreThanThreeEligibleSKUs()
    var
        FifthFillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a fill group with five eligible SKUs
        CreatePlanWithSalesDemand(50, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", true, 5, ProductGroup);

        // [WHEN] the demand is converted and the fifth member is allocated
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 50, true, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 5, FifthFillMember);
        CreatePallet(ResultPlanHeader, 50, PlanPallet."Pallet Type"::Standard, PlanPallet);
        AddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", FifthFillMember."Line No.", 50);

        // [THEN] no three-SKU ceiling is applied
        AssertThat(CountFillMembers(ResultPlanHeader, PlanSource."Line No.") = 5, 'expected all five eligible SKUs to be retained');
        AssertThat(CountFillComponents(ResultPlanHeader, PlanSource."Line No.") = 1, 'expected the fifth member to be allocatable');
    end;

    [Test]
    procedure PerOrderQuantityCapOverridesTemplateAndRejectsExcessAllocation()
    var
        FirstFillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ProductGroupMember: Record "SAL Product Group Member";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a template member capped at 160, overridden to 80 for this order
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        GetGroupMemberByOrdinal(ProductGroup.Code, 1, ProductGroupMember);
        ProductGroupMember."Maximum Quantity" := 160;
        ProductGroupMember.Modify(true);

        // [WHEN] the fill conversion is created with an 80-tray order-specific cap
        ConvertToFill(
            PlanHeader, PlanSource, ProductGroup.Code, 160, false,
            BuildMembersJsonWithOverride(ProductGroup.Code, ProductGroupMember."Line No.", 80, 0), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberForTemplate(ResultPlanHeader, PlanSource."Line No.", ProductGroupMember."Line No.", FirstFillMember);
        CreatePallet(ResultPlanHeader, 81, PlanPallet."Pallet Type"::Standard, PlanPallet);

        // [THEN] the snapshot stores the override and rejects 81 trays
        AssertThat(FirstFillMember."Maximum Quantity" = 80, 'expected the order-specific maximum to replace the template maximum');
        AssertThat(
            not TryAddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", FirstFillMember."Line No.", 81),
            'expected allocation above the order-specific member cap to be rejected');
    end;

    [Test]
    procedure PalletEquivalentCapRejectsExcessAllocation()
    var
        FirstFillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ProductGroupMember: Record "SAL Product Group Member";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] one eligible SKU capped at one 60-tray pallet-equivalent
        CreatePlanWithSalesDemand(120, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        GetGroupMemberByOrdinal(ProductGroup.Code, 1, ProductGroupMember);
        ProductGroupMember."Default Pallet Quantity" := 60;
        ProductGroupMember."Maximum Pallets" := 1;
        ProductGroupMember.Modify(true);

        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 120, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberForTemplate(ResultPlanHeader, PlanSource."Line No.", ProductGroupMember."Line No.", FirstFillMember);
        CreatePallet(ResultPlanHeader, 61, PlanPallet."Pallet Type"::Standard, PlanPallet);

        // [WHEN/THEN] 61 trays cannot be allocated against a 60-tray effective cap
        AssertThat(
            not TryAddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", FirstFillMember."Line No.", 61),
            'expected allocation above the pallet-equivalent cap to be rejected');
    end;

    [Test]
    procedure MarketerMismatchedFillGroupCannotBeSelected()
    var
        OtherMarketer: Record Customer;
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a TAC plan and a fill group owned by a different marketer
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateCustomer(OtherMarketer);
        CreateFillGroup(OtherMarketer."No.", false, 2, ProductGroup);

        // [WHEN/THEN] the group cannot be used for the plan
        AssertThat(
            not TryConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader),
            'expected an exact marketer mismatch to block fill conversion');
    end;

    [Test]
    procedure FillComponentMustMatchItsSnapshottedMember()
    var
        FillMember: Record "SAL Plan Fill Member";
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a complete fill plan containing one valid fill component
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 1, ProductGroup);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 1, FillMember);
        CreatePallet(ResultPlanHeader, 160, PlanPallet."Pallet Type"::Standard, PlanPallet);
        AddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", FillMember."Line No.", 160);

        // [WHEN] the stored component product is corrupted away from its selected member
        GetOnlyFillComponent(ResultPlanHeader, PlanSource."Line No.", PlanComponent);
        PlanComponent."Item No." := 'WRONG-SKU';
        PlanComponent.Modify(true);

        // [THEN] release validation detects the mismatch
        AssertThat(not TryValidatePlan(ResultPlanHeader), 'expected a fill component/member product mismatch to be rejected');
    end;

    [Test]
    procedure MixedFillPalletIsRejectedWhenGroupDoesNotAllowMixing()
    var
        FirstFillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
        SecondFillMember: Record "SAL Plan Fill Member";
    begin
        // [GIVEN] a non-mixable fill group allocated across two SKUs on one pallet
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", false, 2, ProductGroup);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, false, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 1, FirstFillMember);
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 2, SecondFillMember);
        CreatePallet(ResultPlanHeader, 160, PlanPallet."Pallet Type"::Mixed, PlanPallet);
        InsertFillComponent(ResultPlanHeader, PlanPallet, PlanSource, FirstFillMember, 100);
        InsertFillComponent(ResultPlanHeader, PlanPallet, PlanSource, SecondFillMember, 60);

        // [WHEN/THEN] release validation blocks the mixed physical pallet
        AssertThat(not TryValidatePlan(ResultPlanHeader), 'expected a non-mixable fill group to reject a mixed pallet');
    end;

    [Test]
    procedure MixedFillPalletValidatesWhenGroupAllowsMixing()
    var
        FirstFillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
        SecondFillMember: Record "SAL Plan Fill Member";
    begin
        // [GIVEN] a mixable fill group allocated as 100 + 60 trays on one physical pallet
        CreatePlanWithSalesDemand(160, PlanHeader, PlanSource);
        CreateFillGroup(PlanHeader."Marketer Customer No.", true, 2, ProductGroup);
        ConvertToFill(PlanHeader, PlanSource, ProductGroup.Code, 160, true, BuildMembersJson(ProductGroup.Code), ResultPlanHeader);
        PlanSource.Get(ResultPlanHeader."No.", ResultPlanHeader."Version No.", PlanSource."Line No.");
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 1, FirstFillMember);
        GetFillMemberByOrdinal(ResultPlanHeader, PlanSource."Line No.", 2, SecondFillMember);
        CreatePallet(ResultPlanHeader, 160, PlanPallet."Pallet Type"::Mixed, PlanPallet);
        AddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", FirstFillMember."Line No.", 100);
        AddFillComponent(ResultPlanHeader, PlanPallet."Pallet No.", PlanSource."Line No.", SecondFillMember."Line No.", 60);

        // [WHEN/THEN] the balanced plan passes release validation
        AssertThat(TryValidatePlan(ResultPlanHeader), 'expected an allowed mixed fill pallet to validate');
    end;

    [Test]
    procedure ReleasedPlanConversionIsBlockedUntilCompletionFeedExists()
    var
        OriginalPlanHeader: Record "SAL Plan Header";
        OriginalPlanSource: Record "SAL Plan Source";
        PlanHeader: Record "SAL Plan Header";
        ProductGroup: Record "SAL Product Group";
        ResultPlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a released version (SAL does not yet receive physical completion state)
        CreatePlanWithSalesDemand(320, OriginalPlanHeader, OriginalPlanSource);
        CreateExactPallet(OriginalPlanHeader, OriginalPlanSource, 160);
        CreateFillGroup(OriginalPlanHeader."Marketer Customer No.", true, 4, ProductGroup);
        OriginalPlanHeader.MarkReleased();

        // [WHEN/THEN] conversion is refused instead of guessing which released pallets remain uncompleted
        AssertThat(
            not TryConvertToFill(
                OriginalPlanHeader, OriginalPlanSource, ProductGroup.Code, 160, true,
                BuildMembersJson(ProductGroup.Code), ResultPlanHeader),
            'expected fill conversion on a Released plan to be blocked');

        // [THEN] no revision or fill audit row is created and the released version remains unchanged
        OriginalPlanHeader.Get(OriginalPlanHeader."No.", 1);
        AssertThat(OriginalPlanHeader.Status = OriginalPlanHeader.Status::Released, 'expected version 1 to remain Released');
        OriginalPlanSource.Get(OriginalPlanHeader."No.", 1, OriginalPlanSource."Line No.");
        AssertThat(OriginalPlanSource."Fill Target Quantity" = 0, 'expected version 1 demand to remain exact');
        PlanHeader.SetRange("No.", OriginalPlanHeader."No.");
        AssertThat(PlanHeader.Count() = 1, 'expected no draft revision to be created');
        AssertNoEventExists(OriginalPlanHeader, 'Fill Converted');
    end;

    [Test]
    procedure ExplicitRevisionCopiesFillSnapshotComponentsAndVersionAudit()
    var
        FillMember: Record "SAL Plan Fill Member";
        OriginalPlanHeader: Record "SAL Plan Header";
        OriginalPlanSource: Record "SAL Plan Source";
        PlanComponent: Record "SAL Plan Component";
        PlanManagement: Codeunit "SAL Plan Management";
        PlanPallet: Record "SAL Plan Pallet";
        ProductGroup: Record "SAL Product Group";
        ReleasedFillPlan: Record "SAL Plan Header";
        RevisionPlanHeader: Record "SAL Plan Header";
        RevisionPlanSource: Record "SAL Plan Source";
    begin
        // [GIVEN] a fill plan that was deliberately released after its physical plan was completed
        CreatePlanWithSalesDemand(160, OriginalPlanHeader, OriginalPlanSource);
        CreateFillGroup(OriginalPlanHeader."Marketer Customer No.", true, 4, ProductGroup);
        ConvertToFill(
            OriginalPlanHeader, OriginalPlanSource, ProductGroup.Code, 160, true,
            BuildMembersJson(ProductGroup.Code), ReleasedFillPlan);
        OriginalPlanSource.Get(ReleasedFillPlan."No.", ReleasedFillPlan."Version No.", OriginalPlanSource."Line No.");
        GetFillMemberByOrdinal(ReleasedFillPlan, OriginalPlanSource."Line No.", 1, FillMember);
        CreatePallet(ReleasedFillPlan, 160, PlanPallet."Pallet Type"::Standard, PlanPallet);
        AddFillComponent(ReleasedFillPlan, PlanPallet."Pallet No.", OriginalPlanSource."Line No.", FillMember."Line No.", 160);
        ReleasedFillPlan.MarkReleased();

        // [WHEN] the normal explicit revision command is used
        PlanManagement.CreateNewVersion(ReleasedFillPlan, RevisionPlanHeader);

        // [THEN] the fill contract, member snapshot and physical allocation are copied with a version audit event
        AssertThat(RevisionPlanHeader."Version No." = 2, 'expected an explicit version 2 revision');
        AssertThat(RevisionPlanHeader.Status = RevisionPlanHeader.Status::Draft, 'expected the revision to be Draft');
        RevisionPlanSource.Get(RevisionPlanHeader."No.", RevisionPlanHeader."Version No.", OriginalPlanSource."Line No.");
        AssertThat(RevisionPlanSource."Fill Target Quantity" = 160, 'expected the fill target to be copied');
        AssertThat(RevisionPlanSource."Fill Group Code" = ProductGroup.Code, 'expected the fill group identity to be copied');
        AssertThat(CountFillMembers(RevisionPlanHeader, RevisionPlanSource."Line No.") = 4, 'expected every fill member snapshot to be copied');
        PlanComponent.SetRange("Plan No.", RevisionPlanHeader."No.");
        PlanComponent.SetRange("Version No.", RevisionPlanHeader."Version No.");
        PlanComponent.SetRange("Fulfilment Mode", PlanComponent."Fulfilment Mode"::FillGroup);
        AssertThat(PlanComponent.Count() = 1, 'expected the fill component to be copied');
        AssertEventExists(RevisionPlanHeader, 'Version Created');
    end;

    local procedure CreatePlanWithSalesDemand(Quantity: Decimal; var PlanHeader: Record "SAL Plan Header"; var PlanSource: Record "SAL Plan Source")
    var
        Customer: Record Customer;
        SalesDocumentNo: Code[20];
        SourceItemNo: Code[20];
    begin
        CreateCustomer(Customer);
        SalesDocumentNo := GetUniqueCode('SO');
        SourceItemNo := GetUniqueCode('BASE');
        CreateReleasedSalesOrderLine(SalesDocumentNo, 10000, SourceItemNo, '', 'TRAY', Quantity);

        Clear(PlanHeader);
        PlanHeader.Init();
        PlanHeader."No." := GetUniqueCode('SAL');
        PlanHeader.Insert(true);
        PlanHeader.Description := 'Fill group test plan';
        PlanHeader.Priority := 1;
        PlanHeader."Required Finish Date" := WorkDate();
        PlanHeader."Dispatch Date" := WorkDate() + 1;
        PlanHeader.Validate("Marketer Customer No.", Customer."No.");
        PlanHeader."Marketer Confirmed" := true;
        PlanHeader.Modify(true);

        Clear(PlanSource);
        PlanSource.Init();
        PlanSource."Plan No." := PlanHeader."No.";
        PlanSource."Version No." := PlanHeader."Version No.";
        PlanSource."Source Type" := PlanSource."Source Type"::SalesOrder;
        PlanSource."Source Document No." := SalesDocumentNo;
        PlanSource."Source Document Line No." := 10000;
        PlanSource."Execution Route" := PlanSource."Execution Route"::ManjimupPack;
        PlanSource."Facility Work Type" := PlanSource."Facility Work Type"::PackNew;
        PlanSource."Routing Confirmed" := true;
        PlanSource."Item No." := SourceItemNo;
        PlanSource."Unit of Measure Code" := 'TRAY';
        PlanSource."Item Description" := 'Original exact SKU';
        PlanSource.Priority := 1;
        PlanSource.Quantity := Quantity;
        PlanSource."Remaining Quantity Snapshot" := Quantity;
        PlanSource.Insert(true);
    end;

    local procedure CreateReleasedSalesOrderLine(DocumentNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; VariantCode: Code[10]; UnitOfMeasureCode: Code[10]; Quantity: Decimal)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := DocumentNo;
        SalesHeader.Status := SalesHeader.Status::Released;
        SalesHeader.Insert(false);

        SalesLine.Init();
        SalesLine."Document Type" := SalesLine."Document Type"::Order;
        SalesLine."Document No." := DocumentNo;
        SalesLine."Line No." := LineNo;
        SalesLine.Type := SalesLine.Type::Item;
        SalesLine."No." := ItemNo;
        SalesLine."Variant Code" := VariantCode;
        SalesLine."Unit of Measure Code" := UnitOfMeasureCode;
        SalesLine.Quantity := Quantity;
        SalesLine."Outstanding Quantity" := Quantity;
        SalesLine.Insert(false);
    end;

    local procedure CreateCustomer(var Customer: Record Customer)
    begin
        Clear(Customer);
        Customer.Init();
        Customer."No." := GetUniqueCode('MKT');
        Customer.Name := CopyStr('Marketer ' + Customer."No.", 1, MaxStrLen(Customer.Name));
        Customer.Insert(false);
    end;

    local procedure CreateFillGroup(MarketerCustomerNo: Code[20]; AllowMixedPallets: Boolean; MemberCount: Integer; var ProductGroup: Record "SAL Product Group")
    var
        MemberIndex: Integer;
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        Clear(ProductGroup);
        ProductGroup.Init();
        ProductGroup.Code := GetUniqueCode('FG');
        ProductGroup.Description := 'Fill group test';
        ProductGroup.Active := true;
        ProductGroup."Marketer Customer No." := MarketerCustomerNo;
        ProductGroup."Allow Mixed Pallets" := AllowMixedPallets;
        ProductGroup."Default Pallet Quantity" := 160;
        ProductGroup.Insert(true);

        for MemberIndex := 1 to MemberCount do begin
            Clear(ProductGroupMember);
            ProductGroupMember.Init();
            ProductGroupMember."Group Code" := ProductGroup.Code;
            ProductGroupMember."Item No." := GetUniqueCode('SKU');
            ProductGroupMember."Unit of Measure Code" := 'TRAY';
            ProductGroupMember.Description := CopyStr('Eligible fill SKU ' + Format(MemberIndex), 1, MaxStrLen(ProductGroupMember.Description));
            ProductGroupMember."Default Pallet Quantity" := 160;
            ProductGroupMember.Preference := MemberIndex;
            ProductGroupMember.Active := true;
            ProductGroupMember.Insert(true);
        end;
    end;

    local procedure CreateExactPallet(PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; Quantity: Decimal)
    var
        PlanComponent: Record "SAL Plan Component";
        PlanPallet: Record "SAL Plan Pallet";
    begin
        CreatePallet(PlanHeader, Quantity, PlanPallet."Pallet Type"::Standard, PlanPallet);
        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := PlanHeader."Version No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent.Validate("Source Line No.", PlanSource."Line No.");
        PlanComponent.Quantity := Quantity;
        PlanComponent.Insert(true);
    end;

    local procedure CreatePallet(PlanHeader: Record "SAL Plan Header"; TargetQuantity: Decimal; PalletType: Enum "SAL Pallet Type"; var PlanPallet: Record "SAL Plan Pallet")
    begin
        Clear(PlanPallet);
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanHeader."No.";
        PlanPallet."Version No." := PlanHeader."Version No.";
        PlanPallet."Pallet Type" := PalletType;
        PlanPallet."Target Quantity" := TargetQuantity;
        PlanPallet.Insert(true);
    end;

    local procedure InsertFillComponent(PlanHeader: Record "SAL Plan Header"; PlanPallet: Record "SAL Plan Pallet"; PlanSource: Record "SAL Plan Source"; FillMember: Record "SAL Plan Fill Member"; Quantity: Decimal)
    var
        PlanComponent: Record "SAL Plan Component";
    begin
        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := PlanHeader."Version No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent.Validate("Source Line No.", PlanSource."Line No.");
        PlanComponent.Validate("Fulfilment Mode", PlanComponent."Fulfilment Mode"::FillGroup);
        PlanComponent.Validate("Fill Member Line No.", FillMember."Line No.");
        PlanComponent.Quantity := Quantity;
        PlanComponent.Insert(true);
    end;

    local procedure ConvertToFill(var PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; FillGroupCode: Code[20]; ConvertQuantity: Decimal; AllowMixed: Boolean; MembersJson: Text; var ResultPlanHeader: Record "SAL Plan Header")
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
    begin
        AllocationManagement.ConvertRemainingToFill(
            PlanHeader, PlanSource."Line No.", FillGroupCode, ConvertQuantity, AllowMixed, MembersJson,
            'Converted during SAL fill-group test', ResultPlanHeader);
    end;

    local procedure ConvertToFill(var PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; FillGroupCode: Code[20]; ConvertQuantity: Decimal; AllowMixed: Boolean; MembersJson: Text; Reason: Text; var ResultPlanHeader: Record "SAL Plan Header")
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
    begin
        AllocationManagement.ConvertRemainingToFill(
            PlanHeader, PlanSource."Line No.", FillGroupCode, ConvertQuantity, AllowMixed, MembersJson,
            Reason, ResultPlanHeader);
    end;

    local procedure AddFillComponent(var PlanHeader: Record "SAL Plan Header"; PalletNo: Integer; SourceLineNo: Integer; FillMemberLineNo: Integer; Quantity: Decimal)
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
    begin
        AllocationManagement.AddFillComponent(PlanHeader, PalletNo, SourceLineNo, FillMemberLineNo, Quantity);
    end;

    local procedure AdjustFillTarget(var PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; NewFillTarget: Decimal; Reason: Text)
    var
        AllocationManagement: Codeunit "SAL Allocation Management";
    begin
        AllocationManagement.AdjustFillTarget(PlanHeader, SourceLineNo, NewFillTarget, Reason);
    end;

    local procedure BuildMembersJson(GroupCode: Code[20]): Text
    begin
        exit(BuildMembersJsonWithOverride(GroupCode, 0, 0, 0));
    end;

    local procedure BuildMembersJsonWithOverride(GroupCode: Code[20]; OverrideLineNo: Integer; OverrideMaximumQuantity: Decimal; OverrideMaximumPallets: Decimal) Result: Text
    var
        MemberArray: JsonArray;
        MemberObject: JsonObject;
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        ProductGroupMember.SetRange("Group Code", GroupCode);
        ProductGroupMember.SetRange(Active, true);
        if ProductGroupMember.FindSet() then
            repeat
                Clear(MemberObject);
                MemberObject.Add('lineNo', ProductGroupMember."Line No.");
                MemberObject.Add('selected', true);
                MemberObject.Add('minQuantity', ProductGroupMember."Minimum Quantity");
                if ProductGroupMember."Line No." = OverrideLineNo then begin
                    MemberObject.Add('maxQuantity', OverrideMaximumQuantity);
                    MemberObject.Add('maxPallets', OverrideMaximumPallets);
                end else begin
                    MemberObject.Add('maxQuantity', ProductGroupMember."Maximum Quantity");
                    MemberObject.Add('maxPallets', ProductGroupMember."Maximum Pallets");
                end;
                MemberArray.Add(MemberObject);
            until ProductGroupMember.Next() = 0;
        MemberArray.WriteTo(Result);
    end;

    local procedure BuildSelectionOnlyJson(GroupCode: Code[20]; DeselectedLineNo: Integer) Result: Text
    var
        MemberArray: JsonArray;
        MemberObject: JsonObject;
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        ProductGroupMember.SetRange("Group Code", GroupCode);
        ProductGroupMember.SetRange(Active, true);
        if ProductGroupMember.FindSet() then
            repeat
                Clear(MemberObject);
                MemberObject.Add('lineNo', ProductGroupMember."Line No.");
                MemberObject.Add('selected', ProductGroupMember."Line No." <> DeselectedLineNo);
                MemberArray.Add(MemberObject);
            until ProductGroupMember.Next() = 0;
        MemberArray.WriteTo(Result);
    end;

    local procedure GetGroupMemberByOrdinal(GroupCode: Code[20]; Ordinal: Integer; var ProductGroupMember: Record "SAL Product Group Member")
    var
        CurrentOrdinal: Integer;
    begin
        ProductGroupMember.SetRange("Group Code", GroupCode);
        if ProductGroupMember.FindSet() then
            repeat
                CurrentOrdinal += 1;
                if CurrentOrdinal = Ordinal then
                    exit;
            until ProductGroupMember.Next() = 0;
        Error(AssertFailedErr, StrSubstNo('fill group member ordinal %1 was not found', Ordinal));
    end;

    local procedure GetFillMemberByOrdinal(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; Ordinal: Integer; var FillMember: Record "SAL Plan Fill Member")
    var
        CurrentOrdinal: Integer;
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", SourceLineNo);
        if FillMember.FindSet() then
            repeat
                CurrentOrdinal += 1;
                if CurrentOrdinal = Ordinal then
                    exit;
            until FillMember.Next() = 0;
        Error(AssertFailedErr, StrSubstNo('plan fill member ordinal %1 was not found', Ordinal));
    end;

    local procedure GetFillMemberForTemplate(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; TemplateMemberLineNo: Integer; var FillMember: Record "SAL Plan Fill Member")
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", SourceLineNo);
        FillMember.SetRange("Template Member Line No.", TemplateMemberLineNo);
        AssertThat(FillMember.FindFirst(), 'expected a plan fill member for the selected template member');
    end;

    local procedure FillMemberExistsForTemplate(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; TemplateMemberLineNo: Integer): Boolean
    var
        FillMember: Record "SAL Plan Fill Member";
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", SourceLineNo);
        FillMember.SetRange("Template Member Line No.", TemplateMemberLineNo);
        exit(not FillMember.IsEmpty());
    end;

    local procedure GetOnlyFillComponent(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; var PlanComponent: Record "SAL Plan Component")
    begin
        PlanComponent.SetRange("Plan No.", PlanHeader."No.");
        PlanComponent.SetRange("Version No.", PlanHeader."Version No.");
        PlanComponent.SetRange("Source Line No.", SourceLineNo);
        PlanComponent.SetRange("Fulfilment Mode", PlanComponent."Fulfilment Mode"::FillGroup);
        AssertThat(PlanComponent.FindFirst(), 'expected a fill component');
    end;

    local procedure CountFillMembers(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer): Integer
    var
        FillMember: Record "SAL Plan Fill Member";
    begin
        FillMember.SetRange("Plan No.", PlanHeader."No.");
        FillMember.SetRange("Version No.", PlanHeader."Version No.");
        FillMember.SetRange("Source Line No.", SourceLineNo);
        exit(FillMember.Count());
    end;

    local procedure CountFillComponents(PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer): Integer
    var
        PlanComponent: Record "SAL Plan Component";
    begin
        PlanComponent.SetRange("Plan No.", PlanHeader."No.");
        PlanComponent.SetRange("Version No.", PlanHeader."Version No.");
        PlanComponent.SetRange("Source Line No.", SourceLineNo);
        PlanComponent.SetRange("Fulfilment Mode", PlanComponent."Fulfilment Mode"::FillGroup);
        exit(PlanComponent.Count());
    end;

    local procedure AssertEventExists(PlanHeader: Record "SAL Plan Header"; EventType: Text[50])
    var
        PlanEvent: Record "SAL Plan Event";
    begin
        PlanEvent.SetRange("Plan No.", PlanHeader."No.");
        PlanEvent.SetRange("Version No.", PlanHeader."Version No.");
        PlanEvent.SetRange("Event Type", EventType);
        AssertThat(PlanEvent.Count() = 1, StrSubstNo('expected one %1 event', EventType));
    end;

    local procedure AssertNoEventExists(PlanHeader: Record "SAL Plan Header"; EventType: Text[50])
    var
        PlanEvent: Record "SAL Plan Event";
    begin
        PlanEvent.SetRange("Plan No.", PlanHeader."No.");
        PlanEvent.SetRange("Version No.", PlanHeader."Version No.");
        PlanEvent.SetRange("Event Type", EventType);
        AssertThat(PlanEvent.IsEmpty(), StrSubstNo('expected no %1 event', EventType));
    end;

    local procedure GetOnlyEvent(PlanHeader: Record "SAL Plan Header"; EventType: Text[50]; var PlanEvent: Record "SAL Plan Event")
    begin
        PlanEvent.SetRange("Plan No.", PlanHeader."No.");
        PlanEvent.SetRange("Version No.", PlanHeader."Version No.");
        PlanEvent.SetRange("Event Type", EventType);
        AssertThat(PlanEvent.Count() = 1, StrSubstNo('expected one %1 event', EventType));
        PlanEvent.FindFirst();
    end;

    local procedure CountEvents(PlanHeader: Record "SAL Plan Header"; EventType: Text[50]): Integer
    var
        PlanEvent: Record "SAL Plan Event";
    begin
        PlanEvent.SetRange("Plan No.", PlanHeader."No.");
        PlanEvent.SetRange("Version No.", PlanHeader."Version No.");
        PlanEvent.SetRange("Event Type", EventType);
        exit(PlanEvent.Count());
    end;

    local procedure GetUniqueCode(Prefix: Text): Code[20]
    begin
        exit(CopyStr(Prefix + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    [TryFunction]
    local procedure TryConvertToFill(var PlanHeader: Record "SAL Plan Header"; PlanSource: Record "SAL Plan Source"; FillGroupCode: Code[20]; ConvertQuantity: Decimal; AllowMixed: Boolean; MembersJson: Text; var ResultPlanHeader: Record "SAL Plan Header")
    begin
        ConvertToFill(PlanHeader, PlanSource, FillGroupCode, ConvertQuantity, AllowMixed, MembersJson, ResultPlanHeader);
    end;

    [TryFunction]
    local procedure TryAddFillComponent(var PlanHeader: Record "SAL Plan Header"; PalletNo: Integer; SourceLineNo: Integer; FillMemberLineNo: Integer; Quantity: Decimal)
    begin
        AddFillComponent(PlanHeader, PalletNo, SourceLineNo, FillMemberLineNo, Quantity);
    end;

    [TryFunction]
    local procedure TryAdjustFillTarget(var PlanHeader: Record "SAL Plan Header"; SourceLineNo: Integer; NewFillTarget: Decimal; Reason: Text)
    begin
        AdjustFillTarget(PlanHeader, SourceLineNo, NewFillTarget, Reason);
    end;

    [TryFunction]
    local procedure TryValidatePlan(var PlanHeader: Record "SAL Plan Header")
    var
        PlanValidation: Codeunit "SAL Plan Validation";
    begin
        PlanValidation.ValidatePlan(PlanHeader);
    end;

    [MessageHandler]
    procedure DemandRefreshedMessageHandler(Message: Text[1024])
    begin
        AssertThat(StrPos(Message, 'demand line(s) refreshed') > 0, 'expected the demand refresh confirmation message');
    end;

    local procedure AssertThat(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(AssertFailedErr, Message);
    end;
}
