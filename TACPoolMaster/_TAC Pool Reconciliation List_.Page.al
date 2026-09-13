page 50268 "TAC Pool Reconciliation List"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'Pool Reconciliations';
    SourceTable = "TAC Pool Reconciliation";
    CardPageId = "TAC Pool Reconciliation Card";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
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
                field("Missing Entry Count"; Rec."Missing Entry Count")
                {
                }
                field("Error Entry Count"; Rec."Error Entry Count")
                {
                }
                field("Created Entry Count"; Rec."Created Entry Count")
                {
                }
            }
        }
    }
}
