page 50204 "TAC Consignment"
{
    ApplicationArea = All;
    Caption = 'TAC Consignment';
    PageType = Document;
    SourceTable = "TAC Consignment Header";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Consignment No."; Rec."Consignment No.")
                {
                }
                field("Consignment Type"; Rec."Consignment Type")
                {
                }
                field("Customer Reference"; Rec."Customer Reference")
                {
                }
                field("Despatch Date"; Rec."Despatch Date")
                {
                }
                field("Despatch From Company"; Rec."Despatch From Company")
                {
                }
                field("Despatch To Company"; Rec."Despatch To Company")
                {
                }
                //field("Dimension Set ID"; Rec."Dimension Set ID") { }
                field("Estimated Date of Arrival"; Rec."Estimated Date of Arrival")
                {
                }
                field("External Consignment"; Rec."External Consignment")
                {
                }
                field("External Grower Advice No."; Rec."External Grower Advice No.")
                {
                }
                field("Final Destination"; Rec."Final Destination")
                {
                }
                field("Fully Paid"; Rec."Fully Paid")
                {
                }
                field("ICA Docket No."; Rec."ICA Docket No.")
                {
                }
                field("Marketer Code"; Rec."Marketer Code")
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
                field("Posted to Pool"; Rec."Posted to Pool")
                {
                }
                field(Redirected; Rec.Redirected)
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
                field("Total Freight Cost"; Rec."Total Freight Cost")
                {
                }
                field("Total Kilograms"; Rec."Total Kilograms")
                {
                }
                field("Transfer Order No."; Rec."Transfer Order No.")
                {
                }
                field("Chiller Temperature"; Rec."Chiller Temperature")
                {
                }
            }
            part(ConsignmentFreightLegs; "TAC Consmgt. Freights")
            {
                ApplicationArea = All;
                Caption = 'Consignment Freights';
                SubPageLink = "Consignment No."=field("Consignment No.");
            }
            part(ConsignmentLines; "TAC Consignment Lines")
            {
                ApplicationArea = All;
                Caption = 'Details';
                SubPageLink = "Consignment No."=field("Consignment No.");
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ReleaseConsignment)
            {
                ApplicationArea = All;
                Caption = 'Release Consignment';
                Image = ReleaseDoc;
                ToolTip = 'Release the consignment for further processing.';

                trigger OnAction()
                var
                    ConsignmentMgt: Codeunit "TAC Pool Consignment Post";
                begin
                    ConsignmentMgt.ReleaseConsignment(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(PostConsignment)
            {
                ApplicationArea = All;
                Caption = 'Post Consignment';
                Image = Post;
                ToolTip = 'Post the consignment and create the related documents.';

                trigger OnAction()
                var
                    PostConsignmentMgt: Codeunit "TAC Pool Consignment Post";
                begin
                    PostConsignmentMgt.PostConsignment(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(AllocateFreight)
            {
                ApplicationArea = All;
                Caption = 'Allocate Freight';
                Image = Allocate;
                ToolTip = 'Allocate the total freight cost to the consignment lines based on their weight.';

                trigger OnAction()
                begin
                    Rec.AllocateFreightCost();
                    CurrPage.Update(false);
                end;
            }
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
                        CurrPage.SaveRecord();
                    end;
                end;
            }
        }
    }
}
