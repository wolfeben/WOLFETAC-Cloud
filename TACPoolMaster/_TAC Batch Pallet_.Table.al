table 50217 "TAC Batch Pallet"
{
    Caption = 'Batch Pallet';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Batch No."; Code[20])
        {
            Caption = 'Batch No.';
        }
        field(2; "Pallet No."; Code[20])
        {
            Caption = 'Pallet No.';
        }
        field(3; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(4; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(5; Quantity; Decimal)
        {
            Caption = 'Quantity';
        }
        field(6; "Grower No."; Code[20])
        {
            Caption = 'Grower No.';
        }
    }
    keys
    {
        key(PK; "Batch No.", "Pallet No.", "Document No.", "Line No.")
        {
            Clustered = true;
        }
    }
}
