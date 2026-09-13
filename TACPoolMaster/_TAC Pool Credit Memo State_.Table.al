table 50227 "TAC Pool Credit Memo State"
{
    Caption = 'Pool Credit Memo Posting State';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Posted Credit Memo SystemId"; Guid)
        {
            Caption = 'Posted Credit Memo SystemId';
            ToolTip = 'Specifies the immutable system ID of the posted credit memo already processed by pooling.';
        }
        field(2; "Posted Credit Memo No."; Code[20])
        {
            Caption = 'Posted Credit Memo No.';
            TableRelation = "Sales Cr.Memo Header"."No.";
            ToolTip = 'Specifies the posted credit memo number processed by pooling.';
        }
        field(3; "Applied Invoice No."; Code[20])
        {
            Caption = 'Applied Invoice No.';
            TableRelation = "Sales Invoice Header"."No.";
            ToolTip = 'Specifies the pooled invoice to which this credit memo was applied.';
        }
        field(4; "Posted DateTime"; DateTime)
        {
            Caption = 'Posted DateTime';
            ToolTip = 'Specifies when pooling processed the credit memo.';
        }
        field(5; "Posted By"; Code[50])
        {
            Caption = 'Posted By';
            ToolTip = 'Specifies the user that caused the credit memo to be processed by pooling.';
        }
    }
    keys
    {
        key(PK; "Posted Credit Memo SystemId")
        {
            Clustered = true;
        }
        key(CreditMemoNo; "Posted Credit Memo No.")
        {
        }
    }
}
