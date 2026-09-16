enum 58009 "SAL Fulfilment Mode"
{
    Extensible = true;
    Caption = 'SAL Fulfilment Mode';

    value(0; ExactSKU)
    {
        Caption = 'Exact SKU';
    }
    value(1; FillGroup)
    {
        Caption = 'Fill Group';
    }
    value(2; Hybrid)
    {
        Caption = 'Exact + Fill';
    }
}
