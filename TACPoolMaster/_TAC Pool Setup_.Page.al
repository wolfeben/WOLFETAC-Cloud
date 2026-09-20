page 50262 "TAC Pool Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "TAC Pool Setup";
    Caption = 'Pool Payment Setup';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Consignment Nos."; Rec."Consignment Nos.") { }
                field("Pool Nos."; Rec."Pool Nos.") { }
                field("Freight Allocation Basis"; Rec."Freight Allocation Basis") { }
                field("Freight Rounding Precision"; Rec."Freight Rounding Precision") { }
                field("Allow Prov. with Unpriced KG"; Rec."Allow Prov. with Unpriced KG") { }
                field("Allow Invoice Credits"; Rec."Allow Invoice Credits")
                {
                    ToolTip = 'Specifies whether credit memos applied to pooled invoices reverse the related pool revenue and charge entries.';
                }
            }
            /*group("Number Series")
            {
                Caption = 'Number Series';
                field("Pool Group Nos."; Rec."Pool Group Nos.") { }
                field("Pool Ledger Entry Nos."; Rec."Pool Ledger Entry Nos.") { }
                field("Pool Payment Nos."; Rec."Pool Payment Nos.") { }
            }*/
            group(Dimensions)
            {
                Caption = 'Pool Dimensions';
                InstructionalText = 'Pooling reads these dimensions from the source document. All seven must be set before a production order or consignment can pool.';

                field("Season Dimension Code"; Rec."Season Dimension Code")
                {
                    ToolTip = 'Specifies the dimension that carries the season.';
                }
                field("Pool Week Dimension Code"; Rec."Pool Week Dimension Code")
                {
                    ToolTip = 'Specifies the dimension that carries the pool week. Its value selects the Pool Group.';
                }
                field("Variety Dimension Code"; Rec."Variety Dimension Code")
                {
                    ToolTip = 'Specifies the dimension that carries the variety. Part of the pool key.';
                }
                field("Grade Dimension Code"; Rec."Grade Dimension Code")
                {
                    ToolTip = 'Specifies the dimension that carries the grade. Part of the pool key.';
                }
                field("Size Dimension Code"; Rec."Size Dimension Code")
                {
                    ToolTip = 'Specifies the dimension that carries the size. Part of the pool key.';
                }
                field("Grower Dimension Code"; Rec."Grower Dimension Code")
                {
                    ToolTip = 'Specifies the dimension whose values are the grower codes. A grower resolves to a vendor through the same dimension on the vendor card.';
                }
                field("Grower Pool Type Dim. Code"; Rec."Grower Pool Type Dim. Code")
                {
                    ToolTip = 'Specifies the dimension that carries the grower pool type (I, E or G). Its value selects the Pool Group alongside the pool week.';
                }
                field("Pack Type Dimension Code"; Rec."Pack Type Dimension Code")
                {
                    ToolTip = 'Specifies the dimension that supplies Pack Type when matching charge templates.';
                }
                field("Pack Type Category Dim. Code"; Rec."Pack Type Category Dim. Code")
                {
                    ToolTip = 'Specifies the dimension that supplies Pack Type Category when matching charge templates.';
                }
                field("Default Pool Dimension Code"; Rec."Default Pool Dimension Code") { }
            }
            group("Packing Orders")
            {
                Caption = 'Packing Orders';
                InstructionalText = 'Which production orders pool. Until this is set, no production order pools.';

                field("Packed Item No. Prefix"; Rec."Packed Item No. Prefix")
                {
                    ToolTip = 'Specifies the item number prefix that marks output as a packing run, for example PKD. A production order pools when it is finished if it has posted output for an item whose number starts with this prefix. The production order number itself is not used.';
                }
            }
            group("Units of Measure")
            {
                Caption = 'Pool Units of Measure';
                InstructionalText = 'How a pack run is measured. All three must be set before a production order can pool.';

                field("Tray Equiv. UoM Code"; Rec."Tray Equiv. UoM Code")
                {
                    ToolTip = 'Specifies the unit of measure the packed output is counted in. Falls back to the item''s base unit of measure when the output item carries no such conversion.';
                }
                field("Kg UoM Code"; Rec."Kg UoM Code")
                {
                    ToolTip = 'Specifies the unit of measure used to convert packed output to kilograms. Falls back to the item''s Net Weight when the output item carries no such conversion.';
                }
                field("Bin UoM Code"; Rec."Bin UoM Code")
                {
                    ToolTip = 'Specifies the base unit of measure of the bin items a pack run consumes. An order that consumes none of these is treated as a repack and does not pool.';
                }
            }
            group("Provisional Payments")
            {
                Caption = 'Provisional Payments';
                InstructionalText = 'How much of a pool is paid at each provisional close. The percentages are cumulative shares of the pool, and the final close pays the balance. Internal pools allow two provisional closes; every other pool type allows one.';

                field("Internal Prov. 1 %"; Rec."Internal Prov. 1 %")
                {
                    ToolTip = 'Specifies the share of an Internal pool paid at its first provisional close.';
                }
                field("Internal Prov. 2 %"; Rec."Internal Prov. 2 %")
                {
                    ToolTip = 'Specifies the additional share of an Internal pool paid at its second provisional close. Together with the first percentage this is the cumulative total paid before final close, so the two cannot exceed 100%.';
                }
                field("External Prov. 1 %"; Rec."External Prov. 1 %")
                {
                    ToolTip = 'Specifies the share of a non-Internal pool paid at its single provisional close.';
                }
                field("Final Residual Tolerance"; Rec."Final Residual Tolerance")
                {
                    ToolTip = 'Specifies the allowed residual at final close before the close is blocked. A value of 0 enforces exact settlement.';
                }
            }
            group(Posting)
            {
                Caption = 'Posting';
                field("Pool Charge Clearing Account"; Rec."Pool Charge Clearing Account") { }
                field("Grower Posting Group"; Rec."Grower Posting Group") { }
                field("Grower Ext. Posting Group"; Rec."Grower Ext. Posting Group") { }
                field("Grower Settlement Reason Code"; Rec."Grower Settlement Reason Code")
                {
                    ToolTip = 'Specifies the reason code assigned to self-billed grower settlement purchase invoices and credit memos.';
                }
                field("Interim Revenue Account"; Rec."Interim Revenue Account") { }
                field("Interim Revenue Bal. Account"; Rec."Interim Revenue Bal. Account") { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
