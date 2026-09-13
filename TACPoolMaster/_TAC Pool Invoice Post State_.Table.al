table 50239 "TAC Pool Invoice Post State"
{
    Caption = 'Pool Invoice Posting State';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Posted Invoice SystemId"; Guid)
        {
            Caption = 'Posted Invoice SystemId';
            ToolTip = 'Specifies the immutable system ID of the posted sales invoice already processed by pooling.';
        }
        field(2; "Posted Invoice No."; Code[20])
        {
            Caption = 'Posted Invoice No.';
            TableRelation = "Sales Invoice Header"."No.";
            ToolTip = 'Specifies the posted sales invoice number processed by pooling.';
        }
        field(3; "Posted DateTime"; DateTime)
        {
            Caption = 'Posted DateTime';
            ToolTip = 'Specifies when pooling processed the posted sales invoice.';
        }
        field(4; "Posted By"; Code[50])
        {
            Caption = 'Posted By';
            ToolTip = 'Specifies the user that caused the invoice to be processed by pooling.';
        }
    }
    keys
    {
        key(PK; "Posted Invoice SystemId")
        {
            Clustered = true;
        }
        key(InvoiceNo; "Posted Invoice No.")
        {
        }
    }
}
