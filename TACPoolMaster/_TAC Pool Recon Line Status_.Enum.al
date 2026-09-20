enum 50213 "TAC Pool Recon Line Status"
{
    Extensible = false;
    Caption = 'Pool Reconciliation Line Status';

    value(0; Found) { Caption = 'Found'; }
    value(1; Missing) { Caption = 'Missing'; }
    value(2; Created) { Caption = 'Created'; }
    value(3; Excluded) { Caption = 'Excluded'; }
    value(4; Error) { Caption = 'Error'; }
}
