enum 50205 "TAC Pool Rate Source"
{
    Extensible = false;
    Caption = 'Pool Rate Source';

    // Governs how the engine resolves the rate (design §2.6 / §6.6).
    // Only FR uses Calculated.
    value(0; Fixed)
    {
        Caption = 'Fixed';
    }
    value(1; Customer)
    {
        Caption = 'Customer';
    }
    value(2; Calculated)
    {
        Caption = 'Calculated';
    }
    value(3; System)
    {
        Caption = 'System';
    }
}
