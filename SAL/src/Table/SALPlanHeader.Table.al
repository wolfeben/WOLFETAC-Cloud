table 58001 "SAL Plan Header"
{
    Caption = 'SAL Plan Header';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; Status; Enum "SAL Plan Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(4; "Version No."; Integer)
        {
            Caption = 'Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 1;
        }
        field(5; "No. of Sources"; Integer)
        {
            Caption = 'No. of Sources';
            FieldClass = FlowField;
            CalcFormula = count("SAL Plan Source" where("Plan No." = field("No."),
                                                         "Version No." = field("Version No.")));
            Editable = false;
        }
        field(6; "No. of Pallets"; Integer)
        {
            Caption = 'No. of Pallets';
            FieldClass = FlowField;
            CalcFormula = count("SAL Plan Pallet" where("Plan No." = field("No."),
                                                         "Version No." = field("Version No.")));
            Editable = false;
        }
        field(7; "Created Date Time"; DateTime)
        {
            Caption = 'Created Date Time';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(8; "Released Date Time"; DateTime)
        {
            Caption = 'Released Date Time';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(9; "Previous Version No."; Integer)
        {
            Caption = 'Previous Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 0;
        }
        field(10; Priority; Integer)
        {
            Caption = 'Priority';
            DataClassification = CustomerContent;
            MinValue = 1;
            MaxValue = 10;
        }
        field(11; "Required Finish Date"; Date)
        {
            Caption = 'Required Finish Date';
            DataClassification = CustomerContent;
        }
        field(12; "Dispatch Date"; Date)
        {
            Caption = 'Dispatch Date';
            DataClassification = CustomerContent;
        }
        field(13; "Marketer Customer No."; Code[20])
        {
            Caption = 'Marketer Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";

            trigger OnValidate()
            var
                Customer: Record Customer;
            begin
                "Marketer Confirmed" := false;
                if "Marketer Customer No." = '' then begin
                    Validate("Marketer Description", '');
                    exit;
                end;

                Customer.Get("Marketer Customer No.");
                Validate("Marketer Description", CopyStr(Customer.Name, 1, MaxStrLen("Marketer Description")));
            end;
        }
        field(14; "Marketer Description"; Text[100])
        {
            Caption = 'Marketer';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the explicitly confirmed commercial marketer. This value is not inferred from customer display text.';

            trigger OnValidate()
            begin
                "Marketer Confirmed" := false;
            end;
        }
        field(15; "Marketer Confirmed"; Boolean)
        {
            Caption = 'Marketer Confirmed';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that the planner has confirmed the commercial marketer for this exact plan version.';
        }
        field(16; "Created By User Id"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(17; "Released By User Id"; Code[50])
        {
            Caption = 'Released By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(18; "Validated Date Time"; DateTime)
        {
            Caption = 'Validated Date Time';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(19; "Validated By User Id"; Code[50])
        {
            Caption = 'Validated By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(20; "Total Required Quantity"; Decimal)
        {
            Caption = 'Total Required Quantity';
            FieldClass = FlowField;
            CalcFormula = sum("SAL Plan Source".Quantity where("Plan No." = field("No."),
                                                                "Version No." = field("Version No.")));
            Editable = false;
        }
        field(21; "Total Planned Quantity"; Decimal)
        {
            Caption = 'Total Planned Quantity';
            FieldClass = FlowField;
            CalcFormula = sum("SAL Plan Component".Quantity where("Plan No." = field("No."),
                                                                   "Version No." = field("Version No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.", "Version No.")
        {
            Clustered = true;
        }
        key(ByStatus; Status, Priority, "Required Finish Date", "No.", "Version No.")
        {
        }
    }

    trigger OnInsert()
    var
        SALSetup: Record "SAL Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            SALSetup.Get();
            SALSetup.TestField("Plan Nos.");
            "No." := NoSeries.GetNextNo(SALSetup."Plan Nos.");
        end;
        TestField("No.");
        if "Version No." = 0 then
            "Version No." := 1;
        if ("Version No." > 1) and not AllowRevisionInsert then
            Error(RevisionInsertErr);
        if Status <> Status::Draft then
            Error(NewPlanMustBeDraftErr);
        if "Created Date Time" = 0DT then
            "Created Date Time" := CurrentDateTime();
        if "Created By User Id" = '' then
            "Created By User Id" := CopyStr(UserId(), 1, MaxStrLen("Created By User Id"));
    end;

    trigger OnModify()
    begin
        if ("No." <> xRec."No.") or ("Version No." <> xRec."Version No.") then
            Error(IdentityImmutableErr);
        if AllowLifecycleTransition then
            exit;
        if Status <> xRec.Status then
            Error(StatusManagedErr);
        if xRec.Status <> xRec.Status::Draft then
            Error(ReleasedImmutableErr, xRec."No.", xRec."Version No.", xRec.Status);
        if DraftContentChanged() then begin
            "Validated Date Time" := 0DT;
            "Validated By User Id" := '';
        end;
    end;

    trigger OnDelete()
    var
        PlanComponent: Record "SAL Plan Component";
        PlanEvent: Record "SAL Plan Event";
        PlanFillMember: Record "SAL Plan Fill Member";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
    begin
        if Status <> Status::Draft then
            Error(ReleasedImmutableErr, "No.", "Version No.", Status);

        PlanSource.SetRange("Plan No.", "No.");
        PlanSource.SetRange("Version No.", "Version No.");
        PlanPallet.SetRange("Plan No.", "No.");
        PlanPallet.SetRange("Version No.", "Version No.");
        PlanComponent.SetRange("Plan No.", "No.");
        PlanComponent.SetRange("Version No.", "Version No.");
        PlanEvent.SetRange("Plan No.", "No.");
        PlanEvent.SetRange("Version No.", "Version No.");
        PlanFillMember.SetRange("Plan No.", "No.");
        PlanFillMember.SetRange("Version No.", "Version No.");
        if not PlanSource.IsEmpty() or not PlanPallet.IsEmpty() or not PlanComponent.IsEmpty() or
           not PlanEvent.IsEmpty() or not PlanFillMember.IsEmpty()
        then
            Error(DeleteChildrenFirstErr);
    end;

    trigger OnRename()
    begin
        Error(IdentityImmutableErr);
    end;

    internal procedure InsertRevision()
    begin
        AllowRevisionInsert := true;
        Insert(true);
        AllowRevisionInsert := false;
    end;

    internal procedure MarkReleased()
    begin
        TestField(Status, Status::Draft);
        AllowLifecycleTransition := true;
        Status := Status::Released;
        "Released Date Time" := CurrentDateTime();
        "Released By User Id" := CopyStr(UserId(), 1, MaxStrLen("Released By User Id"));
        Modify(true);
        AllowLifecycleTransition := false;
    end;

    internal procedure MarkSuperseded()
    begin
        TestField(Status, Status::Released);
        AllowLifecycleTransition := true;
        Status := Status::Superseded;
        Modify(true);
        AllowLifecycleTransition := false;
    end;

    internal procedure MarkCancelled()
    begin
        TestField(Status, Status::Draft);
        AllowLifecycleTransition := true;
        Status := Status::Cancelled;
        Modify(true);
        AllowLifecycleTransition := false;
    end;

    internal procedure ClearValidation()
    begin
        if ("Validated Date Time" = 0DT) and ("Validated By User Id" = '') then
            exit;
        TestField(Status, Status::Draft);
        "Validated Date Time" := 0DT;
        "Validated By User Id" := '';
        Modify(true);
    end;

    local procedure DraftContentChanged(): Boolean
    begin
        exit(
            (Description <> xRec.Description) or
            (Priority <> xRec.Priority) or
            ("Required Finish Date" <> xRec."Required Finish Date") or
            ("Dispatch Date" <> xRec."Dispatch Date") or
            ("Marketer Customer No." <> xRec."Marketer Customer No.") or
            ("Marketer Description" <> xRec."Marketer Description") or
            ("Marketer Confirmed" <> xRec."Marketer Confirmed"));
    end;

    var
        AllowLifecycleTransition: Boolean;
        AllowRevisionInsert: Boolean;
        DeleteChildrenFirstErr: Label 'Delete the plan sources, pallet components, pallets and events before deleting this plan version.';
        IdentityImmutableErr: Label 'The plan number and version are immutable. Create a new plan version instead.';
        NewPlanMustBeDraftErr: Label 'A new plan version must be created in Draft status.';
        ReleasedImmutableErr: Label 'Plan %1 version %2 is %3 and cannot be modified or deleted.', Comment = '%1 = plan no., %2 = version no., %3 = status';
        RevisionInsertErr: Label 'Plan revisions must be created through SAL Plan Management.';
        StatusManagedErr: Label 'Plan status must be changed through SAL Plan Management.';
}
