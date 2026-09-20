pageextension 50247 "TAC Pool Posted SI Subf Ext" extends "Posted Sales Invoice Subform"
{
    layout
    {
        addlast(Control1)
        {
            field("Consignment No."; Rec."Consignment No.") { ApplicationArea = All; }
            field("Pool Week"; Rec."Pool Week") { ApplicationArea = All; }
            field("Original Item No."; Rec."Original Item No.") { ApplicationArea = All; }
            field("Original Quantity"; Rec."Original Quantity") { ApplicationArea = All; }
        }
    }
}