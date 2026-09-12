codeunit 59301 "WLF Pool Review Rules"
{
    // This codeunit only evaluates session-only review buffers.
    // It never opens or updates a Business Central source table.
    procedure Evaluate(var Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact"; var Issues: Record "WLF Pool Review Issue")
    var
        GroupFact: Record "WLF Pool Review Fact";
    begin
        Group."Pool Count" := 0;
        Group."Ledger Count" := 0;
        Group."Payment Count" := 0;
        Group."Movement Kg" := 0;
        Group."All Ledger Kg" := 0;
        Group."Ledger Net" := 0;

        Facts.Reset();
        if Facts.FindSet() then
            repeat
                case Facts.Kind of
                    Facts.Kind::Pool:
                        if Facts."Group ID" = Group."Group ID" then
                            Group."Pool Count" += 1;
                    Facts.Kind::Ledger:
                        if (Facts."Group ID" = Group."Group ID") or (Facts."Owner Group ID" = Group."Group ID") or
                           (Facts."Invoice Group ID" = Group."Group ID")
                        then
                            EvaluateLedger(Group, Facts, Issues);
                    Facts.Kind::Payment:
                        if Facts."Group ID" = Group."Group ID" then
                            EvaluatePayment(Group, Facts, Issues);
                    Facts.Kind::Invoice:
                        if Facts."Group ID" = Group."Group ID" then
                            EvaluateInvoice(Group, Facts, Issues);
                end;
            until Facts.Next() = 0;

        if Round(Group."All Ledger Kg" - Group."Movement Kg", 0.00001) <> 0 then begin
            GroupFact."Group ID" := Group."Group ID";
            GroupFact."Source Record ID" := Group."Source Record ID";
            AddIssue(Group, Issues, 'KG-BASIS', "WLF Pool Review Severity"::Warning,
                'Kilogram totals use different transaction bases',
                'Expected shows the raw signed kilograms on TR, TRA and TRD entries. Actual shows raw signed kilograms on all ledger entries recorded against this group. Reversed entries retain their recorded signs in both totals. The difference identifies kilograms carried on other transaction types; it is not a physical stock variance or a confirmed duplicate. Review the transaction basis used by reports and payments.',
                GroupFact, Group."Movement Kg", Group."All Ledger Kg", 'raw signed kg');
        end;
    end;

    procedure AddIssue(var Group: Record "WLF Pool Review Group"; var Issues: Record "WLF Pool Review Issue"; RuleID: Code[20]; Severity: Enum "WLF Pool Review Severity"; Summary: Text; Details: Text; Fact: Record "WLF Pool Review Fact"; Expected: Decimal; Actual: Decimal; Measure: Text)
    var
        SavedView: Text;
        NextIssueNo: Integer;
    begin
        SavedView := Issues.GetView(false);
        Issues.Reset();
        if Issues.FindLast() then
            NextIssueNo := Issues."Issue No." + 1
        else
            NextIssueNo := 1;
        Issues.Init();
        Issues."Issue No." := NextIssueNo;
        Issues."Group ID" := Group."Group ID";
        Issues."Rule ID" := RuleID;
        Issues.Severity := Severity;
        Issues.Summary := CopyStr(Summary, 1, MaxStrLen(Issues.Summary));
        Issues.Details := CopyStr(Details, 1, MaxStrLen(Issues.Details));
        Issues."Pool Code" := Fact."Pool Code";
        Issues."Grower Code" := Fact."Grower Code";
        Issues."Document No." := Fact."Document No.";
        Issues."Source Line No." := Fact."Source Line No.";
        Issues."Payment ID" := Fact."Payment ID";
        Issues.Expected := Expected;
        Issues.Actual := Actual;
        Issues.Measure := CopyStr(Measure, 1, MaxStrLen(Issues.Measure));
        Issues."Evidence Record ID" := Fact."Source Record ID";
        Issues."Related Record ID" := Fact."Related Record ID";
        Issues."Scanned At" := Group."Scanned At";
        Issues.Insert();
        Issues.SetView(SavedView);
        case Severity of
            Severity::Error:
                Group."Error Count" += 1;
            Severity::Warning:
                Group."Warning Count" += 1;
            Severity::Information:
                Group."Information Count" += 1;
        end;
    end;

    local procedure EvaluateLedger(var Group: Record "WLF Pool Review Group"; Fact: Record "WLF Pool Review Fact"; var Issues: Record "WLF Pool Review Issue")
    var
        ActualAllocation: Integer;
    begin
        if Fact."Group ID" = Group."Group ID" then begin
            Group."Ledger Count" += 1;
            // Preserve the ledger's own signs, including reversal records.
            Group."All Ledger Kg" += Fact.Kg;
            Group."Ledger Net" += Fact.Amount;
            if Fact."Trans Type" in ['TR', 'TRA', 'TRD'] then
                Group."Movement Kg" += Fact.Kg;

            if (not Fact.Reversed) and (Fact.Amount > 0) and (Fact."Trans Type" in ['PP', 'PPV']) then
                AddIssue(Group, Issues, 'RECOVERY', "WLF Pool Review Severity"::Warning,
                    'Positive payment entry needs recovery review',
                    'This unreversed PP or PPV entry has a positive amount. It may represent a recovery or adjustment. Inspect the payment and linked purchase documents before deciding its treatment. A positive sign alone does not prove an overpayment, incorrect invoice or unpaid recovery.',
                    Fact, 0, Fact.Amount, 'recorded amount');
        end;

        // Populated only for independently attributed sources with multiple active PR matches.
        if (Fact."Invoice Group ID" > 0) and
           ((Fact."Group ID" <> Fact."Invoice Group ID") or
            ((Fact."Pool Code" <> '') and (Fact."Owner Group ID" <> Fact."Invoice Group ID")))
        then begin
            ActualAllocation := Fact."Group ID";
            if ActualAllocation = Fact."Invoice Group ID" then
                ActualAllocation := Fact."Owner Group ID";
            AddIssue(Group, Issues, 'INV-ALLOCATION', "WLF Pool Review Severity"::Error,
                'One of the invoice PR matches is allocated elsewhere',
                StrSubstNo('The invoice source was independently attributed to group %1. This active PR entry records group %2 and pool %3, whose current owner group is %4. At least one nonblank allocation disagrees with the source group. Inspect all matching PR entries and any intentional reassignment before proposing a correction.', Fact."Invoice Group ID", Fact."Group ID", Fact."Pool Code", Fact."Owner Group ID"),
                Fact, Fact."Invoice Group ID", ActualAllocation, 'group ID');
        end;
        // A blank pool is permitted for group charges and contra entries.
        if Fact."Pool Code" <> '' then
            if Fact."Owner Group ID" = 0 then
                AddIssue(Group, Issues, 'POOL-GROUP', "WLF Pool Review Severity"::Error,
                    'Pool ownership could not be matched',
                    StrSubstNo('Ledger pool %1 does not resolve to a pool with an assigned group. The ledger records group %2. Inspect whether the pool is missing or has an unassigned group; this check does not repair either record.', Fact."Pool Code", Fact."Group ID"),
                    Fact, Fact."Owner Group ID", Fact."Group ID", 'group ID')
            else
                if Fact."Owner Group ID" <> Fact."Group ID" then
                    AddIssue(Group, Issues, 'POOL-GROUP', "WLF Pool Review Severity"::Error,
                        'Ledger group differs from its pool group',
                        StrSubstNo('Ledger pool %1 currently belongs to group %2, while this ledger entry records group %3. This is a recorded ownership mismatch. Check posting history and any intentional reassignment before proposing a correction.', Fact."Pool Code", Fact."Owner Group ID", Fact."Group ID"),
                        Fact, Fact."Owner Group ID", Fact."Group ID", 'group ID');

        if (Fact."Pool Code" <> '') and (Fact."Trans Type" in ['PR', 'FR', 'TR', 'TRA', 'TRD']) and
           ((Fact."Expected Classification" = '') or (Fact."Actual Classification" = ''))
        then begin
            Group."Unresolved Sources" += 1;
            AddIssue(Group, Issues, 'CLASS-UNRESOLVED', "WLF Pool Review Severity"::Information,
                'Source classification could not be compared',
                'This PR, FR, TR, TRA or TRD entry has a nonblank pool, but a complete variety/grade/size classification could not be resolved on both the source dimensions and assigned pool. This source comparison was not completed. Inspect the source before deciding whether setup or allocation needs attention.',
                Fact, 0, 0, 'variety / grade / size');
        end;
        if (Fact."Expected Classification" <> '') and (Fact."Actual Classification" <> '') and
           (Fact."Expected Classification" <> Fact."Actual Classification")
        then
            AddIssue(Group, Issues, 'SOURCE-CLASS', "WLF Pool Review Severity"::Error,
                'Source dimensions differ from assigned pool',
                StrSubstNo('The fully resolved source variety/grade/size classification is %1. The assigned pool currently records %2. Inspect the source dimensions, allocation history and pool definition; a changed classification can require review without proving that the original posting was wrong.', Fact."Expected Classification", Fact."Actual Classification"),
                Fact, 0, 0, 'variety / grade / size');
    end;

    local procedure EvaluatePayment(var Group: Record "WLF Pool Review Group"; Fact: Record "WLF Pool Review Fact"; var Issues: Record "WLF Pool Review Issue")
    begin
        Group."Payment Count" += 1;
        if (not Fact.Reversed) and (Fact."Completed At" = 0DT) then
            AddIssue(Group, Issues, 'PAYMENT-OPEN', "WLF Pool Review Severity"::Warning,
                'Payment has no completion timestamp',
                'This unreversed payment header has no completion timestamp. It may still be running, may be an older record from before completion tracking, or may need investigation. Inspect the header and posting evidence before deciding that the payment failed or attempting to resume it.',
                Fact, 0, 0, '');
    end;

    local procedure EvaluateInvoice(var Group: Record "WLF Pool Review Group"; Fact: Record "WLF Pool Review Fact"; var Issues: Record "WLF Pool Review Issue")
    begin
        if not Fact."Attribution Resolved" then begin
            AddIssue(Group, Issues, 'INV-UNRESOLVED', "WLF Pool Review Severity"::Warning,
                'Invoice attribution could not be resolved',
                'This source line is within the scan candidate scope, but its attribution to this pool group could not be established unambiguously. No missing-revenue conclusion is made. Inspect the consignment, season, week, type and dimensions. ' + Fact.Description,
                Fact, 0, 0, '');
            exit;
        end;

        if Fact."Matching Entry Count" = 0 then
            if Fact."Has Invoice State" then
                AddIssue(Group, Issues, 'INV-MISSING', "WLF Pool Review Severity"::Error,
                    'Processed invoice line has no active PR match',
                    'The source line was attributed to this group, and its invoice has a pooling processed-state record, but no unreversed PR entry matched the source identity or permitted legacy document/line identity. This is a completeness mismatch in the checked records. Confirm eligibility, credit/reversal history and timing before any correction.',
                    Fact, 1, 0, 'active PR matches')
            else
                AddIssue(Group, Issues, 'INV-MISSING', "WLF Pool Review Severity"::Warning,
                    'Invoice line has no active PR match',
                    'The source line was attributed to this group, but no unreversed PR entry matched its source identity or permitted legacy document/line identity. There is also no pooling processed-state record for the invoice. Check processing timing, eligibility and credit/reversal history before concluding that revenue is missing.',
                    Fact, 1, 0, 'active PR matches');

        if (Fact."Matching Entry Count" = 1) and (Fact."Owner Group ID" <> Group."Group ID") then
            AddIssue(Group, Issues, 'INV-GROUP', "WLF Pool Review Severity"::Error,
                'Matched invoice PR records a different group',
                StrSubstNo('This source line was uniquely attributed to group %1, but its single active PR match records group %2. Inspect the source and matched ledger entry, including any intentional reassignment, before proposing a correction.', Group."Group ID", Fact."Owner Group ID"),
                Fact, Group."Group ID", Fact."Owner Group ID", 'group ID');
        if Fact."Matching Entry Count" > 1 then
            AddIssue(Group, Issues, 'INV-DUP', "WLF Pool Review Severity"::Warning,
                'Invoice line matches multiple active PR entries',
                'More than one unreversed PR entry matches this source line. Check whether entries are deliberate allocations or adjustments and whether reversal history is complete. Multiple matches alone do not establish duplicated revenue.',
                Fact, 1, Fact."Matching Entry Count", 'active PR matches');

        if Fact."Legacy Match" and (Fact."Matching Entry Count" > 0) then
            AddIssue(Group, Issues, 'INV-LEGACY', "WLF Pool Review Severity"::Warning,
                'PR match uses legacy document and line identity',
                'At least one matching PR uses the exact document number and source line with a blank source SystemId. Inspect its origin and group allocation; legacy identity is reported separately and is not treated as missing revenue. Other matches may use the source SystemId.',
                Fact, 0, 0, '');
    end;
}




