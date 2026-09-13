codeunit 59300 "WLF Pool Review Read"
{
    procedure LoadGroups(var Groups: Record "WLF Pool Review Group")
    var
        R: RecordRef;
    begin
        Groups.Reset();
        Groups.DeleteAll();
        OpenSource(R, 50230);
        if R.FindSet(false) then
            repeat
                if Groups.Count >= 5000 then
                    Error('There are more than 5,000 visible groups. A filtered group selector is required; this list has not been truncated.');
                Groups.Init();
                ReadGroup(R, Groups);
                Groups."Review Status" := 'Not checked';
                Groups."Review Detail" := 'Select a group and run checks. Results cover the stated checks only.';
                Groups.Insert();
            until R.Next() = 0;
        R.Close();
        Groups.Reset();
    end;

    procedure RunChecks(var Group: Record "WLF Pool Review Group"; var Issues: Record "WLF Pool Review Issue")
    var
        Facts: Record "WLF Pool Review Fact";
        EmptyFact: Record "WLF Pool Review Fact";
        Rules: Codeunit "WLF Pool Review Rules";
        Failure: Text;
    begin
        ClearGroupResults(Group, Issues);
        Group."Scanned At" := CurrentDateTime();
        ClearLastError();
        if not TryCollect(Group, Facts) then begin
            Failure := GetLastErrorText();
            ClearGroupResults(Group, Issues);
            Group."Scanned At" := CurrentDateTime();
            Group."Review Status" := 'Unable to complete';
            Group."Review Detail" := CopyStr(Failure, 1, MaxStrLen(Group."Review Detail"));
            Rules.AddIssue(Group, Issues, 'SCAN-FAILED', "WLF Pool Review Severity"::Warning,
                'Scan could not complete; partial results discarded', Failure, EmptyFact, 0, 0, '');
            exit;
        end;
        Rules.Evaluate(Group, Facts, Issues);
        Group."Scan Complete" := true;
        if Group."Unresolved Sources" > 0 then
            Group."Review Status" := 'Checks have unresolved sources'
        else
            if Group."Error Count" + Group."Warning Count" > 0 then
                Group."Review Status" := 'Review exceptions'
            else
                Group."Review Status" := 'No exception in checked scope';
        Group."Review Detail" := 'Limited snapshot of visible records. Source data may change during or after reading. This is not approval to close or pay.';
    end;

    local procedure ClearGroupResults(var Group: Record "WLF Pool Review Group"; var Issues: Record "WLF Pool Review Issue")
    begin
        Issues.Reset();
        Issues.SetRange("Group ID", Group."Group ID");
        Issues.DeleteAll();
        Issues.Reset();
        Group."Pool Count" := 0;
        Group."Ledger Count" := 0;
        Group."Invoice Candidates" := 0;
        Group."Attributed Invoices" := 0;
        Group."Unresolved Sources" := 0;
        Group."Error Count" := 0;
        Group."Warning Count" := 0;
        Group."Information Count" := 0;
        Group."Movement Kg" := 0;
        Group."All Ledger Kg" := 0;
        Group."Ledger Net" := 0;
        Group."Payment Count" := 0;
        Group."Scan Complete" := false;
    end;

    [TryFunction]
    local procedure TryCollect(var Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact")
    var
        R: RecordRef;
        SelectedID: Integer;
    begin
        Clear(SeenLedger);
        Clear(NextFact);
        Facts.Reset();
        Facts.DeleteAll();
        SelectedID := Group."Group ID";
        OpenSource(R, 50230);
        Filter(R, 1, SelectedID);
        if not R.FindFirst() then
            Error('The selected pool group is no longer visible.');
        ReadGroup(R, Group);
        R.Close();
        if (Group.Season = '') or (Group."Week No." = 0) then
            Error('The selected group has no resolvable season and week. Invoice scope cannot be checked.');
        if (Group."Pool Type" < 0) or (Group."Pool Type" > 2) then
            Error('The selected group uses an unsupported pool type.');
        ReadSetup();
        ReadPools(Group, Facts);
        ReadLedger(Group, Facts);
        ReadPayments(Group, Facts);
        ReadInvoices(Group, Facts);
        ReadMatchedInvoiceLedger(Facts);
    end;

    local procedure ReadGroup(var R: RecordRef; var Group: Record "WLF Pool Review Group")
    var
        WeekRef: RecordRef;
    begin
        Group."Group ID" := IntValue(R, 1);
        Group."Group Code" := CopyStr(TextValue(R, 2), 1, 20);
        Group."Week Code" := CopyStr(TextValue(R, 3), 1, 20);
        Group."Pool Type" := IntValue(R, 4);
        Group."Pool Type Caption" := CopyStr(Format(R.Field(4)), 1, 30);
        Group."Business Status" := CopyStr(Format(R.Field(5)), 1, 30);
        Group."Status Ordinal" := IntValue(R, 5);
        Group."Provisional Count" := IntValue(R, 6);
        Group."Source Record ID" := R.RecordId();
        Group.Season := '';
        Group."Week No." := 0;
        OpenSource(WeekRef, 50220);
        Filter(WeekRef, 1, Group."Week Code");
        if WeekRef.FindFirst() then begin
            Group.Season := CopyStr(TextValue(WeekRef, 3), 1, 20);
            Group."Week No." := IntValue(WeekRef, 4);
        end;
        WeekRef.Close();
    end;

    local procedure ReadSetup()
    var
        R: RecordRef;
    begin
        OpenSource(R, 50225);
        Filter(R, 1, '');
        if not R.FindFirst() then
            Error('TAC Pool Setup with the blank primary key is unavailable.');
        VarietyDim := CopyStr(TextValue(R, 32), 1, 20);
        GradeDim := CopyStr(TextValue(R, 33), 1, 20);
        SizeDim := CopyStr(TextValue(R, 34), 1, 20);
        TypeDim := CopyStr(TextValue(R, 35), 1, 20);
        GrowerDim := CopyStr(TextValue(R, 15), 1, 20);
        PackDim := CopyStr(TextValue(R, 36), 1, 20);
        PackCategoryDim := CopyStr(TextValue(R, 37), 1, 20);
        R.Close();
        if (VarietyDim = '') or (GradeDim = '') or (SizeDim = '') or (TypeDim = '') then
            Error('Pool setup requires variety, grade, size and pool-type dimension codes before these checks can complete.');
    end;

    local procedure ReadPools(Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact")
    var
        R: RecordRef;
    begin
        OpenSource(R, 50208);
        Filter(R, 16, Group."Group ID");
        CheckBound(R);
        if R.FindSet(false) then
            repeat
                NewFact(Facts, "WLF Pool Review Kind"::Pool, R);
                Facts."Pool Code" := CopyStr(TextValue(R, 1), 1, 20);
                Facts."Group ID" := IntValue(R, 16);
                Facts."Owner Group ID" := Facts."Group ID";
                Facts."Actual Classification" := CopyStr(PoolClassification(R), 1, 100);
                Facts.Insert();
            until R.Next() = 0;
        R.Close();
    end;

    local procedure ReadLedger(Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact")
    var
        R: RecordRef;
        Pools: Record "WLF Pool Review Fact";
    begin
        OpenSource(R, 50209);
        Filter(R, 25, Group."Group ID");
        CollectLedger(R, Facts, 0);
        R.Close();
        Pools.Copy(Facts, true);
        Pools.SetRange(Kind, "WLF Pool Review Kind"::Pool);
        if Pools.FindSet() then
            repeat
                OpenSource(R, 50209);
                Filter(R, 2, Pools."Pool Code");
                CollectLedger(R, Facts, 0);
                R.Close();
            until Pools.Next() = 0;
    end;

    local procedure CollectLedger(var R: RecordRef; var Facts: Record "WLF Pool Review Fact"; InvoiceGroupID: Integer)
    var
        EntryID: Integer;
        P: RecordRef;
    begin
        CheckBound(R);
        if R.FindSet(false) then
            repeat
                EntryID := IntValue(R, 1);
                if not SeenLedger.ContainsKey(EntryID) then begin
                    NewFact(Facts, "WLF Pool Review Kind"::Ledger, R);
                    SeenLedger.Add(EntryID, Facts."Fact No.");
                    Facts."Group ID" := IntValue(R, 25);
                    Facts."Pool Code" := CopyStr(TextValue(R, 2), 1, 20);
                    Facts."Document No." := CopyStr(TextValue(R, 34), 1, 20);
                    Facts."Source Line No." := IntValue(R, 38);
                    Facts."Grower Code" := CopyStr(TextValue(R, 26), 1, 20);
                    Facts."Trans Type" := CopyStr(TextValue(R, 27), 1, 10);
                    Facts.Kg := DecimalValue(R, 12);
                    Facts.Amount := DecimalValue(R, 13);
                    Facts.Reversed := BoolValue(R, 20);
                    Facts."Posted to GL" := BoolValue(R, 39);
                    Facts."Payment ID" := IntValue(R, 35);
                    Facts."Dimension Set ID" := IntValue(R, 23);
                    Facts."Expected Classification" := CopyStr(DimensionClassification(Facts."Dimension Set ID"), 1, 100);
                    if Facts."Pool Code" <> '' then begin
                        OpenSource(P, 50208);
                        Filter(P, 1, Facts."Pool Code");
                        if P.FindFirst() then begin
                            Facts."Owner Group ID" := IntValue(P, 16);
                            Facts."Related Record ID" := P.RecordId();
                            Facts."Actual Classification" := CopyStr(PoolClassification(P), 1, 100);
                        end;
                        P.Close();
                    end;
                    Facts.Insert();
                end;
                if InvoiceGroupID <> 0 then begin
                    Facts.Get(SeenLedger.Get(EntryID));
                    Facts."Invoice Group ID" := InvoiceGroupID;
                    Facts.Modify();
                end;
            until R.Next() = 0;
    end;

    local procedure ReadPayments(Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact")
    var
        R: RecordRef;
    begin
        OpenSource(R, 50233);
        Filter(R, 2, Group."Group ID");
        CheckBound(R);
        if R.FindSet(false) then
            repeat
                NewFact(Facts, "WLF Pool Review Kind"::Payment, R);
                Facts."Group ID" := IntValue(R, 2);
                Facts."Payment ID" := IntValue(R, 1);
                Facts."Pool Code" := CopyStr(TextValue(R, 11), 1, 20);
                Facts.Reversed := BoolValue(R, 8);
                Facts."Completed At" := DateTimeValue(R, 13);
                Facts."Posted At" := DateTimeValue(R, 5);
                Facts.Description := CopyStr(TextValue(R, 10), 1, 250);
                Facts.Insert();
            until R.Next() = 0;
        R.Close();
    end;

    local procedure ReadInvoices(var Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact")
    var
        R: RecordRef;
        C: RecordRef;
        G: RecordRef;
        Invoice: Record "Sales Invoice Line";
        ItemNo: Code[20];
        TypeValue: Code[20];
        ResolvedType: Integer;
        IsResolved: Boolean;
        DuplicateGroup: Boolean;
        Reason: Text;
    begin
        OpenSource(G, 50220);
        Filter(G, 3, Group.Season);
        Filter(G, 4, Group."Week No.");
        if G.Count() <> 1 then
            Error('The season and week identify multiple visible pool-week records. Invoice scope is ambiguous.');
        G.Close();
        OpenSource(G, 50230);
        Filter(G, 3, Group."Week Code");
        Filter(G, 4, Group."Pool Type");
        DuplicateGroup := G.Count() <> 1;
        G.Close();
        OpenSource(R, Database::"Sales Invoice Line");
        Filter(R, 50244, Group.Season);
        Filter(R, 50241, Group."Week No.");
        Filter(R, Invoice.FieldNo(Type), Invoice.Type::Item);
        CheckBound(R);
        if R.FindSet(false) then
            repeat
                if TextValue(R, 50240) <> '' then begin
                    Group."Invoice Candidates" += 1;
                    R.SetTable(Invoice);
                    ItemNo := CopyStr(TextValue(R, 50242), 1, 20);
                    if ItemNo = '' then
                        ItemNo := Invoice."No.";
                    IsResolved := false;
                    Reason := '';
                    OpenSource(C, 50206);
                    Filter(C, 1, TextValue(R, 50240));
                    Filter(C, 3, ItemNo);
                    Filter(C, 7, Group."Week No.");
                    Filter(C, 8, Group.Season);
                    if C.Count() = 1 then begin
                        C.FindFirst();
                        TypeValue := DimensionValue(IntValue(C, 16), TypeDim);
                        ResolvedType := PoolTypeOrdinal(TypeValue);
                        IsResolved := ResolvedType >= 0;
                        if not IsResolved then
                            Reason := 'The exact consignment line has no supported pool-type dimension (I, E or G).';
                    end else
                        Reason := 'The consignment, item, season and week do not identify exactly one visible consignment line.';
                    if DuplicateGroup then begin
                        IsResolved := false;
                        Reason := 'More than one visible group has this pool week and pool type; invoice attribution is ambiguous.';
                    end;
                    if (not IsResolved) or (ResolvedType = Group."Pool Type") then begin
                        if IsResolved and not InvoiceDimensionsResolved(IntValue(C, 16)) then begin
                            IsResolved := false;
                            Reason := 'The exact consignment line lacks one or more configured dimensions required by invoice pooling; eligibility needs review.';
                        end;
                        NewFact(Facts, "WLF Pool Review Kind"::Invoice, R);
                        Facts."Group ID" := Group."Group ID";
                        Facts."Document No." := Invoice."Document No.";
                        Facts."Source Line No." := Invoice."Line No.";
                        Facts."Attribution Resolved" := IsResolved;
                        Facts.Description := CopyStr(Reason, 1, 250);
                        if IsResolved then begin
                            Facts."Pool Code" := CopyStr(TextValue(C, 12), 1, 20);
                            Facts."Related Record ID" := C.RecordId();
                            Group."Attributed Invoices" += 1;
                        end else
                            Group."Unresolved Sources" += 1;
                        MatchInvoice(Invoice, Facts);
                        Facts.Insert();
                    end;
                    C.Close();
                end;
            until R.Next() = 0;
        R.Close();
    end;

    local procedure MatchInvoice(Invoice: Record "Sales Invoice Line"; var Fact: Record "WLF Pool Review Fact")
    var
        R: RecordRef;
        StateRef: RecordRef;
        Header: Record "Sales Invoice Header";
        EmptyGuid: Guid;
        LegacyCount: Integer;
        ConsignmentID: RecordId;
    begin
        ConsignmentID := Fact."Related Record ID";
        OpenSource(R, 50209);
        Filter(R, 27, 'PR');
        Filter(R, 41, 1);
        Filter(R, 42, Invoice.SystemId);
        Filter(R, 20, false);
        Fact."Matching Entry Count" := R.Count();
        if Fact."Matching Entry Count" = 1 then
            SetInvoiceMatch(R, Fact);
        // Count the disjoint union: exact source GUID plus blank-GUID legacy identity.
        // Never accept a different populated GUID as a match.
        Filter(R, 42, EmptyGuid);
        Filter(R, 34, Invoice."Document No.");
        Filter(R, 38, Invoice."Line No.");
        LegacyCount := R.Count();
        if (Fact."Matching Entry Count" = 0) and (LegacyCount = 1) then
            SetInvoiceMatch(R, Fact);
        Fact."Matching Entry Count" += LegacyCount;
        Fact."Legacy Match" := LegacyCount > 0;
        if Fact."Matching Entry Count" <> 1 then begin
            Fact."Related Record ID" := ConsignmentID;
            Fact."Owner Group ID" := 0;
            Fact."Actual Classification" := '';
        end;
        R.Close();
        if not Header.Get(Invoice."Document No.") then
            Error('Posted invoice %1 has no visible header. Invoice-state coverage cannot be completed.', Invoice."Document No.");
        OpenSource(StateRef, 50239);
        Filter(StateRef, 1, Header.SystemId);
        Fact."Has Invoice State" := StateRef.FindFirst();
        StateRef.Close();
    end;

    local procedure SetInvoiceMatch(var R: RecordRef; var Fact: Record "WLF Pool Review Fact")
    begin
        R.FindFirst();
        Fact."Related Record ID" := R.RecordId();
        Fact."Owner Group ID" := IntValue(R, 25);
        Fact."Actual Classification" := CopyStr(TextValue(R, 2), 1, 100);
    end;

    local procedure ReadMatchedInvoiceLedger(var Facts: Record "WLF Pool Review Fact")
    var
        Invoices: Record "WLF Pool Review Fact";
        R: RecordRef;
        EmptyGuid: Guid;
        InvoiceGroupID: Integer;
    begin
        Invoices.Copy(Facts, true);
        Invoices.SetRange(Kind, "WLF Pool Review Kind"::Invoice);
        Invoices.SetRange("Attribution Resolved", true);
        if Invoices.FindSet() then
            repeat
                InvoiceGroupID := 0;
                if Invoices."Matching Entry Count" > 1 then
                    InvoiceGroupID := Invoices."Group ID";
                OpenSource(R, 50209);
                Filter(R, 27, 'PR');
                Filter(R, 41, 1);
                Filter(R, 42, Invoices."Source System ID");
                Filter(R, 20, false);
                CollectLedger(R, Facts, InvoiceGroupID);
                Filter(R, 42, EmptyGuid);
                Filter(R, 34, Invoices."Document No.");
                Filter(R, 38, Invoices."Source Line No.");
                CollectLedger(R, Facts, InvoiceGroupID);
                R.Close();
            until Invoices.Next() = 0;
    end;

    local procedure InvoiceDimensionsResolved(SetID: Integer): Boolean
    begin
        exit((DimensionClassification(SetID) <> '') and
            (DimensionValue(SetID, GrowerDim) <> '') and
            (DimensionValue(SetID, PackDim) <> '') and
            (DimensionValue(SetID, PackCategoryDim) <> ''));
    end;

    local procedure PoolClassification(var R: RecordRef): Text
    begin
        if (TextValue(R, 5) = '') or (TextValue(R, 17) = '') or (TextValue(R, 18) = '') then
            exit('');
        exit(StrSubstNo('%1 / %2 / %3', TextValue(R, 5), TextValue(R, 17), TextValue(R, 18)));
    end;

    local procedure DimensionClassification(SetID: Integer): Text
    var
        V: Code[20];
        G: Code[20];
        S: Code[20];
    begin
        V := DimensionValue(SetID, VarietyDim);
        G := DimensionValue(SetID, GradeDim);
        S := DimensionValue(SetID, SizeDim);
        if (V = '') or (G = '') or (S = '') then
            exit('');
        exit(StrSubstNo('%1 / %2 / %3', V, G, S));
    end;

    local procedure DimensionValue(SetID: Integer; DimensionCode: Code[20]): Code[20]
    var
        Entry: Record "Dimension Set Entry";
    begin
        if not Entry.ReadPermission() then
            Error('Read permission for dimension set entries is required.');
        if (SetID = 0) or (DimensionCode = '') then
            exit('');
        if Entry.Get(SetID, DimensionCode) then
            exit(Entry."Dimension Value Code");
        exit('');
    end;

    local procedure PoolTypeOrdinal(Value: Code[20]): Integer
    begin
        case Value of
            'I': exit(0);
            'E': exit(1);
            'G': exit(2);
        end;
        exit(-1);
    end;

    local procedure NewFact(var Fact: Record "WLF Pool Review Fact"; Kind: Enum "WLF Pool Review Kind"; var R: RecordRef)
    begin
        NextFact += 1;
        if NextFact > 25000 then
            Error('The selected scan exceeds 25,000 evidence records. No partial clear result is allowed.');
        Fact.Init();
        Fact."Fact No." := NextFact;
        Fact.Kind := Kind;
        Fact."Source Record ID" := R.RecordId();
        Fact."Source System ID" := R.Field(2000000000).Value;
        Fact."Source Modified At" := R.Field(2000000003).Value;
    end;

    local procedure CheckBound(var R: RecordRef)
    begin
        if R.Count() > 25000 then
            Error('More than 25,000 visible %1 records match this check. The scan cannot complete within its limit.', R.Name());
    end;

    procedure CoverageNotes(): Text
    begin
        exit('Checks v0.1: selected group; visible pool/ledger ownership and available ledger dimension classification; signed ledger kg bases; positive PP/PPV recovery indicators; unfinished payment headers; posted Item invoice lines with a consignment and matching stored season/week. Invoice candidates are enumerated independently of processed markers. Missing season/week lines, production-source completeness, credits, freight, tax, charge-template ties, market rules and purchase-document reconciliation are outside this version. Snapshot results may change during reading. No exception in this scope is not approval to close or pay.');
    end;

    procedure PaymentHistory(GroupID: Integer): JsonObject
    var
        R: RecordRef;
        Result: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        Shown: Integer;
        Total: Integer;
        StatusText: Text;
    begin
        if GroupID <= 0 then
            Error('Choose a pool group before loading payments.');
        OpenSource(R, 50233);
        // Extra display fields are checked only for this view, not imposed on existing rules.
        CheckField(R, 3, 'Payment Type', FieldType::Option);
        CheckField(R, 4, 'Payment No.', FieldType::Integer);
        CheckField(R, 6, 'Closed By User', FieldType::Code);
        CheckField(R, 7, 'GL Journal Batch Name', FieldType::Code);
        CheckField(R, 9, 'Reversed By Payment ID', FieldType::Integer);
        CheckField(R, 12, 'Provisional', FieldType::Boolean);
        CheckField(R, 14, 'Completed By User', FieldType::Code);
        Filter(R, 2, GroupID);
        Total := R.Count();
        if R.FindSet(false) then
            repeat
                if Shown >= 200 then
                    break;
                Clear(Row);
                if BoolValue(R, 8) then
                    StatusText := 'Reversed'
                else
                    if DateTimeValue(R, 13) = 0DT then
                        StatusText := 'Completion not recorded'
                    else
                        StatusText := 'Run completed';
                Row.Add('id', IntValue(R, 1));
                Row.Add('groupId', GroupID);
                Row.Add('number', IntValue(R, 4));
                Row.Add('type', Format(R.Field(3)));
                Row.Add('pool', TextValue(R, 11));
                Row.Add('provisional', BoolValue(R, 12));
                Row.Add('status', StatusText);
                Row.Add('reversed', BoolValue(R, 8));
                Row.Add('reversedBy', IntValue(R, 9));
                Row.Add('closedAt', PaymentDateText(DateTimeValue(R, 5)));
                Row.Add('completedAt', PaymentDateText(DateTimeValue(R, 13)));
                Row.Add('closedBy', TextValue(R, 6));
                Row.Add('completedBy', TextValue(R, 14));
                Row.Add('journalBatch', TextValue(R, 7));
                Row.Add('invoiceReferences', TextValue(R, 10));
                Rows.Add(Row);
                Shown += 1;
            until R.Next() = 0;
        R.Close();
        Result.Add('groupId', GroupID);
        Result.Add('loaded', true);
        Result.Add('loadedAt', Format(CurrentDateTime()));
        Result.Add('rows', Rows);
        Result.Add('total', Total);
        Result.Add('hasMore', Total > Shown);
        Result.Add('error', '');
        exit(Result);
    end;

    procedure ShowPaymentEvidence(GroupID: Integer; PaymentID: Integer)
    var
        R: RecordRef;
        SourceID: RecordId;
    begin
        if (GroupID <= 0) or (PaymentID <= 0) then
            Error('Choose a payment from the current group.');
        OpenSource(R, 50233);
        Filter(R, 1, PaymentID);
        Filter(R, 2, GroupID);
        if not R.FindFirst() then
            Error('This payment no longer belongs to the selected visible group, or is not accessible. Reload payment history.');
        SourceID := R.RecordId();
        R.Close();
        ShowEvidence(SourceID);
    end;

    local procedure PaymentDateText(Value: DateTime): Text
    begin
        if Value = 0DT then
            exit('');
        exit(Format(Value));
    end;

    procedure ShowLinkedLedger(SourceID: RecordId)
    var
        Source: RecordRef;
        R: RecordRef;
        Facts: Record "WLF Pool Review Fact";
        LedgerPage: Page "WLF Pool Review Ledger";
        LinkField: Integer;
        LinkValue: Variant;
    begin
        if not (SourceID.TableNo() in [50233, 50230, 50208]) then
            Error('This source does not support linked ledger entries.');
        OpenSource(Source, SourceID.TableNo());
        if not Source.Get(SourceID) then
            Error('The source record is no longer visible. Reload the review.');
        case SourceID.TableNo() of
            50233: LinkField := 35;
            50230: LinkField := 25;
            50208: LinkField := 2;
        end;
        LinkValue := Source.Field(1).Value;
        if Format(LinkValue) in ['', '0'] then
            Error('The source has no valid ledger link.');
        Source.Close();
        OpenSource(R, 50209);
        CheckField(R, 5, 'Posting Date', FieldType::Date);
        CheckField(R, 14, 'VAT Amount', FieldType::Decimal);
        CheckField(R, 22, 'G/L Entry No.', FieldType::Integer);
        CheckField(R, 37, 'Comment', FieldType::Text);
        Filter(R, LinkField, LinkValue);
        if R.Count() > 25000 then
            Error('More than 25,000 linked entries. This view cannot show the full result.');
        if R.FindSet(false) then
            repeat
                Facts.Init();
                Facts."Fact No." := IntValue(R, 1);
                Facts."Source Record ID" := R.RecordId();
                Facts."Group ID" := IntValue(R, 25);
                Facts."Pool Code" := CopyStr(TextValue(R, 2), 1, 20);
                Facts."Grower Code" := CopyStr(TextValue(R, 26), 1, 20);
                Facts."Trans Type" := CopyStr(TextValue(R, 27), 1, 10);
                Facts."Document No." := CopyStr(TextValue(R, 34), 1, 20);
                Facts."Payment ID" := IntValue(R, 35);
                Facts."Posting Date" := R.Field(5).Value;
                Facts.Amount := DecimalValue(R, 13);
                Facts."GST Amount" := DecimalValue(R, 14);
                Facts.Kg := DecimalValue(R, 12);
                Facts.Reversed := BoolValue(R, 20);
                Facts."Posted to GL" := BoolValue(R, 39);
                Facts."GL Entry No." := IntValue(R, 22);
                Facts.Description := CopyStr(TextValue(R, 37), 1, 250);
                Facts.Insert();
            until R.Next() = 0;
        R.Close();
        LedgerPage.SetRows(Facts, Format(SourceID));
        LedgerPage.RunModal();
    end;

    procedure OpenNativeSource(SourceID: RecordId)
    var
        R: RecordRef;
        Target: RecordRef;
    begin
        OpenSource(R, SourceID.TableNo());
        if not R.Get(SourceID) then
            Error('The source record is no longer visible. Refresh the review.');
        case R.Number() of
            50230: OpenNativePage(R, 50251, 'TAC Pool Group Card');
            50220: OpenNativePage(R, 50259, 'TAC Pool Weeks');
            50208: OpenNativePage(R, 50211, 'TAC Pool');
            50209: OpenNativePage(R, 50208, 'TAC Pool Ledger Entries');
            50233:
                begin
                    OpenSource(Target, 50230);
                    Filter(Target, 1, R.Field(2).Value);
                    if not Target.FindFirst() then
                        Error('The payment group is no longer visible.');
                    OpenNativePage(Target, 50251, 'TAC Pool Group Card');
                    Target.Close();
                end;
            50206: OpenDocumentHeader(R, 50204, 'TAC Consignment Header', 1, 50204, 'TAC Consignment');
            113: OpenDocumentHeader(R, 112, 'Sales Invoice Header', 3, Page::"Posted Sales Invoice", 'Posted Sales Invoice');
            else
                Error('No native page is mapped for this source. Use the source evidence.');
        end;
        R.Close();
    end;

    procedure OpenOriginatingDocument(SourceID: RecordId)
    var
        R: RecordRef;
        Line: RecordRef;
        SourceGuid: Guid;
        SourceKind: Integer;
        SourceTable: Integer;
        KeyField: Integer;
    begin
        if SourceID.TableNo() <> 50209 then
            Error('Select a pool ledger entry.');
        OpenSource(R, 50209);
        if not R.Get(SourceID) then
            Error('The ledger entry is no longer visible.');
        SourceKind := IntValue(R, 41);
        SourceGuid := R.Field(42).Value;
        case SourceKind of
            1: begin SourceTable := 113; KeyField := 3; end;
            2: begin SourceTable := 115; KeyField := 3; end;
            3: begin SourceTable := 50206; KeyField := 1; end;
            4: begin SourceTable := 50236; KeyField := 1; end;
            else
                Error('This entry has no supported originating document link. Open its native ledger record or pool group instead.');
        end;
        case SourceKind of
            1: CheckEnum(R, 41, 2, 1, 'Sales Invoice');
            2: CheckEnum(R, 41, 3, 2, 'Sales Credit Memo');
            3: CheckEnum(R, 41, 4, 3, 'Consignment');
            4: CheckEnum(R, 41, 5, 4, 'Expense');
        end;
        Line.Open(SourceTable);
        if not Line.ReadPermission() then
            Error('You do not have read access to the originating document lines.');
        case SourceKind of
            1: CheckTable(Line, 'Sales Invoice Line');
            2: CheckTable(Line, 'Sales Cr.Memo Line');
            3: CheckTable(Line, 'TAC Consignment Line');
            4: CheckTable(Line, 'TAC Pool Expense Detail');
        end;
        // System ID is authoritative: never fall back to a coincidentally matching document number.
        if IsNullGuid(SourceGuid) then
            Error('This entry has no originating line System ID. Use its native ledger record to investigate the stored references.');
        if not Line.GetBySystemId(SourceGuid) then
            Error('The originating document line is missing or not visible. No substitute document was opened.');
        case SourceKind of
            1: OpenDocumentHeader(Line, 112, 'Sales Invoice Header', KeyField, Page::"Posted Sales Invoice", 'Posted Sales Invoice');
            2: OpenDocumentHeader(Line, 114, 'Sales Cr.Memo Header', KeyField, Page::"Posted Sales Credit Memo", 'Posted Sales Credit Memo');
            3: OpenDocumentHeader(Line, 50204, 'TAC Consignment Header', KeyField, 50204, 'TAC Consignment');
            4: OpenDocumentHeader(Line, 50235, 'TAC Pool Expense Header', KeyField, 50255, 'TAC Pool Expense');
        end;
        Line.Close();
        R.Close();
    end;

    local procedure OpenDocumentHeader(var Line: RecordRef; HeaderTable: Integer; HeaderName: Text; LineKeyField: Integer; PageID: Integer; PageName: Text)
    var
        Header: RecordRef;
        HeaderKeyField: Integer;
    begin
        Header.Open(HeaderTable);
        CheckTable(Header, HeaderName);
        if not Header.ReadPermission() then
            Error('You do not have read access to this document.');
        HeaderKeyField := 1;
        if HeaderTable in [112, 114] then
            HeaderKeyField := 3;
        Filter(Header, HeaderKeyField, Line.Field(LineKeyField).Value);
        if not Header.FindFirst() then
            Error('The document header is missing or not visible.');
        OpenNativePage(Header, PageID, PageName);
        Header.Close();
    end;

    local procedure OpenNativePage(var R: RecordRef; PageID: Integer; ExpectedName: Text)
    var
        Metadata: RecordRef;
        SourceRecord: Variant;
    begin
        Metadata.Open(2000000138);
        CheckTable(Metadata, 'Page Metadata');
        Filter(Metadata, 1, PageID);
        if not Metadata.FindFirst() then
            Error('The source page is not installed.');
        if (TextValue(Metadata, 2) <> ExpectedName) or (IntValue(Metadata, 14) <> R.Number()) or BoolValue(Metadata, 25) then
            Error('The source page mapping has changed. Ask the team to review this link.');
        Metadata.Close();
        R.SetRecFilter();
        SourceRecord := R;
        Page.RunModal(PageID, SourceRecord);
    end;

    procedure ShowEvidence(SourceID: RecordId)
    var
        R: RecordRef;
        F: FieldRef;
        Fields: Record "WLF Pool Review Field";
        Evidence: Page "WLF Pool Review Evidence";
        I: Integer;
    begin
        case SourceID.TableNo() of
            50230, 50220, 50208, 50209, 50233, 50239, 50206, 113:
                ;
            else
                Error('No supported source record is linked to this result.');
        end;
        OpenSource(R, SourceID.TableNo());
        if not R.Get(SourceID) then
            Error('This source record is no longer visible. Refresh the review.');
        Fields.Init();
        Fields."Field No." := 0;
        Fields."Field Name" := 'Record';
        Fields.Value := CopyStr(Format(SourceID), 1, 2048);
        Fields.Insert();
        for I := 1 to R.FieldCount() do begin
            F := R.FieldIndex(I);
            if (F.Class() = FieldClass::Normal) and not (F.Type() in [FieldType::Blob, FieldType::Media, FieldType::MediaSet]) then begin
                Fields.Init();
                Fields."Field No." := F.Number();
                Fields."Field Name" := CopyStr(F.Name(), 1, 100);
                Fields.Value := CopyStr(Format(F), 1, 2048);
                Fields.Insert();
            end;
        end;
        R.Close();
        Evidence.SetSource(SourceID);
        Evidence.SetFields(Fields);
        Evidence.RunModal();
    end;

    local procedure OpenSource(var R: RecordRef; TableNo: Integer)
    begin
        R.Open(TableNo);
        if not R.ReadPermission() then
            Error('Read access to table %1 is required. Ask an administrator to review the existing source permissions.', TableNo);
        case TableNo of
            113:
                begin
                    CheckTable(R, 'Sales Invoice Line');
                    CheckField(R, 50240, 'Consignment No.', FieldType::Code);
                    CheckField(R, 50241, 'Pool Week', FieldType::Integer);
                    CheckField(R, 50242, 'Original Item No.', FieldType::Code);
                    CheckField(R, 50244, 'Season Code', FieldType::Code);
                end;
            50206:
                begin
                    CheckTable(R, 'TAC Consignment Line');
                    CheckField(R, 1, 'Consignment No.', FieldType::Code);
                    CheckField(R, 2, 'Line No.', FieldType::Integer);
                    CheckField(R, 3, 'Item No.', FieldType::Code);
                    CheckField(R, 7, 'Pool Week', FieldType::Integer);
                    CheckField(R, 8, 'Season Code', FieldType::Code);
                    CheckField(R, 12, 'Pool Code', FieldType::Code);
                    CheckField(R, 16, 'Dimension Set ID', FieldType::Integer);
                end;
            50208:
                begin
                    CheckTable(R, 'TAC Pool');
                    CheckField(R, 1, 'Pool Code', FieldType::Code);
                    CheckField(R, 5, 'Variety Code', FieldType::Code);
                    CheckField(R, 16, 'Pool Group ID', FieldType::Integer);
                    CheckField(R, 17, 'Grade Code', FieldType::Code);
                    CheckField(R, 18, 'Size Code', FieldType::Code);
                end;
            50209:
                begin
                    CheckTable(R, 'TAC Pool Ledger Entry');
                    CheckField(R, 1, 'Entry No.', FieldType::Integer);
                    CheckField(R, 2, 'Pool Code', FieldType::Code);
                    CheckField(R, 12, 'Quantity (Kg)', FieldType::Decimal);
                    CheckField(R, 13, 'Amount', FieldType::Decimal);
                    CheckField(R, 20, 'Reversed', FieldType::Boolean);
                    CheckField(R, 23, 'Dimension Set ID', FieldType::Integer);
                    CheckField(R, 25, 'Pool Group ID', FieldType::Integer);
                    CheckField(R, 26, 'Grower Code', FieldType::Code);
                    CheckField(R, 27, 'Trans Type Code', FieldType::Code);
                    CheckField(R, 34, 'Source Document No.', FieldType::Code);
                    CheckField(R, 35, 'Pool Payment ID', FieldType::Integer);
                    CheckField(R, 38, 'Source Line No.', FieldType::Integer);
                    CheckField(R, 39, 'Posted to G/L', FieldType::Boolean);
                    CheckField(R, 41, 'Source Type', FieldType::Option);
                    CheckField(R, 42, 'Source System ID', FieldType::Guid);
                    CheckEnum(R, 41, 2, 1, 'Sales Invoice');
                end;
            50220:
                begin
                    CheckTable(R, 'TAC Pool Week');
                    CheckField(R, 1, 'Code', FieldType::Code);
                    CheckField(R, 3, 'Season Code', FieldType::Code);
                    CheckField(R, 4, 'Week No.', FieldType::Integer);
                end;
            50225:
                begin
                    CheckTable(R, 'TAC Pool Setup');
                    CheckField(R, 1, 'Primary Key', FieldType::Code);
                    CheckField(R, 32, 'Variety Dimension Code', FieldType::Code);
                    CheckField(R, 33, 'Grade Dimension Code', FieldType::Code);
                    CheckField(R, 34, 'Size Dimension Code', FieldType::Code);
                    CheckField(R, 35, 'Grower Pool Type Dim. Code', FieldType::Code);
                    CheckField(R, 15, 'Grower Dimension Code', FieldType::Code);
                    CheckField(R, 36, 'Pack Type Dimension Code', FieldType::Code);
                    CheckField(R, 37, 'Pack Type Category Dim. Code', FieldType::Code);
                end;
            50230:
                begin
                    CheckTable(R, 'TAC Pool Group Header');
                    CheckField(R, 1, 'Pool Group ID', FieldType::Integer);
                    CheckField(R, 2, 'Pool Group Code', FieldType::Code);
                    CheckField(R, 3, 'Pool Week Code', FieldType::Code);
                    CheckField(R, 4, 'Grower Pool Type', FieldType::Option);
                    CheckField(R, 5, 'Status', FieldType::Option);
                    CheckField(R, 6, 'Provisional Close Count', FieldType::Integer);
                    CheckEnum(R, 4, 1, 0, 'Internal');
                    CheckEnum(R, 4, 2, 1, 'External');
                    CheckEnum(R, 4, 3, 2, 'Contract Pack');
                end;
            50233:
                begin
                    CheckTable(R, 'TAC Pool Payment Header');
                    CheckField(R, 1, 'Pool Payment ID', FieldType::Integer);
                    CheckField(R, 2, 'Pool Group ID', FieldType::Integer);
                    CheckField(R, 5, 'Closed DateTime', FieldType::DateTime);
                    CheckField(R, 8, 'Reversed', FieldType::Boolean);
                    CheckField(R, 10, 'Created Purchase Invoice Nos.', FieldType::Text);
                    CheckField(R, 11, 'Pool Code', FieldType::Code);
                    CheckField(R, 13, 'Completed DateTime', FieldType::DateTime);
                end;
            50239:
                begin
                    CheckTable(R, 'TAC Pool Invoice Post State');
                    CheckField(R, 1, 'Posted Invoice SystemId', FieldType::Guid);
                    CheckField(R, 2, 'Posted Invoice No.', FieldType::Code);
                end;
            else
                Error('Table %1 is outside this reader schema.', TableNo);
        end;
    end;

    local procedure CheckEnum(var R: RecordRef; Number: Integer; Index: Integer; Ordinal: Integer; ExpectedName: Text)
    var
        F: FieldRef;
    begin
        F := R.Field(Number);
        if not F.IsEnum() then
            Error('Schema mismatch: %1 field %2 is no longer an enum.', R.Name(), Number);
        if (F.GetEnumValueOrdinal(Index) <> Ordinal) or (F.GetEnumValueName(Index) <> ExpectedName) then
            Error('Schema mismatch: %1 field %2 enum values have changed.', R.Name(), Number);
    end;

    local procedure CheckTable(var R: RecordRef; ExpectedName: Text)
    begin
        if R.Name() <> ExpectedName then
            Error('Schema mismatch: table %1 is %2; expected %3. This check version must be reviewed.', R.Number(), R.Name(), ExpectedName);
    end;

    local procedure CheckField(var R: RecordRef; Number: Integer; ExpectedName: Text; ExpectedType: FieldType)
    var
        F: FieldRef;
    begin
        if not R.FieldExist(Number) then
            Error('Schema mismatch: %1 field %2 (%3) is missing.', R.Name(), Number, ExpectedName);
        F := R.Field(Number);
        if (F.Name() <> ExpectedName) or (F.Type() <> ExpectedType) then
            Error('Schema mismatch: %1 field %2 must be %3, type %4. The scan has stopped.', R.Name(), Number, ExpectedName, ExpectedType);
    end;

    local procedure Filter(var R: RecordRef; Number: Integer; Value: Variant)
    var
        F: FieldRef;
    begin
        F := R.Field(Number);
        F.SetRange(Value);
    end;

    local procedure TextValue(var R: RecordRef; Number: Integer): Text
    var
        Value: Text;
    begin
        Value := R.Field(Number).Value;
        exit(Value);
    end;

    local procedure IntValue(var R: RecordRef; Number: Integer): Integer
    var
        Value: Integer;
    begin
        Value := R.Field(Number).Value;
        exit(Value);
    end;

    local procedure DecimalValue(var R: RecordRef; Number: Integer): Decimal
    var
        Value: Decimal;
    begin
        Value := R.Field(Number).Value;
        exit(Value);
    end;

    local procedure BoolValue(var R: RecordRef; Number: Integer): Boolean
    var
        Value: Boolean;
    begin
        Value := R.Field(Number).Value;
        exit(Value);
    end;

    local procedure DateTimeValue(var R: RecordRef; Number: Integer): DateTime
    var
        Value: DateTime;
    begin
        Value := R.Field(Number).Value;
        exit(Value);
    end;

    var
        SeenLedger: Dictionary of [Integer, Integer];
        NextFact: Integer;
        VarietyDim: Code[20];
        GradeDim: Code[20];
        SizeDim: Code[20];
        TypeDim: Code[20];
        GrowerDim: Code[20];
        PackDim: Code[20];
        PackCategoryDim: Code[20];
}
