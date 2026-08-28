page 58007 "SAL Stock & Logistics Planner"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'SAL Stock & Logistics Planner';
    SourceTable = "SAL Plan Header";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique plan number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a short description of the plan.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the plan.';
                }
                field("Version No."; Rec."Version No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the immutable version number of the plan.';
                }
                field("No. of Sources"; Rec."No. of Sources")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of sources included in this plan.';
                }
                field("No. of Pallets"; Rec."No. of Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of pallets planned for this plan.';
                }
                field("Created Date Time"; Rec."Created Date Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the plan was created.';
                }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec.Status := Rec.Status::Draft;
    end;
}
