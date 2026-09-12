page 59301 "WLF Pool Review Issues"
{
    Caption = 'Pooling Review Issues';
    PageType = List;
    SourceTable = "WLF Pool Review Issue";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    SourceTableView = sorting("Group ID", Severity) order(descending);

    layout
    {
        area(Content)
        {
            group(Context)
            {
                Caption = 'Review context';
                field(GroupCode; SelectedGroupCode)
                {
                    ApplicationArea = All;
                    Caption = 'Pool Group';
                    ToolTip = 'Specifies the group selected when this issue snapshot was opened.';
                }
                field(SnapshotNotes; SnapshotNotesLbl)
                {
                    ApplicationArea = All;
                    Caption = 'Evidence timing';
                    MultiLine = true;
                    ToolTip = 'Explains that scan findings remain a snapshot while source evidence is read again when opened.';
                }
            }
            repeater(Issues)
            {
                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = SeverityStyle;
                    ToolTip = 'Distinguishes a recorded mismatch, a condition requiring investigation, and an informational or coverage note.';
                }
                field("Rule ID"; Rec."Rule ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Identifies the check that produced this issue so the team can refer to it consistently.';
                }
                field(Summary; Rec.Summary)
                {
                    ApplicationArea = All;
                    ToolTip = 'Describes the condition found. Select the row to see its full explanation and supporting values.';
                }
                field("Pool Code"; Rec."Pool Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the pool associated with the issue, when one is available.';
                }
                field("Grower Code"; Rec."Grower Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the grower associated with the issue, when one is available.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document associated with the issue, when one is available.';
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source document line associated with the issue.';
                }
                field("Payment ID"; Rec."Payment ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the pool payment header associated with the issue, when one is available.';
                }
                field("Scanned At"; Rec."Scanned At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows when the evidence for this finding was collected. Source records may have changed since this time.';
                }
            }
            group(SelectedIssue)
            {
                Caption = 'Selected issue';
                field(SelectedSummary; Rec.Summary)
                {
                    ApplicationArea = All;
                    Caption = 'Summary';
                    MultiLine = true;
                    ToolTip = 'Shows the summary for the currently selected issue.';
                }
                field(Details; Rec.Details)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    ToolTip = 'Explains the triggering evidence, the potential effect and any limits on the conclusion.';
                }
                field(Measure; Rec.Measure)
                {
                    ApplicationArea = All;
                    Caption = 'Comparison';
                    ToolTip = 'Identifies what the expected and actual values compare. If blank, this issue does not contain a numeric comparison.';
                }
                field(Expected; Rec.Expected)
                {
                    ApplicationArea = All;
                    Caption = 'Expected / Reference';
                    ToolTip = 'Shows the expected or reference value for the stated comparison. Use this value only when Comparison is populated.';
                }
                field(Actual; Rec.Actual)
                {
                    ApplicationArea = All;
                    Caption = 'Actual / Observed';
                    ToolTip = 'Shows the observed value for the stated comparison. Use this value only when Comparison is populated.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewSource)
            {
                ApplicationArea = All;
                Caption = 'View Source Evidence';
                Image = View;
                ToolTip = 'Reads the selected issue''s source record into a read-only field snapshot. Current values may differ from the scan evidence.';
                trigger OnAction()
                begin
                    EnsureIssueSelected();
                    if Rec."Evidence Record ID".TableNo() = 0 then
                        Error(NoSourceErr);
                    Reader.ShowEvidence(Rec."Evidence Record ID");
                end;
            }
            action(ViewRelatedSource)
            {
                ApplicationArea = All;
                Caption = 'View Related Evidence';
                Image = View;
                ToolTip = 'Reads a related pool or ledger record into a read-only field snapshot when the scan identified an unambiguous related record.';
                trigger OnAction()
                begin
                    EnsureIssueSelected();
                    if Rec."Related Record ID".TableNo() = 0 then
                        Error(NoRelatedSourceErr);
                    Reader.ShowEvidence(Rec."Related Record ID");
                end;
            }
        }
        area(Promoted)
        {
            actionref(ViewSourcePromoted; ViewSource) { }
            actionref(ViewRelatedSourcePromoted; ViewRelatedSource) { }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Severity of
            Rec.Severity::Error:
                SeverityStyle := 'Unfavorable';
            Rec.Severity::Warning:
                SeverityStyle := 'Attention';
            else
                SeverityStyle := 'Subordinate';
        end;
    end;

    procedure SetIssues(var SourceIssues: Record "WLF Pool Review Issue"; GroupID: Integer; GroupCode: Code[20])
    var
        IssueView: Record "WLF Pool Review Issue";
    begin
        SelectedGroupCode := GroupCode;
        Rec.Reset();
        Rec.DeleteAll();
        // Copy only this group's records so opening filters cannot expose another group's snapshot.
        IssueView.Copy(SourceIssues, true);
        IssueView.Reset();
        IssueView.SetRange("Group ID", GroupID);
        if IssueView.FindSet() then
            repeat
                Rec := IssueView;
                Rec.Insert();
            until IssueView.Next() = 0;
        Rec.Reset();
        Rec.SetCurrentKey("Group ID", Severity);
        Rec.Ascending(false);
        if not Rec.IsEmpty() then
            Rec.FindFirst();
    end;

    local procedure EnsureIssueSelected()
    begin
        if Rec.IsEmpty() then
            Error(SelectIssueErr);
    end;

    var
        Reader: Codeunit "WLF Pool Review Read";
        SelectedGroupCode: Code[20];
        SeverityStyle: Text;
        SnapshotNotesLbl: Label 'These findings are a scan snapshot. View Source Evidence and View Related Evidence read the source again; values may have changed since the scan. Run checks again in Pooling Review after source changes. Coverage notes apply even when there are no mismatches.';
        SelectIssueErr: Label 'Select an issue first. If the list is empty, check the filters and the group''s scan status.';
        NoSourceErr: Label 'This issue has no single source record to open. Read its explanation and the group''s scan detail.';
        NoRelatedSourceErr: Label 'This issue has no unambiguous related source record to open. Read its explanation.';
}