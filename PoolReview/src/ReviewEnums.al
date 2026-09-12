enum 59300 "WLF Pool Review Severity"
{
    Extensible = false;
    value(0; Information) { Caption = 'Information'; }
    value(1; Warning) { Caption = 'Needs review'; }
    value(2; Error) { Caption = 'Mismatch'; }
}
enum 59301 "WLF Pool Review Kind"
{
    Extensible = false;
    value(0; Pool) { }
    value(1; Ledger) { }
    value(2; Payment) { }
    value(3; Invoice) { }
}

