page 58018 "SAL Plan Fill Members"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'Plan Fill Members';
    SourceTable = "SAL Plan Fill Member";
    SourceTableView = sorting("Plan No.", "Version No.", "Source Line No.", "Line No.");
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Members)
            {
                field("Group Code"; Rec."Group Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the fill group captured for this plan version.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows an eligible product captured for this plan version.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the eligible size or variant.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the eligible product description.';
                }
                field("Minimum Quantity"; Rec."Minimum Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the minimum quantity required from this selected member.';
                }
                field("Maximum Quantity"; Rec."Maximum Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum quantity allowed from this selected member. Zero means unlimited.';
                }
                field("Maximum Pallets"; Rec."Maximum Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum pallet-equivalent allocation. Zero means unlimited.';
                }
                field("Default Pallet Quantity"; Rec."Default Pallet Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the standard quantity per pallet captured for this member.';
                }
                field("Planned Quantity"; Rec."Planned Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the quantity currently assigned to this fill member.';
                }
            }
        }
    }
}
