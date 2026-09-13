page 50202 "TAC Carrier Manifests"
{
    ApplicationArea = All;
    Caption = 'Carrier Manifests';
    PageType = List;
    SourceTable = "TAC Carrier Manifest";
    UsageCategory = Documents;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                }
                field("From Freight Location"; Rec."From Freight Location")
                {
                }
                field("To Freight Location"; Rec."To Freight Location")
                {
                }
                field("Manifest Date"; Rec."Manifest Date")
                {
                }
                field("Pallet Space Rate"; Rec."Pallet Space Rate")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field("Shipping Agent Code"; Rec."Shipping Agent Code")
                {
                }
                field("Carrier Invoice No."; Rec."Carrier Invoice No.")
                {
                }
                field("Carrier Invoice Amount"; Rec."Carrier Invoice Amount")
                {
                }
                field(Blocked; Rec.Blocked)
                {
                }
            }
        }
    }
}
