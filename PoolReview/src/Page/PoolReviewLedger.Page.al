page 59304 "WLF Pool Review Ledger"
{
    Caption = 'Pooling Linked Ledger Entries';
    PageType = List;
    SourceTable = "WLF Pool Review Fact";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            group(Context)
            {
                field(Source; SourceText) { ApplicationArea = All; Caption = 'Linked source'; }
                field(Coverage; NotesLbl) { ApplicationArea = All; Caption = 'Amounts shown'; MultiLine = true; }
            }
            repeater(Entries)
            {
                field("Fact No."; Rec."Fact No.") { ApplicationArea = All; Caption = 'Entry No.'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Posting Date"; Rec."Posting Date") { ApplicationArea = All; Caption = 'Posting Date'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Trans Type"; Rec."Trans Type") { ApplicationArea = All; Caption = 'Transaction Type'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Amount"; Rec."Amount") { ApplicationArea = All; Caption = 'Amount (signed)'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("GST Amount"; Rec."GST Amount") { ApplicationArea = All; Caption = 'GST Amount (signed)'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Kg"; Rec."Kg") { ApplicationArea = All; Caption = 'Kilograms (signed)'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Grower Code"; Rec."Grower Code") { ApplicationArea = All; Caption = 'Grower Code'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Pool Code"; Rec."Pool Code") { ApplicationArea = All; Caption = 'Pool Code'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Group ID"; Rec."Group ID") { ApplicationArea = All; Caption = 'Group ID'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Payment ID"; Rec."Payment ID") { ApplicationArea = All; Caption = 'Payment ID'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Document No."; Rec."Document No.") { ApplicationArea = All; Caption = 'Source Document No.'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Reversed"; Rec."Reversed") { ApplicationArea = All; Caption = 'Reversed'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Posted to GL"; Rec."Posted to GL") { ApplicationArea = All; Caption = 'Posted to G/L'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("GL Entry No."; Rec."GL Entry No.") { ApplicationArea = All; Caption = 'G/L Entry No.'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
                field("Description"; Rec."Description") { ApplicationArea = All; Caption = 'Comment'; ToolTip = 'Shows the stored source value. Open Entry evidence for the full record.'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(EntryEvidence)
            {
                Caption = 'Entry evidence'; ApplicationArea = All; Image = View;
                ToolTip = 'Open the complete read-only source record, including amount, GST and posting references.';
                trigger OnAction()
                var Reader: Codeunit "WLF Pool Review Read";
                begin
                    Reader.ShowEvidence(Rec."Source Record ID");
                end;
            }
        }
        area(Promoted) { actionref(EntryEvidencePromoted; EntryEvidence) { } }
    }
    procedure SetRows(var Facts: Record "WLF Pool Review Fact"; ContextText: Text)
    begin
        Rec.Copy(Facts, true);
        SourceText := ContextText;
    end;
    var
        SourceText: Text;
        NotesLbl: Label 'Stored signed pool ledger amounts and GST, not bank payments or outstanding balances. All transaction types and reversed entries are included. Payment links use Payment ID; group links use recorded Group ID; pool links use Pool Code. Source permissions apply. This is a current snapshot, not a reconciled payment total.';
}
