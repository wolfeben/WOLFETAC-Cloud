enum 50206 "TAC Pool Rate Type"
{
    Extensible = false;
    Caption = 'Pool Rate Type';

    // Multiplier base for the charge amount (design §6.7).
    value(0; Kg)
    {
        Caption = 'Kg';
    }
    value(1; Unit)
    {
        Caption = 'Unit';
    }
    value(2; Bin)
    {
        Caption = 'Bin';
    }
    value(3; Value)
    {
        Caption = 'Value (%)';
    }
    value(4; Calc)
    {
        Caption = 'Calc';
    }
    value(5; System)
    {
        Caption = 'System';
    }
}
