page 50207 "TAC Pools"
{
    ApplicationArea = All;
    Caption = 'Pools';
    PageType = List;
    SourceTable = "TAC Pool";
    CardPageId = "TAC Pool";
    UsageCategory = Documents;
    Editable = false;
    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Pool Code"; Rec."Pool Code") { }
                field(Description; Rec.Description) { }
                field("Pool Type"; Rec."Pool Type") { }
                field("Pool Week"; Rec."Pool Week") { }
                field(Status; Rec.Status) { }
                field("Gross Value"; Rec."Gross Value") { }
                field("Variety Code"; Rec."Variety Code") { }
                field("Season Code"; Rec."Season Code") { }
                field("Provisional Count"; Rec."Provisional Count") { }
                field("Net Value"; Rec."Net Value") { }
                field("Total Kilograms"; Rec."Total Kilograms") { }
                field("Grower No."; Rec."Grower No.") { }
                field("Payment Model"; Rec."Payment Model") { }
                field("Closed DateTime"; Rec."Closed DateTime") { }
                field("Closed By"; Rec."Closed By") { }
            }
        }
    }
}
