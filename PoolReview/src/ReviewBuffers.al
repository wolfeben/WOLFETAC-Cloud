table 59300 "WLF Pool Review Group"
{
    TableType = Temporary;
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Group ID"; Integer) { Caption = 'Group ID'; }
        field(2; "Group Code"; Code[20]) { Caption = 'Group Code'; }
        field(3; "Week Code"; Code[20]) { Caption = 'Week Code'; }
        field(4; "Season"; Code[20]) { Caption = 'Season'; }
        field(5; "Week No."; Integer) { Caption = 'Week No.'; }
        field(6; "Pool Type"; Integer) { Caption = 'Pool Type'; }
        field(7; "Pool Type Caption"; Text[30]) { Caption = 'Pool Type Caption'; }
        field(8; "Business Status"; Text[30]) { Caption = 'Business Status'; }
        field(9; "Status Ordinal"; Integer) { Caption = 'Status Ordinal'; }
        field(10; "Pool Count"; Integer) { Caption = 'Pool Count'; }
        field(11; "Ledger Count"; Integer) { Caption = 'Ledger Count'; }
        field(12; "Invoice Candidates"; Integer) { Caption = 'Invoice Candidates'; }
        field(13; "Attributed Invoices"; Integer) { Caption = 'Attributed Invoices'; }
        field(14; "Unresolved Sources"; Integer) { Caption = 'Unresolved Sources'; }
        field(15; "Error Count"; Integer) { Caption = 'Error Count'; }
        field(16; "Warning Count"; Integer) { Caption = 'Warning Count'; }
        field(17; "Information Count"; Integer) { Caption = 'Information Count'; }
        field(18; "Movement Kg"; Decimal) { Caption = 'Movement Kg'; }
        field(19; "All Ledger Kg"; Decimal) { Caption = 'All Ledger Kg'; }
        field(20; "Ledger Net"; Decimal) { Caption = 'Ledger Net'; }
        field(21; "Scanned At"; DateTime) { Caption = 'Scanned At'; }
        field(22; "Review Status"; Text[40]) { Caption = 'Review Status'; }
        field(23; "Review Detail"; Text[250]) { Caption = 'Review Detail'; }
        field(24; "Source Record ID"; RecordId) { Caption = 'Source Record ID'; }
        field(25; "Provisional Count"; Integer) { Caption = 'Provisional Count'; }
        field(26; "Scan Complete"; Boolean) { Caption = 'Scan Complete'; }
        field(27; "Payment Count"; Integer) { Caption = 'Payment Count'; }
        field(28; "Review Bucket"; Integer) { Caption = 'Review Bucket'; }
    }
    keys { key(PK; "Group ID") { Clustered = true; }  }
}
table 59301 "WLF Pool Review Issue"
{
    TableType = Temporary;
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Issue No."; Integer) { Caption = 'Issue No.'; }
        field(2; "Group ID"; Integer) { Caption = 'Group ID'; }
        field(3; "Rule ID"; Code[20]) { Caption = 'Rule ID'; }
        field(4; "Severity"; Enum "WLF Pool Review Severity") { Caption = 'Severity'; }
        field(5; "Summary"; Text[150]) { Caption = 'Summary'; }
        field(6; "Details"; Text[2048]) { Caption = 'Details'; }
        field(7; "Pool Code"; Code[20]) { Caption = 'Pool Code'; }
        field(8; "Grower Code"; Code[20]) { Caption = 'Grower Code'; }
        field(9; "Document No."; Code[20]) { Caption = 'Document No.'; }
        field(10; "Source Line No."; Integer) { Caption = 'Source Line No.'; }
        field(11; "Payment ID"; Integer) { Caption = 'Payment ID'; }
        field(12; "Expected"; Decimal) { Caption = 'Expected'; }
        field(13; "Actual"; Decimal) { Caption = 'Actual'; }
        field(14; "Measure"; Text[30]) { Caption = 'Measure'; }
        field(15; "Evidence Record ID"; RecordId) { Caption = 'Evidence Record ID'; }
        field(16; "Related Record ID"; RecordId) { Caption = 'Related Record ID'; }
        field(17; "Scanned At"; DateTime) { Caption = 'Scanned At'; }
    }
    keys { key(PK; "Issue No.") { Clustered = true; } key(Group; "Group ID", Severity) { } }
}
table 59302 "WLF Pool Review Fact"
{
    TableType = Temporary;
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Fact No."; Integer) { Caption = 'Fact No.'; }
        field(2; "Kind"; Enum "WLF Pool Review Kind") { Caption = 'Kind'; }
        field(3; "Group ID"; Integer) { Caption = 'Group ID'; }
        field(4; "Pool Code"; Code[20]) { Caption = 'Pool Code'; }
        field(5; "Owner Group ID"; Integer) { Caption = 'Owner Group ID'; }
        field(6; "Document No."; Code[20]) { Caption = 'Document No.'; }
        field(7; "Source Line No."; Integer) { Caption = 'Source Line No.'; }
        field(8; "Source System ID"; Guid) { Caption = 'Source System ID'; }
        field(9; "Source Record ID"; RecordId) { Caption = 'Source Record ID'; }
        field(10; "Source Modified At"; DateTime) { Caption = 'Source Modified At'; }
        field(11; "Grower Code"; Code[20]) { Caption = 'Grower Code'; }
        field(12; "Trans Type"; Code[10]) { Caption = 'Trans Type'; }
        field(13; "Kg"; Decimal) { Caption = 'Kg'; }
        field(14; "Amount"; Decimal) { Caption = 'Amount'; }
        field(15; "Reversed"; Boolean) { Caption = 'Reversed'; }
        field(16; "Posted to GL"; Boolean) { Caption = 'Posted to GL'; }
        field(17; "Payment ID"; Integer) { Caption = 'Payment ID'; }
        field(18; "Completed At"; DateTime) { Caption = 'Completed At'; }
        field(19; "Description"; Text[250]) { Caption = 'Description'; }
        field(20; "Status Ordinal"; Integer) { Caption = 'Status Ordinal'; }
        field(21; "Dimension Set ID"; Integer) { Caption = 'Dimension Set ID'; }
        field(22; "Expected Classification"; Text[100]) { Caption = 'Expected Classification'; }
        field(23; "Actual Classification"; Text[100]) { Caption = 'Actual Classification'; }
        field(24; "Attribution Resolved"; Boolean) { Caption = 'Attribution Resolved'; }
        field(25; "Has Invoice State"; Boolean) { Caption = 'Has Invoice State'; }
        field(26; "Matching Entry Count"; Integer) { Caption = 'Matching Entry Count'; }
        field(27; "Related Record ID"; RecordId) { Caption = 'Related Record ID'; }
        field(28; "Legacy Match"; Boolean) { Caption = 'Legacy Match'; }
        field(29; "Posted At"; DateTime) { Caption = 'Posted At'; }
        field(30; "Invoice Group ID"; Integer) { Caption = 'Invoice Group ID'; }
        field(31; "Posting Date"; Date) { Caption = 'Posting Date'; }
        field(32; "GST Amount"; Decimal) { Caption = 'GST Amount'; }
        field(33; "GL Entry No."; Integer) { Caption = 'G/L Entry No.'; }
    }
    keys { key(PK; "Fact No.") { Clustered = true; } key(KindPool; Kind, "Pool Code") { } key(Source; Kind, "Document No.", "Source Line No.") { } }
}
table 59303 "WLF Pool Review Field"
{
    TableType = Temporary;
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Field No."; Integer) { Caption = 'Field No.'; }
        field(2; "Field Name"; Text[100]) { Caption = 'Field Name'; }
        field(3; "Value"; Text[2048]) { Caption = 'Value'; }
    }
    keys { key(PK; "Field No.") { Clustered = true; }  }
}



