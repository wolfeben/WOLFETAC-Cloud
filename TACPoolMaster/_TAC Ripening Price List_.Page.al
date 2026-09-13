page 50213 "TAC Ripening Price List"
{
    ApplicationArea = All;
    Caption = 'TAC Ripening Price List';
    PageType = List;
    SourceTable = "TAC Ripening Price";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Customer No."; Rec."Customer No.")
                {
                }
                field("Item No."; Rec."Item No.")
                {
                }
                field("Starting Date"; Rec."Starting Date")
                {
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                }
                field("Unit Price"; Rec."Unit Price")
                {
                }
                field(Active; Rec.Active)
                {
                }
            }
        }
    }
}
