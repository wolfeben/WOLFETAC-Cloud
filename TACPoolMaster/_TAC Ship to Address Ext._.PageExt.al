pageextension 50205 "TAC Ship to Address Ext." extends "Ship-to Address"
{
    layout
    {
        addlast(Control3)
        {
            field("TAC Ripening Rate"; Rec."TAC Ripening Rate") { ApplicationArea = All; }
        }
    }
}
