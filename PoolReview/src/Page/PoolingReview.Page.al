page 59300 "WLF Pooling Review"
{
    Caption = 'Pooling Review List';
    PageType = Worksheet;
    SourceTable = "WLF Pool Review Group";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = Tasks;
    AdditionalSearchTerms = 'pooling review list,pool checks,standard pool review';
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    SourceTableView = sorting("Group ID");

    layout
    {
        area(Content)
        {
            group(Scope)
            {
                Caption = 'Your pooling workspace';
                field(CurrentCompany; CompanyName())
                {
                    ApplicationArea = All;
                    Caption = 'Company';
                    Editable = false;
                    ToolTip = 'Shows the current company. This overview uses your existing access to this company only.';
                }
                field(SeasonScope; SeasonFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Season filter';
                    ToolTip = 'Enter a season or a Business Central filter expression. Leave blank for all seasons. The cards and list respect this filter.';
                    trigger OnValidate()
                    begin
                        ApplyScope();
                    end;
                }
                field(WeekScope; WeekFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Pool week filter';
                    ToolTip = 'Enter a pool week code or filter expression. Leave blank for all weeks. The cards and list respect this filter.';
                    trigger OnValidate()
                    begin
                        ApplyScope();
                    end;
                }
                field(TypeScope; PoolTypeFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Pool type';
                    ToolTip = 'Choose Internal, External, Contract Pack or all pool types for both the cards and the list.';
                    trigger OnValidate()
                    begin
                        ApplyScope();
                    end;
                }
                field(CurrentFocus; FocusText)
                {
                    ApplicationArea = All;
                    Caption = 'List focus';
                    Editable = false;
                    ToolTip = 'Shows the status card currently filtering the list. The cards continue to count all statuses within the season, week, type and standard filters.';
                }
            }
            cuegroup(ReviewOverview)
            {
                Caption = 'Groups at a glance';
                field(GroupsInScope; ScopeCount)
                {
                    ApplicationArea = All;
                    Caption = 'Groups in scope';
                    ToolTip = 'Counts groups within the season, week, type and standard filters. Choose this card to show every review status in that scope.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        SetFocus(-1);
                    end;
                }
                field(NotChecked; UncheckedCount)
                {
                    ApplicationArea = All;
                    Caption = 'Not checked';
                    Style = Subordinate;
                    ToolTip = 'Counts groups with no scan in this session. These groups have no review result and are not included in the checked totals.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        SetFocus(0);
                    end;
                }
                field(Mismatches; MismatchCount)
                {
                    ApplicationArea = All;
                    Caption = 'Mismatches';
                    Style = Unfavorable;
                    ToolTip = 'Counts groups whose reads completed and have at least one mismatch. Each group appears in one status card only.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        SetFocus(1);
                    end;
                }
                field(NeedsReview; ReviewCount)
                {
                    ApplicationArea = All;
                    Caption = 'Needs review';
                    Style = Attention;
                    ToolTip = 'Counts groups whose reads completed with warnings or unresolved sources and no mismatch. Read the findings to understand the evidence.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        SetFocus(2);
                    end;
                }
                field(UnableToCheck; UnableCount)
                {
                    ApplicationArea = All;
                    Caption = 'Unable to check';
                    Style = Ambiguous;
                    ToolTip = 'Counts groups whose latest scan could not complete, for example because of missing access, setup, schema support or scan limits.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        SetFocus(3);
                    end;
                }
                field(NoExceptionInScope; NoExceptionCount)
                {
                    ApplicationArea = All;
                    Caption = 'No exception in checked scope';
                    ToolTip = 'Counts completed group scans with no recorded mismatch, warning or unresolved source. Limited coverage still applies; this is not approval to close or pay.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        SetFocus(4);
                    end;
                }
            }
            group(OverviewNotes)
            {
                ShowCaption = false;
                Editable = false;
                field(ScopeSummary; SummaryText)
                {
                    ApplicationArea = All;
                    Caption = 'Scope summary';
                    ToolTip = 'Summarises coverage within the filters. Cards count groups, not individual findings. The focused list may show fewer groups.';
                }
                field(LastScan; LatestScan)
                {
                    ApplicationArea = All;
                    Caption = 'Latest check in scope';
                    ToolTip = 'Shows the most recent scan attempt in the filtered scope. Other rows can have older snapshots or no check.';
                }
                field(SnapshotNote; CompactSnapshotLbl)
                {
                    ApplicationArea = All;
                    Caption = 'Snapshot';
                    ToolTip = 'Results exist only in this session. Run checks again after posting or other source changes.';
                }
            }
            repeater(Groups)
            {
                Editable = false;
                field("Group Code"; Rec."Group Code")
                {
                    ApplicationArea = All;
                    Caption = 'Pool group';
                    Style = Strong;
                    ToolTip = 'Select a group to see its detail. Run Checks updates this group; View Issues opens its findings and source evidence.';
                }
                field(ReviewResult; RowStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Review result';
                    StyleExpr = ReviewStyle;
                    ToolTip = 'Shows one review category for this group. Business status is separate from the latest check result.';
                }
                field(Season; Rec.Season)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the group season.';
                }
                field("Week Code"; Rec."Week Code")
                {
                    ApplicationArea = All;
                    Caption = 'Pool week';
                    ToolTip = 'Specifies the group pool week code.';
                }
                field("Pool Type Caption"; Rec."Pool Type Caption")
                {
                    ApplicationArea = All;
                    Caption = 'Pool type';
                    ToolTip = 'Specifies Internal, External or Contract Pack as recorded on the group.';
                }
                field("Business Status"; Rec."Business Status")
                {
                    ApplicationArea = All;
                    Caption = 'Pool status';
                    ToolTip = 'Shows the status recorded by the pooling engine. A closed group can still have review exceptions.';
                }
                field(Pools; PoolCountText)
                {
                    ApplicationArea = All;
                    Caption = 'Pools';
                    ToolTip = 'Shows the number of pools in the latest completed scan. A dash means no completed check.';
                }
                field(GroupMismatches; ErrorCountText)
                {
                    ApplicationArea = All;
                    Caption = 'Mismatches';
                    StyleExpr = ReviewStyle;
                    ToolTip = 'Shows the mismatch count after a completed scan. Select the group and choose View Issues to inspect its findings.';
                }
                field(GroupWarnings; WarningCountText)
                {
                    ApplicationArea = All;
                    Caption = 'Needs review';
                    ToolTip = 'Shows the warning count after a completed scan. Select the group and choose View Issues to inspect its findings.';
                }
                field(MovementKilograms; MovementKgText)
                {
                    ApplicationArea = All;
                    Caption = 'Movement kg';
                    ToolTip = 'Shows raw signed TR, TRA and TRD kilograms from the completed scan, including reversal records. This is not certified physical quantity.';
                }
                field(AllLedgerKilograms; AllLedgerKgText)
                {
                    ApplicationArea = All;
                    Caption = 'All ledger kg';
                    ToolTip = 'Shows raw signed kilograms across every ledger transaction type in the completed scan. Revenue and charges can carry kilograms too.';
                }
                field("Scanned At"; Rec."Scanned At")
                {
                    ApplicationArea = All;
                    Caption = 'Last checked';
                    ToolTip = 'Shows this group''s last scan attempt in the session. Run checks again when source records change.';
                }
            }
            group(SelectedGroup)
            {
                Caption = 'Selected group';
                Editable = false;
                field(SelectedCode; Rec."Group Code")
                {
                    ApplicationArea = All;
                    Caption = 'Pool group';
                    Style = Strong;
                    ToolTip = 'Identifies the row whose detail appears below.';
                }
                field(SelectedResult; Rec."Review Status")
                {
                    ApplicationArea = All;
                    Caption = 'Check detail';
                    StyleExpr = ReviewStyle;
                    ToolTip = 'Shows the reader''s detailed status, including any unresolved checks.';
                }
                field("Review Detail"; Rec."Review Detail")
                {
                    ApplicationArea = All;
                    Caption = 'What needs attention';
                    MultiLine = true;
                    ToolTip = 'Explains a failed or limited scan. View Issues contains individual findings with read-only evidence.';
                }
                field(SelectedKgBasis; KgBasisLbl)
                {
                    ApplicationArea = All;
                    Caption = 'Kilogram basis';
                    ToolTip = 'Explains why movement kilograms and all ledger kilograms are shown separately.';
                }
                field("Ledger Net"; Rec."Ledger Net")
                {
                    ApplicationArea = All;
                    Caption = 'Recorded ledger net';
                    BlankZero = true;
                    ToolTip = 'Shows the signed ledger amount from the selected completed scan. This is a ledger total, not an amount payable or approved.';
                }
                field("Ledger Count"; Rec."Ledger Count")
                {
                    ApplicationArea = All;
                    BlankZero = true;
                    ToolTip = 'Shows the ledger rows included in this group''s totals. No completed scan means no measured count.';
                }
                field("Invoice Candidates"; Rec."Invoice Candidates")
                {
                    ApplicationArea = All;
                    Caption = 'Invoice lines considered';
                    BlankZero = true;
                    ToolTip = 'Counts consignment invoice item lines in this season and week before pool-type attribution. This can include other pool types.';
                }
                field("Attributed Invoices"; Rec."Attributed Invoices")
                {
                    ApplicationArea = All;
                    Caption = 'Invoice lines attributed';
                    BlankZero = true;
                    ToolTip = 'Counts candidates resolved to this group. This does not certify their full financial reconciliation.';
                }
                field("Unresolved Sources"; Rec."Unresolved Sources")
                {
                    ApplicationArea = All;
                    Caption = 'Unresolved sources';
                    BlankZero = true;
                    Style = Attention;
                    ToolTip = 'Counts unresolved invoice attributions or classifications that limit the corresponding checks.';
                }
                field("Payment Count"; Rec."Payment Count")
                {
                    ApplicationArea = All;
                    Caption = 'Payment headers';
                    BlankZero = true;
                    ToolTip = 'Counts payment headers read. These are not proof of reconciliation to vendor or bank entries.';
                }
                field("Information Count"; Rec."Information Count")
                {
                    ApplicationArea = All;
                    Caption = 'Coverage and information notes';
                    BlankZero = true;
                    ToolTip = 'Counts informational findings, including the limits that apply to every review.';
                    DrillDown = true;
                    trigger OnDrillDown()
                    begin
                        OpenIssues();
                    end;
                }
            }
            group(Coverage)
            {
                Caption = 'Checks and coverage';
                Editable = false;
                Visible = ShowCoverage;
                field(CoverageNotes; CoverageText)
                {
                    ApplicationArea = All;
                    Caption = 'Checks included';
                    MultiLine = true;
                    ToolTip = 'Describes the checks included and the checks outside this version''s scope.';
                }
                field(FullSnapshotNotes; SnapshotNotesLbl)
                {
                    ApplicationArea = All;
                    Caption = 'How to read results';
                    MultiLine = true;
                    ToolTip = 'Explains the session snapshot and why completed reads do not approve a pool for closing or payment.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RunChecks)
            {
                ApplicationArea = All;
                Caption = 'Run Checks';
                Image = Calculate;
                ToolTip = 'Checks the selected group and refreshes its findings and status card. Reads source records without changing the pooling engine or financial data.';
                trigger OnAction()
                var
                    SelectedID: Integer;
                begin
                    EnsureGroupSelected();
                    SelectedID := Rec."Group ID";
                    Reader.RunChecks(Rec, Issues);
                    Rec."Review Bucket" := GetBucket(Rec);
                    Rec.Modify();
                    RefreshView(SelectedID);
                end;
            }
            action(CheckFilteredGroups)
            {
                ApplicationArea = All;
                Caption = 'Check Filtered Groups';
                Image = Calculate;
                ToolTip = 'Checks every group currently visible in the filtered list, up to 50 per action. Group IDs are captured before scanning so changing results cannot skip rows.';
                trigger OnAction()
                begin
                    RunFilteredChecks();
                end;
            }
            action(ViewIssues)
            {
                ApplicationArea = All;
                Caption = 'View Issues';
                Image = ErrorLog;
                ToolTip = 'Opens the selected group''s mismatches, review warnings and coverage notes, with read-only source and related-record drill-downs.';
                trigger OnAction()
                begin
                    OpenIssues();
                end;
            }
            action(ViewGroupSource)
            {
                ApplicationArea = All;
                Caption = 'View Group Source';
                Image = View;
                ToolTip = 'Opens the current group record as a read-only field snapshot. Values may have changed since its last check.';
                trigger OnAction()
                begin
                    EnsureGroupSelected();
                    Reader.ShowEvidence(Rec."Source Record ID");
                end;
            }
            action(ShowAllStatuses)
            {
                ApplicationArea = All;
                Caption = 'Show All Review Statuses';
                Image = ClearFilter;
                ToolTip = 'Clears only the status-card focus. Season, week, type and standard filters remain in place.';
                trigger OnAction()
                begin
                    SetFocus(-1);
                end;
            }
            action(ToggleCoverage)
            {
                ApplicationArea = All;
                Caption = 'Checks and Coverage';
                Image = AboutNav;
                ToolTip = 'Shows or hides the full scope and interpretation notes beneath the selected group.';
                trigger OnAction()
                begin
                    ShowCoverage := not ShowCoverage;
                    CurrPage.Update(false);
                end;
            }
            action(ReloadGroups)
            {
                ApplicationArea = All;
                Caption = 'Reload Groups';
                Image = Refresh;
                ToolTip = 'Loads current group headers again and clears session checks. Existing scope filters are retained; all review statuses become visible.';
                trigger OnAction()
                begin
                    LoadGroups();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(RunChecksPromoted; RunChecks) { }
            actionref(CheckFilteredGroupsPromoted; CheckFilteredGroups) { }
            actionref(ViewIssuesPromoted; ViewIssues) { }
            actionref(ViewGroupSourcePromoted; ViewGroupSource) { }
            actionref(ReloadGroupsPromoted; ReloadGroups) { }
            actionref(ToggleCoveragePromoted; ToggleCoverage) { }
        }
    }

    trigger OnOpenPage()
    begin
        CoverageText := Reader.CoverageNotes();
        FocusBucket := -1;
        LoadGroups();
    end;

    trigger OnAfterGetRecord()
    begin
        SetRowPresentation();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        SetRowPresentation();
        RecalculateOverview();
    end;

    local procedure LoadGroups()
    var
        StandardView: Text;
    begin
        Rec.FilterGroup(0);
        StandardView := Rec.GetView(false);
        Issues.Reset();
        Issues.DeleteAll();
        Rec.Reset();
        Reader.LoadGroups(Rec);
        Rec.SetView(StandardView);
        FocusBucket := -1;
        ApplyScope();
    end;

    local procedure ApplyScope()
    begin
        // Dedicated scope and card filters leave the standard filter pane independent.
        Rec.FilterGroup(101);
        Rec.SetFilter(Season, SeasonFilter);
        Rec.SetFilter("Week Code", WeekFilter);
        if PoolTypeFilter = PoolTypeFilter::"All pool types" then
            Rec.SetRange("Pool Type")
        else
            case PoolTypeFilter of
                PoolTypeFilter::Internal: Rec.SetRange("Pool Type", 0);
                PoolTypeFilter::External: Rec.SetRange("Pool Type", 1);
                PoolTypeFilter::"Contract Pack": Rec.SetRange("Pool Type", 2);
            end;
        Rec.FilterGroup(0);
        ApplyFocus();
        RefreshView(0);
    end;

    local procedure SetFocus(NewBucket: Integer)
    begin
        FocusBucket := NewBucket;
        ApplyFocus();
        RefreshView(0);
    end;

    local procedure ApplyFocus()
    begin
        Rec.FilterGroup(100);
        if FocusBucket < 0 then
            Rec.SetRange("Review Bucket")
        else
            Rec.SetRange("Review Bucket", FocusBucket);
        Rec.FilterGroup(0);
        if FocusBucket < 0 then
            FocusText := 'All review statuses'
        else
            FocusText := BucketCaption(FocusBucket);
    end;

    local procedure RefreshView(PreferredID: Integer)
    var
        Candidate: Record "WLF Pool Review Group";
        FoundPreferred: Boolean;
    begin
        Candidate.Copy(Rec, true);
        Candidate.SetRange("Group ID", PreferredID);
        if (PreferredID <> 0) and Candidate.FindFirst() then begin
            Rec := Candidate;
            FoundPreferred := true;
        end;
        if not FoundPreferred then
            if not Rec.FindFirst() then begin
                Rec.Init();
                Rec."Group ID" := 0;
            end;
        RecalculateOverview();
        SetRowPresentation();
        CurrPage.Update(false);
    end;

    local procedure RecalculateOverview()
    var
        ScopeRows: Record "WLF Pool Review Group";
        Bucket: Integer;
    begin
        if UpdatingOverview then
            exit;
        UpdatingOverview := true;
        ScopeCount := 0;
        UncheckedCount := 0;
        MismatchCount := 0;
        ReviewCount := 0;
        UnableCount := 0;
        NoExceptionCount := 0;
        LatestScan := 0DT;
        ScopeRows.Copy(Rec, true);
        // Status-card focus changes the list, not the denominator of the status cards.
        ScopeRows.FilterGroup(100);
        ScopeRows.SetRange("Review Bucket");
        ScopeRows.FilterGroup(0);
        if ScopeRows.FindSet() then
            repeat
                ScopeCount += 1;
                Bucket := GetBucket(ScopeRows);
                case Bucket of
                    0: UncheckedCount += 1;
                    1: MismatchCount += 1;
                    2: ReviewCount += 1;
                    3: UnableCount += 1;
                    4: NoExceptionCount += 1;
                end;
                if ScopeRows."Scanned At" > LatestScan then
                    LatestScan := ScopeRows."Scanned At";
            until ScopeRows.Next() = 0;
        SummaryText := StrSubstNo(SummaryLbl, ScopeCount, MismatchCount + ReviewCount + NoExceptionCount, UncheckedCount, UnableCount);
        UpdatingOverview := false;
    end;

    local procedure SetRowPresentation()
    begin
        RowStatus := BucketCaption(GetBucket(Rec));
        ReviewStyle := 'Subordinate';
        case GetBucket(Rec) of
            1: ReviewStyle := 'Unfavorable';
            2: ReviewStyle := 'Attention';
            3: ReviewStyle := 'Ambiguous';
            4: ReviewStyle := 'Standard';
        end;
        PoolCountText := '-';
        ErrorCountText := '-';
        WarningCountText := '-';
        MovementKgText := '-';
        AllLedgerKgText := '-';
        if (Rec."Scanned At" <> 0DT) and Rec."Scan Complete" then begin
            PoolCountText := Format(Rec."Pool Count");
            ErrorCountText := Format(Rec."Error Count");
            WarningCountText := Format(Rec."Warning Count");
            MovementKgText := Format(Rec."Movement Kg");
            AllLedgerKgText := Format(Rec."All Ledger Kg");
        end;
        if Rec."Group ID" = 0 then
            RowStatus := '';
    end;

    local procedure GetBucket(Group: Record "WLF Pool Review Group"): Integer
    begin
        if Group."Scanned At" = 0DT then
            exit(0);
        if not Group."Scan Complete" then
            exit(3);
        if Group."Error Count" > 0 then
            exit(1);
        if (Group."Warning Count" > 0) or (Group."Unresolved Sources" > 0) then
            exit(2);
        exit(4);
    end;

    local procedure BucketCaption(Bucket: Integer): Text
    begin
        case Bucket of
            0: exit('Not checked');
            1: exit('Mismatches');
            2: exit('Needs review');
            3: exit('Unable to check');
            4: exit('No exception in checked scope');
        end;
    end;

    local procedure RunFilteredChecks()
    var
        ScanRows: Record "WLF Pool Review Group";
        GroupIDs: List of [Integer];
        GroupID: Integer;
        Finished: Integer;
        Completed: Integer;
        Progress: Dialog;
    begin
        ScanRows.Copy(Rec, true);
        if ScanRows.Count() > 50 then
            Error(BatchLimitErr);
        if ScanRows.FindSet() then
            repeat
                GroupIDs.Add(ScanRows."Group ID");
            until ScanRows.Next() = 0;
        if GroupIDs.Count() = 0 then
            Error(SelectGroupErr);
        // Freeze IDs before any bucket or source metadata changes. Reset only the working view.
        ScanRows.Reset();
        if GuiAllowed() then
            Progress.Open(ProgressLbl);
        foreach GroupID in GroupIDs do begin
            ScanRows.Get(GroupID);
            if GuiAllowed() then begin
                Progress.Update(1, ScanRows."Group Code");
                Progress.Update(2, Round(Finished / GroupIDs.Count() * 10000, 1));
            end;
            Reader.RunChecks(ScanRows, Issues);
            ScanRows."Review Bucket" := GetBucket(ScanRows);
            ScanRows.Modify();
            Finished += 1;
            if ScanRows."Scan Complete" then
                Completed += 1;
        end;
        if GuiAllowed() then
            Progress.Close();
        RefreshView(0);
        Message(BatchCompleteLbl, Finished, Completed, Finished - Completed);
    end;

    local procedure EnsureGroupSelected()
    begin
        if Rec.IsEmpty() or (Rec."Group ID" = 0) then
            Error(SelectGroupErr);
    end;

    local procedure OpenIssues()
    var
        IssuePage: Page "WLF Pool Review Issues";
    begin
        EnsureGroupSelected();
        if Rec."Scanned At" = 0DT then
            Error(ScanFirstErr);
        IssuePage.SetIssues(Issues, Rec."Group ID", Rec."Group Code");
        IssuePage.RunModal();
    end;

    var
        Issues: Record "WLF Pool Review Issue";
        Reader: Codeunit "WLF Pool Review Read";
        SeasonFilter: Text[100];
        WeekFilter: Text[100];
        PoolTypeFilter: Option "All pool types",Internal,External,"Contract Pack";
        FocusBucket: Integer;
        FocusText: Text;
        ScopeCount: Integer;
        UncheckedCount: Integer;
        MismatchCount: Integer;
        ReviewCount: Integer;
        UnableCount: Integer;
        NoExceptionCount: Integer;
        LatestScan: DateTime;
        SummaryText: Text;
        RowStatus: Text;
        PoolCountText: Text;
        ErrorCountText: Text;
        WarningCountText: Text;
        MovementKgText: Text;
        AllLedgerKgText: Text;
        CoverageText: Text;
        ReviewStyle: Text;
        UpdatingOverview: Boolean;
        ShowCoverage: Boolean;
        SummaryLbl: Label '%1 groups in scope. %2 completed checks; %3 not checked; %4 unable to check. Cards count groups, not findings.';
        CompactSnapshotLbl: Label 'Session results only. Recheck after posting. A clear check is not approval to pay or close.';
        KgBasisLbl: Label 'Movement = signed TR + TRA + TRD. All ledger = every transaction type. Both retain recorded reversal signs.';
        SnapshotNotesLbl: Label 'A completed check means the listed reads finished, not that a pool is fully reconciled. Review mismatches, warnings and coverage notes. Results use your visible records in the current company and are not an atomic snapshot. Refresh after source changes. Closing this page or reloading groups clears all session findings.';
        SelectGroupErr: Label 'No pool group is selected. Adjust the scope or status-card focus, or reload the groups.';
        ScanFirstErr: Label 'Run checks for this pool group first. No review result exists in this session.';
        BatchLimitErr: Label 'This list contains more than 50 groups. Narrow the season, week, pool type or status focus, then choose Check Filtered Groups again.';
        ProgressLbl: Label 'Checking filtered groups\Pool group #1####################\Progress @2@@@@@@@@@@@@@@@@@@@@@@';
        BatchCompleteLbl: Label 'Checked %1 groups. %2 completed the covered reads; %3 could not complete. Review the status cards and findings. These checks do not approve payment or closing.';
}





