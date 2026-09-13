enum 50211 "TAC Pool Source Type"
{
    Extensible = false;
    Caption = 'Pool Source Type';

    value(0; "Production Output")
    {
    Caption = 'Production Output';
    }
    value(1; "Sales Invoice")
    {
    Caption = 'Sales Invoice';
    }
    value(2; "Sales Credit Memo")
    {
    Caption = 'Sales Credit Memo';
    }
    value(3; Consignment)
    {
    Caption = 'Consignment';
    }
    value(4; Expense)
    {
    Caption = 'Expense';
    }
    value(5; Adjustment)
    {
    Caption = 'Adjustment';
    }
}
