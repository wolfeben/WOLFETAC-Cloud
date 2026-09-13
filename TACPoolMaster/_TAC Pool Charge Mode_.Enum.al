enum 50209 "TAC Pool Charge Mode"
{
    Extensible = false;
    Caption = 'Pool Charge Mode';

    // Engine dispatch mode (ADR-001 / ADR-003): Write posts ledger entries;
    // Validate is the dry-run that resolves rows + rates and raises the same
    // errors but writes nothing. Replaces the design's inline Option so the
    // callers (50271/50272/50273) can reference it (house rule: enums > options).
    value(0; Write)
    {
    Caption = 'Write';
    }
    value(1; Validate)
    {
    Caption = 'Validate';
    }
}
