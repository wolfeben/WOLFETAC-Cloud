pageextension 50246 "TAC Pool Vendor Card Ext" extends "Vendor Card"
{
    layout
    {
        addlast(General)
        {
            group("Pool Master")
            {
                Caption = 'Pool Master';
                field("Is Grower"; Rec."Is Grower") { ApplicationArea = All; }
                field("Grower Pool Type"; Rec."Grower Pool Type") { ApplicationArea = All; }
                field("Default Pool Type"; Rec."Default Pool Type") { ApplicationArea = All; }
            }
        }
    }
}