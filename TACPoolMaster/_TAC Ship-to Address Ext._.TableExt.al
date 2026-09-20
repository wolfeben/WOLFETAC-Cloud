tableextension 50205 "TAC Ship-to Address Ext." extends "Ship-to Address"
{
    fields
    {
        field(50200; "TAC Ripening Rate"; Decimal)
        {
            Caption = 'TAC Ripening Rate';
            DataClassification = CustomerContent;
        }
    }
}
