pageextension 50201 "TAC Sales Order Extension" extends "Sales Order"
{
    layout
    {
        modify("DIY_Consignment No.")
        {
            trigger OnDrillDown()
            var
                Consignment: record "TAC Consignment Header";
            begin
                if Consignment.Get(Rec."DIY_Consignment No.")then Page.Run(Page::"TAC Consignment", Consignment);
            end;
        }
    }
}
