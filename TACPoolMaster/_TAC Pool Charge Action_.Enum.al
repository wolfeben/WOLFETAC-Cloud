enum 50204 "TAC Pool Charge Action"
{
    Extensible = false;
    Caption = 'Pool Charge Action';

    // Charge Engine dispatch parameter (ADR-003). Spec codes: RC / CP / PG.
    value(0; RunClose)
    {
    Caption = 'Run Close';
    }
    value(1; ConsignmentPost)
    {
    Caption = 'Consignment Post';
    }
    value(2; GroupClose)
    {
    Caption = 'Group Close';
    }
    value(3; System)
    {
    Caption = 'System';
    }
    value(4; InvoicePost)
    {
    Caption = 'Invoice Post';
    }
}
