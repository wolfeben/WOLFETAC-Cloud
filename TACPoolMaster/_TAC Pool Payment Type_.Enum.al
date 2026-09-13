enum 50203 "TAC Pool Payment Type"
{
    Extensible = false;
    Caption = 'Pool Payment Type';

    // Provisional stamps PPV ledger entries; Final stamps PP (design §6.4).
    value(0; Provisional)
    {
    Caption = 'Provisional';
    }
    value(1; Final)
    {
    Caption = 'Final';
    }
}
