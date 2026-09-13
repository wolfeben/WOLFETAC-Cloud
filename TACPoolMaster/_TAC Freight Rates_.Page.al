page 50201 "TAC Freight Rates"
{
    ApplicationArea = All;
    Caption = 'Freight Rates';
    PageType = List;
    SourceTable = "TAC Freight Rate";
    DelayedInsert = true;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Shipping Agent Code"; Rec."Shipping Agent Code")
                {
                }
                field("From Freight Location"; Rec."From Freight Location")
                {
                }
                field("To Freight Location"; Rec."To Freight Location")
                {
                }
                field("Starting Date"; Rec."Starting Date")
                {
                }
                field("Ending Date"; Rec."Ending Date")
                {
                }
                field("Currency Code"; Rec."Currency Code")
                {
                }
                field("Pallet Space Rate"; Rec."Pallet Space Rate")
                {
                }
                field(Blocked; Rec.Blocked)
                {
                }
            }
        }
    }
}
