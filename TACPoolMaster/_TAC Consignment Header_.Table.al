table 50204 "TAC Consignment Header"
{
    Caption = 'Consignment Header';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Consignment No."; Code[30])
        {
            Caption = 'Consignment No.';
            ToolTip = 'Specifies the unique consignment number.';
        }
        field(2; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Open,Released,Despatched,Posted,Cancelled;
            ToolTip = 'Specifies the current processing status of the consignment.';
        }
        field(3; "Consignment Type"; Option)
        {
            Caption = 'Consignment Type';
            OptionMembers = Internal,External;
            ToolTip = 'Specifies whether the consignment is internal or external.';
        }
        field(4; "Customer Reference"; Code[35])
        {
            Caption = 'Customer Reference';
            ToolTip = 'Specifies the customer-facing reference for this consignment.';
        }
        field(5; "Final Destination"; Code[20])
        {
            Caption = 'Final Destination';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies the headline final destination freight location.';
        }
        field(6; "Despatch From Company"; Code[20])
        {
            Caption = 'Despatch From Company';
            ToolTip = 'Specifies the despatch source company identifier.';
        }
        field(7; "Despatch To Company"; Code[20])
        {
            Caption = 'Despatch To Company';
            ToolTip = 'Specifies the despatch destination company identifier.';
        }
        field(8; "Sell-to Customer No."; Code[20])
        {
            Caption = 'Sell-to Customer No.';
            TableRelation = Customer."No.";
            ToolTip = 'Specifies the sell-to customer number for this consignment.';
        }
        field(9; "Marketer Code"; Code[20])
        {
            Caption = 'Marketer Code';
            ToolTip = 'Specifies the marketer code used in pool routing.';
        }
        field(10; "Transfer Order No."; Code[20])
        {
            Caption = 'Transfer Order No.';
            TableRelation = "Transfer Header"."No.";
            ToolTip = 'Specifies the related transfer order number.';
        }
        field(11; "Sales Order No."; Code[20])
        {
            Caption = 'Sales Order No.';
            TableRelation = "Sales Header"."No." where("Document Type" = const(Order));
            ToolTip = 'Specifies the related sales order number.';
        }
        field(12; "Despatch Date"; Date)
        {
            Caption = 'Despatch Date';
            ToolTip = 'Specifies the despatch date used for validations and rate resolution.';
        }
        field(13; "Estimated Date of Arrival"; Date)
        {
            Caption = 'Estimated Date of Arrival';
            ToolTip = 'Specifies the estimated date of arrival.';
        }
        field(14; "ICA Docket No."; Code[20])
        {
            Caption = 'ICA Docket No.';
            ToolTip = 'Specifies the interstate certification docket number.';
        }
        field(15; "Chiller Temperature"; Decimal)
        {
            Caption = 'Chiller Temperature';
            ToolTip = 'Specifies the recorded chiller temperature for this consignment.';
        }
        field(16; "No. of Units"; Decimal)
        {
            Caption = 'No. of Units';
            FieldClass = FlowField;
            CalcFormula = sum("TAC Consignment Line".Quantity where("Consignment No." = field("Consignment No.")));
            Editable = false;
            ToolTip = 'Shows the total unit quantity from consignment detail lines.';
        }
        field(17; "No. of Pallet Spaces"; Integer)
        {
            Caption = 'No. of Pallet Spaces';
            ToolTip = 'Specifies the number of pallet spaces used for freight calculations.';
        }
        field(18; "No. of CHEP Pallets"; Integer)
        {
            Caption = 'No. of CHEP Pallets';
            ToolTip = 'Specifies the number of CHEP pallets for transfer reconciliation.';
        }
        field(19; "Total Freight Cost"; Decimal)
        {
            Caption = 'Total Freight Cost';
            FieldClass = FlowField;
            CalcFormula = sum("TAC Consignment Freight Leg"."Freight Cost" where("Consignment No." = field("Consignment No.")));
            Editable = false;
            ToolTip = 'Shows the total freight cost from all freight legs on the consignment.';
        }
        field(20; "Total Kilograms"; Decimal)
        {
            Caption = 'Total Kilograms';
            FieldClass = FlowField;
            CalcFormula = sum("TAC Consignment Line"."Quantity (Kg)" where("Consignment No." = field("Consignment No.")));
            Editable = false;
            ToolTip = 'Shows the total kilograms from consignment detail lines.';
        }
        field(21; "Fully Paid"; Boolean)
        {
            Caption = 'Fully Paid';
            ToolTip = 'Specifies whether all related fruit payments are complete.';
        }
        field(22; Redirected; Boolean)
        {
            Caption = 'Redirected';
            ToolTip = 'Specifies whether this consignment was redirected.';
        }
        field(23; "External Consignment"; Boolean)
        {
            Caption = 'External Consignment';
            ToolTip = 'Specifies whether this is an externally sourced consignment.';
        }
        field(24; "External Grower Advice No."; Code[20])
        {
            Caption = 'External Grower Advice No.';
            ToolTip = 'Specifies the external grower advice reference number.';
        }
        field(25; "Posted to Pool"; Boolean)
        {
            Caption = 'Posted to Pool';
            ToolTip = 'Specifies whether this consignment has been posted to pool ledger.';
        }
        field(26; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
            TableRelation = "Dimension Set Entry"."Dimension Set ID";
            ToolTip = 'Specifies the dimension set ID applied to this consignment.';
        }
        field(27; "Fruit Payment Exists"; Boolean)
        {
            Caption = 'Fruit Payment Exists';
            ToolTip = 'Specifies whether a fruit payment exists for this consignment.';
            fieldclass = flowfield;
            CalcFormula = exist("TAC Consignment Fruit Payment" where("Consignment No." = field("Consignment No.")));
        }
        field(100; "Shipped Not Invoiced"; Decimal)
        {
            Caption = 'Shipped Not Invoiced';
            FieldClass = FlowField;
            CalcFormula = sum("Sales Line"."Shipped Not Invoiced" where("Consignment No." = field("Consignment No.")));
            Editable = false;
            ToolTip = 'Shows the total quantity shipped but not invoiced from consignment detail lines.';
        }
    }

    keys
    {
        key(PK; "Consignment No.")
        {
            Clustered = true;
        }
    }
    trigger OnInsert()
    var
        NoSeries: Codeunit "No. Series";
        PoolSetup: Record "TAC Pool Setup";
    begin
        if "Consignment No." <> '' then
            exit;
        PoolSetup.Get();
        PoolSetup.TestField("Consignment Nos.");
        "Consignment No." := NoSeries.GetNextNo(PoolSetup."Consignment Nos.");
    end;

    procedure AllocateFreightCost()
    var
        ConsmtLine: Record "TAC Consignment Line";
        LargestLine: Record "TAC Consignment Line";
        PooLSetup: Record "TAC Pool Setup";
        AmountRoundingPrecision: Decimal;
        MaxQuantityKg: Decimal;
        LineAllocation: Decimal;
        AllocatedTotal: Decimal;
        RoundingDiff: Decimal;
    begin
        CalcFields("Total Freight Cost", "Total Kilograms");
        if "Total Freight Cost" = 0 then
            Error('Total Freight Cost cannot be zero.');

        PooLSetup.Get();
        AmountRoundingPrecision := PooLSetup."Freight Rounding Precision";
        if AmountRoundingPrecision = 0 then
            AmountRoundingPrecision := 0.01;

        ConsmtLine.SetRange("Consignment No.", "Consignment No.");
        if not ConsmtLine.FindSet() then
            exit;

        if "Total Kilograms" = 0 then begin
            repeat
                if ConsmtLine."Allocated Freight Cost" <> 0 then begin
                    ConsmtLine."Allocated Freight Cost" := 0;
                    ConsmtLine.Modify();
                end;
            until ConsmtLine.Next() = 0;
            exit;
        end;

        repeat
            LineAllocation := Round(("Total Freight Cost" * ConsmtLine."Quantity (Kg)") / "Total Kilograms", AmountRoundingPrecision);
            ConsmtLine."Allocated Freight Cost" := LineAllocation;
            ConsmtLine.Modify();

            AllocatedTotal += LineAllocation;

            if (LargestLine."Consignment No." = '') or (ConsmtLine."Quantity (Kg)" > MaxQuantityKg) then begin
                MaxQuantityKg := ConsmtLine."Quantity (Kg)";
                LargestLine := ConsmtLine;
            end;
        until ConsmtLine.Next() = 0;

        // Force exact total by placing any rounding remainder on the largest line.
        RoundingDiff := Round("Total Freight Cost" - AllocatedTotal, AmountRoundingPrecision);
        if (RoundingDiff <> 0) and (LargestLine."Consignment No." <> '') then begin
            LargestLine."Allocated Freight Cost" += RoundingDiff;
            LargestLine.Modify();
        end;
    end;
    // open items: more mapping rules for the consignment header!!!
    procedure InitiateFromSalesOrder(SalesOrder: Record "Sales Header")
    var
        CarrierManifest: Record "TAC Carrier Manifest";
        FreightLocation: Record "TAC Freight Location";
    begin
        "Consignment No." := SalesOrder."DIY_Consignment No.";
        "Sales Order No." := SalesOrder."No.";
        insert(true);
        /*FreightLocation.SetRange("BC Location Code", SalesOrder."Location Code");
        FreightLocation.SetRange(Blocked, false);
        FreightLocation.FindFirst();
        CarrierManifest.SetRange("Shipping Agent Code", SalesOrder."Shipping Agent Code");
        CarrierManifest.SetRange("Manifest Date", SalesOrder."Shipment Date");
        CarrierManifest.SetRange("From Freight Location", FreightLocation."Code");
        if not CarrierManifest.FindFirst() then begin
            CarrierManifest.Init();
            CarrierManifest."Shipping Agent Code" := SalesOrder."Shipping Agent Code";
            CarrierManifest."From Freight Location" := FreightLocation."Code";
            CarrierManifest."Manifest Date" := SalesOrder."Shipment Date";
            CarrierManifest.Insert(true);
        end;*/
    end;

    procedure InitiateFromTransfer(TransferHeader: Record "Transfer Header")
    var
        CarrierManifest: Record "TAC Carrier Manifest";
        FreightLocation: Record "TAC Freight Location";
        FromCode: Code[20];
        ToCode: Code[20];
    begin
        "Consignment No." := TransferHeader."DIY_Consignment No.";
        "Transfer Order No." := TransferHeader."No.";
        insert(true);

        /*
                CarrierManifest.SetRange("Shipping Agent Code", TransferHeader."Shipping Agent Code");
                CarrierManifest.SetRange("Manifest Date", TransferHeader."Shipment Date");

                FreightLocation.SetRange("BC Location Code", TransferHeader."Transfer-from Code");
                FreightLocation.SetRange(Blocked, false);
                FreightLocation.FindFirst();
                FromCode := FreightLocation."Code";
                CarrierManifest.SetRange("From Freight Location", FromCode);

                FreightLocation.SetRange("BC Location Code", TransferHeader."Transfer-to Code");
                FreightLocation.SetRange(Blocked, false);
                FreightLocation.FindFirst();
                ToCode := FreightLocation."Code";
                CarrierManifest.SetRange("To Freight Location", ToCode);

                if not CarrierManifest.FindFirst() then begin
                    CarrierManifest.Init();
                    CarrierManifest."Shipping Agent Code" := TransferHeader."Shipping Agent Code";
                    CarrierManifest."Manifest Date" := TransferHeader."Shipment Date";
                    CarrierManifest."From Freight Location" := FromCode;
                    CarrierManifest."To Freight Location" := ToCode;
                    CarrierManifest.Insert(true);
                end;
                */
    end;
}