table 50237 "TAC Pool Grower Charge"
{
    Caption = 'Pool Grower Charge';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Pool Grower Charge ID"; Integer)
        {
            Caption = 'Pool Grower Charge ID';
            AutoIncrement = true;
        }
        field(2; "Pool Payment ID"; Integer)
        {
            Caption = 'Pool Payment ID';
            TableRelation = "TAC Pool Payment Header"."Pool Payment ID";
        // Which close created it.
        }
        field(3; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            TableRelation = "TAC Pool Group Header"."Pool Group ID";
        }
        field(4; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
        // Blank for group-level charges.
        }
        field(5; "Grower Code"; Code[20])
        {
            Caption = 'Grower Code';
        // A value of the grower dimension, not the Vendor No. (ADR-004).
        // No TableRelation — the dimension's Code is configuration. Written
        // only by the close; this table is read-only from the UI.
        }
        field(6; "Trans Type Code"; Code[10])
        {
            Caption = 'Trans Type Code';
            TableRelation = "TAC Pool Trans Type"."Code";
        }
        field(7; Amount; Decimal)
        {
            Caption = 'Amount';
        // Positive = cost to grower.
        }
        field(8; "GST Amount"; Decimal)
        {
            Caption = 'GST Amount';
        }
        field(9; "Source Pool Ledger Entry No."; Integer)
        {
            Caption = 'Source Pool Ledger Entry No.';
            TableRelation = "TAC Pool Ledger Entry"."Entry No.";
        // Audit FK to the pre-proration pool-level amount.
        }
    }
    keys
    {
        key(PK; "Pool Grower Charge ID")
        {
            Clustered = true;
        }
        key(Payment; "Pool Payment ID")
        {
        }
        key(Grower; "Pool Group ID", "Grower Code")
        {
        }
    }
}
