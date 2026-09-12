codeunit 58890 "WLF Pool Review Tests"
{
    Subtype = Test;

    [Test]
    procedure BlankPoolIsAllowedForGroupEntry()
    begin
        Initialize();
        AddLedger(42, '', 0, 'CH', 0, -5, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(0, CountRule('POOL-GROUP'), 'Blank-pool group entry');
        AssertInteger(1, Group."Ledger Count", 'Blank-pool ledger count');
        AssertDecimal(-5, Group."Ledger Net", 'Blank-pool ledger amount');
    end;

    [Test]
    procedure OwnershipChecksIncludeIncomingButTotalsUseRecordedGroup()
    begin
        Initialize();
        AddLedger(99, 'OWNED-BY-42', 42, 'TR', 10, 7, false);
        AddLedger(42, 'OWNED-BY-99', 99, 'TR', 20, 9, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(2, CountRule('POOL-GROUP'), 'Both ownership directions');
        AssertInteger(2, Group."Error Count", 'Ownership severity');
        AssertInteger(1, Group."Ledger Count", 'Recorded-group count');
        AssertDecimal(20, Group."Movement Kg", 'Recorded-group movement kg');
        AssertDecimal(20, Group."All Ledger Kg", 'Recorded-group all kg');
        AssertDecimal(9, Group."Ledger Net", 'Recorded-group net');
    end;

    [Test]
    procedure UnassignedNonblankPoolIsReported()
    begin
        Initialize();
        AddLedger(42, 'UNRESOLVED', 0, 'TR', 10, 7, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('POOL-GROUP'), 'Unassigned nonblank pool');
        AssertInteger(1, Group."Error Count", 'Unassigned-pool severity');
    end;

    [Test]
    procedure UnrelatedFactsDoNotAffectSelectedGroup()
    begin
        Initialize();
        AddLedger(99, 'OTHER', 99, 'PP', 20, 90, false);
        AddInvoice(99, true, true, 0, false);
        AddPayment(99, 0DT, false);
        Rules.Evaluate(Group, Facts, Issues);
        Issues.Reset();
        AssertInteger(0, Issues.Count(), 'Unrelated facts create no issues');
        AssertInteger(0, Group."Ledger Count", 'Unrelated ledger count');
        AssertInteger(0, Group."Payment Count", 'Unrelated payment count');
        AssertDecimal(0, Group."Ledger Net", 'Unrelated ledger total');
    end;

    [Test]
    procedure RecordedReversalSignsCancelWithoutDoubleInversion()
    begin
        Initialize();
        AddLedger(42, 'P42', 42, 'TR', 100, 100, true);
        AddLedger(42, 'P42', 42, 'TR', -100, -100, false);
        AddLedger(42, 'P42', 42, 'FR', 40, -8, true);
        AddLedger(42, 'P42', 42, 'FR', -40, 8, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertDecimal(0, Group."Movement Kg", 'Signed movement cancellation');
        AssertDecimal(0, Group."All Ledger Kg", 'Signed all-kg cancellation');
        AssertDecimal(0, Group."Ledger Net", 'Signed amount cancellation');
        AssertInteger(0, CountRule('KG-BASIS'), 'No kg basis issue after cancellation');
    end;

    [Test]
    procedure KgBasisDifferenceIsReviewWarning()
    begin
        Initialize();
        AddLedger(42, 'P42', 42, 'TR', 100, 0, false);
        AddLedger(42, 'P42', 42, 'PR', 100, 200, false);
        AddLedger(42, 'P42', 42, 'FR', 100, -20, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertDecimal(100, Group."Movement Kg", 'Movement-only kg');
        AssertDecimal(300, Group."All Ledger Kg", 'All transaction kg');
        AssertInteger(1, CountRule('KG-BASIS'), 'Kg basis issue');
        AssertInteger(1, Group."Warning Count", 'Kg warning severity');
        AssertInteger(0, Group."Error Count", 'Kg difference is not definitive error');
    end;

    [Test]
    procedure OnlyPositiveUnreversedPaymentEntriesTriggerRecoveryReview()
    begin
        Initialize();
        AddLedger(42, 'P42', 42, 'PP', 0, 25, false);
        AddLedger(42, 'P42', 42, 'PP', 0, -25, false);
        AddLedger(42, 'P42', 42, 'PPV', 0, 15, true);
        AddLedger(42, 'P42', 42, 'CH', 0, 10, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('RECOVERY'), 'Recovery sign and reversal scope');
        AssertInteger(1, Group."Warning Count", 'Recovery requires review');
        AssertInteger(0, Group."Error Count", 'Recovery sign does not prove error');
    end;

    [Test]
    procedure ProcessedStateRaisesMissingInvoiceSeverity()
    begin
        Initialize();
        AddInvoice(42, true, false, 0, false);
        AddInvoice(42, true, true, 0, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(2, CountRule('INV-MISSING'), 'Two missing invoice lines');
        AssertInteger(1, Group."Warning Count", 'Unprocessed source timing warning');
        AssertInteger(1, Group."Error Count", 'Processed source completeness mismatch');
    end;

    [Test]
    procedure UnresolvedInvoiceIsNeverCalledMissing()
    begin
        Initialize();
        AddInvoice(42, false, true, 0, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('INV-UNRESOLVED'), 'Unresolved attribution');
        AssertInteger(0, CountRule('INV-MISSING'), 'No unsupported missing-revenue finding');
        AssertInteger(0, Group."Error Count", 'Unresolved is not mismatch');
    end;

    [Test]
    procedure MultipleLegacyMatchesRemainReviewWarnings()
    begin
        Initialize();
        AddInvoice(42, true, true, 2, true);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('INV-DUP'), 'Multiple active matches');
        AssertInteger(1, CountRule('INV-LEGACY'), 'Legacy identity is explicit');
        AssertInteger(0, CountRule('INV-MISSING'), 'Matched source is not missing');
        AssertInteger(0, Group."Error Count", 'Multiple matches do not prove duplication');
    end;

    [Test]
    procedure PaymentCompletionCheckExcludesCompletedAndReversed()
    begin
        Initialize();
        AddPayment(42, 0DT, false);
        AddPayment(42, CreateDateTime(DMY2Date(11, 9, 2026), 120000T), false);
        AddPayment(42, 0DT, true);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(3, Group."Payment Count", 'All payment headers counted');
        AssertInteger(1, CountRule('PAYMENT-OPEN'), 'Only unfinished active header');
        AssertInteger(1, Group."Warning Count", 'Missing timestamp warning');
    end;

    [Test]
    procedure ClassificationCheckRequiresBothResolvedSides()
    begin
        Initialize();
        AddLedger(42, 'P42', 42, 'TR', 0, 0, false);
        Facts."Expected Classification" := '';
        Facts."Actual Classification" := 'HASS|1|16';
        Facts.Modify();
        AddLedger(42, 'P42', 42, 'TR', 0, 0, false);
        Facts."Expected Classification" := 'HASS|1|16';
        Facts."Actual Classification" := '';
        Facts.Modify();
        AddLedger(42, 'P42', 42, 'TR', 0, 0, false);
        Facts."Expected Classification" := 'HASS|1|16';
        Facts."Actual Classification" := 'HASS|1|18';
        Facts.Modify();
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('SOURCE-CLASS'), 'Only fully resolved mismatch');
        AssertInteger(2, CountRule('CLASS-UNRESOLVED'), 'Incomplete comparisons visible');
        AssertInteger(2, Group."Unresolved Sources", 'Incomplete comparisons affect scan coverage');
    end;

    [Test]
    procedure IssueNumbersRemainUniqueAcrossFilteredGroups()
    var
        OtherGroup: Record "WLF Pool Review Group";
        EmptyFact: Record "WLF Pool Review Fact";
    begin
        Initialize();
        OtherGroup."Group ID" := 99;
        Rules.AddIssue(OtherGroup, Issues, 'EXISTING', "WLF Pool Review Severity"::Information,
            'Existing issue', '', EmptyFact, 0, 0, '');
        Issues.SetRange("Group ID", 42);
        AddInvoice(42, false, false, 0, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, Issues.Count(), 'Selected-group filter is preserved');
        Issues.Reset();
        AssertInteger(2, Issues.Count(), 'Existing issue survives');
        if not Issues.Get(1) then
            Error('Original issue number 1 was lost.');
        AssertInteger(99, Issues."Group ID", 'Original issue group');
        if not Issues.Get(2) then
            Error('New issue number 2 was not allocated.');
        AssertInteger(42, Issues."Group ID", 'New issue group');
    end;

    [Test]
    procedure ReaderCoverageCountersArePreserved()
    begin
        Initialize();
        Group."Invoice Candidates" := 8;
        Group."Attributed Invoices" := 3;
        Group."Unresolved Sources" := 2;
        Group."Information Count" := 1;
        AddLedger(42, 'P42', 42, 'TR', 10, 20, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(8, Group."Invoice Candidates", 'Candidate counter preserved');
        AssertInteger(3, Group."Attributed Invoices", 'Attributed counter preserved');
        AssertInteger(2, Group."Unresolved Sources", 'Unresolved counter preserved');
        AssertInteger(1, Group."Information Count", 'Prior reader issue count preserved');
    end;

    [Test]
    procedure UniqueInvoiceMatchMustRecordAttributedGroup()
    begin
        Initialize();
        AddInvoice(42, true, true, 1, false);
        Facts."Owner Group ID" := 99;
        Facts.Modify();
        AddInvoice(42, true, true, 1, false);
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('INV-GROUP'), 'Only the PR in another group');
        AssertInteger(0, CountRule('INV-MISSING'), 'Wrong group does not mean missing match');
        AssertInteger(1, Group."Error Count", 'Recorded invoice group mismatch');
    end;
    [Test]
    procedure MultipleInvoiceMatchesIncludeEntriesEntirelyOutsideSourceGroup()
    begin
        Initialize();
        AddLedger(99, 'OTHER-99', 99, 'PR', 0, 20, false);
        Facts."Invoice Group ID" := 42;
        Facts.Modify();
        AddLedger(88, 'OTHER-88', 88, 'PR', 0, 30, false);
        Facts."Invoice Group ID" := 42;
        Facts.Modify();
        AddLedger(42, 'P42', 42, 'PR', 0, 10, false);
        Facts."Invoice Group ID" := 42;
        Facts.Modify();
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(2, CountRule('INV-ALLOCATION'), 'Both entries outside source group');
        AssertInteger(0, CountRule('POOL-GROUP'), 'Each ledger agrees with its own pool');
        AssertInteger(2, Group."Error Count", 'Source allocation mismatches');
        AssertInteger(1, Group."Ledger Count", 'Only recorded-group entry counted');
        AssertDecimal(10, Group."Ledger Net", 'Other-group allocations excluded from total');
    end;

    [Test]
    procedure InvoiceAllocationChecksPoolOwnerAndAllowsBlankPool()
    begin
        Initialize();
        AddLedger(42, 'OTHER-99', 99, 'PR', 0, 20, false);
        Facts."Invoice Group ID" := 42;
        Facts.Modify();
        AddLedger(42, '', 0, 'PR', 0, 10, false);
        Facts."Invoice Group ID" := 42;
        Facts.Modify();
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('INV-ALLOCATION'), 'Nonblank wrong-owner pool only');
        if not Issues.FindFirst() then
            Error('Expected allocation issue was not found.');
        AssertDecimal(42, Issues.Expected, 'Expected source group');
        AssertDecimal(99, Issues.Actual, 'Actual conflicting pool owner');
    end;

    [Test]
    procedure MissingClassificationCoverageUsesSourceTransactionsOnly()
    begin
        Initialize();
        AddLedger(42, 'P42', 42, 'PP', 0, -20, false);
        Facts."Expected Classification" := '';
        Facts.Modify();
        AddLedger(42, 'P42', 42, 'CH', 0, -5, false);
        Facts."Expected Classification" := '';
        Facts.Modify();
        AddLedger(42, 'P42', 42, 'FR', 0, -5, false);
        Facts."Expected Classification" := '';
        Facts.Modify();
        AddLedger(42, '', 0, 'PR', 0, 20, false);
        Facts."Expected Classification" := '';
        Facts."Actual Classification" := '';
        Facts.Modify();
        Rules.Evaluate(Group, Facts, Issues);
        AssertInteger(1, CountRule('CLASS-UNRESOLVED'), 'Only nonblank source-bearing FR');
        AssertInteger(1, Group."Unresolved Sources", 'Source coverage counter');
        AssertInteger(0, Group."Warning Count", 'Dimensionless payment creates no warning');
    end;
    local procedure Initialize()
    begin
        Clear(Group);
        Group."Group ID" := 42;
        Group."Scanned At" := CreateDateTime(DMY2Date(11, 9, 2026), 120000T);
        Facts.Reset();
        Facts.DeleteAll();
        Issues.Reset();
        Issues.DeleteAll();
        NextFactNo := 0;
    end;

    local procedure AddLedger(GroupID: Integer; PoolCode: Code[20]; OwnerGroupID: Integer; TransType: Code[10]; Kg: Decimal; Amount: Decimal; Reversed: Boolean)
    begin
        NewFact("WLF Pool Review Kind"::Ledger, GroupID);
        Facts."Pool Code" := PoolCode;
        Facts."Owner Group ID" := OwnerGroupID;
        Facts."Trans Type" := TransType;
        Facts."Expected Classification" := 'HASS|1|16';
        Facts."Actual Classification" := 'HASS|1|16';
        Facts.Kg := Kg;
        Facts.Amount := Amount;
        Facts.Reversed := Reversed;
        Facts.Insert();
    end;

    local procedure AddInvoice(GroupID: Integer; Resolved: Boolean; HasState: Boolean; MatchCount: Integer; Legacy: Boolean)
    begin
        NewFact("WLF Pool Review Kind"::Invoice, GroupID);
        Facts."Document No." := 'INV-TEST';
        Facts."Source Line No." := NextFactNo * 10000;
        Facts."Attribution Resolved" := Resolved;
        Facts."Has Invoice State" := HasState;
        Facts."Matching Entry Count" := MatchCount;
        Facts."Owner Group ID" := GroupID;
        Facts."Legacy Match" := Legacy;
        Facts.Insert();
    end;

    local procedure AddPayment(GroupID: Integer; CompletedAt: DateTime; Reversed: Boolean)
    begin
        NewFact("WLF Pool Review Kind"::Payment, GroupID);
        Facts."Payment ID" := NextFactNo;
        Facts."Completed At" := CompletedAt;
        Facts.Reversed := Reversed;
        Facts.Insert();
    end;

    local procedure NewFact(Kind: Enum "WLF Pool Review Kind"; GroupID: Integer)
    begin
        NextFactNo += 1;
        Facts.Init();
        Facts."Fact No." := NextFactNo;
        Facts.Kind := Kind;
        Facts."Group ID" := GroupID;
    end;

    local procedure CountRule(RuleID: Code[20]): Integer
    begin
        Issues.Reset();
        Issues.SetRange("Group ID", Group."Group ID");
        Issues.SetRange("Rule ID", RuleID);
        exit(Issues.Count());
    end;

    [Test]
    procedure CsvPreservesQuotesCommasAndLineBreaks()
    var
        Exporter: Codeunit "WLF Pool Review Export";
        LFChar: Char;
    begin
        LFChar := 10;
        if Exporter.Cell('Grower, "A"') <> '"Grower, ""A"""' then
            Error('CSV must quote commas and double embedded quotation marks.');
        if Exporter.Cell('First' + Format(LFChar) + 'Second') <> '"First' + Format(LFChar) + 'Second"' then
            Error('CSV must retain a quoted multiline value.');
    end;

    [Test]
    procedure CsvNeutralizesFormulaPrefixesAfterWhitespace()
    var
        Exporter: Codeunit "WLF Pool Review Export";
        Value: Text;
        Values: List of [Text];
        PrefixChar: Char;
        TabChar: Char;
    begin
        PrefixChar := 39;
        TabChar := 9;
        Values := '=1+1|+SUM(1,2)|-1+1|@SUM(1,2)|  =1+1'.Split('|');
        Values.Add(Format(TabChar) + '=1+1');
        foreach Value in Values do
            if Exporter.Cell(Value) <> '"' + Format(PrefixChar) + Value + '"' then
                Error('CSV must neutralize spreadsheet formula text: %1', Value);
    end;
    local procedure AssertInteger(Expected: Integer; Actual: Integer; Context: Text)
    begin
        if Expected <> Actual then
            Error('%1: expected %2, received %3.', Context, Expected, Actual);
    end;

    local procedure AssertDecimal(Expected: Decimal; Actual: Decimal; Context: Text)
    begin
        if Expected <> Actual then
            Error('%1: expected %2, received %3.', Context, Expected, Actual);
    end;

    var
        Group: Record "WLF Pool Review Group";
        Facts: Record "WLF Pool Review Fact";
        Issues: Record "WLF Pool Review Issue";
        Rules: Codeunit "WLF Pool Review Rules";
        NextFactNo: Integer;
}



