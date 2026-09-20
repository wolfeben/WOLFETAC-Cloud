enum 50200 "TAC Pool Group Status"
{
    Extensible = false;
    Caption = 'Pool Group Status';

    value(0; Open)
    {
        Caption = 'Open';
    }
    value(1; "Provisionally Closed")
    {
        Caption = 'Provisionally Closed';
    }
    value(2; Closed)
    {
        Caption = 'Closed';
    }
}
