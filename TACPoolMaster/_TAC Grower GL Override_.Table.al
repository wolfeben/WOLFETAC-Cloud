table 50224 "TAC Grower GL Override"
{
    Caption = 'Grower GL Code Override';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Grower GL Overrides";
    DrillDownPageId = "TAC Grower GL Overrides";

    fields
    {
        field(1; "Grower Code"; Code[20])
        {
            Caption = 'Grower Code';
            // A value of the grower dimension (ADR-004). The dimension's Code
            // is configuration, so lookup and validation go through 50280.
            // Sheet 3.6 therefore loads AFTER the grower dimension values.

            trigger OnLookup()
            var
                GrowerMgt: Codeunit "TAC Pool Grower Mgt";
                NewGrowerCode: Code[20];
            begin
                NewGrowerCode := "Grower Code";
                if GrowerMgt.LookupGrowerCode(NewGrowerCode) then
                    Validate("Grower Code", NewGrowerCode);
            end;

            trigger OnValidate()
            var
                GrowerMgt: Codeunit "TAC Pool Grower Mgt";
            begin
                GrowerMgt.ValidateGrowerCode("Grower Code");
            end;
        }
        field(2; "Trans Type Code"; Code[10])
        {
            Caption = 'Trans Type Code';
            TableRelation = "TAC Pool Trans Type"."Code";
        }
        field(3; "Override GL Account"; Code[20])
        {
            Caption = 'Override GL Account';
            TableRelation = "G/L Account"."No.";
        }
    }

    keys
    {
        key(PK; "Grower Code", "Trans Type Code")
        {
            Clustered = true;
        }
    }
}
