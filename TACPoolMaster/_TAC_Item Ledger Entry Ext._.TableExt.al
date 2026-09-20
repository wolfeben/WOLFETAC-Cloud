tableextension 50207 "TAC_Item Ledger Entry Ext." extends "Item Ledger Entry"
{
    fields
    {
        field(50200; "TAC Grower No."; Code[20])
        {
            Caption = 'Grower No.';
            fieldclass = flowfield;
            CalcFormula = lookup("TAC Batch Plan Grower"."Vendor No." where("Batch No." = field("Order No.")));
        }
    }
}
