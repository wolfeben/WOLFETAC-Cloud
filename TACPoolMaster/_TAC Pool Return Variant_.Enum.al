enum 50210 "TAC Pool Return Variant"
{
    Extensible = false;
    Caption = 'Pool Return Variant';

    // Request-page selector for the single Pool Return report (design §F-09):
    // one report object, three variants — not three reports.
    value(0; TaxInvoice)
    {
    Caption = 'Tax Invoice';
    }
    value(1; Provisional)
    {
    Caption = 'Provisional Statement';
    }
    value(2; Summary)
    {
    Caption = 'Summary';
    }
}
