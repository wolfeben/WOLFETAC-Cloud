pageextension 58019 "SAL Customer Card" extends "Customer Card"
{
    layout
    {
        addlast(Content)
        {
            group("SAL Packing")
            {
                Caption = 'SAL Packing';

                field("SAL Pallet Quantity UOM"; Rec."SAL Pallet Quantity UOM")
                {
                    ApplicationArea = All;
                }
                field("SAL Units per Pallet"; Rec."SAL Units per Pallet")
                {
                    ApplicationArea = All;
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
        }
    }
}
