table 59354 "WLF Pool Week Output"
{
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Order Index"; Integer) { }
        field(2; "Item Index"; Integer) { }
        field(3; Slot; Integer) { }
        field(4; "Pallet No."; Code[20]) { }
        field(5; "Item No."; Code[20]) { }
        field(6; "Base Quantity"; Decimal) { DecimalPlaces = 0 : 5; }
        field(7; "Serial Count"; Integer) { }
        field(8; "First Serial"; Code[50]) { }
        field(9; "Last Serial"; Code[50]) { }
        field(10; "Posting Date"; Date) { }
        field(11; Verified; Boolean) { }
        field(12; "Ledger Entries"; Integer) { }
        field(13; "Warehouse Quantity"; Decimal) { DecimalPlaces = 0 : 5; }
        field(14; "Verified At"; DateTime) { }
        field(15; "Pallet Detail Serials Only"; Boolean) { }
    }
    keys
    {
        key(PK; "Order Index", "Item Index", Slot) { Clustered = true; }
        key(Pallet; "Pallet No.") { }
    }
}
