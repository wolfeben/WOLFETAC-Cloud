table 58500 "FBK Portal Site"
{
    Caption = 'FruitBank Portal Site';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(2; "Display Name"; Text[100])
        {
            Caption = 'Display Name';
            DataClassification = CustomerContent;
        }
        field(3; "Location Code"; Code[10])
        {
            Caption = 'Business Central Location Code';
            DataClassification = CustomerContent;
            TableRelation = Location.Code;
        }
        field(4; "State Code"; Code[10])
        {
            Caption = 'State Code';
            DataClassification = CustomerContent;
        }
        field(5; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
        key(ByLocation; "Location Code")
        {
        }
        key(ByActiveName; Active, "Display Name")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Code, "Display Name", "Location Code", Active)
        {
        }
    }

    trigger OnInsert()
    begin
        TestField(Code);
        if "Display Name" = '' then
            "Display Name" := Code;
    end;
}
