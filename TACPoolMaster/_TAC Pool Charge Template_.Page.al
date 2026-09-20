page 50258 "TAC Pool Charge Template"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "TAC Pool Charge Template";
    Caption = 'Pool Charge Template';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(ID; Rec.ID) { }
                field("Trans Type Code"; Rec."Trans Type Code") { }
                field("Charge Action"; Rec."Charge Action") { }
                field(Rate; Rec.Rate) { }
                field("Rate Source"; Rec."Rate Source") { }
                field("Rate Type"; Rec."Rate Type") { }
                field("Charge Level"; Rec."Charge Level") { }
                field("Supplier Type Filter"; Rec."Supplier Type Filter") { }
                field("Grower Type Filter"; Rec."Grower Type Filter") { }
                field("Variety Filter"; Rec."Variety Filter") { }
                field("Pack Type Filter"; Rec."Pack Type Filter") { }
                field("Pack Type Category Filter"; Rec."Pack Type Category Filter") { }
                field("Grade Filter"; Rec."Grade Filter") { }
                field("Grower Code Filter"; Rec."Grower Code Filter") { }
                field("Ripener Required Filter"; Rec."Ripener Required Filter") { }
                field(Mandatory; Rec.Mandatory) { }
                field(Active; Rec.Active) { }
            }
        }
    }
}
