tableextension 50240 "TAC Pool Customer Ext" extends Customer
{
    // Read by the Charge Engine for Customer-source rates and the ripener
    // condition (design §7.13 / §12 prereqs). Field names follow the design
    // (unprefixed); add a TAC prefix if this ever moves to AppSource.
    fields
    {
        /*field(50240; "Ripening Required"; Boolean)
        {
            Caption = 'Ripening Required';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether this customer requires ripening, which gates ripener charge eligibility.';
        }
        field(50241; "Ripening Rate"; Decimal)
        {
            Caption = 'Ripening Rate';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the rate per unit used for ripener charges.';
        }*/
        field(50242; "Default Settlement Rebate Rate"; Decimal)
        {
            Caption = 'Default Settlement Rebate Rate';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the default rebate rate used for customer-source settlement rebate charges.';
        }
    }
}
