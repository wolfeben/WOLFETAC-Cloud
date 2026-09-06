page 58001 "SAL Plans"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Stock & Logistics Plans';
    SourceTable = "SAL Plan Header";
    SourceTableView = sorting(Status, Priority, "Required Finish Date", "No.", "Version No.");
    CardPageId = "SAL Stock & Logistics Planner";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Plans)
            {
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the lifecycle state of this exact plan version.';
                }
                field(Priority; Rec.Priority)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the plan priority from 1 to 10.';
                }
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the stock and logistics plan number.';
                }
                field("Version No."; Rec."Version No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the immutable plan version.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the plan description.';
                }
                field("Marketer Description"; Rec."Marketer Description")
                {
                    ApplicationArea = All;
                    Caption = 'Marketer';
                    ToolTip = 'Specifies the confirmed commercial marketer.';
                }
                field("Required Finish Date"; Rec."Required Finish Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the stock must be ready.';
                }
                field("Dispatch Date"; Rec."Dispatch Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the planned dispatch date.';
                }
                field("No. of Sources"; Rec."No. of Sources")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of demand source lines.';
                }
                field("No. of Pallets"; Rec."No. of Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of physical pallets.';
                }
                field("Total Required Quantity"; Rec."Total Required Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total required quantity.';
                }
                field("Total Planned Quantity"; Rec."Total Planned Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total quantity planned into pallets.';
                }
                field("Created Date Time"; Rec."Created Date Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this version was created.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Draft:
                StatusStyle := 'Attention';
            Rec.Status::Released:
                StatusStyle := 'Favorable';
            Rec.Status::Superseded:
                StatusStyle := 'Subordinate';
            Rec.Status::Cancelled:
                StatusStyle := 'Unfavorable';
        end;
    end;

    var
        StatusStyle: Text;
}
