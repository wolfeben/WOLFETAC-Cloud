pageextension 58019 "SAL Customer Card" extends "Customer Card"
{
    layout
    {
        addlast(Content)
        {
            group("SAL Packing")
            {
                Caption = 'SAL Packing';

                field("SAL Pallet Template Code"; Rec."SAL Pallet Template Code")
                {
                    ApplicationArea = All;
                }
                field("SAL Physical Pallet Type"; Rec."SAL Physical Pallet Type")
                {
                    ApplicationArea = All;
                }
                field("SAL Pallet Quantity UOM"; Rec."SAL Pallet Quantity UOM")
                {
                    ApplicationArea = All;
                }
                field("SAL Units per Pallet"; Rec."SAL Units per Pallet")
                {
                    ApplicationArea = All;
                }
                field("SAL Mixed Pallet Policy"; Rec."SAL Mixed Pallet Policy")
                {
                    ApplicationArea = All;
                }
                field("SAL Freight Company"; Rec."Shipping Agent Code")
                {
                    ApplicationArea = All;
                    Caption = 'Freight Company';
                    ToolTip = 'Specifies the default freight company for new customer sales documents. SAL snapshots the freight company actually recorded on each source order.';
                }
                field("SAL Freight Service"; Rec."Shipping Agent Service Code")
                {
                    ApplicationArea = All;
                    Caption = 'Freight Service';
                    ToolTip = 'Specifies the default freight service for new customer sales documents.';
                }
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action("SAL Pallet Allocation Rules")
            {
                ApplicationArea = All;
                Caption = 'SAL Pallet Allocation Rules';
                Image = SetupLines;
                RunObject = page "SAL Template Rules";
                RunPageLink = "Customer No." = field("No.");
                ToolTip = 'Opens detailed pallet-capacity exceptions for this customer, including ship-to and item-specific rules.';
            }
            action("SAL Pallet Templates")
            {
                ApplicationArea = All;
                Caption = 'SAL Pallet Templates';
                Image = Setup;
                RunObject = page "SAL Pallet Templates";
                ToolTip = 'Opens reusable physical pallet formats such as CHEP, PMC, AKE, standard packed and standard bulk.';
            }
            action("SAL Freight Companies")
            {
                ApplicationArea = All;
                Caption = 'Freight Companies';
                Image = Delivery;
                RunObject = page "Shipping Agents";
                ToolTip = 'Opens the standard Business Central shipping agents used as freight companies.';
            }
        }
    }
}
