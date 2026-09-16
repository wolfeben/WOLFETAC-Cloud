page 58013 "SAL Product Group Members"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'SAL Fill Group Members';
    SourceTable = "SAL Product Group Member";
    DelayedInsert = true;
    AutoSplitKey = true;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Members)
            {
                field("Group Code"; Rec."Group Code")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the fill group.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an eligible item.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an eligible item variant.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit used for allocation and validation.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the product or size description.';
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this product or size can be selected for new fill conversions.';
                }
                field(Preference; Rec.Preference)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the preferred matching order. Lower values are considered first.';
                }
                field("Minimum Quantity"; Rec."Minimum Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the minimum allocation for this member.';
                }
                field("Maximum Quantity"; Rec."Maximum Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum allocation for this member.';
                }
                field("Maximum Pallets"; Rec."Maximum Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum pallet-equivalent allocation for this member.';
                }
                field("Default Pallet Quantity"; Rec."Default Pallet Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the standard trays or units per pallet for this member.';
                }
            }
        }
    }
}
