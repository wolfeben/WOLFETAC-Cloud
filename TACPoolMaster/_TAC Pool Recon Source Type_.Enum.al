enum 50212 "TAC Pool Recon Source Type"
{
    Extensible = false;
    Caption = 'Pool Reconciliation Source Type';

    value(0; "Production Output") { Caption = 'Production Output'; }
    value(1; "Sales Invoice") { Caption = 'Sales Invoice'; }
    value(2; "Sales Credit Memo") { Caption = 'Sales Credit Memo'; }
    value(3; Consignment) { Caption = 'Consignment/Freight'; }
    value(4; Expense) { Caption = 'Expense'; }
    value(5; Adjustment) { Caption = 'Adjustment'; }
}
