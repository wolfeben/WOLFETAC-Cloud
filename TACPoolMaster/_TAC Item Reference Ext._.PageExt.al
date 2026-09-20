pageextension 50204 "TAC Item Reference Ext." extends "Item Reference List"
{
    layout
    {
        addlast(Control1)
        {
            field("TAC Ripening Item"; Rec."TAC Ripening Item")
            {
                ApplicationArea = All;
            }
        }
    }
}
