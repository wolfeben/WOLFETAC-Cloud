pageextension 50242 "TAC Pool Customer Card Ext" extends "Customer Card"
{
    // Surfaces the pool fields added by table extension 50240 so they can be
    // maintained in the UI. Not in the design's object inventory (which listed
    // only the table extension); added so the Charge Engine's Customer-source
    // rates and the ripener condition (F-05) have an entry point.
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
