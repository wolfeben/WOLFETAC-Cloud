table 50214 "TAC Freight Loc. Market Rule"
{
    Caption = 'Freight Location Market Rule';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Freight Location Code"; Code[20])
        {
            Caption = 'Freight Location Code';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies the freight location this market rule requirement applies to.';
        }
        field(2; "Market Rule Code"; Code[20])
        {
            Caption = 'Market Rule Code';
            TableRelation = "TAC Market Rule".Code;
            ToolTip = 'Specifies the required market rule at this freight location.';
        }
        field(3; Mandatory; Boolean)
        {
            Caption = 'Mandatory';
            ToolTip = 'Specifies whether the market rule is mandatory at this freight location.';
        }
    }

    keys
    {
        key(PK; "Freight Location Code", "Market Rule Code")
        {
            Clustered = true;
        }
    }
}