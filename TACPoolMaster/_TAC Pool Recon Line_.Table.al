table 50229 "TAC Pool Recon Line"
{
    Caption = 'Pool Reconciliation Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Reconciliation ID"; Integer)
        {
            Caption = 'Reconciliation ID';
            TableRelation = "TAC Pool Reconciliation"."Reconciliation ID";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Source Type";Enum "TAC Pool Recon Source Type")
        {
            Caption = 'Source Type';
        }
        field(4; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
        }
        field(5; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
        }
        field(6; "Source System ID"; Guid)
        {
            Caption = 'Source System ID';
        }
        field(7; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
        }
        field(8; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
        }
        field(9; "Expected Transaction Type"; Code[10])
        {
            Caption = 'Expected Transaction Type';
        }
        field(10; "Expected Entry Type"; Option)
        {
            Caption = 'Expected Entry Type';
            OptionMembers = Revenue, Charge, Freight, Payment, Quantity;
        }
        field(11; "Expected Quantity"; Decimal)
        {
            Caption = 'Expected Quantity';
        }
        field(12; "Expected Kg"; Decimal)
        {
            Caption = 'Expected Kg';
        }
        field(13; "Expected Amount"; Decimal)
        {
            Caption = 'Expected Amount';
        }
        field(14; "Expected GST"; Decimal)
        {
            Caption = 'Expected GST';
        }
        field(15; "Actual Ledger Entry Count"; Integer)
        {
            Caption = 'Actual Ledger Entry Count';
        }
        field(16; "Actual Ledger Amount"; Decimal)
        {
            Caption = 'Actual Ledger Amount';
        }
        field(17; Status;Enum "TAC Pool Recon Line Status")
        {
            Caption = 'Status';
        }
        field(18; Details; Text[250])
        {
            Caption = 'Details';
        }
        field(19; "Created Entry No."; Integer)
        {
            Caption = 'Created Entry No.';
            TableRelation = "TAC Pool Ledger Entry"."Entry No.";
        }
        field(20; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
        }
        field(21; "Created By"; Code[50])
        {
            Caption = 'Created By';
        }
        field(22; "Template ID"; Integer)
        {
            Caption = 'Template ID';
        }
    }
    keys
    {
        key(PK; "Reconciliation ID", "Line No.")
        {
            Clustered = true;
        }
        key(Status; "Reconciliation ID", Status)
        {
        }
        key(Source; "Source Type", "Source System ID", "Source Line No.", "Expected Transaction Type")
        {
        }
    }
}
