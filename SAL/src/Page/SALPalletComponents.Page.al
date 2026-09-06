page 58004 "SAL Pallet Components"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Pallet Components';
    SourceTable = "SAL Plan Component";
    SourceTableView = sorting("Plan No.", "Version No.", "Pallet No.", "Line No.");
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Components)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the component line number within the selected physical pallet.';
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the plan demand line fulfilled by this pallet component.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the product copied from the selected source demand line.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the product variant or size copied from the selected source demand line.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the product description copied from the selected source demand line.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the exact tray or unit quantity of this product and size on the selected pallet.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the unit of measure copied from the selected source demand line.';
                }
            }
        }
    }
}
