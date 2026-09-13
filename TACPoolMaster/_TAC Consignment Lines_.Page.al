page 50206 "TAC Consignment Lines"
{
    ApplicationArea = All;
    Caption = 'Consignment Lines';
    PageType = ListPart;
    SourceTable = "TAC Consignment Line";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Source No."; Rec."Source No.")
                {
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                }
                field("Item No."; Rec."Item No.")
                {
                }
                field("Pack Type Code"; Rec."Pack Type Code")
                {
                }
                field("Pool Code"; Rec."Pool Code")
                {
                }
                field("Pool Week"; Rec."Pool Week")
                {
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Quantity (Kg)"; Rec."Quantity (Kg)")
                {
                }
                field("Estimated Price"; Rec."Estimated Price")
                {
                }
                field("Estimated Amount"; Rec.EstimatedAmount())
                {
                }
                field("Quantity to Repack"; Rec."Quantity to Repack")
                {
                }
                field("Grower No."; Rec."Grower No.")
                {
                }
                field("Season Code"; Rec."Season Code")
                {
                }
                field("Variety Code"; Rec."Variety Code")
                {
                }
                field("Allocated Freight Cost"; Rec."Allocated Freight Cost")
                {
                }
                field("External Grower Advice No."; Rec."External Grower Advice No.")
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
                ToolTip = 'View or edit dimensions, such as area, project, or department, that you can assign to sales and purchase documents to distribute costs and analyze transaction history.';

                trigger OnAction()
                var
                    DimMgt: Codeunit DimensionManagement;
                    NewDimSetID: Integer;
                begin
                    NewDimSetID:=DimMgt.EditDimensionSet(Rec."Dimension Set ID", StrSubstNo('%1 %2 %3', Rec.TableCaption(), Rec."Consignment No.", Rec."Line No."));
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
