table 50236 "TAC Pool Expense Detail"
{
    Caption = 'Pool Expense Detail';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Expense ID"; Integer)
        {
            Caption = 'Expense ID';
            TableRelation = "TAC Pool Expense Header"."Expense ID";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
        }
        field(4; Amount; Decimal)
        {
            Caption = 'Amount';
        }
    }

    keys
    {
        key(PK; "Expense ID", "Line No.")
        {
            Clustered = true;
        }
    }
}
