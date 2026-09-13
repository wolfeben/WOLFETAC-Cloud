table 50211 "TAC Pool Charge Rate"
{
    Caption = 'Pool Charge Rate';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            ToolTip = 'Specifies the unique row number for this charge rate.';
        }
        field(2; "Charge Type Code"; Code[20])
        {
            Caption = 'Charge Type Code';
            TableRelation = "TAC Pool Charge Type".Code;
            ToolTip = 'Specifies the charge type this rate row belongs to.';
        }
        field(3; "Produce Type Code"; Code[20])
        {
            Caption = 'Produce Type Code';
            ToolTip = 'Specifies an optional produce type filter.';
        }
        field(4; "Supplier Type"; Option)
        {
            Caption = 'Supplier Type';
            OptionMembers = " ", Internal, External, Grower;
            ToolTip = 'Specifies an optional supplier type filter for this rate row.';
        }
        field(5; "Grower Type";enum "TAC Grower Pool Type")
        {
            Caption = 'Grower Type';
            ToolTip = 'Specifies an optional grower type filter for this rate row.';
        }
        field(6; "Variety Code"; Code[10])
        {
            Caption = 'Variety Code';
            ToolTip = 'Specifies an optional variety filter for this rate row.';
        }
        field(7; "Pack Type Category"; Code[20])
        {
            Caption = 'Pack Type Category';
            ToolTip = 'Specifies an optional pack type category filter.';
        }
        field(8; "Pack Type Code"; Code[20])
        {
            Caption = 'Pack Type Code';
            ToolTip = 'Specifies an optional pack type code filter.';
        }
        field(9; "Grower No."; Code[20])
        {
            Caption = 'Grower No.';
            TableRelation = Vendor."No.";
            ToolTip = 'Specifies an optional grower filter.';
        }
        field(10; "From Freight Location"; Code[20])
        {
            Caption = 'From Freight Location';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies an optional origin freight location filter.';
        }
        field(11; "To Freight Location"; Code[20])
        {
            Caption = 'To Freight Location';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies an optional destination freight location filter.';
        }
        field(12; "Ripener Code"; Code[20])
        {
            Caption = 'Ripener Code';
            ToolTip = 'Specifies an optional ripener filter.';
        }
        field(13; "Rate Type"; Option)
        {
            Caption = 'Rate Type';
            OptionMembers = Units, Kilograms, Bins, "Value (%)";
            ToolTip = 'Specifies whether this rate is based on units, kilograms, bins, or value percentage.';
        }
        field(14; Rate; Decimal)
        {
            Caption = 'Rate';
            ToolTip = 'Specifies the rate amount or percentage for this row.';
        }
        field(15; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            ToolTip = 'Specifies the date this rate row becomes effective.';
        }
        field(16; "Ending Date"; Date)
        {
            Caption = 'Ending Date';
            ToolTip = 'Specifies the date this rate row expires. Leave blank for open-ended.';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
