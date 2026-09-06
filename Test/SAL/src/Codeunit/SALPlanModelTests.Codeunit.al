codeunit 58800 "SAL Plan Model Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        AssertFailedErr: Label 'Assertion failed: %1', Comment = '%1 = message';

    [Test]
    procedure NewHeaderDefaultsToDraftVersionOne()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        // [WHEN] a new plan is inserted without lifecycle values
        CreatePlan(PlanHeader);

        // [THEN] the table supplies the immutable version and audit defaults
        AssertThat(PlanHeader."Version No." = 1, 'expected the first version to be 1');
        AssertThat(PlanHeader.Status = PlanHeader.Status::Draft, 'expected a new plan to be Draft');
        AssertThat(PlanHeader."Created Date Time" <> 0DT, 'expected the created date and time to be stamped');
        AssertThat(PlanHeader."Created By User Id" = CopyStr(UserId(), 1, MaxStrLen(PlanHeader."Created By User Id")), 'expected the creating user to be stamped');
    end;

    [Test]
    procedure PlanVersionsCanCoexistUnderOnePlanNumber()
    var
        FirstVersion: Record "SAL Plan Header";
        PlanHeader: Record "SAL Plan Header";
        SecondVersion: Record "SAL Plan Header";
    begin
        // [GIVEN] an initial plan version
        CreatePlan(FirstVersion);

        // [WHEN] a second version is inserted through the revision entry point
        CreateRevision(FirstVersion, 2, SecondVersion);

        // [THEN] both exact versions remain addressable under the same plan number
        AssertThat(PlanHeader.Get(FirstVersion."No.", 1), 'expected version 1 to remain available');
        AssertThat(PlanHeader.Get(FirstVersion."No.", 2), 'expected version 2 to be available');
        PlanHeader.SetRange("No.", FirstVersion."No.");
        AssertThat(PlanHeader.Count() = 2, 'expected exactly two coexisting versions');
    end;

    [Test]
    procedure DirectLifecycleBypassIsRejected()
    var
        PlanHeader: Record "SAL Plan Header";
        UnmanagedRevision: Record "SAL Plan Header";
    begin
        // [GIVEN] a normal draft plan
        CreatePlan(PlanHeader);

        // [WHEN/THEN] status is assigned directly, the table rejects the change
        PlanHeader.Status := PlanHeader.Status::Released;
        AssertThat(not TryModifyHeader(PlanHeader), 'expected a direct status transition to be rejected');

        // [WHEN/THEN] a later version bypasses SAL Plan Management, the insert is rejected
        UnmanagedRevision.Init();
        UnmanagedRevision."No." := PlanHeader."No.";
        UnmanagedRevision."Version No." := 2;
        AssertThat(not TryInsertHeader(UnmanagedRevision), 'expected an unmanaged revision insert to be rejected');
    end;

    [Test]
    procedure NumberingAndFlowFieldsAreVersionScoped()
    var
        FirstComponent: Record "SAL Plan Component";
        FirstPallet: Record "SAL Plan Pallet";
        FirstSource: Record "SAL Plan Source";
        FirstVersion: Record "SAL Plan Header";
        FourthComponent: Record "SAL Plan Component";
        SecondComponent: Record "SAL Plan Component";
        SecondPallet: Record "SAL Plan Pallet";
        SecondSource: Record "SAL Plan Source";
        SecondVersion: Record "SAL Plan Header";
        ThirdComponent: Record "SAL Plan Component";
        VersionTwoPallet: Record "SAL Plan Pallet";
        VersionTwoSource: Record "SAL Plan Source";
    begin
        // [GIVEN] two versions of the same plan
        CreatePlan(FirstVersion);
        CreateRevision(FirstVersion, 2, SecondVersion);

        // [WHEN] each version receives its own sources, pallets and components
        CreateSource(FirstVersion, 'SO-V1-1', 10, FirstSource);
        CreateSource(FirstVersion, 'SO-V1-2', 20, SecondSource);
        CreatePallet(FirstVersion, 10, FirstPallet);
        CreatePallet(FirstVersion, 20, SecondPallet);
        CreateComponent(FirstVersion, FirstPallet, FirstSource, 4, FirstComponent);
        CreateComponent(FirstVersion, FirstPallet, FirstSource, 6, SecondComponent);
        CreateComponent(FirstVersion, SecondPallet, SecondSource, 20, ThirdComponent);

        CreateSource(SecondVersion, 'SO-V2-1', 7, VersionTwoSource);
        CreatePallet(SecondVersion, 7, VersionTwoPallet);
        CreateComponent(SecondVersion, VersionTwoPallet, VersionTwoSource, 7, FourthComponent);

        // [THEN] numbering restarts inside each version and pallet
        AssertThat(FirstSource."Line No." = 10000, 'expected the first version 1 source line to be 10000');
        AssertThat(SecondSource."Line No." = 20000, 'expected the second version 1 source line to be 20000');
        AssertThat(VersionTwoSource."Line No." = 10000, 'expected source numbering to restart in version 2');
        AssertThat(FirstPallet."Pallet No." = 1, 'expected the first version 1 pallet to be 1');
        AssertThat(SecondPallet."Pallet No." = 2, 'expected the second version 1 pallet to be 2');
        AssertThat(VersionTwoPallet."Pallet No." = 1, 'expected pallet numbering to restart in version 2');
        AssertThat(FirstComponent."Line No." = 10000, 'expected the first component line to be 10000');
        AssertThat(SecondComponent."Line No." = 20000, 'expected the second component on the same pallet to be 20000');
        AssertThat(ThirdComponent."Line No." = 10000, 'expected component numbering to restart on the next pallet');
        AssertThat(FourthComponent."Line No." = 10000, 'expected component numbering to restart in version 2');

        // [THEN] header, source and pallet totals include only their exact version
        FirstVersion.CalcFields("No. of Sources", "No. of Pallets", "Total Required Quantity", "Total Planned Quantity");
        AssertThat(FirstVersion."No. of Sources" = 2, 'expected two sources on version 1');
        AssertThat(FirstVersion."No. of Pallets" = 2, 'expected two pallets on version 1');
        AssertThat(FirstVersion."Total Required Quantity" = 30, 'expected version 1 required quantity to be 30');
        AssertThat(FirstVersion."Total Planned Quantity" = 30, 'expected version 1 planned quantity to be 30');
        FirstSource.CalcFields("Planned Quantity");
        AssertThat(FirstSource."Planned Quantity" = 10, 'expected the first source to total its two components');
        FirstPallet.CalcFields("No. of Components", "Planned Quantity");
        AssertThat(FirstPallet."No. of Components" = 2, 'expected two components on the first pallet');
        AssertThat(FirstPallet."Planned Quantity" = 10, 'expected the first pallet planned quantity to be 10');

        SecondVersion.CalcFields("No. of Sources", "No. of Pallets", "Total Required Quantity", "Total Planned Quantity");
        AssertThat(SecondVersion."No. of Sources" = 1, 'expected one source on version 2');
        AssertThat(SecondVersion."No. of Pallets" = 1, 'expected one pallet on version 2');
        AssertThat(SecondVersion."Total Required Quantity" = 7, 'expected version 2 required quantity to be 7');
        AssertThat(SecondVersion."Total Planned Quantity" = 7, 'expected version 2 planned quantity to be 7');
    end;

    [Test]
    procedure ChildrenRejectMissingExactHeaderVersion()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanEvent: Record "SAL Plan Event";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        MissingVersionNo: Integer;
    begin
        // [GIVEN] a plan number for which only version 1 exists
        CreatePlan(PlanHeader);
        MissingVersionNo := 99;

        // [WHEN/THEN] children target a missing exact version, every insert is rejected
        InitialiseSource(PlanHeader."No.", MissingVersionNo, 'SO-MISSING', 1, PlanSource);
        AssertThat(not TryInsertSource(PlanSource), 'expected a source with a missing parent version to be rejected');

        InitialisePallet(PlanHeader."No.", MissingVersionNo, 1, PlanPallet);
        AssertThat(not TryInsertPallet(PlanPallet), 'expected a pallet with a missing parent version to be rejected');

        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := MissingVersionNo;
        PlanComponent."Pallet No." := 1;
        PlanComponent.Quantity := 1;
        AssertThat(not TryInsertComponent(PlanComponent), 'expected a component with a missing parent version to be rejected');

        PlanEvent.Init();
        PlanEvent."Plan No." := PlanHeader."No.";
        PlanEvent."Version No." := MissingVersionNo;
        PlanEvent."Event Type" := 'Missing Parent';
        AssertThat(not TryInsertEvent(PlanEvent), 'expected an event with a missing parent version to be rejected');
    end;

    [Test]
    procedure ComponentsRejectCrossVersionPalletAndSource()
    var
        FirstVersion: Record "SAL Plan Header";
        PlanComponent: Record "SAL Plan Component";
        VersionOnePallet: Record "SAL Plan Pallet";
        VersionOneSource: Record "SAL Plan Source";
        SecondVersion: Record "SAL Plan Header";
        VersionTwoPallet: Record "SAL Plan Pallet";
    begin
        // [GIVEN] version 1 has a source and pallet, while version 2 initially has neither
        CreatePlan(FirstVersion);
        CreateRevision(FirstVersion, 2, SecondVersion);
        CreateSource(FirstVersion, 'SO-CROSS', 10, VersionOneSource);
        CreatePallet(FirstVersion, 10, VersionOnePallet);

        // [WHEN] version 2 refers to the pallet number that exists only in version 1
        PlanComponent.Init();
        PlanComponent."Plan No." := SecondVersion."No.";
        PlanComponent."Version No." := SecondVersion."Version No.";
        PlanComponent."Pallet No." := VersionOnePallet."Pallet No.";
        PlanComponent.Quantity := 1;

        // [THEN] the cross-version pallet reference is rejected
        AssertThat(not TryInsertComponent(PlanComponent), 'expected a cross-version pallet reference to be rejected');

        // [GIVEN] version 2 now has its own pallet but still has no source
        CreatePallet(SecondVersion, 10, VersionTwoPallet);

        // [WHEN] its component refers to the line number that exists only in version 1
        Clear(PlanComponent);
        PlanComponent.Init();
        PlanComponent."Plan No." := SecondVersion."No.";
        PlanComponent."Version No." := SecondVersion."Version No.";
        PlanComponent."Pallet No." := VersionTwoPallet."Pallet No.";
        PlanComponent."Source Line No." := VersionOneSource."Line No.";
        PlanComponent.Quantity := 1;

        // [THEN] the cross-version source reference is rejected
        AssertThat(not TryInsertComponent(PlanComponent), 'expected a cross-version source reference to be rejected');
    end;

    [Test]
    procedure ReleasedPlanChildrenCannotBeInsertedModifiedOrDeleted()
    var
        ExistingComponent: Record "SAL Plan Component";
        ExistingPallet: Record "SAL Plan Pallet";
        ExistingSource: Record "SAL Plan Source";
        NewComponent: Record "SAL Plan Component";
        NewPallet: Record "SAL Plan Pallet";
        NewSource: Record "SAL Plan Source";
        PlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a released plan containing a source, pallet and component
        CreatePlan(PlanHeader);
        CreateSource(PlanHeader, 'SO-LOCKED', 10, ExistingSource);
        CreatePallet(PlanHeader, 10, ExistingPallet);
        CreateComponent(PlanHeader, ExistingPallet, ExistingSource, 10, ExistingComponent);
        PlanHeader.MarkReleased();

        // [WHEN/THEN] existing child rows cannot be modified
        ExistingSource.Quantity := 9;
        AssertThat(not TryModifySource(ExistingSource), 'expected a released source to be immutable');
        ExistingPallet.Description := 'Changed';
        AssertThat(not TryModifyPallet(ExistingPallet), 'expected a released pallet to be immutable');
        ExistingComponent.Quantity := 9;
        AssertThat(not TryModifyComponent(ExistingComponent), 'expected a released component to be immutable');

        // [WHEN/THEN] new child rows cannot be inserted
        InitialiseSource(PlanHeader."No.", PlanHeader."Version No.", 'SO-NEW', 1, NewSource);
        AssertThat(not TryInsertSource(NewSource), 'expected a source insert on a released plan to be rejected');
        InitialisePallet(PlanHeader."No.", PlanHeader."Version No.", 1, NewPallet);
        AssertThat(not TryInsertPallet(NewPallet), 'expected a pallet insert on a released plan to be rejected');
        NewComponent.Init();
        NewComponent."Plan No." := PlanHeader."No.";
        NewComponent."Version No." := PlanHeader."Version No.";
        NewComponent."Pallet No." := ExistingPallet."Pallet No.";
        NewComponent."Source Line No." := ExistingSource."Line No.";
        NewComponent.Quantity := 1;
        AssertThat(not TryInsertComponent(NewComponent), 'expected a component insert on a released plan to be rejected');

        // [WHEN/THEN] existing child rows cannot be deleted
        AssertThat(not TryDeleteSource(ExistingSource), 'expected a released source delete to be rejected');
        AssertThat(not TryDeletePallet(ExistingPallet), 'expected a released pallet delete to be rejected');
        AssertThat(not TryDeleteComponent(ExistingComponent), 'expected a released component delete to be rejected');
    end;

    [Test]
    procedure EventsRemainAppendOnlyAfterRelease()
    var
        PlanEvent: Record "SAL Plan Event";
        PlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a released plan
        CreatePlan(PlanHeader);
        PlanHeader.MarkReleased();

        // [WHEN] an audit event is appended after release
        PlanEvent.Init();
        PlanEvent."Plan No." := PlanHeader."No.";
        PlanEvent."Version No." := PlanHeader."Version No.";
        PlanEvent."Event Type" := 'Acknowledged';
        PlanEvent.Description := 'Packing Facility acknowledged the release.';
        PlanEvent.Insert(true);

        // [THEN] the event is accepted and receives audit values
        AssertThat(PlanEvent."Entry No." > 0, 'expected an automatically assigned event entry number');
        AssertThat(PlanEvent."Event Date Time" <> 0DT, 'expected the event date and time to be stamped');

        // [WHEN/THEN] the inserted event cannot be changed, deleted or renamed
        PlanEvent.Description := 'Changed';
        AssertThat(not TryModifyEvent(PlanEvent), 'expected event modification to be rejected');
        AssertThat(not TryDeleteEvent(PlanEvent), 'expected event deletion to be rejected');
        AssertThat(not TryRenameEvent(PlanEvent, PlanEvent."Entry No." + 1000), 'expected event renaming to be rejected');
    end;

    [Test]
    procedure CreateNewVersionCopiesPlanRowsButNotEventHistory()
    var
        CopiedComponent: Record "SAL Plan Component";
        CopiedPallet: Record "SAL Plan Pallet";
        CopiedSource: Record "SAL Plan Source";
        NewPlanHeader: Record "SAL Plan Header";
        OriginalComponent: Record "SAL Plan Component";
        OriginalEvent: Record "SAL Plan Event";
        OriginalPallet: Record "SAL Plan Pallet";
        OriginalPlanHeader: Record "SAL Plan Header";
        OriginalSource: Record "SAL Plan Source";
        PlanEvent: Record "SAL Plan Event";
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        // [GIVEN] a released version with demand, a physical pallet plan and audit history
        CreatePlan(OriginalPlanHeader);
        OriginalPlanHeader.Description := 'Original plan';
        OriginalPlanHeader.Priority := 3;
        OriginalPlanHeader."Required Finish Date" := WorkDate();
        OriginalPlanHeader."Dispatch Date" := WorkDate() + 1;
        OriginalPlanHeader."Marketer Description" := 'The Avocado Collective';
        OriginalPlanHeader."Marketer Confirmed" := true;
        OriginalPlanHeader.Modify(true);
        CreateSource(OriginalPlanHeader, 'SO-REVISION', 160, OriginalSource);
        CreatePallet(OriginalPlanHeader, 160, OriginalPallet);
        CreateComponent(OriginalPlanHeader, OriginalPallet, OriginalSource, 160, OriginalComponent);

        OriginalEvent.Init();
        OriginalEvent."Plan No." := OriginalPlanHeader."No.";
        OriginalEvent."Version No." := OriginalPlanHeader."Version No.";
        OriginalEvent."Event Type" := 'Original Audit';
        OriginalEvent.Description := 'This event belongs only to version 1.';
        OriginalEvent.Insert(true);
        OriginalPlanHeader.MarkReleased();

        // [WHEN] a new version is created through the orchestration codeunit
        PlanManagement.CreateNewVersion(OriginalPlanHeader, NewPlanHeader);

        // [THEN] the base remains released and the new exact version is a draft revision
        OriginalPlanHeader.Get(OriginalPlanHeader."No.", 1);
        AssertThat(OriginalPlanHeader.Status = OriginalPlanHeader.Status::Released, 'expected version 1 to remain Released until a replacement is released');
        AssertThat(NewPlanHeader."Version No." = 2, 'expected the new version number to be 2');
        AssertThat(NewPlanHeader."Previous Version No." = 1, 'expected version 2 to refer back to version 1');
        AssertThat(NewPlanHeader.Status = NewPlanHeader.Status::Draft, 'expected the new version to be Draft');

        // [THEN] source, pallet and component rows are copied with their exact identities
        AssertThat(CopiedSource.Get(NewPlanHeader."No.", NewPlanHeader."Version No.", OriginalSource."Line No."), 'expected the source to be copied');
        AssertThat(CopiedSource."Source Document No." = OriginalSource."Source Document No.", 'expected the source document number to be copied');
        AssertThat(CopiedSource.Quantity = OriginalSource.Quantity, 'expected the source quantity to be copied');
        AssertThat(CopiedPallet.Get(NewPlanHeader."No.", NewPlanHeader."Version No.", OriginalPallet."Pallet No."), 'expected the pallet to be copied');
        AssertThat(CopiedPallet."Target Quantity" = OriginalPallet."Target Quantity", 'expected the pallet target to be copied');
        AssertThat(CopiedComponent.Get(NewPlanHeader."No.", NewPlanHeader."Version No.", OriginalComponent."Pallet No.", OriginalComponent."Line No."), 'expected the component to be copied');
        AssertThat(CopiedComponent."Source Line No." = OriginalComponent."Source Line No.", 'expected the component source link to be copied');
        AssertThat(CopiedComponent.Quantity = OriginalComponent.Quantity, 'expected the component quantity to be copied');

        // [THEN] old event history is not copied; only the new revision event exists on version 2
        PlanEvent.SetRange("Plan No.", NewPlanHeader."No.");
        PlanEvent.SetRange("Version No.", NewPlanHeader."Version No.");
        PlanEvent.SetRange("Event Type", 'Original Audit');
        AssertThat(PlanEvent.IsEmpty(), 'expected version 1 audit history not to be copied');
        PlanEvent.SetRange("Event Type", 'Version Created');
        AssertThat(PlanEvent.Count() = 1, 'expected exactly one version-created audit event on version 2');
    end;

    [Test]
    procedure ReleasingRevisionSupersedesPreviousVersionOnlyAfterValidation()
    var
        FirstVersion: Record "SAL Plan Header";
        NewVersion: Record "SAL Plan Header";
        PlanComponent: Record "SAL Plan Component";
        PlanManagement: Codeunit "SAL Plan Management";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        SalesDocumentNo: Code[20];
    begin
        // [GIVEN] a balanced draft backed by an exact Released Sales Order line
        SalesDocumentNo := GetUniquePlanNo();
        CreateReleasedSalesOrderLine(SalesDocumentNo, 10000, 'ITEM-TEST', 'V1', 'TRAY', 10);
        CreatePlan(FirstVersion);
        FirstVersion.Description := 'Release lifecycle';
        FirstVersion.Priority := 1;
        FirstVersion."Required Finish Date" := WorkDate();
        FirstVersion."Dispatch Date" := WorkDate();
        FirstVersion."Marketer Description" := 'The Avocado Collective';
        FirstVersion."Marketer Confirmed" := true;
        FirstVersion.Modify(true);
        CreateSource(FirstVersion, SalesDocumentNo, 10, PlanSource);
        CreatePallet(FirstVersion, 10, PlanPallet);
        CreateComponent(FirstVersion, PlanPallet, PlanSource, 10, PlanComponent);

        // [WHEN] version 1 is released and a copied version 2 is subsequently released
        PlanManagement.ReleasePlan(FirstVersion);
        PlanManagement.CreateNewVersion(FirstVersion, NewVersion);

        // [THEN] the live version is still version 1 while the replacement remains Draft
        FirstVersion.Get(FirstVersion."No.", 1);
        AssertThat(FirstVersion.Status = FirstVersion.Status::Released, 'expected version 1 to remain live while version 2 is Draft');
        AssertThat(NewVersion.Status = NewVersion.Status::Draft, 'expected the copied replacement to remain Draft');

        // [GIVEN] the replacement marketer and routing are explicitly reconfirmed
        AssertThat(not NewVersion."Marketer Confirmed", 'expected a new version to require marketer reconfirmation');
        NewVersion."Marketer Confirmed" := true;
        NewVersion.Modify(true);
        PlanSource.Get(NewVersion."No.", NewVersion."Version No.", PlanSource."Line No.");
        AssertThat(not PlanSource."Routing Confirmed", 'expected copied demand to require routing reconfirmation');
        PlanSource."Routing Confirmed" := true;
        PlanSource.Modify(true);

        PlanManagement.ReleasePlan(NewVersion);

        // [THEN] successful validation and release atomically supersede version 1
        FirstVersion.Get(FirstVersion."No.", 1);
        NewVersion.Get(NewVersion."No.", 2);
        AssertThat(FirstVersion.Status = FirstVersion.Status::Superseded, 'expected version 1 to be superseded only after version 2 releases');
        AssertThat(NewVersion.Status = NewVersion.Status::Released, 'expected version 2 to become the live Released version');
        AssertThat(NewVersion."Validated Date Time" <> 0DT, 'expected release to record successful validation');
        AssertThat(NewVersion."Released Date Time" <> 0DT, 'expected release audit data to be stamped');
    end;

    [Test]
    procedure ConfirmationIsInvalidatedWhenConfirmedValuesChange()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        // [GIVEN] confirmed marketer and routing decisions
        CreatePlan(PlanHeader);
        PlanHeader."Marketer Description" := 'The Avocado Collective';
        PlanHeader."Marketer Confirmed" := true;
        PlanHeader.Modify(true);
        CreateSource(PlanHeader, 'SO-CONFIRM', 10, PlanSource);
        AssertThat(PlanSource."Routing Confirmed", 'expected test routing to start confirmed');

        // [WHEN] either confirmed value changes
        PlanHeader.Validate("Marketer Description", 'Costa');
        PlanHeader.Modify(true);
        PlanSource.Validate("Execution Route", PlanSource."Execution Route"::ExternalDCFulfilment);
        PlanSource.Validate("Facility Work Type", PlanSource."Facility Work Type"::None);
        PlanSource.Modify(true);

        // [THEN] both decisions require explicit confirmation again
        AssertThat(not PlanHeader."Marketer Confirmed", 'expected a changed marketer to clear confirmation');
        AssertThat(not PlanSource."Routing Confirmed", 'expected a changed route to clear confirmation');
    end;

    [Test]
    procedure CancelledDraftDoesNotBlockAnotherRevision()
    var
        CancelledVersion: Record "SAL Plan Header";
        FirstVersion: Record "SAL Plan Header";
        NewVersion: Record "SAL Plan Header";
        PlanManagement: Codeunit "SAL Plan Management";
    begin
        // [GIVEN] a released plan with an abandoned draft revision
        CreatePlan(FirstVersion);
        FirstVersion.MarkReleased();
        PlanManagement.CreateNewVersion(FirstVersion, CancelledVersion);

        // [WHEN] the abandoned draft is cancelled and another revision is requested
        PlanManagement.CancelDraft(CancelledVersion);
        PlanManagement.CreateNewVersion(FirstVersion, NewVersion);

        // [THEN] history is retained and the next version is available for work
        CancelledVersion.Get(CancelledVersion."No.", 2);
        AssertThat(CancelledVersion.Status = CancelledVersion.Status::Cancelled, 'expected version 2 to remain as cancelled history');
        AssertThat(NewVersion."Version No." = 3, 'expected the fresh draft to use the next immutable version number');
        AssertThat(NewVersion.Status = NewVersion.Status::Draft, 'expected version 3 to be Draft');
    end;

    [Test]
    procedure ValidationRejectsQuantityAboveLiveRemainingDemand()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        SalesDocumentNo: Code[20];
    begin
        // [GIVEN] live demand for 10 units but a balanced plan attempting 11
        SalesDocumentNo := GetUniquePlanNo();
        CreateReleasedSalesOrderLine(SalesDocumentNo, 10000, 'ITEM-TEST', 'V1', 'TRAY', 10);
        CreatePlan(PlanHeader);
        PlanHeader.Priority := 1;
        PlanHeader."Required Finish Date" := WorkDate();
        PlanHeader."Dispatch Date" := WorkDate();
        PlanHeader."Marketer Description" := 'The Avocado Collective';
        PlanHeader."Marketer Confirmed" := true;
        PlanHeader.Modify(true);
        CreateSource(PlanHeader, SalesDocumentNo, 11, PlanSource);
        CreatePallet(PlanHeader, 11, PlanPallet);
        CreateComponent(PlanHeader, PlanPallet, PlanSource, 11, PlanComponent);

        // [WHEN/THEN] release validation checks current remaining demand and rejects the excess
        AssertThat(not TryValidatePlan(PlanHeader), 'expected quantity above live remaining demand to be rejected');
    end;

    [Test]
    procedure DuplicateSourceDocumentLineIsRejected()
    var
        DuplicateSource: Record "SAL Plan Source";
        FirstSource: Record "SAL Plan Source";
        PlanHeader: Record "SAL Plan Header";
    begin
        // [GIVEN] a source document line already exists on the plan version
        CreatePlan(PlanHeader);
        CreateSource(PlanHeader, 'SO-DUPLICATE', 10, FirstSource);

        // [WHEN] another row targets the same source type, document and line
        InitialiseSource(PlanHeader."No.", PlanHeader."Version No.", 'SO-DUPLICATE', 10, DuplicateSource);

        // [THEN] the unique source key prevents duplicate demand
        AssertThat(not TryInsertSource(DuplicateSource), 'expected duplicate demand to be rejected');
    end;

    [Test]
    procedure ReleasedSalesOrderAddsAllOutstandingItemLinesToNewPlan()
    var
        DemandManagement: Codeunit "SAL Demand Management";
        FirstPlanSource: Record "SAL Plan Source";
        PlanHeader: Record "SAL Plan Header";
        SecondPlanSource: Record "SAL Plan Source";
        AddedCount: Integer;
        SalesOrderNo: Code[20];
        SkippedCount: Integer;
    begin
        // [GIVEN] a new draft plan and a Released Sales Order with two outstanding item lines
        SalesOrderNo := GetUniquePlanNo();
        CreateSalesOrder(SalesOrderNo, true);
        CreateSalesOrderLine(SalesOrderNo, 10000, true, 'ITEM-FIRST', 12, 9);
        CreateSalesOrderLine(SalesOrderNo, 20000, true, 'ITEM-SECOND', 4, 4);
        CreatePlan(PlanHeader);

        // [WHEN] the whole Sales Order is added to the plan
        DemandManagement.AddSalesOrderDemand(PlanHeader, SalesOrderNo, AddedCount, SkippedCount);

        // [THEN] every outstanding item line becomes one exact plan source snapshot
        AssertThat(AddedCount = 2, 'expected both outstanding item lines to be added');
        AssertThat(SkippedCount = 0, 'expected no eligible line to be skipped');
        AssertThat(CountSalesOrderSources(PlanHeader, SalesOrderNo) = 2, 'expected exactly two sources for the Sales Order');
        AssertThat(GetSalesOrderSource(PlanHeader, SalesOrderNo, 10000, FirstPlanSource), 'expected the first Sales Order line on the plan');
        AssertThat(FirstPlanSource."Item No." = 'ITEM-FIRST', 'expected the first source item snapshot');
        AssertThat(FirstPlanSource.Quantity = 9, 'expected the first source to use outstanding quantity');
        AssertThat(FirstPlanSource."Allocated Quantity" = 3, 'expected the first source to snapshot the already allocated quantity');
        AssertThat(GetSalesOrderSource(PlanHeader, SalesOrderNo, 20000, SecondPlanSource), 'expected the second Sales Order line on the plan');
        AssertThat(SecondPlanSource."Item No." = 'ITEM-SECOND', 'expected the second source item snapshot');
        AssertThat(SecondPlanSource.Quantity = 4, 'expected the second source to use outstanding quantity');
    end;

    [Test]
    procedure SalesOrderDemandSkipsDuplicatesAndIneligibleLines()
    var
        DemandManagement: Codeunit "SAL Demand Management";
        PlanHeader: Record "SAL Plan Header";
        AddedCount: Integer;
        SalesOrderNo: Code[20];
        SkippedCount: Integer;
    begin
        // [GIVEN] a Released Sales Order with one eligible item, one non-item and one fully handled item
        SalesOrderNo := GetUniquePlanNo();
        CreateSalesOrder(SalesOrderNo, true);
        CreateSalesOrderLine(SalesOrderNo, 10000, true, 'ITEM-ELIGIBLE', 8, 8);
        CreateSalesOrderLine(SalesOrderNo, 20000, false, 'NON-ITEM', 5, 5);
        CreateSalesOrderLine(SalesOrderNo, 30000, true, 'ITEM-COMPLETE', 6, 0);
        CreatePlan(PlanHeader);

        // [WHEN] the Sales Order is added twice
        DemandManagement.AddSalesOrderDemand(PlanHeader, SalesOrderNo, AddedCount, SkippedCount);
        AssertThat(AddedCount = 1, 'expected only the outstanding item line to be added');
        AssertThat(SkippedCount = 0, 'expected filtered-out lines not to count as duplicates');
        DemandManagement.AddSalesOrderDemand(PlanHeader, SalesOrderNo, AddedCount, SkippedCount);

        // [THEN] the eligible duplicate is skipped and no ineligible source is ever created
        AssertThat(AddedCount = 0, 'expected no source to be added on the second import');
        AssertThat(SkippedCount = 1, 'expected the existing eligible line to be reported as skipped');
        AssertThat(CountSalesOrderSources(PlanHeader, SalesOrderNo) = 1, 'expected only one source after repeated import');
    end;

    [Test]
    procedure OpenSalesOrderIsRefusedWithoutCreatingPlanSources()
    var
        PlanHeader: Record "SAL Plan Header";
        AddedCount: Integer;
        SalesOrderNo: Code[20];
        SkippedCount: Integer;
    begin
        // [GIVEN] a new draft plan and an Open Sales Order with otherwise eligible demand
        SalesOrderNo := GetUniquePlanNo();
        CreateSalesOrder(SalesOrderNo, false);
        CreateSalesOrderLine(SalesOrderNo, 10000, true, 'ITEM-OPEN', 10, 10);
        CreatePlan(PlanHeader);

        // [WHEN/THEN] whole-order import refuses the Open order and leaves the new plan empty
        AssertThat(not TryAddSalesOrderDemand(PlanHeader, SalesOrderNo, AddedCount, SkippedCount), 'expected an Open Sales Order to be refused');
        AssertThat(CountSalesOrderSources(PlanHeader, SalesOrderNo) = 0, 'expected no source rows from the refused Sales Order');
    end;

    local procedure CreatePlan(var PlanHeader: Record "SAL Plan Header")
    begin
        Clear(PlanHeader);
        PlanHeader.Init();
        PlanHeader."No." := GetUniquePlanNo();
        PlanHeader.Insert(true);
    end;

    local procedure CreateRevision(PreviousPlanHeader: Record "SAL Plan Header"; VersionNo: Integer; var RevisionPlanHeader: Record "SAL Plan Header")
    begin
        Clear(RevisionPlanHeader);
        RevisionPlanHeader.Init();
        RevisionPlanHeader."No." := PreviousPlanHeader."No.";
        RevisionPlanHeader."Version No." := VersionNo;
        RevisionPlanHeader."Previous Version No." := PreviousPlanHeader."Version No.";
        RevisionPlanHeader.InsertRevision();
    end;

    local procedure CreateSource(PlanHeader: Record "SAL Plan Header"; SourceDocumentNo: Code[20]; Quantity: Decimal; var PlanSource: Record "SAL Plan Source")
    begin
        InitialiseSource(PlanHeader."No.", PlanHeader."Version No.", SourceDocumentNo, Quantity, PlanSource);
        PlanSource.Insert(true);
    end;

    local procedure InitialiseSource(PlanNo: Code[20]; VersionNo: Integer; SourceDocumentNo: Code[20]; Quantity: Decimal; var PlanSource: Record "SAL Plan Source")
    begin
        Clear(PlanSource);
        PlanSource.Init();
        PlanSource."Plan No." := PlanNo;
        PlanSource."Version No." := VersionNo;
        PlanSource."Source Type" := PlanSource."Source Type"::SalesOrder;
        PlanSource."Source Document No." := SourceDocumentNo;
        PlanSource."Source Document Line No." := 10000;
        PlanSource."Execution Route" := PlanSource."Execution Route"::ManjimupPack;
        PlanSource."Facility Work Type" := PlanSource."Facility Work Type"::PackNew;
        PlanSource."Routing Confirmed" := true;
        PlanSource."Item No." := 'ITEM-TEST';
        PlanSource."Variant Code" := 'V1';
        PlanSource."Unit of Measure Code" := 'TRAY';
        PlanSource."Item Description" := 'Test item';
        PlanSource.Priority := 1;
        PlanSource.Quantity := Quantity;
    end;

    local procedure CreatePallet(PlanHeader: Record "SAL Plan Header"; TargetQuantity: Decimal; var PlanPallet: Record "SAL Plan Pallet")
    begin
        InitialisePallet(PlanHeader."No.", PlanHeader."Version No.", TargetQuantity, PlanPallet);
        PlanPallet.Insert(true);
    end;

    local procedure InitialisePallet(PlanNo: Code[20]; VersionNo: Integer; TargetQuantity: Decimal; var PlanPallet: Record "SAL Plan Pallet")
    begin
        Clear(PlanPallet);
        PlanPallet.Init();
        PlanPallet."Plan No." := PlanNo;
        PlanPallet."Version No." := VersionNo;
        PlanPallet."Pallet Type" := PlanPallet."Pallet Type"::Standard;
        PlanPallet."Target Quantity" := TargetQuantity;
    end;

    local procedure CreateComponent(PlanHeader: Record "SAL Plan Header"; PlanPallet: Record "SAL Plan Pallet"; PlanSource: Record "SAL Plan Source"; Quantity: Decimal; var PlanComponent: Record "SAL Plan Component")
    begin
        Clear(PlanComponent);
        PlanComponent.Init();
        PlanComponent."Plan No." := PlanHeader."No.";
        PlanComponent."Version No." := PlanHeader."Version No.";
        PlanComponent."Pallet No." := PlanPallet."Pallet No.";
        PlanComponent."Source Line No." := PlanSource."Line No.";
        PlanComponent."Item No." := PlanSource."Item No.";
        PlanComponent."Variant Code" := PlanSource."Variant Code";
        PlanComponent."Unit of Measure Code" := PlanSource."Unit of Measure Code";
        PlanComponent.Description := PlanSource."Item Description";
        PlanComponent.Quantity := Quantity;
        PlanComponent.Insert(true);
    end;

    local procedure GetUniquePlanNo(): Code[20]
    begin
        exit(CopyStr('SAL' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure CountSalesOrderSources(PlanHeader: Record "SAL Plan Header"; SalesOrderNo: Code[20]): Integer
    var
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Source Type", PlanSource."Source Type"::SalesOrder);
        PlanSource.SetRange("Source Document No.", SalesOrderNo);
        exit(PlanSource.Count());
    end;

    local procedure GetSalesOrderSource(PlanHeader: Record "SAL Plan Header"; SalesOrderNo: Code[20]; SalesLineNo: Integer; var PlanSource: Record "SAL Plan Source"): Boolean
    begin
        Clear(PlanSource);
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Source Type", PlanSource."Source Type"::SalesOrder);
        PlanSource.SetRange("Source Document No.", SalesOrderNo);
        PlanSource.SetRange("Source Document Line No.", SalesLineNo);
        exit(PlanSource.FindFirst());
    end;

    local procedure CreateSalesOrder(DocumentNo: Code[20]; Released: Boolean)
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := DocumentNo;
        if Released then
            SalesHeader.Status := SalesHeader.Status::Released
        else
            SalesHeader.Status := SalesHeader.Status::Open;
        SalesHeader.Insert(false);
    end;

    local procedure CreateSalesOrderLine(DocumentNo: Code[20]; LineNo: Integer; IsItem: Boolean; ItemNo: Code[20]; Quantity: Decimal; OutstandingQuantity: Decimal)
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.Init();
        SalesLine."Document Type" := SalesLine."Document Type"::Order;
        SalesLine."Document No." := DocumentNo;
        SalesLine."Line No." := LineNo;
        if IsItem then
            SalesLine.Type := SalesLine.Type::Item;
        SalesLine."No." := ItemNo;
        SalesLine."Unit of Measure Code" := 'TRAY';
        SalesLine.Quantity := Quantity;
        SalesLine."Outstanding Quantity" := OutstandingQuantity;
        SalesLine.Insert(false);
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

    [TryFunction]
    local procedure TryInsertHeader(var PlanHeader: Record "SAL Plan Header")
    begin
        PlanHeader.Insert(true);
    end;

    [TryFunction]
    local procedure TryValidatePlan(var PlanHeader: Record "SAL Plan Header")
    var
        PlanValidation: Codeunit "SAL Plan Validation";
    begin
        PlanValidation.ValidatePlan(PlanHeader);
    end;

    [TryFunction]
    local procedure TryAddSalesOrderDemand(var PlanHeader: Record "SAL Plan Header"; SalesOrderNo: Code[20]; var AddedCount: Integer; var SkippedCount: Integer)
    var
        DemandManagement: Codeunit "SAL Demand Management";
    begin
        DemandManagement.AddSalesOrderDemand(PlanHeader, SalesOrderNo, AddedCount, SkippedCount);
    end;

    [TryFunction]
    local procedure TryInsertSource(var PlanSource: Record "SAL Plan Source")
    begin
        PlanSource.Insert(true);
    end;

    [TryFunction]
    local procedure TryInsertPallet(var PlanPallet: Record "SAL Plan Pallet")
    begin
        PlanPallet.Insert(true);
    end;

    [TryFunction]
    local procedure TryInsertComponent(var PlanComponent: Record "SAL Plan Component")
    begin
        PlanComponent.Insert(true);
    end;

    [TryFunction]
    local procedure TryInsertEvent(var PlanEvent: Record "SAL Plan Event")
    begin
        PlanEvent.Insert(true);
    end;

    [TryFunction]
    local procedure TryModifyHeader(var PlanHeader: Record "SAL Plan Header")
    begin
        PlanHeader.Modify(true);
    end;

    [TryFunction]
    local procedure TryModifySource(var PlanSource: Record "SAL Plan Source")
    begin
        PlanSource.Modify(true);
    end;

    [TryFunction]
    local procedure TryModifyPallet(var PlanPallet: Record "SAL Plan Pallet")
    begin
        PlanPallet.Modify(true);
    end;

    [TryFunction]
    local procedure TryModifyComponent(var PlanComponent: Record "SAL Plan Component")
    begin
        PlanComponent.Modify(true);
    end;

    [TryFunction]
    local procedure TryModifyEvent(var PlanEvent: Record "SAL Plan Event")
    begin
        PlanEvent.Modify(true);
    end;

    [TryFunction]
    local procedure TryDeleteSource(var PlanSource: Record "SAL Plan Source")
    begin
        PlanSource.Delete(true);
    end;

    [TryFunction]
    local procedure TryDeletePallet(var PlanPallet: Record "SAL Plan Pallet")
    begin
        PlanPallet.Delete(true);
    end;

    [TryFunction]
    local procedure TryDeleteComponent(var PlanComponent: Record "SAL Plan Component")
    begin
        PlanComponent.Delete(true);
    end;

    [TryFunction]
    local procedure TryDeleteEvent(var PlanEvent: Record "SAL Plan Event")
    begin
        PlanEvent.Delete(true);
    end;

    [TryFunction]
    local procedure TryRenameEvent(var PlanEvent: Record "SAL Plan Event"; NewEntryNo: Integer)
    begin
        PlanEvent.Rename(PlanEvent."Plan No.", PlanEvent."Version No.", NewEntryNo);
    end;

    local procedure AssertThat(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(AssertFailedErr, Message);
    end;
}
