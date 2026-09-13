tableextension 50202 "TAC Sales Line Ext." extends "Sales Line"
{
    fields
    {
        field(50240; "Consignment No."; Code[30])
        {
            Caption = 'Consignment No.';
            ToolTip = 'Specifies the source consignment for pooled product lines. This is required to resolve invoice value back to pools.';
            DataClassification = CustomerContent;
            TableRelation = "TAC Consignment Header"."Consignment No.";
        }
    }
    trigger OnBeforeInsert()
    var
        SalesHeader: Record "Sales Header";
    begin
        if("Document Type" = "Document Type"::Order) and ("Consignment No." = '')then begin
            SalesHeader.Get("Document Type", "Document No.");
            "Consignment No.":=SalesHeader."DIY_Consignment No.";
        end;
    end;
}
