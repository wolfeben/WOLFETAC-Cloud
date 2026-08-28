page 58500 "FruitBank Portal Sites"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'FruitBank Portal Sites';
    SourceTable = "FBK Portal Site";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Sites)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the stable logical site code used by FruitBank.';
                }
                field("Display Name"; Rec."Display Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the site name shown to FruitBank users.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central location represented by this FruitBank site.';
                }
                field("State Code"; Rec."State Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the state code used for FruitBank filtering and display.';
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the site is available through the FruitBank API.';
                }
                field("Last Modified Date Time"; Rec.SystemModifiedAt)
                {
                    ApplicationArea = All;
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                    ToolTip = 'Specifies when the mapping was last changed.';
                }
            }
        }
    }
}
