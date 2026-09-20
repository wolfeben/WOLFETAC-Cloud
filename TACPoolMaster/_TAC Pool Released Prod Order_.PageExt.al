pageextension 50244 "TAC Pool Released Prod Order" extends "Released Production Order"
{
    // The same check before finishing, so a packing order can be proved ready
    // to pool rather than found wanting afterwards (50282).

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
            /*action(TACWillThisPool)
            {
                ApplicationArea = All;
                Caption = 'Will This Pool?';
                Image = Track;
                ToolTip = 'Runs the pool posting checks for this order and reports anything that would stop it pooling when it is finished.';

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
