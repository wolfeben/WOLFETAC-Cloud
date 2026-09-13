page 50263 "TAC Market Rule"
{
    ApplicationArea = All;
    Caption = 'Market Rule';
    PageType = List;
    SourceTable = "TAC Market Rule";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Code; Rec.Code)
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Rule Type"; Rec."Rule Type")
                {
                }
                field("Requires Expiry Date"; Rec."Requires Expiry Date")
                {
                }
            }
        }
    }
}
