page 50254 "TAC Pool Adjustment"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Tasks;
    SourceTable = "TAC Pool Adjustment";
    Caption = 'Pool Adjustment';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Adjustment ID"; Rec."Adjustment ID")
                {
                    Editable = false;
                }
                field("Date"; Rec."Date")
                {
                }
                field("Pool Group ID"; Rec."Pool Group ID")
                {
                }
                field("Grower Code"; Rec."Grower Code")
                {
                }
                field("From Pool Code"; Rec."From Pool Code")
                {
                }
                field("To Pool Code"; Rec."To Pool Code")
                {
                }
                field(Kgs; Rec.Kgs)
                {
                }
                field(Comment; Rec.Comment)
                {
                }
                field(Posted; Rec.Posted)
                {
                    Editable = false;
                }
                field("Posted By"; Rec."Posted By")
                {
                    Editable = false;
                }
                field("Posted DateTime"; Rec."Posted DateTime")
                {
                    Editable = false;
                }
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
                    PoolAdjustmentPost: Codeunit "TAC Pool Adjustment Post";
                begin
                    PoolAdjustmentPost.PostAdjustment(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
