table 50221 "TAC Pool Trans Type"
{
    Caption = 'Pool Transaction Type';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Pool Trans Types";
    DrillDownPageId = "TAC Pool Trans Types";

    fields
    {
        field(1; "Code"; Code[10])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "GST Rate"; Decimal)
        {
            Caption = 'GST Rate';
            DecimalPlaces = 0: 4;
        }
        field(4; "Charge Rate Type";Enum "TAC Pool Rate Type")
        {
            Caption = 'Charge Rate Type';
        }
        field(5; "Rate Source";Enum "TAC Pool Rate Source")
        {
            Caption = 'Rate Source';
        }
        field(6; "Charge Level";Enum "TAC Pool Charge Level")
        {
            Caption = 'Charge Level';
        }
        field(7; "Prorata to Grower Level";Enum "TAC Pool Prorata Level")
        {
            Caption = 'Prorata to Grower Level';
        }
        field(8; "Charge Action";Enum "TAC Pool Charge Action")
        {
            Caption = 'Charge Action';
        }
        field(9; "GL Account Internal"; Code[20])
        {
            Caption = 'GL Account Internal';
            TableRelation = "G/L Account"."No.";
        // Export types (AQIS/SEA/AF/...) carry blank GL accounts until OI-08.
        }
        field(10; "GL Account External"; Code[20])
        {
            Caption = 'GL Account External';
            TableRelation = "G/L Account"."No.";
        }
        field(11; "Suppress on Grower Invoice"; Boolean)
        {
            Caption = 'Suppress on Grower Invoice';
        }
        field(12; Mandatory; Boolean)
        {
            Caption = 'Mandatory';
        }
        field(13; Active; Boolean)
        {
            Caption = 'Active';
        }
    }
    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
        key(Action; "Charge Action", Active)
        {
        }
    }
}
