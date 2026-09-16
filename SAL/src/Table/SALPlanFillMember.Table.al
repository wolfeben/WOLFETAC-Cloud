table 58013 "SAL Plan Fill Member"
{
    Caption = 'SAL Plan Fill Member';
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
        field(2; "Version No."; Integer)
        {
            Caption = 'Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 1;
            TableRelation = "SAL Plan Header"."Version No." where("No." = field("Plan No."));
        }
        field(3; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            DataClassification = CustomerContent;
            TableRelation = "SAL Plan Source"."Line No." where("Plan No." = field("Plan No."),
                                                                 "Version No." = field("Version No."));
        }
        field(4; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(5; "Group Code"; Code[20])
        {
            Caption = 'Fill Group Code';
            DataClassification = CustomerContent;
        }
        field(6; "Template Member Line No."; Integer)
        {
            Caption = 'Template Member Line No.';
            DataClassification = SystemMetadata;
        }
        field(7; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
        }
        field(8; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(9; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(10; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(11; "Minimum Quantity"; Decimal)
        {
            Caption = 'Minimum Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(12; "Maximum Quantity"; Decimal)
        {
            Caption = 'Maximum Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(13; "Maximum Pallets"; Decimal)
        {
            Caption = 'Maximum Pallets';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(14; "Default Pallet Quantity"; Decimal)
        {
            Caption = 'Default Pallet Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(15; Preference; Integer)
        {
            Caption = 'Preference';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
        field(16; "Planned Quantity"; Decimal)
        {
            Caption = 'Planned Quantity';
            FieldClass = FlowField;
            CalcFormula = sum("SAL Plan Component".Quantity where("Plan No." = field("Plan No."),
                                                                   "Version No." = field("Version No."),
                                                                   "Source Line No." = field("Source Line No."),
                                                                   "Fulfilment Mode" = const(FillGroup),
                                                                   "Fill Member Line No." = field("Line No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Version No.", "Source Line No.", "Line No.")
        {
            Clustered = true;
        }
        key(ByProduct; "Plan No.", "Version No.", "Source Line No.", "Item No.", "Variant Code", "Unit of Measure Code")
        {
            Unique = true;
        }
    }

    trigger OnInsert()
    var
        FillMember: Record "SAL Plan Fill Member";
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParentAndSource(PlanHeader);
        PlanHeader.ClearValidation();
        TestField("Item No.");
        TestField("Unit of Measure Code");
        if "Line No." = 0 then begin
            FillMember.SetRange("Plan No.", "Plan No.");
            FillMember.SetRange("Version No.", "Version No.");
            FillMember.SetRange("Source Line No.", "Source Line No.");
            if FillMember.FindLast() then
                "Line No." := FillMember."Line No." + 10000
            else
                "Line No." := 10000;
        end;
        ValidateBounds();
    end;

    trigger OnModify()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParentAndSource(PlanHeader);
        if ("Plan No." <> xRec."Plan No.") or
           ("Version No." <> xRec."Version No.") or
           ("Source Line No." <> xRec."Source Line No.") or
           ("Line No." <> xRec."Line No.") or
           ("Group Code" <> xRec."Group Code") or
           ("Template Member Line No." <> xRec."Template Member Line No.") or
           ("Item No." <> xRec."Item No.") or
           ("Variant Code" <> xRec."Variant Code") or
           ("Unit of Measure Code" <> xRec."Unit of Measure Code") or
           (Description <> xRec.Description) or
           ("Default Pallet Quantity" <> xRec."Default Pallet Quantity") or
           (Preference <> xRec.Preference)
        then
            Error(SnapshotIdentityErr);
        PlanHeader.ClearValidation();
        ValidateBounds();
    end;

    trigger OnDelete()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParentAndSource(PlanHeader);
        PlanHeader.ClearValidation();
        PlanComponent.SetRange("Plan No.", "Plan No.");
        PlanComponent.SetRange("Version No.", "Version No.");
        PlanComponent.SetRange("Source Line No.", "Source Line No.");
        PlanComponent.SetRange("Fulfilment Mode", PlanComponent."Fulfilment Mode"::FillGroup);
        PlanComponent.SetRange("Fill Member Line No.", "Line No.");
        if not PlanComponent.IsEmpty() then
            Error(MemberInUseErr, "Line No.");
    end;

    trigger OnRename()
    begin
        Error(IdentityImmutableErr);
    end;

    local procedure EnsureDraftParentAndSource(var PlanHeader: Record "SAL Plan Header")
    var
        PlanSource: Record "SAL Plan Source";
    begin
        TestField("Plan No.");
        TestField("Version No.");
        TestField("Source Line No.");
        PlanHeader.LockTable();
        if not PlanHeader.Get("Plan No.", "Version No.") then
            Error(PlanNotFoundErr, "Plan No.", "Version No.");
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(PlanNotDraftErr, "Plan No.", "Version No.", PlanHeader.Status);
        if not PlanSource.Get("Plan No.", "Version No.", "Source Line No.") then
            Error(SourceNotFoundErr, "Source Line No.", "Plan No.", "Version No.");
    end;

    local procedure ValidateBounds()
    begin
        if ("Maximum Quantity" > 0) and ("Minimum Quantity" > "Maximum Quantity") then
            Error(MinimumExceedsMaximumErr, "Minimum Quantity", "Maximum Quantity");
        if ("Maximum Pallets" > 0) and ("Default Pallet Quantity" <= 0) then
            Error(PalletQuantityRequiredErr);
    end;

    var
        IdentityImmutableErr: Label 'Plan fill member identity is immutable.';
        MemberInUseErr: Label 'Fill member line %1 is used by a pallet component and cannot be removed.', Comment = '%1 = fill member line no.';
        MinimumExceedsMaximumErr: Label 'Minimum quantity %1 cannot exceed maximum quantity %2.', Comment = '%1 = minimum quantity, %2 = maximum quantity';
        PalletQuantityRequiredErr: Label 'Enter a default pallet quantity before setting a maximum number of pallets.';
        PlanNotDraftErr: Label 'Plan %1 version %2 is %3. Fill members can only be changed on a Draft plan.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
        SourceNotFoundErr: Label 'Source line %1 does not exist on plan %2 version %3.', Comment = '%1 = source line no., %2 = plan no., %3 = version no.';
        SnapshotIdentityErr: Label 'A plan fill member is a versioned snapshot. Only its minimum, maximum and maximum pallets may be changed.';
}
