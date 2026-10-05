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
        field(4; "Default Packed UOM"; Code[10])
        {
            Caption = 'Default Packed UOM';
            DataClassification = CustomerContent;
            InitValue = 'TE';
            TableRelation = "Unit of Measure".Code;
            ToolTip = 'Specifies the order-line unit that uses the standard packed pallet quantity when no customer or allocation rule matches.';
        }
        field(5; "Default Packed Qty. per Pallet"; Decimal)
        {
            Caption = 'Default Packed Quantity per Pallet';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            InitValue = 160;
            MinValue = 0;
            ToolTip = 'Specifies the standard packed quantity per pallet used after customer, ship-to, item and global allocation rules.';
        }
        field(6; "Default Bulk UOM"; Code[10])
        {
            Caption = 'Default Bulk UOM';
            DataClassification = CustomerContent;
            InitValue = 'BK';
            TableRelation = "Unit of Measure".Code;
            ToolTip = 'Specifies the order-line unit that uses the standard bulk pallet quantity when no customer or allocation rule matches.';
        }
        field(7; "Default Bulk Qty. per Pallet"; Decimal)
        {
            Caption = 'Default Bulk Quantity per Pallet';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            InitValue = 96;
            MinValue = 0;
            ToolTip = 'Specifies the standard bulk quantity per pallet used after customer, ship-to, item and global allocation rules.';
        }
        field(8; "TAC Marketer Customer No."; Code[20])
        {
            Caption = 'TAC Marketer Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";
            ToolTip = 'Specifies the Business Central customer record that represents The Avocados Collective for marketer validation.';
        }
        field(9; "Costa Marketer Customer No."; Code[20])
        {
            Caption = 'Costa Marketer Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";
            ToolTip = 'Specifies the Business Central customer record that represents Costa for marketer validation.';
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

    procedure EnsureStandardDefaults()
    var
        SetupChanged: Boolean;
    begin
        if not Get('') then begin
            Init();
            "Primary Key" := '';
            "Default Pallet Type" := "Default Pallet Type"::Standard;
            "Default Packed UOM" := DefaultPackedUOMTxt;
            "Default Packed Qty. per Pallet" := 160;
            "Default Bulk UOM" := DefaultBulkUOMTxt;
            "Default Bulk Qty. per Pallet" := 96;
            Insert(true);
            exit;
        end;

        if "Default Packed UOM" = '' then begin
            "Default Packed UOM" := DefaultPackedUOMTxt;
            SetupChanged := true;
        end;
        if "Default Packed Qty. per Pallet" = 0 then begin
            "Default Packed Qty. per Pallet" := 160;
            SetupChanged := true;
        end;
        if "Default Bulk UOM" = '' then begin
            "Default Bulk UOM" := DefaultBulkUOMTxt;
            SetupChanged := true;
        end;
        if "Default Bulk Qty. per Pallet" = 0 then begin
            "Default Bulk Qty. per Pallet" := 96;
            SetupChanged := true;
        end;
        if SetupChanged then
            Modify(true);
    end;

    var
        DefaultBulkUOMTxt: Label 'BK', Locked = true;
        DefaultPackedUOMTxt: Label 'TE', Locked = true;
        SingletonErr: Label 'Only the single SAL Setup record with a blank primary key is supported.';
}
