table 58501 "FBK Portal Site Buffer"
{
    Caption = 'FruitBank Portal Site Buffer';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            DataClassification = CustomerContent;
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
        }
        field(6; "Last Modified Date Time"; DateTime)
        {
            Caption = 'Last Modified Date Time';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }
}
