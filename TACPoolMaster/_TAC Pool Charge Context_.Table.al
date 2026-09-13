table 50238 "TAC Pool Charge Context"
{
    Caption = 'Pool Charge Context';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
        }
        field(2; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
        }
        field(3; "Grower Code"; Code[20])
        {
            Caption = 'Grower Code';
        }
        field(4; "Grower Type";Enum "TAC Grower Type")
        {
            Caption = 'Grower Type';
        }
        field(5; "Supplier Type";Enum "TAC Grower Pool Type")
        {
            Caption = 'Supplier Type';
        }
        field(6; "Variety Code"; Code[10])
        {
            Caption = 'Variety Code';
        }
        field(7; "Grade Code"; Code[10])
        {
            Caption = 'Grade Code';
        }
        field(8; "Size Code"; Code[10])
        {
            Caption = 'Size Code';
        }
        field(9; "Pack Type Code"; Code[20])
        {
            Caption = 'Pack Type Code';
        }
        field(10; "Pack Type Category Code"; Code[20])
        {
            Caption = 'Pack Type Category Code';
        }
        field(11; Kgs; Decimal)
        {
            Caption = 'Kgs';
        }
        field(12; Units; Decimal)
        {
            Caption = 'Units';
        }
        field(13; Bins; Decimal)
        {
            Caption = 'Bins';
        }
        field(14; Value; Decimal)
        {
            Caption = 'Value';
        }
        field(15; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer."No.";
        }
        field(16; "Transaction Date"; Date)
        {
            Caption = 'Transaction Date';
        }
        field(17; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(18; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
        }
        field(19; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
        }
        field(20; "Source Item No."; Code[20])
        {
            Caption = 'Source Item No.';
        }
        field(21; Reversal; Boolean)
        {
            Caption = 'Reversal';
        }
        field(22; "Pool Payment ID"; Integer)
        {
            Caption = 'Pool Payment ID';
        }
        field(23; "Source Type";Enum "TAC Pool Source Type")
        {
            Caption = 'Source Type';
        }
        field(24; "Source System ID"; Guid)
        {
            Caption = 'Source System ID';
        }
        field(25; "UOM Code"; Code[20])
        {
            Caption = 'UOM Code';
        }
    }
    keys
    {
        key(PK; "Pool Code", "Grower Code")
        {
            Clustered = true;
        }
    }
}
