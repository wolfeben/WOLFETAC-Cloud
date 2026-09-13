page 50200 "TAC Pool Freight Locations"
{
    ApplicationArea = All;
    Caption = 'Pool Freight Locations';
    PageType = List;
    SourceTable = "TAC Freight Location";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Code"; Rec."Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("BC Location Code"; Rec."BC Location Code")
                {
                }
                field("Location Type"; Rec."Location Type")
                {
                }
                field("Is Export"; Rec."Is Export")
                {
                }
                field(Blocked; Rec.Blocked)
                {
                }
                field(State; Rec.State)
                {
                }
            }
        }
    }
}
