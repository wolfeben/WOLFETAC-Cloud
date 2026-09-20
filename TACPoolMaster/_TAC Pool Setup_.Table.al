table 50225 "TAC Pool Setup"
{
    Caption = 'Pool Payment Setup';
    DataClassification = CustomerContent;

    // Singleton backing the Pool Payment Setup page (50262). Not in the
    // design's object inventory (which lists only the page); added here so the
    // setup page and the install codeunit (50278) have a table to read/seed.
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Consignment Nos."; Code[20])
        {
            Caption = 'Consignment Nos.';
            TableRelation = "No. Series".Code;
            ToolTip = 'Specifies the number series used for consignment numbers.';
        }
        field(3; "Pool Nos."; Code[20])
        {
            Caption = 'Pool Nos.';
            TableRelation = "No. Series".Code;
            ToolTip = 'Specifies the number series used for generated pool numbers.';
        }

        field(4; "Freight Allocation Basis"; Option)
        {
            Caption = 'Freight Allocation Basis';
            OptionMembers = Kilograms,Units;
            InitValue = Kilograms;
            ToolTip = 'Specifies whether freight allocation is based on kilograms or units.';
        }

        field(5; "Freight Rounding Precision"; Decimal)
        {
            Caption = 'Freight Rounding Precision';
            InitValue = 0.01;
            ToolTip = 'Specifies the rounding precision used when allocating freight.';
        }
        field(6; "Default Pool Dimension Code"; Code[20])
        {
            Caption = 'Default Pool Dimension Code';
            TableRelation = Dimension.Code;
            ToolTip = 'Specifies the default pool dimension code used by posting logic.';
        }
        field(7; "Allow Prov. with Unpriced KG"; Boolean)
        {
            Caption = 'Allow Provisional with Unpriced Kg';
            ToolTip = 'Specifies whether provisional closes are allowed when there are unpriced kilograms in the pool.';
        }
        field(10; "Pool Charge Clearing Account"; Code[20])
        {
            Caption = 'Pool Charge Clearing Account';
            TableRelation = "G/L Account"."No.";
        }
        // The seven pool dimensions. All configuration, never literals in code:
        // dimension names differ per tenant and a wrong literal resolves to
        // blank silently — collapsing every pool into one, or leaving a group
        // with no week (ADR-004, OI-PE-07). Grower keeps ID 15 (it shipped
        // first); the rest follow at 30+.
        field(15; "Grower Dimension Code"; Code[20])
        {
            Caption = 'Grower Dimension Code';
            TableRelation = Dimension;
            // Also the vendor's own default dimension — that is how a grower
            // resolves to a vendor (ADR-004).
        }
        field(30; "Season Dimension Code"; Code[20])
        {
            Caption = 'Season Dimension Code';
            TableRelation = Dimension;
        }
        field(31; "Pool Week Dimension Code"; Code[20])
        {
            Caption = 'Pool Week Dimension Code';
            TableRelation = Dimension;
        }
        field(32; "Variety Dimension Code"; Code[20])
        {
            Caption = 'Variety Dimension Code';
            TableRelation = Dimension;
        }
        field(33; "Grade Dimension Code"; Code[20])
        {
            Caption = 'Grade Dimension Code';
            TableRelation = Dimension;
        }
        field(34; "Size Dimension Code"; Code[20])
        {
            Caption = 'Size Dimension Code';
            TableRelation = Dimension;
        }
        field(35; "Grower Pool Type Dim. Code"; Code[20])
        {
            Caption = 'Grower Pool Type Dimension Code';
            TableRelation = Dimension;
        }
        // The three units of measure the Run Close path measures a pack run in.
        // Configuration for the same reason as the dimensions: a wrong code
        // silently produces zero bins or zero units, and the order then exits
        // the Run Close path without a trace (ADR-004, OI-PE-07).
        field(40; "Tray Equiv. UoM Code"; Code[10])
        {
            Caption = 'Tray Equivalent UoM Code';
            TableRelation = "Unit of Measure";
        }
        field(41; "Kg UoM Code"; Code[10])
        {
            Caption = 'Kilogram UoM Code';
            TableRelation = "Unit of Measure";
        }
        field(42; "Bin UoM Code"; Code[10])
        {
            Caption = 'Bin UoM Code';
            TableRelation = "Unit of Measure";
            // Matched against the consumed ITEM's Base Unit of Measure, which
            // is how a pack run is told from a repack.
        }
        field(50; "Packed Item No. Prefix"; Code[20])
        {
            Caption = 'Packed Item No. Prefix';
            // Which production orders pool. Matched against the ITEM NO. of the
            // order's posted output, not the order number: packing orders no
            // longer carry a number prefix of their own, but they are still the
            // only orders that output packed items.
            //
            // Configuration for the same reason as the dimensions and units of
            // measure — but note this one fails CLOSED when blank: an empty
            // prefix matches every item number, so treating blank as "match all"
            // would pool the entire production floor. Blank means "pooling not
            // configured yet" (ADR-004).
        }
        // Provisional payment percentages (Grant, 2026-08-14). A provisional
        // close pays a configured share of the pool value rather than the whole
        // of it; the balance follows at final close. The percentages are
        // CUMULATIVE targets, not increments: Internal's second provisional
        // targets Prov. 1 % + Prov. 2 % of the pool, and what has already been
        // paid is deducted. That is what makes the same arithmetic correct under
        // both the current incremental model and the reverse-and-rewrite model
        // of the new spec (P-05), where the reversal simply resets "already
        // paid" to zero.
        //
        // The close counts are unchanged: 2 provisionals for Internal, 1 for
        // every other pool type (50273 MaxProvisionalCloses).
        field(60; "Internal Prov. 1 %"; Decimal)
        {
            Caption = 'Internal Provisional 1 %';
            DecimalPlaces = 0 : 2;
            InitValue = 40;
            MinValue = 0;
            MaxValue = 100;

            trigger OnValidate()
            begin
                CheckInternalProvTotal();
            end;
        }
        field(61; "Internal Prov. 2 %"; Decimal)
        {
            Caption = 'Internal Provisional 2 %';
            DecimalPlaces = 0 : 2;
            InitValue = 40;
            MinValue = 0;
            MaxValue = 100;

            trigger OnValidate()
            begin
                CheckInternalProvTotal();
            end;
        }
        field(62; "External Prov. 1 %"; Decimal)
        {
            Caption = 'External Provisional 1 %';
            DecimalPlaces = 0 : 2;
            InitValue = 50;
            MinValue = 0;
            MaxValue = 100;
            // Applies to every non-Internal pool type, which today means
            // External (Contract Pack cannot be closed in v1).
        }
        field(63; "Final Residual Tolerance"; Decimal)
        {
            Caption = 'Final Residual Tolerance';
            DecimalPlaces = 0 : 5;
            InitValue = 0;
            MinValue = 0;
            ToolTip = 'Specifies the allowed residual at final close before the close is blocked. A value of 0 enforces exact settlement.';
        }
        field(20; "Grower Posting Group"; Code[20])
        {
            Caption = 'Grower Posting Group';
            TableRelation = "Vendor Posting Group";
        }
        field(21; "Grower Ext. Posting Group"; Code[20])
        {
            Caption = 'Grower Ext. Posting Group';
            TableRelation = "Vendor Posting Group";
        }
        field(22; "Allow Invoice Credits"; Boolean)
        {
            Caption = 'Allow Invoice Credits';
            ToolTip = 'Specifies whether a posted sales credit memo can reverse pool revenue and charges when it is applied to the original sales invoice. Unapplied credits are never included in a pool.';
        }
        field(23; "Grower Settlement Reason Code"; Code[10])
        {
            Caption = 'Grower Settlement Reason Code';
            TableRelation = "Reason Code";
            ToolTip = 'Specifies the reason code assigned to self-billed grower settlement purchase invoices and credit memos.';
        }
        field(36; "Pack Type Dimension Code"; Code[20])
        {
            Caption = 'Pack Type Dimension Code';
            TableRelation = Dimension;
            ToolTip = 'Specifies the dimension that carries the pack type used when matching pool charge templates.';
        }
        field(37; "Pack Type Category Dim. Code"; Code[20])
        {
            Caption = 'Pack Type Category Dimension Code';
            TableRelation = Dimension;
            ToolTip = 'Specifies the dimension that carries the pack type category used when matching pool charge templates.';
        }
        field(100; "Interim Revenue Account"; Code[20])
        {
            Caption = 'Interim Revenue Account';
            TableRelation = "G/L Account" where("Direct Posting" = const(true));
            toolTip = 'Specifies the interim revenue account used for posting.';
        }
        field(101; "Interim Revenue Bal. Account"; Code[20])
        {
            Caption = 'Interim Revenue Balancing Account';
            TableRelation = "G/L Account" where("Direct Posting" = const(true));
            toolTip = 'Specifies the interim revenue offset account used for posting.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        ProvTotalErr: Label 'The Internal provisional percentages total %1%. Together they cannot exceed 100% — the final close pays the balance.', Comment = '%1 = the total of the two Internal provisional percentages';

    /// <summary>
    /// The two Internal provisionals are cumulative, so together they must leave
    /// something for the final close. Checked on both fields because either one
    /// can be the edit that breaks the pair.
    /// </summary>
    local procedure CheckInternalProvTotal()
    begin
        if "Internal Prov. 1 %" + "Internal Prov. 2 %" > 100 then
            Error(ProvTotalErr, "Internal Prov. 1 %" + "Internal Prov. 2 %");
    end;

    /// <summary>
    /// The cumulative share of the pool payable by the end of the given
    /// provisional close. PriorCloseCount is the group's Provisional Close Count
    /// BEFORE this close runs, so 0 is the first provisional.
    /// </summary>
    procedure CumulativeProvisionalPct(GrowerPoolType: Enum "TAC Grower Pool Type"; PriorCloseCount: Integer): Decimal
    begin
        if GrowerPoolType <> GrowerPoolType::Internal then
            exit("External Prov. 1 %");

        if PriorCloseCount <= 0 then
            exit("Internal Prov. 1 %");
        exit("Internal Prov. 1 %" + "Internal Prov. 2 %");
    end;
}
