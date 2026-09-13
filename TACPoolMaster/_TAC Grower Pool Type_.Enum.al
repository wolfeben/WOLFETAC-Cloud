enum 50201 "TAC Grower Pool Type"
{
    Extensible = false;
    Caption = 'Grower Pool Type';

    // Captions are the single-letter spec codes (design §6.2). G (Contract Pack)
    // cannot be closed in v1 — enforced in the close codeunit, not the enum.
    value(0; Internal)
    {
    Caption = 'I';
    }
    value(1; External)
    {
    Caption = 'E';
    }
    value(2; "Contract Pack")
    {
    Caption = 'G';
    }
}
