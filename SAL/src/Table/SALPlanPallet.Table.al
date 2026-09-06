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
            TableRelation = "SAL Plan Header"."No." where("Version No." = field("Version No."));
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
            CalcFormula = count("SAL Plan Component" where("Plan No." = field("Plan No."),
                                                            "Version No." = field("Version No."),
                                                            "Pallet No." = field("Pallet No.")));
            Editable = false;
        }
        field(6; "Version No."; Integer)
        {
            Caption = 'Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 1;
            TableRelation = "SAL Plan Header"."Version No." where("No." = field("Plan No."));
        }
        field(7; "Target Quantity"; Decimal)
        {
            Caption = 'Target Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies the exact planned tray or unit quantity for this physical pallet.';
        }
        field(8; "Planned Quantity"; Decimal)
        {
            Caption = 'Planned Quantity';
            FieldClass = FlowField;
            CalcFormula = sum("SAL Plan Component".Quantity where("Plan No." = field("Plan No."),
                                                                   "Version No." = field("Version No."),
                                                                   "Pallet No." = field("Pallet No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Version No.", "Pallet No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanPallet: Record "SAL Plan Pallet";
    begin
        EnsureDraftParent(PlanHeader);
        PlanHeader.ClearValidation();
        if "Pallet No." = 0 then begin
            PlanPallet.SetRange("Plan No.", "Plan No.");
            PlanPallet.SetRange("Version No.", "Version No.");
            if PlanPallet.FindLast() then
                "Pallet No." := PlanPallet."Pallet No." + 1
            else
                "Pallet No." := 1;
        end;
    end;

    trigger OnModify()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParent(PlanHeader);
        PlanHeader.ClearValidation();
    end;

    trigger OnDelete()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParent(PlanHeader);
        PlanHeader.ClearValidation();
        PlanComponent.SetRange("Plan No.", "Plan No.");
        PlanComponent.SetRange("Version No.", "Version No.");
        PlanComponent.SetRange("Pallet No.", "Pallet No.");
        if not PlanComponent.IsEmpty() then
            Error(PalletInUseErr, "Pallet No.");
    end;

    trigger OnRename()
    begin
        Error(IdentityImmutableErr);
    end;

    local procedure EnsureDraftParent(var PlanHeader: Record "SAL Plan Header")
    begin
        TestField("Plan No.");
        TestField("Version No.");
        PlanHeader.LockTable();
        if not PlanHeader.Get("Plan No.", "Version No.") then
            Error(PlanNotFoundErr, "Plan No.", "Version No.");
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(PlanNotDraftErr, "Plan No.", "Version No.", PlanHeader.Status);
    end;

    var
        IdentityImmutableErr: Label 'Plan pallet identity is immutable. Delete and recreate the pallet while the plan is Draft.';
        PalletInUseErr: Label 'Pallet %1 has components and cannot be deleted.', Comment = '%1 = pallet no.';
        PlanNotDraftErr: Label 'Plan %1 version %2 is %3. Pallets can only be changed on a Draft plan.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
}
