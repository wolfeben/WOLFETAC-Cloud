pageextension 50243 "TAC Pool Finished Prod Order" extends "Finished Production Order"
{
    // Where a user first notices that a packing order did not pool: the
    // finished order itself. The action explains why (50282).

    actions
    {
        addlast(processing)
        {
            action(TACWillThisPool)
            {
                ApplicationArea = All;
                Caption = 'Will This Pool?';
                Image = ViewDetails;
                ToolTip = 'Shows, without posting anything, how each production output line would be evaluated for pooling.';

                trigger OnAction()
                var
                    PoolPreview: Codeunit "TAC Pool Preview";
                begin
                    PoolPreview.ShowPreview(Rec."No.");
                end;
            }
            /*action(TACWhyDidntThisPool)
            {
                ApplicationArea = All;
                Caption = 'Why Didn''t This Pool?';
                Image = Track;
                ToolTip = 'Runs the pool posting checks for this order and reports the first condition that stopped it, with the quantities and dimensions actually found.';

                trigger OnAction()
                var
                    PoolPostDiagnostic: Codeunit "TAC Pool Post Diagnostic";
                begin
                    PoolPostDiagnostic.ShowExplanation(Rec."No.");
                end;
            }*/
        }
    }
}
