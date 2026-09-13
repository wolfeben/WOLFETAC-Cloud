pageextension 50242 "TAC Pool Customer Card Ext" extends "Customer Card"
{
    layout
    {
        addafter(Invoicing)
        {
            group(PoolPayment)
            {
                Caption = 'Pool Payment';

                /*field("Ripening Required"; Rec."Ripening Required")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether ripening charges (RIP/RAD) apply to this customer''s consignments, subject to the pack type being a tray type.';
                }
                field("Ripening Rate"; Rec."Ripening Rate")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the rate the Charge Engine uses for ripening charges when Ripening Required is set.';
                }*/
                field("Default Settlement Rebate Rate"; Rec."Default Settlement Rebate Rate")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the rate the Charge Engine uses for settlement rebate charges (SR/WR/DR).';
                }
            }
        }
    }
}
