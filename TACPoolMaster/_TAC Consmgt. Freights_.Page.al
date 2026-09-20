page 50205 "TAC Consmgt. Freights"
{
    ApplicationArea = All;
    Caption = 'TAC Consmgt. Freights';
    PageType = ListPart;
    DelayedInsert = true;
    SourceTable = "TAC Consignment Freight Leg";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                //field("Leg No."; Rec."Leg No.") { }
                field("Manifest No."; Rec."Manifest No.")
                {
                }
                field("Consignment No."; Rec."Consignment No.")
                {
                }
                field("Shipping Agent Code"; Rec."Shipping Agent Code")
                {
                }
                field("From Freight Location"; Rec."From Freight Location")
                {
                }
                field("To Freight Location"; Rec."To Freight Location")
                {
                }
                field("Pallet Spaces"; Rec."Pallet Spaces")
                {
                }
                field("Pallet Space Rate"; Rec."Pallet Space Rate")
                {
                }
                field("Fuel Surcharge %"; Rec.CalcFuelChargePct())
                {
                }
                field("Freight Cost"; Rec."Freight Cost")
                {
                }
                field("External Reference"; Rec."External Reference")
                {
                }
            }
        }
    }
}
