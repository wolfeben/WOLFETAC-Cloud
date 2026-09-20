page 50264 "TAC Grower Market Rule"
{
    ApplicationArea = All;
    Caption = 'Grower Market Rule';
    PageType = List;
    SourceTable = "TAC Grower Market Rule";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Grower No."; Rec."Grower No.") { }
                field("Market Rule Code"; Rec."Market Rule Code") { }
                field(Reference; Rec.Reference) { }
                field("Expiry Date"; Rec."Expiry Date") { }
            }
        }
    }
}