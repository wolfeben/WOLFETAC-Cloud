table 50228 "TAC Pool Reconciliation"
{
    Caption = 'Pool Reconciliation';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Pool Reconciliation List";
    DrillDownPageId = "TAC Pool Reconciliation List";

    fields
    {
        field(1; "Reconciliation ID"; Integer)
        {
            Caption = 'Reconciliation ID';
            AutoIncrement = true;
        }
        field(2; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            TableRelation = "TAC Pool Group Header"."Pool Group ID";
        }
        field(3; "Pool Group Code"; Code[20])
        {
            Caption = 'Pool Group Code';
        }
        field(4; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
        }
        field(5; "Created By"; Code[50])
        {
            Caption = 'Created By';
        }
        field(6; "As-at DateTime"; DateTime)
        {
            Caption = 'As-at DateTime';
        }
        field(7; "Missing Entry Count"; Integer)
        {
            Caption = 'Missing Entry Count';
        }
        field(8; "Found Entry Count"; Integer)
        {
            Caption = 'Found Entry Count';
        }
        field(9; "Excluded Entry Count"; Integer)
        {
            Caption = 'Excluded Entry Count';
        }
        field(10; "Error Entry Count"; Integer)
        {
            Caption = 'Error Entry Count';
        }
        field(11; "Created Entry Count"; Integer)
        {
            Caption = 'Created Entry Count';
        }
    }
    keys
    {
        key(PK; "Reconciliation ID")
        {
            Clustered = true;
        }
        key(Group; "Pool Group ID", "Created DateTime")
        {
        }
    }
}
