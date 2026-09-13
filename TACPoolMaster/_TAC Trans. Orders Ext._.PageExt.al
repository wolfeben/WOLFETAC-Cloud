pageextension 50202 "TAC Trans. Orders Ext." extends "Transfer Orders"
{
    layout
    {
        addafter("No.")
        {
            field("DIY_Consignment No."; Rec."DIY_Consignment No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
