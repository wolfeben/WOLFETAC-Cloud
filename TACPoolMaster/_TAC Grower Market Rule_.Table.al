table 50213 "TAC Grower Market Rule"
{
    Caption = 'Grower Market Rule';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Grower No."; Code[20])
        {
            Caption = 'Grower No.';
            TableRelation = Vendor."No.";
            ToolTip = 'Specifies the grower to which the market rule assignment applies.';
        }
        field(2; "Market Rule Code"; Code[20])
        {
            Caption = 'Market Rule Code';
            TableRelation = "TAC Market Rule".Code;
            ToolTip = 'Specifies the market rule assigned to the grower.';
        }
        field(3; Reference; Code[30])
        {
            Caption = 'Reference';
            ToolTip = 'Specifies the accreditation or certificate reference value.';
        }
        field(4; "Expiry Date"; Date)
        {
            Caption = 'Expiry Date';
            ToolTip = 'Specifies the date the grower market rule assignment expires.';
        }
    }
    keys
    {
        key(PK; "Grower No.", "Market Rule Code")
        {
            Clustered = true;
        }
        key(Date; "Expiry Date")
        {
        }
    }
}
