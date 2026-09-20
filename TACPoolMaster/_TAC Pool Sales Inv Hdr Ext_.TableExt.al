tableextension 50241 "TAC Pool Sales Inv Hdr Ext" extends "Sales Invoice Header"
{
    fields
    {
        field(50240; "Posted to Pools Flag"; Boolean)
        {
            Caption = 'Posted to Pools';
            DataClassification = CustomerContent;
        }
    }
}
