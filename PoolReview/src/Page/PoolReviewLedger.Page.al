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
            action(OpenNative)
            {
                Caption = 'Open in Business Central'; ApplicationArea = All; Image = Navigate;
                ToolTip = 'Open the actual source page in Business Central. Use the native pop-out button for a separate window. Payment headers open their pool group. Normal BC permissions and actions apply.';
                trigger OnAction()
                var Reader: Codeunit "WLF Pool Review Read";
                begin
                    Reader.OpenNativeSource(Rec."Source Record ID");
                end;
            }
            action(OpenOrigin)
            {
                Caption = 'Open originating document'; ApplicationArea = All; Image = Document;
                ToolTip = 'Open the invoice, credit memo, consignment or expense identified by the stored source line System ID. Reports when no reliable link is available.';
                trigger OnAction()
                var Reader: Codeunit "WLF Pool Review Read";
                begin
                    Reader.OpenOriginatingDocument(Rec."Source Record ID");
                end;
            }

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
        area(Promoted) { actionref(OpenNativePromoted; OpenNative) { } actionref(OpenOriginPromoted; OpenOrigin) { }  actionref(EntryEvidencePromoted; EntryEvidence) { } }
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
