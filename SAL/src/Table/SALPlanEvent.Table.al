table 58005 "SAL Plan Event"
{
    Caption = 'SAL Plan Event';
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
        field(2; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(3; "Event Date Time"; DateTime)
        {
            Caption = 'Event Date Time';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(4; "Event Type"; Text[50])
        {
            Caption = 'Event Type';
            DataClassification = CustomerContent;
        }
        field(5; "User Id"; Code[50])
        {
            Caption = 'User Id';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(6; Description; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(7; "Version No."; Integer)
        {
            Caption = 'Version No.';
            DataClassification = SystemMetadata;
            Editable = false;
            MinValue = 1;
            TableRelation = "SAL Plan Header"."Version No." where("No." = field("Plan No."));
        }
    }

    keys
    {
        key(PK; "Plan No.", "Version No.", "Entry No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        PlanHeader: Record "SAL Plan Header";
    begin
        TestField("Plan No.");
        TestField("Version No.");
        PlanHeader.LockTable();
        if not PlanHeader.Get("Plan No.", "Version No.") then
            Error(PlanNotFoundErr, "Plan No.", "Version No.");
        if "Event Date Time" = 0DT then
            "Event Date Time" := CurrentDateTime();
        if "User Id" = '' then
            "User Id" := CopyStr(UserId(), 1, MaxStrLen("User Id"));
    end;

    trigger OnModify()
    begin
        Error(AppendOnlyErr);
    end;

    trigger OnDelete()
    begin
        Error(AppendOnlyErr);
    end;

    trigger OnRename()
    begin
        Error(AppendOnlyErr);
    end;

    var
        AppendOnlyErr: Label 'SAL plan events are append-only and cannot be modified, deleted or renamed.';
        PlanNotFoundErr: Label 'Plan %1 version %2 does not exist.', Comment = '%1 = plan no., %2 = version no.';
}
