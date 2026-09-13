page 50203 "TAC Consignments"
{
    ApplicationArea = All;
    Caption = 'Consignments';
    PageType = List;
    SourceTable = "TAC Consignment Header";
    UsageCategory = Documents;
    Editable = false;
    CardPageId = "TAC Consignment";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Consignment No."; Rec."Consignment No.")
                {
                }
                field("Consignment Type"; Rec."Consignment Type")
                {
                }
                field("Customer Reference"; Rec."Customer Reference")
                {
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                }
                field("Sell-to Customer No."; Rec."Sell-to Customer No.")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field(Redirected; Rec.Redirected)
                {
                }
                field("No. of CHEP Pallets"; Rec."No. of CHEP Pallets")
                {
                }
                field("No. of Pallet Spaces"; Rec."No. of Pallet Spaces")
                {
                }
                field("No. of Units"; Rec."No. of Units")
                {
                }
                field("Total Freight Cost"; Rec."Total Freight Cost")
                {
                }
                field("Total Kilograms"; Rec."Total Kilograms")
                {
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Dimensions)
            {
                AccessByPermission = TableData Dimension=R;
                ApplicationArea = Dimensions;
                Caption = 'Dimensions';
                Enabled = Rec."Consignment No." <> '';
                Image = Dimensions;
                ShortCutKey = 'Alt+D';
                ToolTip = 'View or edit dimensions, such as area, project, or department, that you can assign to documents to distribute costs and analyze transaction history.';

                trigger OnAction()
                var
                    DimMgt: Codeunit DimensionManagement;
                    NewDimSetID: Integer;
                begin
                    NewDimSetID:=DimMgt.EditDimensionSet(Rec."Dimension Set ID", StrSubstNo('%1 %2', Rec.TableCaption(), Rec."Consignment No."));
                    if Rec."Dimension Set ID" <> NewDimSetID then begin
                        Rec."Dimension Set ID":=NewDimSetID;
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }
}
