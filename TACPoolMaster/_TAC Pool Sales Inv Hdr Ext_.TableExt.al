tableextension 50241 "TAC Pool Sales Inv Hdr Ext" extends "Sales Invoice Header"
{
    fields
    {
        field(50113; "DIY_Consignment No."; Code[30])
        {
            Caption = 'Consignment No.';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the consignment number for the sales order, derived from the customer consignment prefix and the sales order number.';
        }
        field(50240; "Posted to Pools Flag"; Boolean)
        {
            Caption = 'Posted to Pools';
            DataClassification = CustomerContent;
        }
    }
}
