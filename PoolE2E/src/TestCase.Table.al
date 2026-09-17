table 59350 "WLF Pool E2E Case"
{
    Caption = 'Pooling test case';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Step No."; Integer) { }
        field(2; Scenario; Text[100]) { }
        field(3; Operation; Option) { OptionMembers = Pack,Sale,Expense,Adjustment,Provisional,Final,RepeatProduction,RepeatInvoice,Manual; }
        field(4; "Source No."; Code[20]) { }
        field(5; "Related No."; Code[20]) { }
        field(6; "Grower No."; Code[20]) { }
        field(7; "Week No."; Integer) { }
        field(8; "Pool Type"; Enum "TAC Grower Pool Type") { }
        field(9; Quantity; Decimal) { DecimalPlaces = 0:5; }
        field(10; Price; Decimal) { DecimalPlaces = 0:5; }
        field(11; "Dimension Set ID"; Integer) { }
        field(12; "Expected Result"; Text[2048]) { }
        field(13; Status; Option) { OptionMembers = Ready,Completed,Blocked,Mismatch,"Manual check"; }
        field(14; "Actual Result"; Text[2048]) { }
        field(15; "Last Run"; DateTime) { }
        field(16; "Prerequisite Step"; Integer) { }
        field(17; "Actual Kg"; Decimal) { }
        field(18; "Actual Amount"; Decimal) { }
        field(19; "Posted Document No."; Code[20]) { }
        field(20; "Second Source No."; Code[20]) { }
        field(21; "Second Quantity"; Decimal) { }
        field(22; "Test Date"; Date) { }
        field(23; "Engine Group ID"; Integer) { }
        field(24; "Expect Rejection"; Boolean) { }
    }
    keys { key(PK; "Step No.") { Clustered = true; } }
}
