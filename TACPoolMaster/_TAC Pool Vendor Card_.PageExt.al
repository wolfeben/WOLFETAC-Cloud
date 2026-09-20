pageextension 50248 "TAC Pool Vendor Card" extends "Vendor Card"
{
    layout
    {
        modify("TAC Grower Code")
        {
            Editable = false;
            ToolTip = 'Shows the Grower Code from this vendor''s Default Dimension for the Grower Dimension Code configured in Pool Payment Setup.';
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(TACSyncGrowerCode)
            {
                ApplicationArea = All;
                Caption = 'Synchronise Grower Code';
                Image = Refresh;
                ToolTip = 'Refreshes the read-only Grower Code from the vendor Default Dimension selected in Pool Payment Setup.';

                trigger OnAction()
                var
                    VendorGrowerSync: Codeunit "TAC Pool Vendor Grower Sync";
                begin
                    VendorGrowerSync.SyncVendor(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
