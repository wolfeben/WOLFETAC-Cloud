table 58002 "SAL Plan Source"
{
    Caption = 'SAL Plan Source';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; "Plan No."; Code[20])
        {
            Caption = 'Plan No.';
            DataClassification = CustomerContent;
            TableRelation = "SAL Plan Header"."No.";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Source Type"; Enum "SAL Source Type")
        {
            Caption = 'Source Type';
            DataClassification = CustomerContent;
        }
        field(4; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
            DataClassification = CustomerContent;
        }
        field(5; "Source Document Line No."; Integer)
        {
            Caption = 'Source Document Line No.';
            DataClassification = CustomerContent;
        }
        field(6; "Execution Route"; Enum "SAL Execution Route")
        {
            Caption = 'Execution Route';
            DataClassification = CustomerContent;
        }
        field(7; "Facility Work Type"; Enum "SAL Facility Work Type")
        {
            Caption = 'Facility Work Type';
            DataClassification = CustomerContent;
        }
        field(8; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Line No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        PlanSource: Record "SAL Plan Source";
    begin
        TestField("Plan No.");
        TestField("Source Document No.");
        if "Line No." = 0 then begin
            PlanSource.SetRange("Plan No.", "Plan No.");
            if PlanSource.FindLast() then
                "Line No." := PlanSource."Line No." + 10000
            else
                "Line No." := 10000;
        end;
    end;
}
