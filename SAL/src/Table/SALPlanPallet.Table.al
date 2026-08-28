table 58003 "SAL Plan Pallet"
{
    Caption = 'SAL Plan Pallet';
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
        field(2; "Pallet No."; Integer)
        {
            Caption = 'Pallet No.';
            DataClassification = CustomerContent;
            MinValue = 1;
        }
        field(3; "Pallet Type"; Enum "SAL Pallet Type")
        {
            Caption = 'Pallet Type';
            DataClassification = CustomerContent;
        }
        field(4; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(5; "No. of Components"; Integer)
        {
            Caption = 'No. of Components';
            FieldClass = FlowField;
            CalcFormula = count("SAL Plan Component" where("Plan No." = field("Plan No."), "Pallet No." = field("Pallet No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Pallet No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        PlanPallet: Record "SAL Plan Pallet";
    begin
        TestField("Plan No.");
        if "Pallet No." = 0 then begin
            PlanPallet.SetRange("Plan No.", "Plan No.");
            if PlanPallet.FindLast() then
                "Pallet No." := PlanPallet."Pallet No." + 1
            else
                "Pallet No." := 1;
        end;
    end;
}
