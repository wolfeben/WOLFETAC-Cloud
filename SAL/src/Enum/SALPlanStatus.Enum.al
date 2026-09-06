enum 58000 "SAL Plan Status"
{
    Extensible = false;

    value(0; Draft)
    {
        Caption = 'Draft';
    }
    value(1; Released)
    {
        Caption = 'Released';
    }
    value(2; Superseded)
    {
        Caption = 'Superseded';
    }
    value(3; Cancelled)
    {
        Caption = 'Cancelled';
    }
}
