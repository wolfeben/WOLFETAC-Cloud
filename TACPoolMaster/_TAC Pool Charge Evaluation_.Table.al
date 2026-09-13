table 50240 "TAC Pool Charge Evaluation"
{
    Caption = 'Pool Charge Evaluation';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Trans Type Code"; Code[10])
        {
            Caption = 'Transaction Type';
        }
        field(3; Mandatory; Boolean)
        {
            Caption = 'Mandatory';
        }
        field(4; Result; Option)
        {
            Caption = 'Result';
            OptionMembers = Expected, "No Template", "No Match", Ambiguous, Invalid, Ignored, Calculated;
        }
        field(5; "Template ID"; Integer)
        {
            Caption = 'Template ID';
        }
        field(6; "Rate Source";Enum "TAC Pool Rate Source")
        {
            Caption = 'Rate Source';
        }
        field(7; "Rate Type";Enum "TAC Pool Rate Type")
        {
            Caption = 'Rate Type';
        }
        field(8; Rate; Decimal)
        {
            Caption = 'Rate';
        }
        field(9; "Calculation Base"; Decimal)
        {
            Caption = 'Calculation Base';
        }
        field(10; "Expected Amount"; Decimal)
        {
            Caption = 'Expected Amount';
        }
        field(11; "GST Amount"; Decimal)
        {
            Caption = 'GST Amount';
        }
        field(12; Details; Text[250])
        {
            Caption = 'Details';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(TransType; "Trans Type Code")
        {
        }
    }
}
