table 58011 "SAL Facility Feedback"
{
    Caption = 'SAL Facility Feedback';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; "Entry No."; Integer) { AutoIncrement = true; DataClassification = SystemMetadata; }
        field(2; "Message Id"; Guid) { DataClassification = SystemMetadata; NotBlank = true; }
        field(3; "Feedback Type"; Code[30]) { DataClassification = CustomerContent; NotBlank = true; }
        field(4; "Actual Pallet Id"; Code[50]) { DataClassification = CustomerContent; }
        field(5; "Planned Pallet No."; Integer) { DataClassification = CustomerContent; }
        field(6; "Item No."; Code[20]) { DataClassification = CustomerContent; TableRelation = Item."No."; }
        field(7; "Variant Code"; Code[10]) { DataClassification = CustomerContent; }
        field(8; Quantity; Decimal) { DataClassification = CustomerContent; DecimalPlaces = 0 : 5; }
        field(9; "Unit of Measure Code"; Code[10]) { DataClassification = CustomerContent; }
        field(10; "Lot No."; Code[50]) { DataClassification = CustomerContent; }
        field(11; "Grower Code"; Code[50]) { DataClassification = CustomerContent; }
        field(12; "Error Message"; Text[250]) { DataClassification = CustomerContent; }
        field(13; "Occurred At"; DateTime) { DataClassification = SystemMetadata; }
        field(14; "Source System"; Code[30]) { DataClassification = SystemMetadata; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ByMessage; "Message Id", "Occurred At") { }
        key(ByPallet; "Actual Pallet Id", "Occurred At") { }
    }

    trigger OnInsert()
    var
        Inbound: Codeunit "SAL Integration Inbound";
    begin
        if "Occurred At" = 0DT then
            "Occurred At" := CurrentDateTime();
        Inbound.ApplyFeedback(Rec);
    end;
}
