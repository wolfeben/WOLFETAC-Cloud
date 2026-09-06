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
            TableRelation = "SAL Plan Header"."No." where("Version No." = field("Version No."));
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
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

            trigger OnValidate()
            begin
                "Routing Confirmed" := false;
            end;
        }
        field(7; "Facility Work Type"; Enum "SAL Facility Work Type")
        {
            Caption = 'Facility Work Type';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                "Routing Confirmed" := false;
            end;
        }
        field(8; Quantity; Decimal)
        {
            Caption = 'Required Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(9; "Version No."; Integer)
        {
            Caption = 'Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 1;
            TableRelation = "SAL Plan Header"."Version No." where("No." = field("Plan No."));
        }
        field(10; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
        }
        field(11; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(12; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(13; "Item Description"; Text[100])
        {
            Caption = 'Item Description';
            DataClassification = CustomerContent;
        }
        field(14; "Consignment No."; Code[30])
        {
            Caption = 'Consignment No.';
            DataClassification = CustomerContent;
        }
        field(15; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";
        }
        field(16; Priority; Integer)
        {
            Caption = 'Priority';
            DataClassification = CustomerContent;
            MinValue = 1;
            MaxValue = 10;
        }
        field(17; "Shipment Date"; Date)
        {
            Caption = 'Shipment Date';
            DataClassification = CustomerContent;
        }
        field(18; "Allocated Pallet Quantity"; Decimal)
        {
            Caption = 'Allocated Pallet Quantity';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(19; "Allocated Quantity"; Decimal)
        {
            Caption = 'Allocated Quantity';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(20; "Remaining Quantity Snapshot"; Decimal)
        {
            Caption = 'Remaining Quantity Snapshot';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(21; "Source System Modified At"; DateTime)
        {
            Caption = 'Source System Modified At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(22; "Planned Quantity"; Decimal)
        {
            Caption = 'Planned Quantity';
            FieldClass = FlowField;
            CalcFormula = sum("SAL Plan Component".Quantity where("Plan No." = field("Plan No."),
                                                                   "Version No." = field("Version No."),
                                                                   "Source Line No." = field("Line No.")));
            Editable = false;
        }
        field(23; "Routing Confirmed"; Boolean)
        {
            Caption = 'Routing Confirmed';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that the execution route and facility work type have been explicitly checked for this demand line.';
        }
        field(24; "Customer Name"; Text[100])
        {
            Caption = 'Customer Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(25; "Source Location Code"; Code[10])
        {
            Caption = 'Source Location Code';
            DataClassification = CustomerContent;
            TableRelation = Location.Code;
        }
        field(26; "Destination Code"; Code[20])
        {
            Caption = 'Destination Code';
            DataClassification = CustomerContent;
        }
        field(27; "Destination Name"; Text[100])
        {
            Caption = 'Destination';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Version No.", "Line No.")
        {
            Clustered = true;
            SumIndexFields = Quantity;
        }
        key(BySourceDocument; "Plan No.", "Version No.", "Source Type", "Source Document No.", "Source Document Line No.")
        {
            Unique = true;
        }
    }

    trigger OnInsert()
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        EnsureDraftParent(PlanHeader);
        PlanHeader.ClearValidation();
        TestField("Source Document No.");
        if "Line No." = 0 then begin
            PlanSource.SetRange("Plan No.", "Plan No.");
            PlanSource.SetRange("Version No.", "Version No.");
            if PlanSource.FindLast() then
                "Line No." := PlanSource."Line No." + 10000
            else
                "Line No." := 10000;
        end;
    end;

    trigger OnModify()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParent(PlanHeader);
        if ("Execution Route" <> xRec."Execution Route") or ("Facility Work Type" <> xRec."Facility Work Type") then
            "Routing Confirmed" := false;
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
        PlanComponent.SetRange("Source Line No.", "Line No.");
        if not PlanComponent.IsEmpty() then
            Error(SourceInUseErr, "Line No.");
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
        IdentityImmutableErr: Label 'Plan source identity is immutable. Delete and recreate the line while the plan is Draft.';
        PlanNotDraftErr: Label 'Plan %1 version %2 is %3. Sources can only be changed on a Draft plan.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
        SourceInUseErr: Label 'Source line %1 is used by a pallet component and cannot be deleted.', Comment = '%1 = source line no.';
}
