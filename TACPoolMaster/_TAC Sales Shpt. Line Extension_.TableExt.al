tableextension 50201 "TAC Sales Shpt. Line Extension" extends "Sales Shipment Line"
{
    fields
    {
        field(50240; "Consignment No."; Code[30])
        {
            Caption = 'Consignment No.';
            ToolTip = 'Specifies the source consignment for pooled product lines. This is required to resolve invoice value back to pools.';
            DataClassification = CustomerContent;
        }
    }
}
