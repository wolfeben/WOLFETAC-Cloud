page 59303 "WLF Pooling Workspace"
{
    Caption = 'Pooling Overview';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    AdditionalSearchTerms = 'pooling dashboard,pool checks,pool errors,pooling workspace,The Avocado Collective';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            usercontrol(Workspace; "WLF Pool Review Workspace UI")
            {
                ApplicationArea = All;
                trigger Ready()
                begin
                    if not Initialized then begin
                        Initialized := true;
                        ReloadGroups();
                    end;
                    SendState();
                end;

                trigger ActionRequested(ActionName: Text; Payload: Text)
                begin
                    Feedback := '';
                    HasError := false;
                    ClearLastError();
                    if not TryDispatch(ActionName, Payload) then begin
                        Feedback := 'The action could not complete. ' + GetLastErrorText();
                        HasError := true;
                    end;
                    // Even malformed or failed actions release the client's busy state.
                    SendState();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        PoolTypeScope := -1;
        FocusBucket := -1;
        if not TryReadEnvironment() then
            EnvironmentName := '';
    end;

    [TryFunction]
    local procedure TryReadEnvironment()
    var
        EnvironmentInfo: Codeunit "Environment Information";
    begin
        EnvironmentName := EnvironmentInfo.GetEnvironmentName();
    end;

    [TryFunction]
    local procedure TryDispatch(ActionName: Text; PayloadText: Text)
    var
        Payload: JsonObject;
        GroupID: Integer;
    begin
        if not Initialized then
            Error('The pooling workspace has not finished loading.');
        if StrLen(PayloadText) > 4096 then
            Error('The action payload is too large.');
        if not Payload.ReadFrom(PayloadText) then
            Error('The action payload must be a JSON object.');
        case ActionName of
            'scope':
                ChangeScope(Payload);
            'select':
                begin
                    RequireKeys(Payload, 'groupId');
                    GroupID := IntegerValue(Payload, 'groupId');
                    RequireVisibleGroup(GroupID);
                    SelectedID := GroupID;
                end;
            'check':
                begin
                    RequireKeys(Payload, 'groupId');
                    GroupID := IntegerValue(Payload, 'groupId');
                    RequireVisibleGroup(GroupID);
                    SelectedID := GroupID;
                    if CheckGroup(GroupID) then
                        Feedback := 'Check finished. Review the findings and coverage limits; this does not approve payment or closing.'
                    else begin
                        Feedback := 'The check could not complete. Use the Unable to check card to locate the group and read the reason.';
                        HasError := true;
                    end;
                    EnsureSelection();
                end;
            'batch':
                begin
                    RequireKeys(Payload, '');
                    CheckFocusedGroups();
                end;
            'reload':
                begin
                    RequireKeys(Payload, '');
                    ReloadGroups();
                end;
            'source':
                OpenIssueSource(Payload);
            'groupSource':
                begin
                    RequireKeys(Payload, 'groupId');
                    GroupID := IntegerValue(Payload, 'groupId');
                    RequireVisibleGroup(GroupID);
                    Groups.Get(GroupID);
                    if not IsSupportedSource(Groups."Source Record ID") then
                        Error('No supported source record is linked to this group.');
                    Reader.ShowEvidence(Groups."Source Record ID");
                    Feedback := 'Source evidence reflects the values read when it was opened. Run checks again after source changes.';
                end;
            'payments':
                begin
                    RequireKeys(Payload, 'groupId');
                    GroupID := IntegerValue(Payload, 'groupId');
                    RequireVisibleGroup(GroupID);
                    if GroupID <> SelectedID then
                        Error('Select this group before loading its payments.');
                    LoadPaymentHistory();
                end;
            'paymentSource':
                begin
                    RequireKeys(Payload, 'paymentId');
                    RequireVisibleGroup(SelectedID);
                    RequireLoadedPayment(IntegerValue(Payload, 'paymentId'));
                    Reader.ShowPaymentEvidence(SelectedID, IntegerValue(Payload, 'paymentId'));
                    Feedback := 'Payment header evidence opened. Completion of a run does not confirm bank settlement.';
                end;
            'report':
                begin
                    RequireKeys(Payload, 'kind');
                    ExportReview(TextValue(Payload, 'kind'));
                end;
            'paymentExport':
                begin
                    RequireKeys(Payload, '');
                    RequireVisibleGroup(SelectedID);
                    if PaymentGroupID <> SelectedID then
                        Error('Load the selected group payment history first.');
                    Groups.Get(SelectedID);
                    Exporter.DownloadPayments(Payments, EnvironmentName, Groups."Group Code");
                    Feedback := 'Payment header download prepared from the loaded history; this does not confirm paid balances.';
                end;
            'standard':
                begin
                    RequireKeys(Payload, '');
                    Page.RunModal(Page::"WLF Pooling Review");
                    Feedback := 'The standard review list uses separate session results. This overview still shows its own snapshots.';
                end;
            else
                Error('This pooling action is not supported.');
        end;
    end;

    local procedure ExportReview(Kind: Text)
    var
        Rows: Record "WLF Pool Review Group";
        ScopeDescription: Text;
    begin
        if LoadFailure <> '' then
            Error('Reload the groups successfully before exporting review results.');
        ScopedRows(Rows, true);
        if Rows.IsEmpty() then
            Error('No groups match these report filters.');
        ScopeDescription := 'Season: ' + SeasonScope + '; week: ' + WeekScope + '; pool type: ';
        case PoolTypeScope of
            0: ScopeDescription += 'Internal';
            1: ScopeDescription += 'External';
            2: ScopeDescription += 'Contract Pack';
            else ScopeDescription += 'All';
        end;
        if FocusBucket >= 0 then
            ScopeDescription += '; check status: ' + BucketCaption(FocusBucket)
        else
            ScopeDescription += '; check status: All';
        ScopeDescription += '. Blank season/week means all. Includes every matching group, beyond the 200 displayed row limit.';
        Exporter.DownloadReview(Rows, Issues, Kind, EnvironmentName, ScopeDescription);
        Feedback := 'Report download prepared from existing session checks. Unchecked or incomplete groups are identified in the report; no new scan was run.';
    end;

    local procedure LoadPaymentHistory()
    var
        EmptyRows: JsonArray;
    begin
        Clear(Payments);
        PaymentGroupID := SelectedID;
        ClearLastError();
        if not TryLoadPaymentHistory() then begin
            Clear(Payments);
            Feedback := 'Payment history could not be loaded. ' + GetLastErrorText();
            HasError := true;
            Payments.Add('groupId', SelectedID);
            Payments.Add('loaded', false);
            Payments.Add('rows', EmptyRows);
            Payments.Add('total', 0);
            Payments.Add('hasMore', false);
            Payments.Add('loadedAt', '');
            Payments.Add('error', Feedback);
        end else
            Feedback := 'Payment run headers loaded. Recorded invoice references and completion markers are not a reconciliation of paid amounts.';
    end;

    [TryFunction]
    local procedure TryLoadPaymentHistory()
    begin
        Payments := Reader.PaymentHistory(SelectedID);
    end;

    local procedure RequireLoadedPayment(PaymentID: Integer)
    var
        RowsToken: JsonToken;
        RowToken: JsonToken;
        IdToken: JsonToken;
    begin
        if (PaymentGroupID = SelectedID) and Payments.Get('rows', RowsToken) then
            foreach RowToken in RowsToken.AsArray() do begin
                RowToken.AsObject().Get('id', IdToken);
                if IdToken.AsValue().AsInteger() = PaymentID then
                    exit;
            end;
        Error('Choose a payment from the currently loaded payment history.');
    end;

    local procedure ChangeScope(Payload: JsonObject)
    var
        NewSeason: Text;
        NewWeek: Text;
        NewType: Integer;
        NewFocus: Integer;
    begin
        RequireKeys(Payload, 'season,week,type,focus');
        NewSeason := TextValue(Payload, 'season');
        NewWeek := TextValue(Payload, 'week');
        NewType := IntegerValue(Payload, 'type');
        NewFocus := IntegerValue(Payload, 'focus');
        if (StrLen(NewSeason) > 20) or (StrLen(NewWeek) > 20) then
            Error('Season and week codes cannot exceed 20 characters.');
        if (NewType < -1) or (NewType > 2) then
            Error('Choose all pool types, Internal, External or Contract Pack.');
        if (NewFocus < -1) or (NewFocus > 4) then
            Error('Choose a supported review status.');
        // Validate the complete payload before changing any filter.
        SeasonScope := NewSeason;
        WeekScope := NewWeek;
        PoolTypeScope := NewType;
        FocusBucket := NewFocus;
        EnsureSelection();
    end;

    local procedure ReloadGroups()
    begin
        Clear(Payments);
        PaymentGroupID := 0;
        Groups.Reset();
        Groups.DeleteAll();
        Issues.Reset();
        Issues.DeleteAll();
        SelectedID := 0;
        FocusBucket := -1;
        ClearLastError();
        if not TryLoadGroups() then begin
            LoadFailure := 'Unable to load pool groups. ' + GetLastErrorText();
            Feedback := LoadFailure;
            HasError := true;
            // A failed source read must never leave a plausible partial overview.
            Groups.Reset();
            Groups.DeleteAll();
            Issues.Reset();
            Issues.DeleteAll();
            exit;
        end;
        LoadFailure := '';
        HasError := false;
        Feedback := 'Group headers loaded. Run checks for a group or the focused list. Results remain in this session only.';
        EnsureSelection();
    end;

    [TryFunction]
    local procedure TryLoadGroups()
    begin
        Reader.LoadGroups(Groups);
    end;

    local procedure ScopedRows(var Rows: Record "WLF Pool Review Group"; IncludeFocus: Boolean)
    begin
        Rows.Copy(Groups, true);
        Rows.Reset();
        if SeasonScope <> '' then
            Rows.SetRange(Season, SeasonScope);
        if WeekScope <> '' then
            Rows.SetRange("Week Code", WeekScope);
        if PoolTypeScope >= 0 then
            Rows.SetRange("Pool Type", PoolTypeScope);
        if IncludeFocus and (FocusBucket >= 0) then
            Rows.SetRange("Review Bucket", FocusBucket);
    end;

    local procedure RequireVisibleGroup(GroupID: Integer)
    var
        Rows: Record "WLF Pool Review Group";
        RowNo: Integer;
    begin
        ScopedRows(Rows, true);
        if Rows.FindSet() then
            repeat
                RowNo += 1;
                if RowNo > 200 then
                    break;
                if (GroupID <> 0) and (Rows."Group ID" = GroupID) then
                    exit;
            until Rows.Next() = 0;
        Error('Choose a group from the currently displayed list. Narrow the filters if more than 200 groups match.');
    end;

    local procedure EnsureSelection()
    var
        Rows: Record "WLF Pool Review Group";
        FirstID: Integer;
        RowNo: Integer;
    begin
        ScopedRows(Rows, true);
        if Rows.FindSet() then
            repeat
                RowNo += 1;
                if RowNo > 200 then
                    break;
                if RowNo = 1 then
                    FirstID := Rows."Group ID";
                if (SelectedID <> 0) and (Rows."Group ID" = SelectedID) then
                    exit;
            until Rows.Next() = 0;
        SelectedID := FirstID;
    end;

    local procedure CheckGroup(GroupID: Integer): Boolean
    var
        Group: Record "WLF Pool Review Group";
        BeforeCheck: Record "WLF Pool Review Group";
        Failure: Text;
    begin
        Group.Copy(Groups, true);
        Group.Reset();
        Group.Get(GroupID);
        BeforeCheck := Group;
        ClearLastError();
        if not TryCheckGroup(Group) then begin
            Failure := GetLastErrorText();
            // Only temporary records are changed. Discard all partial findings for this group.
            Group := BeforeCheck;
            ClearFailedResults(Group, Failure);
        end;
        exit(Group."Scan Complete");
    end;

    [TryFunction]
    local procedure TryCheckGroup(var Group: Record "WLF Pool Review Group")
    begin
        Reader.RunChecks(Group, Issues);
        Group."Review Bucket" := GetBucket(Group);
        Group.Modify();
    end;

    local procedure ClearFailedResults(var Group: Record "WLF Pool Review Group"; Failure: Text)
    var
        NextIssue: Integer;
    begin
        Issues.Reset();
        Issues.SetRange("Group ID", Group."Group ID");
        Issues.DeleteAll();
        Issues.Reset();
        if Issues.FindLast() then
            NextIssue := Issues."Issue No.";
        Group."Pool Count" := 0;
        Group."Ledger Count" := 0;
        Group."Invoice Candidates" := 0;
        Group."Attributed Invoices" := 0;
        Group."Unresolved Sources" := 0;
        Group."Error Count" := 0;
        Group."Warning Count" := 1;
        Group."Information Count" := 0;
        Group."Movement Kg" := 0;
        Group."All Ledger Kg" := 0;
        Group."Ledger Net" := 0;
        Group."Payment Count" := 0;
        Group."Scan Complete" := false;
        Group."Scanned At" := CurrentDateTime();
        Group."Review Bucket" := 3;
        Group."Review Status" := 'Unable to complete';
        Group."Review Detail" := CopyStr(Failure, 1, MaxStrLen(Group."Review Detail"));
        Group.Modify();
        Issues.Init();
        Issues."Issue No." := NextIssue + 1;
        Issues."Group ID" := Group."Group ID";
        Issues."Rule ID" := 'UI-SCAN-FAILED';
        Issues.Severity := "WLF Pool Review Severity"::Warning;
        Issues.Summary := 'Check could not complete; partial findings discarded';
        Issues.Details := CopyStr(Failure, 1, MaxStrLen(Issues.Details));
        Issues."Scanned At" := Group."Scanned At";
        Issues.Insert();
    end;

    local procedure CheckFocusedGroups()
    var
        Rows: Record "WLF Pool Review Group";
        GroupIDs: List of [Integer];
        GroupID: Integer;
        CompleteCount: Integer;
    begin
        ScopedRows(Rows, true);
        if Rows.Count() > 50 then
            Error('More than 50 groups match this list. Narrow the season, week, type or status before checking the list.');
        if Rows.FindSet() then
            repeat
                GroupIDs.Add(Rows."Group ID");
            until Rows.Next() = 0;
        if GroupIDs.Count() = 0 then
            Error('No groups match the focused list.');
        // Freeze the complete bounded ID list before scans change status buckets or metadata.
        foreach GroupID in GroupIDs do
            if CheckGroup(GroupID) then
                CompleteCount += 1;
        EnsureSelection();
        Feedback := StrSubstNo('Checked %1 groups: %2 completed the covered reads; %3 could not complete. Review all findings and coverage limits.', GroupIDs.Count(), CompleteCount, GroupIDs.Count() - CompleteCount);
        HasError := CompleteCount <> GroupIDs.Count();
    end;

    local procedure OpenIssueSource(Payload: JsonObject)
    var
        Issue: Record "WLF Pool Review Issue";
        IssueID: Integer;
        Related: Boolean;
        SourceID: RecordId;
    begin
        RequireKeys(Payload, 'issueId,related');
        IssueID := IntegerValue(Payload, 'issueId');
        Related := BooleanValue(Payload, 'related');
        RequireVisibleGroup(SelectedID);
        Issue.Copy(Issues, true);
        Issue.Reset();
        Issue.SetRange("Group ID", SelectedID);
        Issue.SetRange("Issue No.", IssueID);
        if not Issue.FindFirst() then
            Error('Choose a finding from the currently selected group.');
        if Related then
            SourceID := Issue."Related Record ID"
        else
            SourceID := Issue."Evidence Record ID";
        if not IsSupportedSource(SourceID) then
            Error('No supported source record is linked to this finding.');
        // Never accept a RecordId, table number or source key from the browser.
        Reader.ShowEvidence(SourceID);
        Feedback := 'Source evidence reflects the values read when it was opened. Run checks again after source changes.';
    end;

    local procedure IsSupportedSource(SourceID: RecordId): Boolean
    begin
        exit(SourceID.TableNo() in [50230, 50220, 50208, 50209, 50233, 50239, 50206, 113]);
    end;

    local procedure RequireKeys(Payload: JsonObject; AllowedCSV: Text)
    var
        PropertyName: Text;
        Keys: List of [Text];
        Expected: List of [Text];
    begin
        Keys := Payload.Keys();
        if AllowedCSV <> '' then
            Expected := AllowedCSV.Split(',');
        if Keys.Count() <> Expected.Count() then
            Error('The action payload has missing or unexpected properties.');
        foreach PropertyName in Keys do
            if not Expected.Contains(PropertyName) then
                Error('The action payload has an unsupported property.');
    end;

    local procedure ValueToken(Payload: JsonObject; PropertyName: Text): JsonToken
    var
        Token: JsonToken;
    begin
        if not Payload.Get(PropertyName, Token) then
            Error('The action is missing %1.', PropertyName);
        if not Token.IsValue() then
            Error('The action property %1 must be a scalar value.', PropertyName);
        if Token.AsValue().IsNull() then
            Error('The action property %1 cannot be null.', PropertyName);
        exit(Token);
    end;

    local procedure TextValue(Payload: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Token := ValueToken(Payload, PropertyName);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            Error('The action property %1 must be text.', PropertyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure IntegerValue(Payload: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Token := ValueToken(Payload, PropertyName);
        Token.WriteTo(Serialized);
        if (Serialized = '') or (DelChr(Serialized, '=', '-0123456789') <> '') then
            Error('The action property %1 must be a whole number.', PropertyName);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure BooleanValue(Payload: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Token := ValueToken(Payload, PropertyName);
        Token.WriteTo(Serialized);
        if not (Serialized in ['true', 'false']) then
            Error('The action property %1 must be true or false.', PropertyName);
        exit(Token.AsValue().AsBoolean());
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

    local procedure DateTimeText(Value: DateTime): Text
    begin
        if Value = 0DT then
            exit('');
        exit(Format(Value));
    end;

    local procedure SendState()
    var
        StateJson: Text;
        Failure: Text;
        Fallback: JsonObject;
        EmptyRows: JsonArray;
        Scope: JsonObject;
        Summary: JsonObject;
        Options: JsonObject;
    begin
        if PaymentGroupID <> SelectedID then begin
            Clear(Payments);
            PaymentGroupID := 0;
        end;
        ClearLastError();
        if not TryBuildState(StateJson) then begin
            Failure := 'Unable to display pooling results. ' + GetLastErrorText();
            Scope.Add('season', SeasonScope);
            Scope.Add('week', WeekScope);
            Scope.Add('type', PoolTypeScope);
            Scope.Add('focus', FocusBucket);
            Summary.Add('all', 0);
            Summary.Add('unchecked', 0);
            Summary.Add('mismatches', 0);
            Summary.Add('review', 0);
            Summary.Add('unable', 0);
            Summary.Add('clear', 0);
            Summary.Add('latestScanText', '');
            Options.Add('seasons', EmptyRows);
            Options.Add('weeks', EmptyRows);
            Fallback.Add('version', '0.4.0.1');
            Fallback.Add('company', CompanyName());
            Fallback.Add('environment', EnvironmentName);
            Fallback.Add('scope', Scope);
            Fallback.Add('summary', Summary);
            Fallback.Add('options', Options);
            Fallback.Add('groups', EmptyRows);
            Fallback.Add('issues', EmptyRows);
            Fallback.Add('selectedId', 0);
            Fallback.Add('shown', 0);
            Fallback.Add('total', 0);
            Fallback.Add('hasMore', false);
            Fallback.Add('coverage', 'The overview could not be displayed. No review conclusion is available; reload the groups.');
            Fallback.Add('message', Failure);
            Fallback.Add('error', true);
            Fallback.WriteTo(StateJson);
        end;
        CurrPage.Workspace.SetState(StateJson);
    end;

    [TryFunction]
    local procedure TryBuildState(var StateJson: Text)
    var
        State: JsonObject;
        Scope: JsonObject;
        Summary: JsonObject;
        GroupArray: JsonArray;
        IssueArray: JsonArray;
        Rows: Record "WLF Pool Review Group";
        IssueRows: Record "WLF Pool Review Issue";
        BucketCounts: array[5] of Integer;
        AllCount: Integer;
        Total: Integer;
        Shown: Integer;
        IssueTotal: Integer;
        IssueShown: Integer;
        LatestScan: DateTime;
    begin
        State.Add('version', '0.4.0.1');
        State.Add('company', CompanyName());
        State.Add('environment', EnvironmentName);
        Scope.Add('season', SeasonScope);
        Scope.Add('week', WeekScope);
        Scope.Add('type', PoolTypeScope);
        Scope.Add('focus', FocusBucket);
        State.Add('scope', Scope);
        State.Add('options', BuildOptions());
        ScopedRows(Rows, false);
        if Rows.FindSet() then
            repeat
                AllCount += 1;
                BucketCounts[GetBucket(Rows) + 1] += 1;
                if Rows."Scanned At" > LatestScan then
                    LatestScan := Rows."Scanned At";
            until Rows.Next() = 0;
        Summary.Add('all', AllCount);
        Summary.Add('unchecked', BucketCounts[1]);
        Summary.Add('mismatches', BucketCounts[2]);
        Summary.Add('review', BucketCounts[3]);
        Summary.Add('unable', BucketCounts[4]);
        Summary.Add('clear', BucketCounts[5]);
        Summary.Add('latestScanText', DateTimeText(LatestScan));
        State.Add('summary', Summary);
        ScopedRows(Rows, true);
        Total := Rows.Count();
        if Rows.FindSet() then
            repeat
                if Shown >= 200 then
                    break;
                GroupArray.Add(GroupJson(Rows));
                Shown += 1;
            until Rows.Next() = 0;
        if SelectedID <> 0 then begin
            IssueRows.Copy(Issues, true);
            IssueRows.Reset();
            IssueRows.SetRange("Group ID", SelectedID);
            IssueRows.SetCurrentKey("Group ID", Severity);
            IssueRows.Ascending(false);
            IssueTotal := IssueRows.Count();
            if IssueRows.FindSet() then
                repeat
                    if IssueShown >= 500 then
                        break;
                    IssueArray.Add(IssueJson(IssueRows));
                    IssueShown += 1;
                until IssueRows.Next() = 0;
        end;
        State.Add('groups', GroupArray);
        State.Add('issues', IssueArray);
        State.Add('payments', Payments);
        State.Add('selectedId', SelectedID);
        State.Add('shown', Shown);
        State.Add('total', Total);
        State.Add('hasMore', Total > Shown);
        State.Add('issueTotal', IssueTotal);
        State.Add('issueHasMore', IssueTotal > IssueShown);
        State.Add('coverage', Reader.CoverageNotes());
        if LoadFailure <> '' then
            State.Add('message', LoadFailure)
        else
            State.Add('message', Feedback);
        State.Add('error', HasError or (LoadFailure <> ''));
        State.WriteTo(StateJson);
    end;

    local procedure BuildOptions(): JsonObject
    var
        Options: JsonObject;
        Week: JsonObject;
        Seasons: JsonArray;
        Weeks: JsonArray;
        SeenSeasons: List of [Text];
        SeenWeeks: List of [Text];
        Rows: Record "WLF Pool Review Group";
    begin
        Rows.Copy(Groups, true);
        Rows.Reset();
        if Rows.FindSet() then
            repeat
                if (Rows.Season <> '') and not SeenSeasons.Contains(Rows.Season) then begin
                    SeenSeasons.Add(Rows.Season);
                    Seasons.Add(Rows.Season);
                end;
                if (Rows."Week Code" <> '') and not SeenWeeks.Contains(Rows."Week Code") then begin
                    SeenWeeks.Add(Rows."Week Code");
                    Clear(Week);
                    Week.Add('code', Rows."Week Code");
                    Week.Add('season', Rows.Season);
                    Week.Add('number', Rows."Week No.");
                    Weeks.Add(Week);
                end;
            until Rows.Next() = 0;
        Options.Add('seasons', Seasons);
        Options.Add('weeks', Weeks);
        exit(Options);
    end;

    local procedure GroupJson(Group: Record "WLF Pool Review Group"): JsonObject
    var
        Result: JsonObject;
    begin
        Result.Add('id', Group."Group ID");
        Result.Add('code', Group."Group Code");
        Result.Add('season', Group.Season);
        Result.Add('week', Group."Week Code");
        Result.Add('typeCaption', Group."Pool Type Caption");
        Result.Add('businessStatus', Group."Business Status");
        Result.Add('bucket', GetBucket(Group));
        Result.Add('status', BucketCaption(GetBucket(Group)));
        Result.Add('scanComplete', Group."Scan Complete" and (Group."Scanned At" <> 0DT));
        Result.Add('poolCount', Group."Pool Count");
        Result.Add('movementKg', Group."Movement Kg");
        Result.Add('allKg', Group."All Ledger Kg");
        Result.Add('ledgerNet', Group."Ledger Net");
        Result.Add('mismatchCount', Group."Error Count");
        Result.Add('warningCount', Group."Warning Count");
        Result.Add('unresolvedCount', Group."Unresolved Sources");
        Result.Add('lastScanText', DateTimeText(Group."Scanned At"));
        Result.Add('detail', Group."Review Detail");
        Result.Add('invoiceCandidates', Group."Invoice Candidates");
        Result.Add('attributedInvoices', Group."Attributed Invoices");
        Result.Add('ledgerCount', Group."Ledger Count");
        Result.Add('paymentCount', Group."Payment Count");
        exit(Result);
    end;

    local procedure IssueJson(Issue: Record "WLF Pool Review Issue"): JsonObject
    var
        Result: JsonObject;
    begin
        Result.Add('id', Issue."Issue No.");
        Result.Add('groupId', Issue."Group ID");
        Result.Add('rule', Issue."Rule ID");
        Result.Add('severity', Issue.Severity.AsInteger());
        Result.Add('summary', Issue.Summary);
        Result.Add('details', Issue.Details);
        Result.Add('pool', Issue."Pool Code");
        Result.Add('grower', Issue."Grower Code");
        Result.Add('document', Issue."Document No.");
        Result.Add('line', Issue."Source Line No.");
        Result.Add('payment', Issue."Payment ID");
        Result.Add('expected', Issue.Expected);
        Result.Add('actual', Issue.Actual);
        Result.Add('measure', Issue.Measure);
        Result.Add('canSource', IsSupportedSource(Issue."Evidence Record ID"));
        Result.Add('canRelated', IsSupportedSource(Issue."Related Record ID"));
        exit(Result);
    end;

    var
        Groups: Record "WLF Pool Review Group";
        Issues: Record "WLF Pool Review Issue";
        Reader: Codeunit "WLF Pool Review Read";
        Exporter: Codeunit "WLF Pool Review Export";
        SeasonScope: Text[20];
        WeekScope: Text[20];
        PoolTypeScope: Integer;
        FocusBucket: Integer;
        SelectedID: Integer;
        EnvironmentName: Text;
        Feedback: Text;
        LoadFailure: Text;
        HasError: Boolean;
        Initialized: Boolean;
        Payments: JsonObject;
        PaymentGroupID: Integer;
}



