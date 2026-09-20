page 50252 "TAC Pool Subpage"
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "TAC Pool";
    Caption = 'Pools';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Variety Code"; Rec."Variety Code") { }
                //field("Grade Code"; Rec."") { }
                //field("Size Code"; Rec."Size Code") { }
                field("Total Kgs"; Rec."Total Kilograms") { }
                field("Net Amount"; Rec."Net Value") { }
                //field("Manual Pool Flag"; Rec."Manual Pool Flag") { }
                field(Description; Rec.Description) { }
            }
        }
    }
}
