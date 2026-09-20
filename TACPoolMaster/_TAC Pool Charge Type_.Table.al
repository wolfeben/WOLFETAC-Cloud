table 50210 "TAC Pool Charge Type"
{
    Caption = 'Pool Charge Type';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            ToolTip = 'Specifies the unique charge type code.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the description of the charge type.';
        }
        field(3; "G/L Account No."; Code[20])
        {
            Caption = 'G/L Account No.';
            TableRelation = "G/L Account"."No.";
            ToolTip = 'Specifies the charge-side general ledger account number.';
        }
        field(4; "Bal. G/L Account No."; Code[20])
        {
            Caption = 'Balancing G/L Account No.';
            TableRelation = "G/L Account"."No.";
            ToolTip = 'Specifies the contra-side general ledger account number.';
        }
        field(5; "VAT Bus. Posting Group"; Code[20])
        {
            Caption = 'GST Bus. Posting Group';
            TableRelation = "VAT Business Posting Group".Code;
            ToolTip = 'Specifies the VAT business posting group for this charge type.';
        }
        field(6; "VAT Prod. Posting Group"; Code[20])
        {
            Caption = 'GST Prod. Posting Group';
            TableRelation = "VAT Product Posting Group".Code;
            ToolTip = 'Specifies the GST product posting group for this charge type.';
        }
        field(7; "Rate Type"; enum "TAC Pool Rate Type")
        {
            Caption = 'Rate Type';
            // OptionMembers = Units,Kilograms,Bins,"Value (%)";
            ToolTip = 'Specifies whether this charge is calculated by units, kilograms, bins, or gross value percentage.';
        }
        field(8; "Charge Level"; Option)
        {
            Caption = 'Charge Level';
            OptionMembers = Pool,Grower;
            ToolTip = 'Specifies whether this charge is posted at pool level or grower level.';
        }
        field(9; "Prorata Level"; Option)
        {
            Caption = 'Prorata Level';
            OptionMembers = None,Pool,Grower;
            ToolTip = 'Specifies whether and how this charge is prorated.';
        }
        field(10; "Trigger Point"; Option)
        {
            Caption = 'Trigger Point';
            OptionMembers = "Run Close","Consignment Post","Invoice Post","Pool Close",Manual;
            ToolTip = 'Specifies when this charge type is triggered in the process.';
        }
        field(11; Category; Code[20])
        {
            Caption = 'Category';
            ToolTip = 'Specifies the reporting category for this charge type.';
        }
        field(12; Mandatory; Boolean)
        {
            Caption = 'Mandatory';
            ToolTip = 'Specifies whether this charge type is mandatory.';
        }
        field(13; "Suppress from Grower Invoice"; Boolean)
        {
            Caption = 'Suppress from Grower Invoice';
            ToolTip = 'Specifies whether this charge is hidden on grower-facing documents.';
        }
        field(14; Active; Boolean)
        {
            Caption = 'Active';
            ToolTip = 'Specifies whether this charge type is active for processing.';
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }
}