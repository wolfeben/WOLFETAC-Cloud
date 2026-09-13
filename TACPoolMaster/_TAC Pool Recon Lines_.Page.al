page 50270 "TAC Pool Recon Lines"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Reconciliation Lines';
    SourceTable = "TAC Pool Recon Line";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Source Type"; Rec."Source Type")
                {
                }
                field("Source Document No."; Rec."Source Document No.")
                {
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                }
                field("Pool Code"; Rec."Pool Code")
                {
                }
                field("Expected Transaction Type"; Rec."Expected Transaction Type")
                {
                }
                field("Expected Entry Type"; Rec."Expected Entry Type")
                {
                }
                field("Expected Quantity"; Rec."Expected Quantity")
                {
                }
                field("Expected Kg"; Rec."Expected Kg")
                {
                }
                field("Expected Amount"; Rec."Expected Amount")
                {
                }
                field("Expected GST"; Rec."Expected GST")
                {
                }
                field("Actual Ledger Entry Count"; Rec."Actual Ledger Entry Count")
                {
                }
                field("Actual Ledger Amount"; Rec."Actual Ledger Amount")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field(Details; Rec.Details)
                {
                }
                field("Created Entry No."; Rec."Created Entry No.")
                {
                }
            }
        }
    }
}
