page 50210 "TAC Pool Charge Rates"
{
    ApplicationArea = All;
    Caption = 'Pool Charge Rates';
    PageType = List;
    SourceTable = "TAC Pool Charge Rate";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Entry No."; Rec."Entry No.") { }
                field("Charge Type Code"; Rec."Charge Type Code") { }
                field("Produce Type Code"; Rec."Produce Type Code") { }
                field("Supplier Type"; Rec."Supplier Type") { }
                field("Grower Type"; Rec."Grower Type") { }
                field("Variety Code"; Rec."Variety Code") { }
                field("Pack Type Category"; Rec."Pack Type Category") { }
                field("Pack Type Code"; Rec."Pack Type Code") { }
                field("Grower No."; Rec."Grower No.") { }
                field("From Freight Location"; Rec."From Freight Location") { }
                field("To Freight Location"; Rec."To Freight Location") { }
                field("Ripener Code"; Rec."Ripener Code") { }
                field("Rate Type"; Rec."Rate Type") { }
                field(Rate; Rec.Rate) { }
                field("Starting Date"; Rec."Starting Date") { }
                field("Ending Date"; Rec."Ending Date") { }
            }
        }
    }
}
