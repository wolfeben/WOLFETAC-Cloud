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
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
