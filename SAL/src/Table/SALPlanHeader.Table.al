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
            DataClassification = CustomerContent;
            Editable = false;
            MinValue = 1;
        }
        field(5; "No. of Sources"; Integer)
        {
            Caption = 'No. of Sources';
            FieldClass = FlowField;
            CalcFormula = count("SAL Plan Source" where("Plan No." = field("No.")));
            Editable = false;
        }
        field(6; "No. of Pallets"; Integer)
        {
            Caption = 'No. of Pallets';
            FieldClass = FlowField;
            CalcFormula = count("SAL Plan Pallet" where("Plan No." = field("No.")));
            Editable = false;
        }
        field(7; "Created Date Time"; DateTime)
        {
            Caption = 'Created Date Time';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(8; "Released Date Time"; DateTime)
        {
            Caption = 'Released Date Time';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(ByStatus; Status)
        {
        }
    }

    trigger OnInsert()
    begin
        TestField("No.");
        if "Version No." = 0 then
            "Version No." := 1;
        if "Created Date Time" = 0DT then
            "Created Date Time" := CurrentDateTime();
    end;
}
