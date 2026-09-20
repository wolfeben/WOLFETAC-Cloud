enum 50207 "TAC Pool Charge Level"
{
    Extensible = false;
    Caption = 'Pool Charge Level';

    // Pool: computed at pool level then prorated. Grower: computed per grower
    // directly (design §6.8).
    value(0; Pool)
    {
        Caption = 'Pool';
    }
    value(1; Grower)
    {
        Caption = 'Grower';
    }
}
