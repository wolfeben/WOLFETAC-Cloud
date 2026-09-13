page 50209 "TAC Pool Charge Types"
{
    ApplicationArea = All;
    Caption = 'Pool Charge Types';
    PageType = List;
    SourceTable = "TAC Pool Charge Type";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Code"; Rec."Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("G/L Account No."; Rec."G/L Account No.")
                {
                }
                field("Bal. G/L Account No."; Rec."Bal. G/L Account No.")
                {
                }
                field("VAT Bus. Posting Group"; Rec."VAT Bus. Posting Group")
                {
                }
                field("VAT Prod. Posting Group"; Rec."VAT Prod. Posting Group")
                {
                }
                field("Rate Type"; Rec."Rate Type")
                {
                }
                field("Charge Level"; Rec."Charge Level")
                {
                }
                field("Prorata Level"; Rec."Prorata Level")
                {
                }
                field("Trigger Point"; Rec."Trigger Point")
                {
                }
                field(Category; Rec.Category)
                {
                }
                field(Mandatory; Rec.Mandatory)
                {
                }
                field("Suppress from Grower Invoice"; Rec."Suppress from Grower Invoice")
                {
                }
                field(Active; Rec.Active)
                {
                }
            }
        }
    }
}
