tableextension 50241 "TAC Pool Sales Inv Hdr Ext" extends "Sales Invoice Header"
{
    // Set by 50272 to make consignment posting idempotent (design §7.14).
    fields
    {
        field(50240; "Posted to Pools Flag"; Boolean)
        {
            Caption = 'Posted to Pools';
            DataClassification = CustomerContent;
        }
    }
}
