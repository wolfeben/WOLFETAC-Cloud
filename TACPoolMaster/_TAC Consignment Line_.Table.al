table 50206 "TAC Consignment Line"
{
    Caption = 'Consignment Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Consignment No."; Code[20])
        {
            Caption = 'Consignment No.';
            TableRelation = "TAC Consignment Header"."Consignment No.";
            ToolTip = 'Specifies the parent consignment number for this detail line.';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            ToolTip = 'Specifies the line number within the consignment.';
            AutoIncrement = true;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item."No.";
            ToolTip = 'Specifies the item on this detail line.';
        }
        field(4; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Item Unit of Measure".Code where("Item No."=field("Item No."));
            ToolTip = 'Specifies the unit of measure used for the line quantity.';
        }
        field(5; Quantity; Decimal)
        {
            Caption = 'Quantity';
            ToolTip = 'Specifies the quantity in the selected unit of measure.';

            trigger OnValidate()
            begin
                testfield(Quantity);
                if Quantity <> xRec.Quantity then "Quantity (Kg)":=CalculateNormalisedKg();
            end;
        }
        field(6; "Quantity (Kg)"; Decimal)
        {
            Caption = 'Quantity (Kg)';
            ToolTip = 'Specifies the normalized kilogram quantity for allocation and pool posting.';
        }
        field(7; "Pool Week"; Integer)
        {
            Caption = 'Pool Week';
            ToolTip = 'Specifies the ISO pool week for this line.';
        }
        field(8; "Season Code"; Code[10])
        {
            Caption = 'Season Code';
            ToolTip = 'Specifies the season code for pool resolution.';
        }
        field(9; "Variety Code"; Code[10])
        {
            Caption = 'Variety Code';
            ToolTip = 'Specifies the variety code for pool resolution.';
        }
        field(10; "Pack Type Code"; Code[20])
        {
            Caption = 'Pack Type Code';
            ToolTip = 'Specifies the pack type code used for dimension analysis.';
        }
        field(11; "Grower No."; Code[20])
        {
            Caption = 'Grower No.';
            TableRelation = Vendor."No.";
            ToolTip = 'Specifies the grower (vendor) for this detail line.';
        }
        field(12; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            TableRelation = "TAC Pool"."Pool Code";
            ToolTip = 'Specifies the resolved pool code for this line.';
        }
        field(13; "External Grower Advice No."; Code[20])
        {
            Caption = 'External Grower Advice No.';
            ToolTip = 'Specifies the external grower advice reference for this line.';
        }
        field(14; "Quantity to Repack"; Decimal)
        {
            Caption = 'Quantity to Repack';
            ToolTip = 'Specifies the quantity marked for repacking.';
        }
        field(15; "Allocated Freight Cost"; Decimal)
        {
            Caption = 'Allocated Freight Cost';
            ToolTip = 'Specifies the freight amount allocated to this detail line.';
        }
        field(16; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
            TableRelation = "Dimension Set Entry"."Dimension Set ID";
            ToolTip = 'Specifies the dimension set ID for this detail line.';
        }
        field(17; "Source Type"; Integer)
        {
            Caption = 'Source Type';
            ToolTip = 'Specifies the source document type for this detail line.';
        }
        field(18; "Source No."; Code[20])
        {
            Caption = 'Source Document No.';
            ToolTip = 'Specifies the source document number for this detail line.';
        }
        field(19; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            ToolTip = 'Specifies the source line number for this detail line.';
        }
        field(20; "Estimated Price"; Decimal)
        {
            Caption = 'Estimated Price';
            ToolTip = 'Specifies the estimated price for this detail line.';
        }
        field(21; "Qty. Shipped Not Invoiced"; Decimal)
        {
            Caption = 'Qty. Shipped Not Invoiced';
            ToolTip = 'Specifies the quantity that has been shipped but not yet invoiced for this detail line.';
            FieldClass = FlowField;
            CalcFormula = sum("Sales Shipment Line"."Qty. Shipped Not Invoiced" where("Document No."=field("Source No."), "Line No."=field("Source Line No.")));
        }
    }
    keys
    {
        key(PK; "Consignment No.", "Line No.")
        {
            Clustered = true;
        }
        key(Pool; "Pool Code")
        {
        }
    }
    procedure CalculateNormalisedKg(): Decimal var
        Item: Record Item;
        ItemUOMRec: Record "Item Unit of Measure";
        UOMMgt: Codeunit "Unit of Measure Management";
    begin
        Item.Get("Item No.");
        exit(Quantity * UOMMgt.GetQtyPerUnitOfMeasure(Item, 'KG'));
    end;
    procedure EstimatedAmount(): Decimal begin
        calcfields("Qty. Shipped Not Invoiced");
        exit("Qty. Shipped Not Invoiced" * "Estimated Price");
    end;
}
