table 58000 "SAL Setup"
{
    Caption = 'SAL Setup';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; "Default Pallet Type"; Enum "SAL Pallet Type")
        {
            Caption = 'Default Pallet Type';
            DataClassification = CustomerContent;
        }
        field(3; "Plan Nos."; Code[20])
        {
            Caption = 'Plan Nos.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series".Code;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        if "Primary Key" <> '' then
            Error(SingletonErr);
    end;

    trigger OnRename()
    begin
        Error(SingletonErr);
    end;

    var
        SingletonErr: Label 'Only the single SAL Setup record with a blank primary key is supported.';
}
