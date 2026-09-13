pageextension 50203 "TAC Sales Inv. Subform Ext." extends "Sales Invoice Subform"
{
    layout
    {
        addlast(control1)
        {
            field("Consignment No."; Rec."Consignment No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
