tableextension 50245 "TAC Pool Sales Inv Line Ext" extends "Sales Invoice Line"
{
    fields
    {
        field(50240; "Consignment No."; Code[30])
        {
            Caption = 'Consignment No.';
            ToolTip = 'Specifies the source consignment for pooled product lines. This is required to resolve invoice value back to pools.';
            DataClassification = CustomerContent;
        }
        field(50241; "Pool Week"; Integer)
        {
            Caption = 'Pool Week';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the ISO pool week for this invoice line, typically defaulted from the source consignment detail line.';
        }
        field(50242; "Original Item No."; Code[20])
        {
            Caption = 'Original Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
            ToolTip = 'Specifies the original despatched item before any repacking conversion.';
        }
        field(50243; "Original Quantity"; Decimal)
        {
            Caption = 'Original Quantity';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the original despatched quantity used when converting sold lines back to pool-credit basis.';
        }
        field(50244; "Season Code"; Code[20])
        {
            Caption = 'Season Code';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the season code for this invoice line, typically defaulted from the source consignment detail line.';
        }
    }
}
