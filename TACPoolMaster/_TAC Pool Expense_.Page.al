page 50255 "TAC Pool Expense"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    SourceTable = "TAC Pool Expense Header";
    Caption = 'Pool Expense';

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Expense ID"; Rec."Expense ID")
                {
                    Editable = false;
                }
                field("Pool Group ID"; Rec."Pool Group ID")
                {
                }
                field("Trans Type"; Rec."Trans Type")
                {
                }
                field("Date"; Rec."Date")
                {
                }
                field(Amount; Rec.Amount)
                {
                }
                field(Comment; Rec.Comment)
                {
                }
                field(Posted; Rec.Posted)
                {
                    Editable = false;
                }
            }
            part(Lines; "TAC Pool Expense Detail Sub")
            {
                Caption = 'Detail';
                SubPageLink = "Expense ID"=field("Expense ID");
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Post)
            {
                Caption = 'Post';
                Image = PostDocument;

                trigger OnAction()
                var
                    PoolExpensePost: Codeunit "TAC Pool Expense Post";
                begin
                    PoolExpensePost.PostExpense(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
