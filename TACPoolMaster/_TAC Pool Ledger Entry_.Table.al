table 50209 "TAC Pool Ledger Entry"
{
    Caption = 'Pool Ledger Entry';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Pool Ledger Entries";
    DrillDownPageId = "TAC Pool Ledger Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            ToolTip = 'Specifies the unique ledger entry number.';
        }
        field(2; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
            ToolTip = 'Specifies the pool code for this ledger entry.';
        }
        field(3; "Entry Type"; Option)
        {
            Caption = 'Entry Type';
            OptionMembers = Revenue, Charge, Freight, Payment, Quantity;
            ToolTip = 'Specifies the business entry type represented by this row.';
        }
        field(4; "Charge Type Code"; Code[20])
        {
            Caption = 'Charge Type Code';
            TableRelation = "TAC Pool Charge Type".Code;
            ToolTip = 'Specifies the charge type code for charge-related entries.';
        }
        field(5; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            ToolTip = 'Specifies the posting date of the entry.';
        }
        field(6; "Document Type"; Option)
        {
            Caption = 'Document Type';
            OptionMembers = Consignment, "Sales Invoice", "Run Close", "Pool Close", Manual;
            ToolTip = 'Specifies the document origin for this entry.';
        }
        field(7; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            ToolTip = 'Specifies the source document number for this entry.';
        }
        field(8; "Source Consignment No."; Code[20])
        {
            Caption = 'Source Consignment No.';
            TableRelation = "TAC Consignment Header"."Consignment No.";
            ToolTip = 'Specifies the source consignment number, when applicable.';
        }
        field(9; "Grower No."; Code[20])
        {
            Caption = 'Grower No.';
            TableRelation = Vendor."No.";
            ToolTip = 'Specifies the grower related to this entry.';
        }
        field(10; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item."No.";
            ToolTip = 'Specifies the item number related to this entry.';
        }
        field(11; Quantity; Decimal)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the quantity associated with this ledger entry.';
        }
        field(12; "Quantity (Kg)"; Decimal)
        {
            Caption = 'Quantity (Kg)';
            ToolTip = 'Specifies the kilogram quantity associated with this ledger entry.';
        }
        field(13; Amount; Decimal)
        {
            Caption = 'Amount';
            ToolTip = 'Specifies the entry amount. Positive values increase pool value and negative values reduce it.';
        }
        field(14; "VAT Amount"; Decimal)
        {
            Caption = 'GST Amount';
            ToolTip = 'Specifies the VAT amount for this entry.';
        }
        field(15; "VAT Prod. Posting Group"; Code[20])
        {
            Caption = 'GST Prod. Posting Group';
            TableRelation = "VAT Product Posting Group".Code;
            ToolTip = 'Specifies the GST product posting group used for this entry.';
        }
        field(16; "Applied Fuel Surcharge %"; Decimal)
        {
            Caption = 'Applied Fuel Surcharge %';
            ToolTip = 'Specifies the fuel surcharge percentage applied at posting time.';
        }
        field(17; "Applied Pallet Space Rate"; Decimal)
        {
            Caption = 'Applied Pallet Space Rate';
            ToolTip = 'Specifies the pallet space rate applied at posting time.';
        }
        field(18; "Charge Level"; Option)
        {
            Caption = 'Charge Level';
            OptionMembers = Pool, Grower;
            ToolTip = 'Specifies whether the entry is at pool level or grower level.';
        }
        field(19; Provisional; Boolean)
        {
            Caption = 'Provisional';
            ToolTip = 'Specifies whether this entry is part of a provisional close cycle.';
        }
        field(20; Reversed; Boolean)
        {
            Caption = 'Reversed';
            ToolTip = 'Specifies whether this entry has been reversed.';
        }
        field(21; "Reversed by Entry No."; Integer)
        {
            Caption = 'Reversed by Entry No.';
            TableRelation = "TAC Pool Ledger Entry"."Entry No.";
            ToolTip = 'Specifies the ledger entry number that reversed this entry.';
        }
        field(22; "G/L Entry No."; Integer)
        {
            Caption = 'G/L Entry No.';
            TableRelation = "G/L Entry"."Entry No.";
            ToolTip = 'Specifies the linked general ledger entry number.';
        }
        field(23; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
            TableRelation = "Dimension Set Entry"."Dimension Set ID";
            ToolTip = 'Specifies the dimension set ID on this entry.';
        }
        field(24; "User ID"; Code[50])
        {
            Caption = 'User ID';
            ToolTip = 'Specifies the user who created this entry.';
        }
        field(25; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            ToolTip = 'Specifies the pool group ID for this entry.';
            tableRelation = "TAC Pool Group Header"."Pool Group ID";
        }
        field(26; "Grower Code"; Code[20])
        {
            Caption = 'Grower Code';
            ToolTip = 'Specifies the grower code for this entry.';
        }
        field(27; "Trans Type Code"; Code[10])
        {
            Caption = 'Transaction Type';
            ToolTip = 'Specifies the transaction type code for this entry.';
        }
        field(30; "Product Code"; Code[20])
        {
            Caption = 'Product Code';
            ToolTip = 'Specifies the product code for non-item based entries.';
        }
        field(33; "Transaction Date"; Date)
        {
            Caption = 'Transaction Date';
            ToolTip = 'Specifies the originating transaction date.';
        }
        field(34; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
            ToolTip = 'Specifies the originating source document number.';
        }
        field(35; "Pool Payment ID"; Integer)
        {
            Caption = 'Pool Payment ID';
            TableRelation = "TAC Pool Payment Header"."Pool Payment ID";
            ToolTip = 'Specifies the related pool payment header ID.';
        }
        field(36; "Pool Expense ID"; Integer)
        {
            Caption = 'Pool Expense ID';
            TableRelation = "TAC Pool Expense Header"."Expense ID";
            ToolTip = 'Specifies the related pool expense header ID.';
        }
        field(37; Comment; Text[250])
        {
            Caption = 'Comment';
            ToolTip = 'Specifies additional free-text comments for this entry.';
        }
        field(38; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            ToolTip = 'Specifies the line number on the source document. Together with the source document and transaction type it prevents duplicate pool entries.';
        }
        field(39; "Posted to G/L"; Boolean)
        {
            Caption = 'Posted to G/L';
            ToolTip = 'Specifies whether this pool ledger entry has been successfully posted to the general ledger.';
        }
        field(40; "G/L Posted At"; DateTime)
        {
            Caption = 'G/L Posted At';
            ToolTip = 'Specifies when this pool ledger entry was successfully posted to the general ledger.';
        }
        field(41; "Source Type";Enum "TAC Pool Source Type")
        {
            Caption = 'Source Type';
            ToolTip = 'Specifies the type of source record that created this entry.';
        }
        field(42; "Source System ID"; Guid)
        {
            Caption = 'Source System ID';
            ToolTip = 'Specifies the immutable system ID of the source record, when available.';
        }
        field(43; "UOM Code"; Code[20])
        {
            Caption = 'UOM Code';
            ToolTip = 'Specifies the unit of measure code for this entry.';
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Pool; "Pool Code", "Entry Type")
        {
        }
        key(PoolLegacy; "Pool Code", "Trans Type Code")
        {
            SumIndexFields = "Quantity (Kg)", Quantity, Amount, "VAT Amount";
        }
        key(PoolGroup; "Pool Group ID", "Trans Type Code")
        {
            SumIndexFields = "Quantity (Kg)", Quantity, Amount, "VAT Amount";
        }
        key(Grower; "Pool Group ID", "Grower Code", "Trans Type Code")
        {
            SumIndexFields = "Quantity (Kg)", Quantity, Amount, "VAT Amount";
        }
        key(Payment; "Pool Payment ID")
        {
        }
        key(SourceDoc; "Source Document No.", "Trans Type Code")
        {
        }
        key(SourceDocLine; "Source Document No.", "Source Line No.", "Trans Type Code")
        {
        }
        key(SourceIdentity; "Source Type", "Source System ID", "Source Line No.", "Trans Type Code")
        {
        }
    }
}
