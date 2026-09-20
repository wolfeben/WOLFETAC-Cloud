pageextension 50202 "TAC Trans. Orders Ext." extends "Transfer Orders"
{
    layout
    {
        addafter("No.")
        {
            field("DIY_Consignment No."; Rec."DIY_Consignment No.")
            {
                ApplicationArea = All;
                Editable = Rec."DIY_Consignment No." = '';
                trigger OnDrillDown()
                var
                    Consignment: record "TAC Consignment Header";
                begin
                    if Consignment.Get(Rec."DIY_Consignment No.") then
                        Page.Run(Page::"TAC Consignment", Consignment);
                end;
            }
        }
    }
}
