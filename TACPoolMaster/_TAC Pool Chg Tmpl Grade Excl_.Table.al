table 50223 "TAC Pool Chg Tmpl Grade Excl"
{
    Caption = 'Pool Charge Template Grade Exclusion';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Template ID"; Integer)
        {
            Caption = 'Template ID';
            TableRelation = "TAC Pool Charge Template".ID;
        }
        field(2; "Grade Code"; Code[10])
        {
            Caption = 'Grade Code';
        }
        field(3; "Trans Type Code"; Code[10])
        {
            Caption = 'Trans Type Code';
            TableRelation = "TAC Pool Trans Type"."Code";
        }
    }
    keys
    {
        key(PK; "Template ID", "Grade Code")
        {
            Clustered = true;
        }
    }
}
