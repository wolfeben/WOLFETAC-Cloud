page 50251 "TAC Pool Group Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "TAC Pool Group Header";
    Caption = 'Pool Group';
    Editable = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Pool Group Code"; Rec."Pool Group Code")
                {
                }
                field("Pool Week Code"; Rec."Pool Week Code")
                {
                }
                field("Grower Pool Type"; Rec."Grower Pool Type")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field(Description; Rec.Description)
                {
                }
            }
            group(Close)
            {
                Caption = 'Close';

                field("Provisional Close Count"; Rec."Provisional Close Count")
                {
                }
                field("Last Prov. Closed DateTime"; Rec."Last Prov. Closed DateTime")
                {
                }
                field("Final Closed DateTime"; Rec."Final Closed DateTime")
                {
                }
                field("Closed By User"; Rec."Closed By User")
                {
                }
            }
        /*part(Pools; "TAC Pool Subpage")
            {
                Caption = 'Pools';
                SubPageLink = "Pool Group ID" = field("Pool Group ID");
            }*/
        }
    }
    actions
    {
        area(Processing)
        {
            action(ProvisionalClose)
            {
                Caption = 'Provisional Close';
                Image = ReleaseDoc;
                Enabled = Rec.Status <> Rec.Status::Closed;

                trigger OnAction()
                begin
                    RunClose(Rec."Pool Group ID", Enum::"TAC Pool Payment Type"::Provisional, ConfirmProvisionalQst);
                end;
            }
            action(FinalClose)
            {
                Caption = 'Final Close';
                Image = Close;
                Enabled = Rec.Status <> Rec.Status::Closed;

                trigger OnAction()
                begin
                    RunClose(Rec."Pool Group ID", Enum::"TAC Pool Payment Type"::Final, ConfirmFinalQst);
                end;
            }
            action(ResumeLastClose)
            {
                Caption = 'Resume Last Close';
                Image = Refresh;
                Enabled = Rec.Status <> Rec.Status::Closed;
                ToolTip = 'Completes the latest incomplete close after its G/L journal posted but its grower invoices or status update did not complete.';

                trigger OnAction()
                begin
                    RunResumeLastClose(Rec."Pool Group ID");
                end;
            }
            action(PrintPoolReturn)
            {
                Caption = 'Print Pool Return';
                Image = Print;

                trigger OnAction()
                var
                    PoolGroup: Record "TAC Pool Group Header";
                begin
                    PoolGroup:=Rec;
                    PoolGroup.SetRecFilter();
                    Report.Run(Report::"TAC Pool Return", true, false, PoolGroup);
                end;
            }
            action(RunPoolReconciliation)
            {
                ApplicationArea = All;
                Caption = 'Run Pool Reconciliation';
                Image = CheckList;
                Enabled = Rec.Status = Rec.Status::Open;

                trigger OnAction()
                var
                    Reconciliation: Codeunit "TAC Pool Reconciliation";
                    ReconciliationHeader: Record "TAC Pool Reconciliation";
                    ReconciliationID: Integer;
                begin
                    ReconciliationID:=Reconciliation.RunReconciliation(Rec."Pool Group ID");
                    ReconciliationHeader.Get(ReconciliationID);
                    Page.Run(Page::"TAC Pool Reconciliation Card", ReconciliationHeader);
                end;
            }
            action(ViewPoolReconciliations)
            {
                ApplicationArea = All;
                Caption = 'View Pool Reconciliations';
                Image = Entries;
                RunObject = page "TAC Pool Reconciliation List";
                RunPageLink = "Pool Group ID"=field("Pool Group ID");
            }
        }
    /*area(Navigation)
        {
            action(ViewLedgerEntries)
            {
                Caption = 'View Ledger Entries';
                Image = Entries;
                RunObject = page "TAC Pool Ledger Entries";
                RunPageLink = "Pool Group ID" = field("Pool Group ID");
            }
        }*/
    }
    var ConfirmProvisionalQst: Label 'Provisionally close Pool Group %1?', Comment = '%1 = Pool Group Code';
    ConfirmFinalQst: Label 'Finally close Pool Group %1? This cannot be undone.', Comment = '%1 = Pool Group Code';
    ConfirmResumeLastCloseQst: Label 'Resume the last incomplete close for Pool Group %1?', Comment = '%1 = Pool Group Code';
    ClosedMsg: Label 'Pool Group %1 has been closed.', Comment = '%1 = Pool Group Code';
    ResumedCloseMsg: Label 'The last incomplete close for Pool Group %1 has been completed.', Comment = '%1 = Pool Group Code';
    local procedure RunClose(PoolGroupID: Integer; PaymentType: Enum "TAC Pool Payment Type"; Question: Text)
    var
        PoolGroupClose: Codeunit "TAC Pool Group Close";
        ConfirmManagement: Codeunit "Confirm Management";
    begin
        // House SOP: confirm-management, not a raw Confirm().
        if not ConfirmManagement.GetResponseOrDefault(StrSubstNo(Question, Rec."Pool Group Code"), false)then exit;
        PoolGroupClose.Close(PoolGroupID, PaymentType);
        CurrPage.Update(false);
        Message(ClosedMsg, Rec."Pool Group Code");
    end;
    local procedure RunResumeLastClose(PoolGroupID: Integer)
    var
        PoolGroupClose: Codeunit "TAC Pool Group Close";
        ConfirmManagement: Codeunit "Confirm Management";
    begin
        if not ConfirmManagement.GetResponseOrDefault(StrSubstNo(ConfirmResumeLastCloseQst, Rec."Pool Group Code"), false)then exit;
        PoolGroupClose.ResumeLastClose(PoolGroupID);
        CurrPage.Update(false);
        Message(ResumedCloseMsg, Rec."Pool Group Code");
    end;
}
