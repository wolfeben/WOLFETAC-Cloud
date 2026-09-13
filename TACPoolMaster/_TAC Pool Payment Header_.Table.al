table 50233 "TAC Pool Payment Header"
{
    Caption = 'Pool Payment Header';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Pool Payment ID"; Integer)
        {
            Caption = 'Pool Payment ID';
            AutoIncrement = true;
        }
        field(2; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            TableRelation = "TAC Pool Group Header"."Pool Group ID";
        }
        field(3; "Payment Type";Enum "TAC Pool Payment Type")
        {
            Caption = 'Payment Type';
        }
        field(4; "Payment No."; Integer)
        {
            Caption = 'Payment No.';
        // Sequential within the Pool Group.
        }
        field(5; "Closed DateTime"; DateTime)
        {
            Caption = 'Closed DateTime';
        }
        field(6; "Closed By User"; Code[50])
        {
            Caption = 'Closed By User';
        }
        field(7; "GL Journal Batch Name"; Code[10])
        {
            Caption = 'GL Journal Batch Name';
        // Stored for compensating reversal (ADR-001).
        }
        field(8; Reversed; Boolean)
        {
            Caption = 'Reversed';
        }
        field(9; "Reversed By Payment ID"; Integer)
        {
            Caption = 'Reversed By Payment ID';
        }
        field(10; "Created Purchase Invoice Nos."; Text[250])
        {
            Caption = 'Created Purchase Invoice Nos.';
        // Comma list of posted grower Purchase Invoice Nos. so a failed
        // close can be reversed and a final close can apply the prior
        // provisional invoices (ADR-001/002).
        }
        field(11; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            ToolTip = 'The pool code for which this payment was generated.';
            TableRelation = "TAC Pool"."Pool Code";
        }
        field(12; Provisional; Boolean)
        {
            Caption = 'Provisional';
            ToolTip = 'Indicates whether this payment is provisional or final.';
        }
        field(13; "Completed DateTime"; DateTime)
        {
            Caption = 'Completed DateTime';
            ToolTip = 'Specifies when this payment run completed, including the Pool Group status update.';
            Editable = false;
        }
        field(14; "Completed By User"; Code[50])
        {
            Caption = 'Completed By User';
            ToolTip = 'Specifies the user who completed this payment run.';
            Editable = false;
        }
    }
    keys
    {
        key(PK; "Pool Payment ID")
        {
            Clustered = true;
        }
        key(Group; "Pool Group ID", "Payment No.")
        {
        }
    }
}
