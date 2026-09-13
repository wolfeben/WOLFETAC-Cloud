tableextension 50243 "TAC Pool Shipping Agent Ext" extends "Shipping Agent"
{
    fields
    {
        field(50240; "Fuel Surcharge %"; Decimal)
        {
            Caption = 'Fuel Surcharge %';
            DataClassification = CustomerContent;
            MinValue = 0;
            MaxValue = 100;
            ToolTip = 'Specifies the live fuel surcharge percentage applied during freight cost calculation.';

            trigger OnValidate()
            begin
                "Fuel Surcharge Last Updated":=CurrentDateTime();
                "Fuel Surcharge Updated By":=CopyStr(UserId(), 1, MaxStrLen("Fuel Surcharge Updated By"));
            end;
        }
        field(50241; "Manifest Nos."; Code[20])
        {
            Caption = 'Manifest Nos.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
            ToolTip = 'Specifies the number series used to assign manifest numbers for this carrier.';
        }
        field(50242; "Fuel Surcharge Last Updated"; DateTime)
        {
            Caption = 'Fuel Surcharge Last Updated';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies when the fuel surcharge percentage was last changed.';
        }
        field(50243; "Fuel Surcharge Updated By"; Code[50])
        {
            Caption = 'Fuel Surcharge Updated By';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the user who last changed the fuel surcharge percentage.';
        }
    }
}
