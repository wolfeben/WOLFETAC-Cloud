page 58003 "SAL Plan Pallets"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Physical Pallet Plan';
    SourceTable = "SAL Plan Pallet";
    SourceTableView = sorting("Plan No.", "Version No.", "Pallet No.");
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Pallets)
            {
                field("Pallet No."; Rec."Pallet No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the physical pallet sequence within this plan version.';
                }
                field("Pallet Type"; Rec."Pallet Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this is a standard, custom or mixed pallet.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a concise description of the pallet or packing rule.';
                }
                field("Target Quantity"; Rec."Target Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the exact tray or unit quantity intended for this physical pallet.';
                }
                field("Planned Quantity"; Rec."Planned Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = PlannedQuantityStyle;
                    ToolTip = 'Specifies the total quantity entered across this pallet''s components.';
                }
                field("No. of Components"; Rec."No. of Components")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies how many product or size components make up this physical pallet.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Planned Quantity", "No. of Components");
        if (Rec."Target Quantity" > 0) and (Rec."Planned Quantity" = Rec."Target Quantity") then
            PlannedQuantityStyle := 'Favorable'
        else
            PlannedQuantityStyle := 'Attention';
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    var
        Setup: Record "SAL Setup";
    begin
        if Setup.Get('') then
            Rec."Pallet Type" := Setup."Default Pallet Type";
    end;

    var
        PlannedQuantityStyle: Text;
}
