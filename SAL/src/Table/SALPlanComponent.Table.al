table 58004 "SAL Plan Component"
{
    Caption = 'SAL Plan Component';
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
            TableRelation = "SAL Plan Pallet"."Pallet No." where("Plan No." = field("Plan No."));
        }
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(4; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            DataClassification = CustomerContent;
            TableRelation = "SAL Plan Source"."Line No." where("Plan No." = field("Plan No."));
        }
        field(5; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
        }
        field(6; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Pallet No.", "Line No.")
        {
            Clustered = true;
        }
        key(BySource; "Plan No.", "Source Line No.")
        {
        }
    }

    trigger OnInsert()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanSource: Record "SAL Plan Source";
        SourceLineNotFoundErr: Label 'Source line %1 does not exist on plan %2.', Comment = '%1 = source line no., %2 = plan no.';
    begin
        TestField("Plan No.");
        TestField("Pallet No.");
        if "Source Line No." <> 0 then begin
            PlanSource.SetRange("Plan No.", "Plan No.");
            PlanSource.SetRange("Line No.", "Source Line No.");
            if PlanSource.IsEmpty() then
                Error(SourceLineNotFoundErr, "Source Line No.", "Plan No.");
        end;
        if "Line No." = 0 then begin
            PlanComponent.SetRange("Plan No.", "Plan No.");
            PlanComponent.SetRange("Pallet No.", "Pallet No.");
            if PlanComponent.FindLast() then
                "Line No." := PlanComponent."Line No." + 10000
            else
                "Line No." := 10000;
        end;
    end;
}
