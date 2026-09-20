page 50250 "TAC Pool Group List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "TAC Pool Group Header";
    CardPageId = "TAC Pool Group Card";
    Caption = 'Pool Groups';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Pool Group Code"; Rec."Pool Group Code") { }
                field("Pool Week Code"; Rec."Pool Week Code") { }
                field("Grower Pool Type"; Rec."Grower Pool Type") { }
                field(Status; Rec.Status) { }
                field("Provisional Close Count"; Rec."Provisional Close Count") { }
                field(Description; Rec.Description) { }
            }
        }
    }
}
