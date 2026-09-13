page 50257 "TAC Pool Trans Types"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "TAC Pool Trans Type";
    Caption = 'Pool Transaction Types';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Code"; Rec."Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Charge Action"; Rec."Charge Action")
                {
                }
                field("Charge Rate Type"; Rec."Charge Rate Type")
                {
                }
                field("Rate Source"; Rec."Rate Source")
                {
                }
                field("Charge Level"; Rec."Charge Level")
                {
                }
                field("Prorata to Grower Level"; Rec."Prorata to Grower Level")
                {
                }
                field("GST Rate"; Rec."GST Rate")
                {
                }
                field("GL Account Internal"; Rec."GL Account Internal")
                {
                }
                field("GL Account External"; Rec."GL Account External")
                {
                }
                field("Suppress on Grower Invoice"; Rec."Suppress on Grower Invoice")
                {
                }
                field(Mandatory; Rec.Mandatory)
                {
                }
                field(Active; Rec.Active)
                {
                }
            }
        }
    }
}
