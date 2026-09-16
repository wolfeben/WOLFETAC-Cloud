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
            TableRelation = "SAL Plan Header"."No." where("Version No." = field("Version No."));
        }
        field(2; "Pallet No."; Integer)
        {
            Caption = 'Pallet No.';
            DataClassification = CustomerContent;
            TableRelation = "SAL Plan Pallet"."Pallet No." where("Plan No." = field("Plan No."),
                                                                   "Version No." = field("Version No."));
        }
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(4; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            DataClassification = CustomerContent;
            TableRelation = "SAL Plan Source"."Line No." where("Plan No." = field("Plan No."),
                                                                 "Version No." = field("Version No."));

            trigger OnValidate()
            var
                PlanSource: Record "SAL Plan Source";
            begin
                if "Source Line No." = 0 then
                    exit;

                PlanSource.Get("Plan No.", "Version No.", "Source Line No.");
                "Fulfilment Mode" := "Fulfilment Mode"::ExactSKU;
                "Fill Member Line No." := 0;
                Validate("Item No.", PlanSource."Item No.");
                Validate("Variant Code", PlanSource."Variant Code");
                Validate("Unit of Measure Code", PlanSource."Unit of Measure Code");
                Description := PlanSource."Item Description";
            end;
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
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(7; "Version No."; Integer)
        {
            Caption = 'Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 1;
            TableRelation = "SAL Plan Header"."Version No." where("No." = field("Plan No."));
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
        field(11; "Fulfilment Mode"; Enum "SAL Fulfilment Mode")
        {
            Caption = 'Fulfilment Mode';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if "Fulfilment Mode" = "Fulfilment Mode"::ExactSKU then
                    "Fill Member Line No." := 0;
            end;
        }
        field(12; "Fill Member Line No."; Integer)
        {
            Caption = 'Fill Member Line No.';
            DataClassification = CustomerContent;
            TableRelation = "SAL Plan Fill Member"."Line No." where("Plan No." = field("Plan No."),
                                                                      "Version No." = field("Version No."),
                                                                      "Source Line No." = field("Source Line No."));

            trigger OnValidate()
            var
                FillMember: Record "SAL Plan Fill Member";
            begin
                if "Fill Member Line No." = 0 then
                    exit;

                FillMember.Get("Plan No.", "Version No.", "Source Line No.", "Fill Member Line No.");
                "Fulfilment Mode" := "Fulfilment Mode"::FillGroup;
                Validate("Item No.", FillMember."Item No.");
                Validate("Variant Code", FillMember."Variant Code");
                Validate("Unit of Measure Code", FillMember."Unit of Measure Code");
                Description := FillMember.Description;
            end;
        }
    }

    keys
    {
        key(PK; "Plan No.", "Version No.", "Pallet No.", "Line No.")
        {
            Clustered = true;
            SumIndexFields = Quantity;
        }
        key(BySource; "Plan No.", "Version No.", "Source Line No.")
        {
            SumIndexFields = Quantity;
        }
    }

    trigger OnInsert()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParentAndReferences(PlanHeader);
        PlanHeader.ClearValidation();
        if "Line No." = 0 then begin
            PlanComponent.SetRange("Plan No.", "Plan No.");
            PlanComponent.SetRange("Version No.", "Version No.");
            PlanComponent.SetRange("Pallet No.", "Pallet No.");
            if PlanComponent.FindLast() then
                "Line No." := PlanComponent."Line No." + 10000
            else
                "Line No." := 10000;
        end;
    end;

    trigger OnModify()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParentAndReferences(PlanHeader);
        PlanHeader.ClearValidation();
    end;

    trigger OnDelete()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        EnsureDraftParentAndReferences(PlanHeader);
        PlanHeader.ClearValidation();
    end;

    trigger OnRename()
    begin
        Error(IdentityImmutableErr);
    end;

    local procedure EnsureDraftParentAndReferences(var PlanHeader: Record "SAL Plan Header")
    var
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
    begin
        TestField("Plan No.");
        TestField("Version No.");
        TestField("Pallet No.");
        PlanHeader.LockTable();
        if not PlanHeader.Get("Plan No.", "Version No.") then
            Error(PlanNotFoundErr, "Plan No.", "Version No.");
        if PlanHeader.Status <> PlanHeader.Status::Draft then
            Error(PlanNotDraftErr, "Plan No.", "Version No.", PlanHeader.Status);
        if not PlanPallet.Get("Plan No.", "Version No.", "Pallet No.") then
            Error(PalletNotFoundErr, "Pallet No.", "Plan No.", "Version No.");
        if ("Source Line No." <> 0) and not PlanSource.Get("Plan No.", "Version No.", "Source Line No.") then
            Error(SourceNotFoundErr, "Source Line No.", "Plan No.", "Version No.");
    end;

    var
        IdentityImmutableErr: Label 'Plan component identity is immutable. Delete and recreate the component while the plan is Draft.';
        PalletNotFoundErr: Label 'Pallet %1 does not exist on plan %2 version %3.', Comment = '%1 = pallet no., %2 = plan no., %3 = version no.';
        PlanNotDraftErr: Label 'Plan %1 version %2 is %3. Components can only be changed on a Draft plan.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
        SourceNotFoundErr: Label 'Source line %1 does not exist on plan %2 version %3.', Comment = '%1 = source line no., %2 = plan no., %3 = version no.';
}
