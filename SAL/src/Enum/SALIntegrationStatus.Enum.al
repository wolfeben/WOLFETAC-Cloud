enum 58007 "SAL Integration Status"
{
    Extensible = false;
    Caption = 'SAL Integration Status';

    value(0; NotPublished) { Caption = 'Not published'; }
    value(1; Published) { Caption = 'Published'; }
    value(2; Acknowledged) { Caption = 'Acknowledged'; }
    value(3; Packing) { Caption = 'Packing'; }
    value(4; Complete) { Caption = 'Complete'; }
    value(5; Error) { Caption = 'Error'; }
}
