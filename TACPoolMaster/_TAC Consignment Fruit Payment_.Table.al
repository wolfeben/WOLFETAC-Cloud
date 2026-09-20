table 50207 "TAC Consignment Fruit Payment"
{
    Caption = 'Consignment Fruit Payment';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Consignment No."; Code[20])
        {
            Caption = 'Consignment No.';
            TableRelation = "TAC Consignment Header"."Consignment No.";
            ToolTip = 'Specifies the related consignment number.';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            ToolTip = 'Specifies the line number for this fruit payment entry.';
        }
        field(3; "Sales Invoice No."; Code[20])
        {
            Caption = 'Sales Invoice No.';
            TableRelation = "Sales Invoice Header"."No.";
            ToolTip = 'Specifies the posted sales invoice number.';
        }
        field(4; "Customer Invoice Reference"; Code[35])
        {
            Caption = 'Customer Invoice Reference';
            ToolTip = 'Specifies the customer invoice reference, such as the purchase order.';
        }
        field(5; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item."No.";
            ToolTip = 'Specifies the item as sold to the customer.';
        }
        field(6; Quantity; Decimal)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the sold quantity.';
        }
        field(7; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            ToolTip = 'Specifies the unit price from the posted invoice line.';
        }
        field(8; "Original Item No."; Code[20])
        {
            Caption = 'Original Item No.';
            TableRelation = Item."No.";
            ToolTip = 'Specifies the original item despatched before repacking.';
        }
        field(9; "Original Quantity"; Decimal)
        {
            Caption = 'Original Quantity';
            ToolTip = 'Specifies the original despatched quantity before repacking.';
        }
        field(10; "Original Quantity (Kg)"; Decimal)
        {
            Caption = 'Original Quantity (Kg)';
            ToolTip = 'Specifies the original despatched quantity converted to kilograms.';
        }
        field(11; "Pool Week"; Integer)
        {
            Caption = 'Pool Week';
            ToolTip = 'Specifies the pool week credited by this payment.';
        }
        field(12; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
            ToolTip = 'Specifies the pool code credited by this payment.';
        }
        field(13; Amount; Decimal)
        {
            Caption = 'Amount';
            ToolTip = 'Specifies the amount in transaction currency.';
        }
        field(14; "Amount (LCY)"; Decimal)
        {
            Caption = 'Amount (LCY)';
            ToolTip = 'Specifies the amount in local currency.';
        }
        field(15; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            TableRelation = Currency.Code;
            ToolTip = 'Specifies the currency code for the transaction amount.';
        }
        field(16; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Open,Posted;
            ToolTip = 'Specifies whether the fruit payment row is open or posted.';
        }
    }

    keys
    {
        key(PK; "Consignment No.", "Line No.")
        {
            Clustered = true;
        }
        key(Invoice; "Sales Invoice No.")
        {
        }
    }
}