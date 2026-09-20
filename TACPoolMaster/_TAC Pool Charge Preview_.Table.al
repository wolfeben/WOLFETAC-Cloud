table 50226 "TAC Pool Charge Preview"
{
    Caption = 'Pool Charge Preview';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(2; "Production Order No."; Code[20]) { Caption = 'Production Order No.'; }
        field(3; "Production Order Line No."; Integer) { Caption = 'Production Order Line No.'; }
        field(4; "Row Type"; Option) { Caption = 'Row Type'; OptionMembers = Line,"Expected Transaction",Issue; }
        field(5; Severity; Option) { Caption = 'Severity'; OptionMembers = Information,Warning,Blocking; }
        field(6; Outcome; Option) { Caption = 'Outcome'; OptionMembers = "Will Pool","Already Pooled","Will Not Pool","Needs Attention"; }
        field(7; Finding; Text[250]) { Caption = 'Finding'; }
        field(8; "Output Item No."; Code[20]) { Caption = 'Output Item No.'; }
        field(9; "Pool Group ID"; Integer) { Caption = 'Pool Group ID'; }
        field(10; "Pool Group Code"; Code[20]) { Caption = 'Pool Group Code'; }
        field(11; "Pool Code"; Code[20]) { Caption = 'Pool Code'; }
        field(12; "Pool Week"; Code[20]) { Caption = 'Pool Week'; }
        field(13; Season; Code[20]) { Caption = 'Season'; }
        field(14; Variety; Code[20]) { Caption = 'Variety'; }
        field(15; Grade; Code[20]) { Caption = 'Grade'; }
        field(16; Size; Code[20]) { Caption = 'Size'; }
        field(17; "Grower Code"; Code[20]) { Caption = 'Grower Code'; }
        field(18; "Grower Pool Type"; Enum "TAC Grower Pool Type") { Caption = 'Grower Pool Type'; }
        field(19; "Pack Type"; Code[20]) { Caption = 'Pack Type'; }
        field(20; "Pack Type Category"; Code[20]) { Caption = 'Pack Type Category'; }
        field(21; Units; Decimal) { Caption = 'Units'; }
        field(22; Kgs; Decimal) { Caption = 'Kg'; }
        field(23; "Transaction Type"; Code[10]) { Caption = 'Transaction Type'; }
        field(24; "Template ID"; Integer) { Caption = 'Template ID'; }
        field(25; "Rate Source"; Enum "TAC Pool Rate Source") { Caption = 'Rate Source'; }
        field(26; "Rate Type"; Enum "TAC Pool Rate Type") { Caption = 'Rate Type'; }
        field(27; Rate; Decimal) { Caption = 'Rate'; }
        field(28; "Expected Amount"; Decimal) { Caption = 'Expected Amount'; }
        field(29; "GST Amount"; Decimal) { Caption = 'GST Amount'; }
        field(30; "Expected Line Charge Total"; Decimal) { Caption = 'Expected Line Charge Total'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Line; "Production Order No.", "Production Order Line No.", "Entry No.") { }
    }
}
