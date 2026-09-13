tableextension 50203 "TAC Prod. Order Extension" extends "Production Order"
{
    fields
    {
        field(50200; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            DataClassification = CustomerContent;
            TableRelation = "TAC Pool"."Pool Code";
        }
    }
}
