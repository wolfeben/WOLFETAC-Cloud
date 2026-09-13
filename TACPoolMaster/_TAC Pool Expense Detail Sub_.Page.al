page 50256 "TAC Pool Expense Detail Sub"
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "TAC Pool Expense Detail";
    Caption = 'Pool Expense Detail';
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Line No."; Rec."Line No.")
                {
                    Visible = false;
                }
                field("Pool Code"; Rec."Pool Code")
                {
                }
                field(Amount; Rec.Amount)
                {
                }
            }
        }
    }
}
