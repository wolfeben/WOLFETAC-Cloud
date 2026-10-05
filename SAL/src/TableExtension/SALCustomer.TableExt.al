tableextension 58014 "SAL Customer Extension" extends Customer
{
    fields
    {
        field(58002; "SAL Pallet Template Code"; Code[20])
        {
            Caption = 'Pallet Template Code';
            DataClassification = CustomerContent;
            TableRelation = "SAL Pallet Template".Code where(Active = const(true));
            ToolTip = 'Specifies the customer''s default physical pallet format, pallet quantity and mixed-pallet policy.';

            trigger OnValidate()
            var
                PalletTemplate: Record "SAL Pallet Template";
            begin
                if "SAL Pallet Template Code" = '' then
                    exit;
                PalletTemplate.Get("SAL Pallet Template Code");
                PalletTemplate.TestField(Active, true);
                "SAL Units per Pallet" := 0;
                Validate("SAL Pallet Quantity UOM", PalletTemplate."Unit of Measure Code");
                Validate("SAL Units per Pallet", PalletTemplate."Units per Pallet");
                Validate("SAL Mixed Pallet Policy", PalletTemplate."Mixed Pallet Policy");
            end;
        }
        field(58000; "SAL Pallet Quantity UOM"; Code[10])
        {
            Caption = 'Pallet Quantity UOM';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
            ToolTip = 'Specifies the sales-line unit of measure to which this customer''s default pallet quantity applies, such as TE or BK.';

            trigger OnValidate()
            begin
                if ("SAL Pallet Quantity UOM" = '') and ("SAL Units per Pallet" > 0) then
                    Error(PalletUomRequiredErr);
            end;
        }
        field(58001; "SAL Units per Pallet"; Decimal)
        {
            Caption = 'Units per Pallet';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies this customer''s default number of the selected units on one pallet. Detailed customer, ship-to or item rules override this value.';

            trigger OnValidate()
            begin
                if "SAL Units per Pallet" > 0 then
                    TestField("SAL Pallet Quantity UOM");
            end;
        }
        field(58003; "SAL Mixed Pallet Policy"; Enum "SAL Mixed Pallet Policy")
        {
            Caption = 'Mixed Pallets';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether the customer permits mixed product or size pallets. Planner choice preserves the planner''s Allow mixed selection.';
        }
        field(58004; "SAL Physical Pallet Type"; Code[20])
        {
            Caption = 'Physical Pallet Type';
            FieldClass = FlowField;
            CalcFormula = lookup("SAL Pallet Template"."Physical Pallet Type" where(Code = field("SAL Pallet Template Code")));
            Editable = false;
        }
        field(58005; "SAL Labelling Requirements"; Text[1024])
        {
            Caption = 'Known Labelling Requirements';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the customer''s known carton, tray, pallet or dispatch labelling requirements for packing and logistics planning.';
        }
        field(58006; "SAL Special Conditions"; Text[1024])
        {
            Caption = 'Special Conditions';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies known customer handling, packing, temperature or dispatch conditions for stock and logistics planning.';
        }
        field(58007; "SAL Active Pallet Rules"; Integer)
        {
            Caption = 'Active Pallet Rules';
            FieldClass = FlowField;
            CalcFormula = count("SAL Template Rule" where("Customer No." = field("No."), Active = const(true)));
            Editable = false;
            ToolTip = 'Shows the number of active customer, ship-to or item-specific pallet rules for this customer.';
        }
    }

    var
        PalletUomRequiredErr: Label 'Clear Units per Pallet before clearing the Pallet Quantity UOM.';
}
