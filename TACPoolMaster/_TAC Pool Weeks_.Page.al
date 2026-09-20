page 50259 "TAC Pool Weeks"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "TAC Pool Week";
    Caption = 'Pool Weeks';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Code"; Rec."Code") { }
                field(Description; Rec.Description) { }
                field("Season Code"; Rec."Season Code") { }
                field("Week No."; Rec."Week No.") { }
                field("Start Date"; Rec."Start Date") { }
                field("End Date"; Rec."End Date") { }
                field(Closed; Rec.Closed) { }
            }
        }
    }
}
