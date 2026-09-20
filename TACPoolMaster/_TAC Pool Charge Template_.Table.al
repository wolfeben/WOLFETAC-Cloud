table 50222 "TAC Pool Charge Template"
{
    Caption = 'Pool Charge Template';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Pool Charge Template";
    DrillDownPageId = "TAC Pool Charge Template";

    fields
    {
        field(1; ID; Integer)
        {
            Caption = 'ID';
            NotBlank = true;
        }
        field(2; "Trans Type Code"; Code[10])
        {
            Caption = 'Trans Type Code';
            TableRelation = "TAC Pool Trans Type"."Code";
        }
        field(3; "Charge Action"; Enum "TAC Pool Charge Action")
        {
            Caption = 'Charge Action';
        }
        field(4; Rate; Decimal)
        {
            Caption = 'Rate';
            DecimalPlaces = 2 : 5;
        }
        field(5; "Rate Source"; Enum "TAC Pool Rate Source")
        {
            Caption = 'Rate Source';
        }
        field(6; "Rate Type"; Enum "TAC Pool Rate Type")
        {
            Caption = 'Rate Type';
        }
        field(7; "Charge Level"; Enum "TAC Pool Charge Level")
        {
            Caption = 'Charge Level';
        }
        // Design §7.3 specifies "Enum 50201/50202 + blank" for the two type
        // filters. Implemented as blank-able Code holding the single-letter
        // spec code (I/E/G/C/F) so a blank cell from Sheet 3.4 means
        // "applies to all" AND the field default is blank (an AL enum field
        // cannot default to blank without disturbing the pinned ordinals of
        // enums 50201/50202). The engine maps the code to the enum caption.
        field(8; "Supplier Type Filter"; Code[10])
        {
            Caption = 'Supplier Type Filter';
        }
        field(9; "Grower Type Filter"; Code[10])
        {
            Caption = 'Grower Type Filter';
        }
        field(10; "Variety Filter"; Code[10])
        {
            Caption = 'Variety Filter';
        }
        field(11; "Pack Type Filter"; Code[20])
        {
            Caption = 'Pack Type Filter';
        }
        field(12; "Pack Type Category Filter"; Code[20])
        {
            Caption = 'Pack Type Category Filter';
        }
        field(13; "Grade Filter"; Code[10])
        {
            Caption = 'Grade Filter';
        }
        field(14; "Grower Code Filter"; Code[20])
        {
            Caption = 'Grower Code Filter';
            // Zero-padded 3-digit grower code, matching the grower dimension
            // values the engine reads from a pooling source (ADR-004) — not the
            // Vendor No. Deliberately carries no TableRelation: Sheet 3.4 may
            // reference a grower code before its dimension value is created, and
            // an unmatched filter is inert rather than wrong.
        }
        field(15; "Ripener Required Filter"; Option)
        {
            Caption = 'Ripener Required Filter';
            // Design §7.3 specifies an Option here (blank/Y/N tri-state filter).
            OptionMembers = " ",Y,N;
            OptionCaption = ' ,Y,N';
        }
        field(16; Mandatory; Boolean)
        {
            Caption = 'Mandatory';
        }
        field(17; Active; Boolean)
        {
            Caption = 'Active';
        }
    }

    keys
    {
        key(PK; ID)
        {
            Clustered = true;
        }
        key(Eligible; "Trans Type Code", "Charge Action", Active)
        {
            // Engine's eligible-row scan (design §7.3).
        }
    }
}
