table 59353 "WLF Pool Week Run"
{
    Caption = 'Pooling week test delivery';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Order Index"; Integer) { }
        field(2; "Test Date"; Date) { }
        field(3; "Grower No."; Code[20]) { }
        field(4; "Block Code"; Code[20]) { }
        field(5; "Purchase Order No."; Code[20]) { }
        field(6; "Delivery Lot No."; Code[50]) { }
        field(7; "Receipt Entry No."; Integer) { }
        field(8; "Plan No."; Code[20]) { }
        field(9; "Batch No."; Code[20]) { }
        field(10; "Receipt Verified"; Boolean) { }
        field(11; "Plan Prepared"; Boolean) { }
        field(12; "Operation No."; Integer) { }
        field(13; "Last Result"; Text[2048]) { }
        field(14; "Last Run"; DateTime) { }
        field(15; "Receipt Bin Code"; Code[20]) { }
    }
    keys { key(PK; "Order Index") { Clustered = true; } }
}
