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
            TableRelation = "SAL Plan Header"."No.";
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
            DataClassification = CustomerContent;
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
    }

    keys
    {
        key(PK; "Plan No.", "Entry No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        TestField("Plan No.");
        if "Event Date Time" = 0DT then
            "Event Date Time" := CurrentDateTime();
        if "User Id" = '' then
            "User Id" := CopyStr(UserId(), 1, MaxStrLen("User Id"));
    end;
}
