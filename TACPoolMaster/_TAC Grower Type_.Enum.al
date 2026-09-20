enum 50202 "TAC Grower Type"
{
    Extensible = false;
    Caption = 'Grower Type';

    // Individual grower classification (design §6.3). Maps to the Charge
    // Template Grower Type Filter. C and F are legacy classifications.
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
    value(3; Consolidator)
    {
        Caption = 'C';
    }
    value(4; "Fixed FruitBank")
    {
        Caption = 'F';
    }
}
