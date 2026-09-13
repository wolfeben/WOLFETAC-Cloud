page 50269 "TAC Pool Reconciliation Card"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'Pool Reconciliation';
    SourceTable = "TAC Pool Reconciliation";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Reconciliation ID"; Rec."Reconciliation ID")
                {
                }
                field("Pool Group Code"; Rec."Pool Group Code")
                {
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                }
                field("Created By"; Rec."Created By")
                {
                }
                field("As-at DateTime"; Rec."As-at DateTime")
                {
                }
            }
            group(Results)
            {
                field("Found Entry Count"; Rec."Found Entry Count")
                {
                }
                field("Missing Entry Count"; Rec."Missing Entry Count")
                {
                }
                field("Excluded Entry Count"; Rec."Excluded Entry Count")
                {
                }
                field("Error Entry Count"; Rec."Error Entry Count")
                {
                }
                field("Created Entry Count"; Rec."Created Entry Count")
                {
                }
            }
            part(Lines; "TAC Pool Recon Lines")
            {
                SubPageLink = "Reconciliation ID"=field("Reconciliation ID");
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(CreateMissingPoolEntries)
            {
                ApplicationArea = All;
                Caption = 'Create Missing Pool Entries';
                Image = CreateDocument;

                trigger OnAction()
                var
                    Reconciliation: Codeunit "TAC Pool Reconciliation";
                    ConfirmManagement: Codeunit "Confirm Management";
                begin
                    if not ConfirmManagement.GetResponseOrDefault('Create the missing Pool Ledger Entries shown in this reconciliation?', false)then exit;
                    Reconciliation.CreateMissingPoolEntries(Rec."Reconciliation ID");
                    CurrPage.Update(false);
                end;
            }
            action(ViewPoolLedgerEntries)
            {
                ApplicationArea = All;
                Caption = 'View Pool Ledger Entries';
                Image = Entries;
                RunObject = page "TAC Pool Ledger Entries";
                RunPageLink = "Pool Group ID"=field("Pool Group ID");
            }
        }
    }
}
