page 50260 "TAC Grower GL Overrides"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "TAC Grower GL Override";
    Caption = 'Grower GL Overrides';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Grower Code"; Rec."Grower Code")
                {
                }
                field("Trans Type Code"; Rec."Trans Type Code")
                {
                }
                field("Override GL Account"; Rec."Override GL Account")
                {
                }
            }
        }
    }
}
