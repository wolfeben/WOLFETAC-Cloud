page 50266 "TAC Pool Payment Schedule"
{
    ApplicationArea = All;
    Caption = 'Pool Payment Schedule';
    PageType = List;
    SourceTable = "TAC Pool Payment Schedule";
    SourceTableView = sorting("Pool Type", "Sequence No.");
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Pool Type"; Rec."Pool Type")
                {
                    ApplicationArea = All;
                }
                field("Sequence No."; Rec."Sequence No.")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field("Offset Weeks"; Rec."Offset Weeks")
                {
                    ApplicationArea = All;
                }
                field("Payment Share %"; Rec."Payment Share %")
                {
                    ApplicationArea = All;
                }
                field("Cumulative Share %"; Rec."Cumulative Share %")
                {
                    ApplicationArea = All;
                }
                field("Is Final"; Rec."Is Final")
                {
                    ApplicationArea = All;
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}