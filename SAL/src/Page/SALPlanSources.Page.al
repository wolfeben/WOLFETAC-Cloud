page 58015 "SAL Plan Sources"
{
    PageType = ListPart;
    ApplicationArea = All;
    Caption = 'Plan Demand and Routing';
    SourceTable = "SAL Plan Source";
    SourceTableView = sorting("Plan No.", "Version No.", "Line No.");
    DelayedInsert = true;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Sources)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the source line number within this plan version.';
                }
                field("Source Type"; Rec."Source Type")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies whether the demand comes from a sales order or transfer order.';
                }
                field("Source Document No."; Rec."Source Document No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the source order number.';
                }
                field("Consignment No."; Rec."Consignment No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the consignment associated with the demand.';
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the customer or destination name captured from the source demand.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the product required by this source line.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the product variant or size required by this source line.';
                }
                field("Item Description"; Rec."Item Description")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the product description.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity that this plan version commits to fulfil.';
                }
                field("Planned Quantity"; Rec."Planned Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = PlannedQuantityStyle;
                    ToolTip = 'Specifies the quantity currently assigned to physical pallet components.';
                }
                field("Fulfilment Mode"; Rec."Fulfilment Mode")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows whether this demand is exact, flexible fill, or a combination of both.';
                }
                field("Fill Group Code"; Rec."Fill Group Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the fill group selected for the flexible balance.';
                }
                field("Exact Planned Quantity"; Rec."Exact Planned Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the quantity assigned to the original exact SKU.';
                }
                field("Fill Target Quantity"; Rec."Fill Target Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the quantity that may be fulfilled by eligible fill group members.';
                }
                field("Fill Planned Quantity"; Rec."Fill Planned Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Shows the flexible quantity assigned to eligible fill products and sizes.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the unit of measure for the required and planned quantities.';
                }
                field("Execution Route"; Rec."Execution Route")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies where the demand will be fulfilled.';
                }
                field("Facility Work Type"; Rec."Facility Work Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the work, if any, required from the Manjimup Packing Facility.';
                }
                field("Routing Confirmed"; Rec."Routing Confirmed")
                {
                    ApplicationArea = All;
                    StyleExpr = RoutingStyle;
                    ToolTip = 'Specifies that the route and facility work type were explicitly checked.';
                }
                field("Source Location Code"; Rec."Source Location Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the source location captured from the order.';
                }
                field("Destination Name"; Rec."Destination Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the destination captured from the order.';
                }
                field("Shipment Date"; Rec."Shipment Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the shipment date captured from the order.';
                }
                field(Priority; Rec.Priority)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the source demand priority captured when it was added.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Planned Quantity", "Exact Planned Quantity", "Fill Planned Quantity");
        if Rec."Routing Confirmed" then
            RoutingStyle := 'Favorable'
        else
            RoutingStyle := 'Attention';
        if Rec."Planned Quantity" = Rec.Quantity then
            PlannedQuantityStyle := 'Favorable'
        else
            PlannedQuantityStyle := 'Attention';
    end;

    var
        PlannedQuantityStyle: Text;
        RoutingStyle: Text;
}
