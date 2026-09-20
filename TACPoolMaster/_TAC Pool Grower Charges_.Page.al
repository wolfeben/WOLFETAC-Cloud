page 50261 "TAC Pool Grower Charges"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "TAC Pool Grower Charge";
    Caption = 'Pool Grower Charges';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Pool Grower Charge ID"; Rec."Pool Grower Charge ID") { }
                field("Pool Payment ID"; Rec."Pool Payment ID") { }
                field("Pool Group ID"; Rec."Pool Group ID") { }
                field("Pool Code"; Rec."Pool Code") { }
                field("Grower Code"; Rec."Grower Code") { }
                field("Trans Type Code"; Rec."Trans Type Code") { }
                field(Amount; Rec.Amount) { }
                field("GST Amount"; Rec."GST Amount") { }
                field("Source Pool Ledger Entry No."; Rec."Source Pool Ledger Entry No.") { }
            }
        }
    }
}
