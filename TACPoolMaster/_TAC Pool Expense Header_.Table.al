table 50235 "TAC Pool Expense Header"
{
    Caption = 'Pool Expense Header';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Expense ID"; Integer)
        {
            Caption = 'Expense ID';
            AutoIncrement = true;
        }
        field(2; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            TableRelation = "TAC Pool Group Header"."Pool Group ID";
        }
        field(3; "Trans Type"; Code[10])
        {
            Caption = 'Trans Type';
            TableRelation = "TAC Pool Trans Type"."Code" where(Active = const(true));
            // Any Active Trans Type is valid (design §4.6).
        }
        field(4; "Date"; Date)
        {
            Caption = 'Date';
        }
        field(5; Amount; Decimal)
        {
            Caption = 'Amount';
        }
        field(6; Comment; Text[250])
        {
            Caption = 'Comment';
            // Mandatory.
        }
        field(7; Posted; Boolean)
        {
            Caption = 'Posted';
        }
    }

    keys
    {
        key(PK; "Expense ID")
        {
            Clustered = true;
        }
        key(Group; "Pool Group ID")
        {
        }
    }
}
