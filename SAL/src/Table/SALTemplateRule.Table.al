table 58007 "SAL Template Rule"
{
    Caption = 'Customer Pallet Rule';
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
        field(3; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(4; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";
            ToolTip = 'Leave blank for all customers. Use the actual Business Central customer number, not a name match.';
        }
        field(5; "Ship-to Code"; Code[20])
        {
            Caption = 'Ship-to Code';
            DataClassification = CustomerContent;
            TableRelation = "Ship-to Address".Code where("Customer No." = field("Customer No."));
            ToolTip = 'Optional destination override for this customer. Leave blank for all ship-to addresses.';
        }
        field(6; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
            ToolTip = 'Optional exact item override. Leave blank to match the unit of measure for all items.';
        }
        field(7; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            DataClassification = CustomerContent;
            NotBlank = true;
            ToolTip = 'The rule capacity is expressed in this exact Business Central order-line unit; no conversion is assumed.';
        }
        field(8; "Units per Pallet"; Decimal)
        {
            Caption = 'Units per Pallet';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0.00001;
        }
        field(9; "Pallet Template Code"; Code[20])
        {
            Caption = 'Pallet Template Code';
            DataClassification = CustomerContent;
            TableRelation = "SAL Pallet Template".Code where(Active = const(true));
            ToolTip = 'Optionally specifies the physical pallet format and mixed-pallet policy to snapshot onto pallets created by this rule.';

            trigger OnValidate()
            var
                PalletTemplate: Record "SAL Pallet Template";
            begin
                if "Pallet Template Code" = '' then
                    exit;
                PalletTemplate.Get("Pallet Template Code");
                PalletTemplate.TestField(Active, true);
                if "Unit of Measure Code" = '' then
                    "Unit of Measure Code" := PalletTemplate."Unit of Measure Code";
                if "Units per Pallet" = 0 then
                    "Units per Pallet" := PalletTemplate."Units per Pallet";
                "Mixed Pallet Policy" := PalletTemplate."Mixed Pallet Policy";
            end;
        }
        field(10; "Mixed Pallet Policy"; Enum "SAL Mixed Pallet Policy")
        {
            Caption = 'Mixed Pallets';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether this rule permits mixed product or size pallets. Planner choice preserves the planner selection.';
        }
        field(11; "Item Category Code"; Code[20])
        {
            Caption = 'Product Category';
            DataClassification = CustomerContent;
            TableRelation = "Item Category".Code;
            ToolTip = 'Optionally limits the rule to items in this Business Central item category.';
        }
        field(12; "Order Type"; Enum "SAL Rule Order Type")
        {
            Caption = 'Order Type';
            DataClassification = CustomerContent;
        }
        field(13; "Freight Company Code"; Code[10])
        {
            Caption = 'Freight Company';
            DataClassification = CustomerContent;
            TableRelation = "Shipping Agent".Code;
            ToolTip = 'Optionally limits the rule to orders using this freight company.';
        }
        field(14; "Effective From Date"; Date)
        {
            Caption = 'Effective From';
            DataClassification = CustomerContent;
        }
        field(15; "Effective To Date"; Date)
        {
            Caption = 'Effective To';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; Code) { Clustered = true; }
    }

    trigger OnInsert()
    begin
        ValidateRule();
    end;

    trigger OnModify()
    begin
        ValidateRule();
    end;

    local procedure ValidateRule()
    var
        ExistingRule: Record "SAL Template Rule";
    begin
        TestField(Code);
        TestField("Unit of Measure Code");
        if "Units per Pallet" <= 0 then
            Error(QuantityRequiredErr);
        if ("Ship-to Code" <> '') and ("Customer No." = '') then
            Error(CustomerRequiredErr);
        if not Active then
            exit;
        ExistingRule.SetRange(Active, true);
        ExistingRule.SetRange("Customer No.", "Customer No.");
        ExistingRule.SetRange("Ship-to Code", "Ship-to Code");
        ExistingRule.SetRange("Item No.", "Item No.");
        ExistingRule.SetRange("Unit of Measure Code", "Unit of Measure Code");
        ExistingRule.SetRange("Item Category Code", "Item Category Code");
        ExistingRule.SetRange("Order Type", "Order Type");
        ExistingRule.SetRange("Freight Company Code", "Freight Company Code");
        ExistingRule.SetRange("Effective From Date", "Effective From Date");
        ExistingRule.SetRange("Effective To Date", "Effective To Date");
        if ExistingRule.FindSet() then
            repeat
                if ExistingRule.Code <> Code then
                    Error(DuplicateRuleErr, ExistingRule.Code);
            until ExistingRule.Next() = 0;
        if ("Effective From Date" <> 0D) and ("Effective To Date" <> 0D) and
           ("Effective From Date" > "Effective To Date")
        then
            Error(EffectiveDateErr);
    end;

    var
        CustomerRequiredErr: Label 'Choose a customer before setting a ship-to code.';
        DuplicateRuleErr: Label 'Active rule %1 already covers this same customer, ship-to, item and unit of measure.', Comment = '%1 = existing rule code';
        EffectiveDateErr: Label 'Effective From cannot be later than Effective To.';
        QuantityRequiredErr: Label 'Units per pallet must be greater than zero.';
}
