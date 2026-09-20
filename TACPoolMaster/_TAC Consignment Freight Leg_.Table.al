table 50205 "TAC Consignment Freight Leg"
{
    Caption = 'Consignment Freight Leg';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Consignment No."; Code[20])
        {
            Caption = 'Consignment No.';
            TableRelation = "TAC Consignment Header"."Consignment No.";
            ToolTip = 'Specifies the consignment number for this freight leg.';
        }
        field(2; "Leg No."; Integer)
        {
            Caption = 'Leg No.';
            ToolTip = 'Specifies the sequence number of this freight leg within the consignment.';
            AutoIncrement = true;
        }
        field(3; "Manifest No."; Code[20])
        {
            Caption = 'Manifest No.';
            TableRelation = "TAC Carrier Manifest"."No.";
            ToolTip = 'Specifies the manifest used by this freight leg.';
            NotBlank = true;

            trigger OnValidate()
            begin
                testfield("Manifest No.");
                if "Manifest No." <> xRec."Manifest No." then CalculateFreightCost();
            end;
        }
        field(4; "Shipping Agent Code"; Code[10])
        {
            Caption = 'Shipping Agent Code';
            FieldClass = FlowField;
            CalcFormula = lookup("TAC Carrier Manifest"."Shipping Agent Code" where("No."=field("Manifest No.")));
            Editable = false;
            ToolTip = 'Shows the shipping agent from the linked manifest.';
        }
        field(5; "From Freight Location"; Code[20])
        {
            Caption = 'From Freight Location';
            FieldClass = FlowField;
            CalcFormula = lookup("TAC Carrier Manifest"."From Freight Location" where("No."=field("Manifest No.")));
            Editable = false;
            ToolTip = 'Shows the origin freight location from the linked manifest.';
        }
        field(6; "To Freight Location"; Code[20])
        {
            Caption = 'To Freight Location';
            FieldClass = FlowField;
            CalcFormula = lookup("TAC Carrier Manifest"."To Freight Location" where("No."=field("Manifest No.")));
            Editable = false;
            ToolTip = 'Shows the destination freight location from the linked manifest.';
        }
        field(7; "Pallet Space Rate"; Decimal)
        {
            Caption = 'Pallet Space Rate';
            FieldClass = FlowField;
            CalcFormula = lookup("TAC Carrier Manifest"."Pallet Space Rate" where("No."=field("Manifest No.")));
            Editable = false;
            ToolTip = 'Shows the pallet space rate from the linked manifest.';
        }
        field(8; "Pallet Spaces"; Integer)
        {
            Caption = 'Pallet Spaces';
            ToolTip = 'Specifies the pallet space count for this freight leg.';

            trigger OnValidate()
            begin
                if "Pallet Spaces" <> xRec."Pallet Spaces" then CalculateFreightCost();
            end;
        }
        field(9; "Freight Cost"; Decimal)
        {
            Caption = 'Freight Cost';
            ToolTip = 'Specifies the calculated freight cost for this leg.';
        }
        field(10; "External Reference"; Text[100])
        {
            Caption = 'External Reference';
            ToolTip = 'Specifies an external carrier reference, including free-text docket references.';
        }
    }
    keys
    {
        key(PK; "Consignment No.", "Leg No.")
        {
            Clustered = true;
        }
        key(Manifest; "Manifest No.")
        {
        }
    }
    trigger OnInsert()
    begin
        TestField("Manifest No.");
        TestField("Pallet Spaces");
    //CalculateFreightCost();
    end;
    procedure CalculateFreightCost()
    begin
        CalcFields("Pallet Space Rate");
        "Freight Cost":="Pallet Space Rate" * "Pallet Spaces" * (100 + CalcFuelChargePct()) / 100;
    end;
    procedure CalcFuelChargePct(): Decimal var
        ShippingAgentRec: Record "Shipping Agent";
    begin
        Calcfields("Shipping Agent Code");
        if ShippingAgentRec.Get("Shipping Agent Code")then exit(ShippingAgentRec."Fuel Surcharge %");
        exit(0);
    end;
}
