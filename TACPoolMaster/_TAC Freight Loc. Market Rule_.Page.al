page 50265 "TAC Freight Loc. Market Rule"
{
    ApplicationArea = All;
    Caption = 'Freight Location Market Rule';
    PageType = List;
    SourceTable = "TAC Freight Loc. Market Rule";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Freight Location Code"; Rec."Freight Location Code") { }
                field("Market Rule Code"; Rec."Market Rule Code") { }
                field(Mandatory; Rec.Mandatory) { }
            }
        }
    }
}