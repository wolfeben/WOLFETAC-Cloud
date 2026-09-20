enum 50208 "TAC Pool Prorata Level"
{
    Extensible = false;
    Caption = 'Pool Prorata Level';

    // Scope over which an above-the-line charge is prorated to growers at
    // close Step 6 (design §6.9).
    value(0; "None")
    {
        Caption = 'None';
    }
    value(1; Pool)
    {
        Caption = 'Pool';
    }
    value(2; PoolGroup)
    {
        Caption = 'Pool Group';
    }
}
