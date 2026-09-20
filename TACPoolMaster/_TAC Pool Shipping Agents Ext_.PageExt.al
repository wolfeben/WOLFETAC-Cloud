pageextension 50245 "TAC Pool Shipping Agents Ext" extends "Shipping Agents"
{
    layout
    {
        addlast(Control1)
        {
            field("Fuel Surcharge %"; Rec."Fuel Surcharge %") { ApplicationArea = All; }
            field("Manifest Nos."; Rec."Manifest Nos.") { ApplicationArea = All; }
            field("Fuel Surcharge Last Updated"; Rec."Fuel Surcharge Last Updated") { ApplicationArea = All; }
            field("Fuel Surcharge Updated By"; Rec."Fuel Surcharge Updated By") { ApplicationArea = All; }
        }
    }
}