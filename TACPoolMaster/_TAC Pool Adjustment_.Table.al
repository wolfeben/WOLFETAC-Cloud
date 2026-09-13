table 50234 "TAC Pool Adjustment"
{
    Caption = 'Pool Adjustment';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Adjustment ID"; Integer)
        {
            Caption = 'Adjustment ID';
            AutoIncrement = true;
        }
        field(2; "Date"; Date)
        {
            Caption = 'Date';
        }
        field(3; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            TableRelation = "TAC Pool Group Header"."Pool Group ID";
        }
        field(4; "Grower Code"; Code[20])
        {
            Caption = 'Grower Code';

            // A value of the grower dimension (ADR-004). The dimension's Code
            // is configuration, so lookup and validation go through 50280
            // rather than a static TableRelation.
            trigger OnLookup()
            var
                GrowerMgt: Codeunit "TAC Pool Grower Mgt";
                NewGrowerCode: Code[20];
            begin
                NewGrowerCode:="Grower Code";
                if GrowerMgt.LookupGrowerCode(NewGrowerCode)then Validate("Grower Code", NewGrowerCode);
            end;
            trigger OnValidate()
            var
                GrowerMgt: Codeunit "TAC Pool Grower Mgt";
            begin
                GrowerMgt.ValidateGrowerCode("Grower Code");
            end;
        }
        field(5; "From Pool Code"; Code[20])
        {
            Caption = 'From Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
        }
        field(6; "To Pool Code"; Code[20])
        {
            Caption = 'To Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
        }
        field(7; Kgs; Decimal)
        {
            Caption = 'Kgs';
        }
        field(8; Comment; Text[250])
        {
            Caption = 'Comment';
        // Mandatory - enforced on post (50274).
        }
        field(9; Posted; Boolean)
        {
            Caption = 'Posted';
        }
        field(10; "Posted By"; Code[50])
        {
            Caption = 'Posted By';
        }
        field(11; "Posted DateTime"; DateTime)
        {
            Caption = 'Posted DateTime';
        }
    }
    keys
    {
        key(PK; "Adjustment ID")
        {
            Clustered = true;
        }
        key(Group; "Pool Group ID")
        {
        }
    }
}
