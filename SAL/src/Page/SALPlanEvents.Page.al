page 58005 "SAL Plan Events"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Plan Activity';
    SourceTable = "SAL Plan Event";
    SourceTableView = sorting("Plan No.", "Version No.", "Entry No.") order(descending);
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Events)
            {
                field("Event Date Time"; Rec."Event Date Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the event occurred.';
                }
                field("Event Type"; Rec."Event Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the type of planning event.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies what happened to the plan version.';
                }
                field("User Id"; Rec."User Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who performed the action.';
                }
            }
        }
    }
}
