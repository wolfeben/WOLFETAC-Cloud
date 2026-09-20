tableextension 50204 "TAC Item Reference Ext." extends "Item Reference"
{
    fields
    {
        field(50200; "TAC Ripening Item"; Boolean)
        {
            Caption = 'Ripening Item';
            DataClassification = CustomerContent;
            ToolTip = 'Indicates whether the item is used for ripening.';
        }
    }
}
