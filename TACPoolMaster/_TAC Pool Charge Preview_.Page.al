page 50267 "TAC Pool Charge Preview"
{
    PageType = List;
    ApplicationArea = All;
    Caption = 'Will This Pool?';
    SourceTable = "TAC Pool Charge Preview";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Preview)
            {
                field("Production Order No."; Rec."Production Order No.")
                {
                }
                field("Production Order Line No."; Rec."Production Order Line No.")
                {
                }
                field("Row Type"; Rec."Row Type")
                {
                }
                field(Severity; Rec.Severity)
                {
                }
                field(Outcome; Rec.Outcome)
                {
                }
                field(Finding; Rec.Finding)
                {
                }
                field("Output Item No."; Rec."Output Item No.")
                {
                }
                field("Pool Group Code"; Rec."Pool Group Code")
                {
                }
                field("Pool Code"; Rec."Pool Code")
                {
                }
                field("Transaction Type"; Rec."Transaction Type")
                {
                }
                field("Template ID"; Rec."Template ID")
                {
                }
                field("Rate Source"; Rec."Rate Source")
                {
                }
                field("Rate Type"; Rec."Rate Type")
                {
                }
                field(Rate; Rec.Rate)
                {
                }
                field(Units; Rec.Units)
                {
                }
                field(Kgs; Rec.Kgs)
                {
                }
                field("Expected Amount"; Rec."Expected Amount")
                {
                }
                field("GST Amount"; Rec."GST Amount")
                {
                }
                field("Expected Line Charge Total"; Rec."Expected Line Charge Total")
                {
                }
            }
        }
    }
}
