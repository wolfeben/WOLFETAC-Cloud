table 58006 "SAL Pallet Template"
{
    Caption = 'SAL Pallet Template';
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
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; "Physical Pallet Type"; Code[20])
        {
            Caption = 'Physical Pallet Type';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the physical pallet or air-freight format, such as CHEP, PMC or AKE.';
        }
        field(4; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Pallet Quantity UOM';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
        }
        field(5; "Units per Pallet"; Decimal)
        {
            Caption = 'Units per Pallet';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0.00001;
        }
        field(6; "Mixed Pallet Policy"; Enum "SAL Mixed Pallet Policy")
        {
            Caption = 'Mixed Pallets';
            DataClassification = CustomerContent;
        }
        field(7; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }

    keys
    {
        key(PK; Code) { Clustered = true; }
    }

    trigger OnInsert()
    begin
        ValidateTemplate();
    end;

    trigger OnModify()
    begin
        ValidateTemplate();
    end;

    local procedure ValidateTemplate()
    begin
        TestField(Code);
        TestField("Unit of Measure Code");
        if "Units per Pallet" <= 0 then
            Error(QuantityRequiredErr);
    end;

    var
        QuantityRequiredErr: Label 'Units per pallet must be greater than zero.';
}
