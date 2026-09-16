page 58012 "SAL Product Groups"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'SAL Fill Groups';
    SourceTable = "SAL Product Group";
    AdditionalSearchTerms = 'SAL,Fill Order,Flexible Order,Product Group,WebSAM';

    layout
    {
        area(Content)
        {
            repeater(Groups)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reusable fill group code.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name shown to planners.';
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether planners may select this group.';
                }
                field("Marketer Customer No."; Rec."Marketer Customer No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the marketer allowed to use this group.';
                }
                field("Marketer Description"; Rec."Marketer Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the marketer name.';
                }
                field("Allow Mixed Pallets"; Rec."Allow Mixed Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether mixed physical pallets are allowed.';
                }
                field("Default Pallet Quantity"; Rec."Default Pallet Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the group-level default trays or units per pallet.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Members)
            {
                ApplicationArea = All;
                Caption = 'Eligible Products and Sizes';
                Image = ItemGroup;
                RunObject = page "SAL Product Group Members";
                RunPageLink = "Group Code" = field(Code);
                ToolTip = 'Define every item, size and allocation cap that may satisfy this fill group.';
            }
        }
        area(Promoted)
        {
            actionref(MembersPromoted; Members)
            {
            }
        }
    }
}
