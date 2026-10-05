page 58000 "SAL Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Stock & Logistics Setup';
    SourceTable = "SAL Setup";
    SourceTableView = sorting("Primary Key") where("Primary Key" = const(''));
    DeleteAllowed = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(Planning)
            {
                Caption = 'Planning defaults';
                field("Plan Nos."; Rec."Plan Nos.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series used to create stock and logistics plan numbers.';
                }
                field("Default Pallet Type"; Rec."Default Pallet Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the pallet type proposed when a planner adds a physical pallet.';
                }
            }
            group("Automatic pallet quantities")
            {
                Caption = 'Automatic pallet quantities';
                field("Default Packed UOM"; Rec."Default Packed UOM")
                {
                    ApplicationArea = All;
                }
                field("Default Packed Qty. per Pallet"; Rec."Default Packed Qty. per Pallet")
                {
                    ApplicationArea = All;
                }
                field("Default Bulk UOM"; Rec."Default Bulk UOM")
                {
                    ApplicationArea = All;
                }
                field("Default Bulk Qty. per Pallet"; Rec."Default Bulk Qty. per Pallet")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if not Rec.Get('') then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec.Insert(true);
        end;
    end;
}
