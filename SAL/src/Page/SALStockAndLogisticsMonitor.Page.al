page 58006 "SAL Stock & Logistics Monitor"
{
    PageType = UserControlHost;
    Caption = 'Packing & Logistics Monitor';
    ApplicationArea = All;
    UsageCategory = Tasks;
    AdditionalSearchTerms = 'SAL,Packing,Logistics,Movement,Unconsigned,Freight,In Transit,Arrivals,WebSAM';
    Permissions =
        tabledata "SAL Plan Header" = r,
        tabledata "SAL Plan Source" = r,
        tabledata "SAL Plan Pallet" = r,
        tabledata "SAL Plan Component" = r,
        tabledata "Sales Header" = r,
        tabledata "Sales Line" = r,
        tabledata "Sales Shipment Header" = r,
        tabledata "Sales Shipment Line" = r,
        tabledata "Sales Invoice Header" = r,
        tabledata "Sales Invoice Line" = r,
        tabledata "Transfer Receipt Header" = r,
        tabledata "Transfer Receipt Line" = r,
        tabledata "Transfer Header" = r,
        tabledata "Transfer Line" = r,
        tabledata "Purchase Header" = r,
        tabledata "Purchase Line" = r,
        tabledata "Purch. Rcpt. Header" = r,
        tabledata "Purch. Rcpt. Line" = r,
        tabledata "Purch. Inv. Header" = r,
        tabledata "Purch. Inv. Line" = r,
        tabledata "Shipping Agent" = r,
        tabledata "DIY_Pallet Allocation" = r,
        tabledata "DIY_Pallet Information" = r,
        tabledata Location = r;

    layout
    {
        area(Content)
        {
            usercontrol(Workspace; "SAL Stock Logistics Workspace")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    AddInReady := true;
                    LoadScreen('Packing and logistics snapshot loaded from current Business Central documents.', false);
                end;

                trigger RefreshRequested()
                begin
                    LoadScreen('Packing and logistics snapshot refreshed.', false);
                end;

                trigger OpenSourceRequested(SourceType: Text; DocumentNo: Text)
                begin
                    OpenSource(SourceType, DocumentNo);
                end;

                trigger OpenPlanRequested(PlanNo: Text; VersionNo: Integer)
                begin
                    OpenPlan(PlanNo, VersionNo);
                end;

                trigger OpenActualPalletRequested(ItemNo: Text; VariantCode: Text; PalletNo: Text)
                begin
                    OpenActualPallet(ItemNo, VariantCode, PalletNo);
                end;
            }
        }
    }

    local procedure LoadScreen(StatusMessage: Text; IsError: Boolean)
    var
        StateJson: Text;
    begin
        if not AddInReady then
            exit;
        BuildState(StateJson);
        CurrPage.Workspace.SetState(StateJson, StatusMessage, IsError);
    end;

    local procedure BuildState(var StateJson: Text)
    var
        Items: JsonArray;
        Root: JsonObject;
        Summary: JsonObject;
    begin
        ResetCounters();
        AppendSalesOrders(Items);
        AppendTransferOrders(Items);
        AppendPurchaseOrders(Items);
        AppendRecentSalesShipments(Items);
        AppendRecentTransferReceipts(Items);
        AppendRecentPurchaseReceipts(Items);

        Summary.Add('forwardCount', ForwardCount);
        Summary.Add('referenceCount', ReferenceCount);
        Summary.Add('inTransitCount', InTransitCount);
        Summary.Add('dispatchedCount', DispatchedCount);
        Summary.Add('arrivedCount', ArrivedCount);
        Summary.Add('arrivingSoonCount', ArrivingSoonCount);
        Summary.Add('trackingConnectedCount', 0);
        Summary.Add('missingDateCount', MissingDateCount);

        Root.Add('schemaVersion', 2);
        Root.Add('company', CompanyName());
        Root.Add('asOf', Format(CurrentDateTime(), 0, 9));
        Root.Add('conceptMode', false);
        Root.Add('facilityConnected', false);
        Root.Add('packingProgressKnown', false);
        Root.Add('unconsignedAvailable', false);
        Root.Add('freightTrackingConnected', false);
        Root.Add('projectionLimited', true);
        Root.Add('projectionLimit', 120);
        Root.Add('summary', Summary);
        Root.Add('items', Items);
        Root.WriteTo(StateJson);
    end;

    local procedure ResetCounters()
    begin
        ItemCount := 0;
        ForwardCount := 0;
        ReferenceCount := 0;
        InTransitCount := 0;
        DispatchedCount := 0;
        ArrivedCount := 0;
        ArrivingSoonCount := 0;
        MissingDateCount := 0;
    end;

    local procedure AppendSalesOrders(var Items: JsonArray)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SourceType: Enum "SAL Source Type";
        Item: JsonObject;
        MovementLines: JsonArray;
        CarrierName: Text;
        DestinationName: Text;
        FirstShipmentDate: Date;
        AddedForSource: Integer;
        LineCount: Integer;
        OutstandingQuantity: Decimal;
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetFilter(Status, '%1|%2', SalesHeader.Status::Open, SalesHeader.Status::Released);
        if not SalesHeader.FindSet() then
            exit;

        repeat
            Clear(SalesLine);
            SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetRange(Type, SalesLine.Type::Item);
            SalesLine.SetFilter("No.", '<>%1', '');
            SalesLine.SetFilter("Outstanding Quantity", '>0');
            LineCount := 0;
            OutstandingQuantity := 0;
            Clear(MovementLines);
            FirstShipmentDate := SalesHeader."Shipment Date";
            if SalesLine.FindSet() then
                repeat
                    LineCount += 1;
                    OutstandingQuantity += SalesLine."Outstanding Quantity";
                    AddMovementLine(MovementLines, SalesLine."No.", SalesLine.Description, SalesLine."Variant Code",
                        SalesLine."Outstanding Quantity", SalesLine."Unit of Measure Code", 'Outstanding', 0);
                    if (FirstShipmentDate = 0D) and (SalesLine."Shipment Date" <> 0D) then
                        FirstShipmentDate := SalesLine."Shipment Date";
                until SalesLine.Next() = 0;

            if LineCount > 0 then begin
                CarrierName := GetShippingAgentName(SalesHeader."Shipping Agent Code");
                DestinationName := SalesHeader."Ship-to Name";
                if DestinationName = '' then
                    DestinationName := SalesHeader."Sell-to Customer Name";
                Clear(Item);
                AddCommonItem(Item, 'Sales Order', SalesHeader."No.", 'Outbound', 'forward-planned',
                    ResolveForwardStage(SalesHeader."Shipping Agent Code", SalesHeader."Package Tracking No."),
                    Format(SalesHeader.Status), SalesHeader."Sell-to Customer Name", SalesHeader."Location Code", DestinationName,
                    CarrierName, SalesHeader."Shipping Agent Service Code", SalesHeader."Package Tracking No.",
                    FirstShipmentDate, 0D, OutstandingQuantity, LineCount);
                Item.Add('movementLines', MovementLines);
                Item.Add('relatedDocumentNo', '');
                AddSALPlanContext(Item, SourceType::SalesOrder, SalesHeader."No.", SalesHeader.Status = SalesHeader.Status::Released);
                AddSalesInvoiceLink(Item, SalesHeader."No.", '');
                Item.Add('dateSource', 'Sales Order shipment date');
                Item.Add('connectionState', 'Order data only');
                Item.Add('dataNote', 'Carrier reference is shown when present; live ETA and tracking are not connected.');
                Items.Add(Item);
                RegisterForwardItem(FirstShipmentDate, SalesHeader."Shipping Agent Code", SalesHeader."Package Tracking No.");
                ItemCount += 1;
                AddedForSource += 1;
            end;
        until (SalesHeader.Next() = 0) or (AddedForSource >= 30);
    end;

    local procedure AppendTransferOrders(var Items: JsonArray)
    var
        DestinationLocation: Record Location;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        SourceType: Enum "SAL Source Type";
        Item: JsonObject;
        MovementLines: JsonArray;
        CarrierName: Text;
        DestinationName: Text;
        FirstReceiptDate: Date;
        FirstShipmentDate: Date;
        AddedForSource: Integer;
        InTransitQuantity: Decimal;
        LineCount: Integer;
        OutstandingQuantity: Decimal;
    begin
        if ItemCount >= 120 then
            exit;
        TransferHeader.SetFilter(Status, '%1|%2', TransferHeader.Status::Open, TransferHeader.Status::Released);
        if not TransferHeader.FindSet() then
            exit;

        repeat
            Clear(TransferLine);
            TransferLine.SetRange("Document No.", TransferHeader."No.");
            TransferLine.SetFilter("Item No.", '<>%1', '');
            LineCount := 0;
            OutstandingQuantity := 0;
            InTransitQuantity := 0;
            Clear(MovementLines);
            FirstShipmentDate := TransferHeader."Shipment Date";
            FirstReceiptDate := TransferHeader."Receipt Date";
            if TransferLine.FindSet() then
                repeat
                    if (TransferLine."Outstanding Quantity" > 0) or (TransferLine."Qty. in Transit" > 0) then begin
                        LineCount += 1;
                        OutstandingQuantity += TransferLine."Outstanding Quantity";
                        InTransitQuantity += TransferLine."Qty. in Transit";
                        AddMovementLine(MovementLines, TransferLine."Item No.", TransferLine.Description, TransferLine."Variant Code",
                            TransferLine."Outstanding Quantity", TransferLine."Unit of Measure Code", 'Transfer', TransferLine."Qty. in Transit");
                        if (FirstShipmentDate = 0D) and (TransferLine."Shipment Date" <> 0D) then
                            FirstShipmentDate := TransferLine."Shipment Date";
                        if (FirstReceiptDate = 0D) and (TransferLine."Receipt Date" <> 0D) then
                            FirstReceiptDate := TransferLine."Receipt Date";
                    end;
                until TransferLine.Next() = 0;

            if LineCount > 0 then begin
                DestinationName := TransferHeader."Transfer-to Code";
                if DestinationLocation.Get(TransferHeader."Transfer-to Code") then
                    DestinationName := DestinationLocation.Name;
                CarrierName := GetShippingAgentName(TransferHeader."Shipping Agent Code");
                Clear(Item);
                AddCommonItem(Item, 'Transfer Order', TransferHeader."No.", 'Inter-DC',
                    ResolveTransferStageKey(InTransitQuantity),
                    ResolveTransferStage(TransferHeader."Shipping Agent Code", InTransitQuantity), Format(TransferHeader.Status),
                    StrSubstNo('%1 to %2', TransferHeader."Transfer-from Code", TransferHeader."Transfer-to Code"),
                    TransferHeader."Transfer-from Code", DestinationName, CarrierName,
                    TransferHeader."Shipping Agent Service Code", '', FirstShipmentDate, FirstReceiptDate,
                    OutstandingQuantity, LineCount);
                Item.Add('movementLines', MovementLines);
                Item.Add('relatedDocumentNo', '');
                AddSALPlanContext(Item, SourceType::TransferOrder, TransferHeader."No.", TransferHeader.Status = TransferHeader.Status::Released);
                AddNoInvoiceLink(Item);
                Item.Add('inTransitQuantity', InTransitQuantity);
                Item.Add('dateSource', 'Transfer Order shipment and receipt dates');
                Item.Add('connectionState', 'Order data only');
                Item.Add('dataNote', 'Transfer dates are planned BC dates; carrier tracking is not connected.');
                Items.Add(Item);
                RegisterForwardItem(FirstShipmentDate, TransferHeader."Shipping Agent Code", '');
                if InTransitQuantity > 0 then
                    InTransitCount += 1;
                if (FirstReceiptDate >= Today()) and (FirstReceiptDate <= CalcDate('<7D>', Today())) then
                    ArrivingSoonCount += 1;
                ItemCount += 1;
                AddedForSource += 1;
            end;
        until (TransferHeader.Next() = 0) or (AddedForSource >= 20);
    end;

    local procedure AppendPurchaseOrders(var Items: JsonArray)
    var
        DestinationLocation: Record Location;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Item: JsonObject;
        MovementLines: JsonArray;
        DestinationName: Text;
        FirstExpectedReceiptDate: Date;
        AddedForSource: Integer;
        LineCount: Integer;
        OutstandingQuantity: Decimal;
    begin
        if ItemCount >= 120 then
            exit;
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetFilter(Status, '%1|%2', PurchaseHeader.Status::Open, PurchaseHeader.Status::Released);
        if not PurchaseHeader.FindSet() then
            exit;

        repeat
            Clear(PurchaseLine);
            PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
            PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
            PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
            PurchaseLine.SetFilter("No.", '<>%1', '');
            PurchaseLine.SetFilter("Outstanding Quantity", '>0');
            LineCount := 0;
            OutstandingQuantity := 0;
            Clear(MovementLines);
            FirstExpectedReceiptDate := 0D;
            if PurchaseLine.FindSet() then
                repeat
                    LineCount += 1;
                    OutstandingQuantity += PurchaseLine."Outstanding Quantity";
                    AddMovementLine(MovementLines, PurchaseLine."No.", PurchaseLine.Description, PurchaseLine."Variant Code",
                        PurchaseLine."Outstanding Quantity", PurchaseLine."Unit of Measure Code", 'Outstanding', 0);
                    if (PurchaseLine."Expected Receipt Date" <> 0D) and
                       ((FirstExpectedReceiptDate = 0D) or (PurchaseLine."Expected Receipt Date" < FirstExpectedReceiptDate))
                    then
                        FirstExpectedReceiptDate := PurchaseLine."Expected Receipt Date";
                until PurchaseLine.Next() = 0;

            if LineCount > 0 then begin
                DestinationName := PurchaseHeader."Location Code";
                if DestinationLocation.Get(PurchaseHeader."Location Code") then
                    DestinationName := DestinationLocation.Name;
                Clear(Item);
                AddCommonItem(Item, 'Purchase Order', PurchaseHeader."No.", 'Inbound', 'inbound-planned', 'Inbound planned',
                    Format(PurchaseHeader.Status), PurchaseHeader."Buy-from Vendor Name", 'Vendor', DestinationName,
                    'Not supplied in this projection', '', '', 0D, FirstExpectedReceiptDate,
                    OutstandingQuantity, LineCount);
                Item.Add('movementLines', MovementLines);
                Item.Add('relatedDocumentNo', '');
                AddNoSALPlanContext(Item, 'Not applicable / not confirmed');
                AddPurchaseInvoiceLink(Item, PurchaseHeader."No.", '');
                Item.Add('dateSource', 'Purchase Line expected receipt date');
                Item.Add('connectionState', 'Inbound order data only');
                Item.Add('dataNote', 'Expected receipt comes from the purchase order; freight booking and tracking are not connected.');
                Items.Add(Item);
                ForwardCount += 1;
                if FirstExpectedReceiptDate = 0D then
                    MissingDateCount += 1;
                if (FirstExpectedReceiptDate >= Today()) and (FirstExpectedReceiptDate <= CalcDate('<7D>', Today())) then
                    ArrivingSoonCount += 1;
                ItemCount += 1;
                AddedForSource += 1;
            end;
        until (PurchaseHeader.Next() = 0) or (AddedForSource >= 25);
    end;

    local procedure AppendRecentSalesShipments(var Items: JsonArray)
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
        SourceType: Enum "SAL Source Type";
        Item: JsonObject;
        MovementLines: JsonArray;
        DestinationName: Text;
        AddedForSource: Integer;
        LineCount: Integer;
        ShipmentQuantity: Decimal;
    begin
        if ItemCount >= 120 then
            exit;
        SalesShipmentHeader.SetFilter("Shipment Date", '>=%1', CalcDate('<-60D>', Today()));
        if not SalesShipmentHeader.FindSet() then
            exit;

        repeat
            Clear(SalesShipmentLine);
            SalesShipmentLine.SetRange("Document No.", SalesShipmentHeader."No.");
            SalesShipmentLine.SetRange(Type, SalesShipmentLine.Type::Item);
            SalesShipmentLine.SetFilter("No.", '<>%1', '');
            LineCount := 0;
            ShipmentQuantity := 0;
            Clear(MovementLines);
            if SalesShipmentLine.FindSet() then
                repeat
                    LineCount += 1;
                    ShipmentQuantity += SalesShipmentLine.Quantity;
                    AddMovementLine(MovementLines, SalesShipmentLine."No.", SalesShipmentLine.Description, SalesShipmentLine."Variant Code",
                        SalesShipmentLine.Quantity, SalesShipmentLine."Unit of Measure Code", 'Shipped', 0);
                until SalesShipmentLine.Next() = 0;

            DestinationName := SalesShipmentHeader."Ship-to Name";
            if DestinationName = '' then
                DestinationName := SalesShipmentHeader."Sell-to Customer Name";
            Clear(Item);
            AddCommonItem(Item, 'Posted Sales Shipment', SalesShipmentHeader."No.", 'Outbound', 'dispatched',
                ResolveDispatchedStage(SalesShipmentHeader."Package Tracking No."), 'Posted',
                SalesShipmentHeader."Sell-to Customer Name", SalesShipmentHeader."Location Code", DestinationName,
                GetShippingAgentName(SalesShipmentHeader."Shipping Agent Code"),
                SalesShipmentHeader."Shipping Agent Service Code", SalesShipmentHeader."Package Tracking No.",
                SalesShipmentHeader."Shipment Date", 0D, ShipmentQuantity, LineCount);
            Item.Add('movementLines', MovementLines);
            Item.Add('relatedDocumentNo', SalesShipmentHeader."Order No.");
            AddSALPlanContext(Item, SourceType::SalesOrder, SalesShipmentHeader."Order No.", true);
            AddSalesInvoiceLink(Item, SalesShipmentHeader."Order No.", SalesShipmentHeader."No.");
            Item.Add('dateSource', 'Posted Sales Shipment date');
            Item.Add('connectionState', 'Dispatch posted · tracking not connected');
            Item.Add('dataNote', 'Posting confirms dispatch. Current location and ETA require a carrier or freight integration.');
            Items.Add(Item);
            DispatchedCount += 1;
            ItemCount += 1;
            AddedForSource += 1;
        until (SalesShipmentHeader.Next() = 0) or (AddedForSource >= 15);
    end;

    local procedure AppendRecentTransferReceipts(var Items: JsonArray)
    var
        TransferReceiptHeader: Record "Transfer Receipt Header";
        TransferReceiptLine: Record "Transfer Receipt Line";
        SourceType: Enum "SAL Source Type";
        Item: JsonObject;
        MovementLines: JsonArray;
        AddedForSource: Integer;
        LineCount: Integer;
        ReceivedQuantity: Decimal;
    begin
        TransferReceiptHeader.SetFilter("Receipt Date", '>=%1', CalcDate('<-60D>', Today()));
        if not TransferReceiptHeader.FindSet() then
            exit;

        repeat
            Clear(TransferReceiptLine);
            TransferReceiptLine.SetRange("Document No.", TransferReceiptHeader."No.");
            TransferReceiptLine.SetFilter("Item No.", '<>%1', '');
            LineCount := 0;
            ReceivedQuantity := 0;
            Clear(MovementLines);
            if TransferReceiptLine.FindSet() then
                repeat
                    LineCount += 1;
                    ReceivedQuantity += TransferReceiptLine.Quantity;
                    AddMovementLine(MovementLines, TransferReceiptLine."Item No.", TransferReceiptLine.Description, TransferReceiptLine."Variant Code",
                        TransferReceiptLine.Quantity, TransferReceiptLine."Unit of Measure Code", 'Received', 0);
                until TransferReceiptLine.Next() = 0;

            Clear(Item);
            AddCommonItem(Item, 'Posted Transfer Receipt', TransferReceiptHeader."No.", 'Inter-DC', 'arrived', 'Arrived', 'Posted',
                StrSubstNo('%1 to %2', TransferReceiptHeader."Transfer-from Code", TransferReceiptHeader."Transfer-to Code"),
                TransferReceiptHeader."Transfer-from Code", TransferReceiptHeader."Transfer-to Code", 'Not supplied', '', '',
                0D, 0D, ReceivedQuantity, LineCount);
            Item.Add('movementLines', MovementLines);
            Item.Add('actualArrival', FormatDate(TransferReceiptHeader."Receipt Date"));
            Item.Add('relatedDocumentNo', TransferReceiptHeader."Transfer Order No.");
            AddSALPlanContext(Item, SourceType::TransferOrder, TransferReceiptHeader."Transfer Order No.", true);
            AddNoInvoiceLink(Item);
            Item.Add('dateSource', 'Posted Transfer Receipt date');
            Item.Add('connectionState', 'Arrival posted in BC');
            Item.Add('dataNote', 'The posted receipt is reliable evidence that the inter-DC movement arrived.');
            Items.Add(Item);
            ArrivedCount += 1;
            ItemCount += 1;
            AddedForSource += 1;
        until (TransferReceiptHeader.Next() = 0) or (AddedForSource >= 15);
    end;

    local procedure AppendRecentPurchaseReceipts(var Items: JsonArray)
    var
        PurchReceiptHeader: Record "Purch. Rcpt. Header";
        PurchReceiptLine: Record "Purch. Rcpt. Line";
        Item: JsonObject;
        MovementLines: JsonArray;
        AddedForSource: Integer;
        LineCount: Integer;
        ReceivedQuantity: Decimal;
    begin
        PurchReceiptHeader.SetFilter("Posting Date", '>=%1', CalcDate('<-60D>', Today()));
        if not PurchReceiptHeader.FindSet() then
            exit;

        repeat
            Clear(PurchReceiptLine);
            PurchReceiptLine.SetRange("Document No.", PurchReceiptHeader."No.");
            PurchReceiptLine.SetRange(Type, PurchReceiptLine.Type::Item);
            PurchReceiptLine.SetFilter("No.", '<>%1', '');
            LineCount := 0;
            ReceivedQuantity := 0;
            Clear(MovementLines);
            if PurchReceiptLine.FindSet() then
                repeat
                    LineCount += 1;
                    ReceivedQuantity += PurchReceiptLine.Quantity;
                    AddMovementLine(MovementLines, PurchReceiptLine."No.", PurchReceiptLine.Description, PurchReceiptLine."Variant Code",
                        PurchReceiptLine.Quantity, PurchReceiptLine."Unit of Measure Code", 'Received', 0);
                until PurchReceiptLine.Next() = 0;

            Clear(Item);
            AddCommonItem(Item, 'Posted Purchase Receipt', PurchReceiptHeader."No.", 'Inbound', 'arrived', 'Arrived', 'Posted',
                PurchReceiptHeader."Buy-from Vendor Name", 'Vendor', PurchReceiptHeader."Location Code", 'Not supplied', '', '',
                0D, 0D, ReceivedQuantity, LineCount);
            Item.Add('movementLines', MovementLines);
            Item.Add('actualArrival', FormatDate(PurchReceiptHeader."Posting Date"));
            Item.Add('relatedDocumentNo', PurchReceiptHeader."Order No.");
            AddNoSALPlanContext(Item, 'Not applicable / not confirmed');
            AddPurchaseInvoiceLink(Item, PurchReceiptHeader."Order No.", PurchReceiptHeader."No.");
            Item.Add('dateSource', 'Posted Purchase Receipt date');
            Item.Add('connectionState', 'Arrival posted in BC');
            Item.Add('dataNote', 'The posted purchase receipt is reliable evidence that the inbound stock arrived.');
            Items.Add(Item);
            ArrivedCount += 1;
            ItemCount += 1;
            AddedForSource += 1;
        until (PurchReceiptHeader.Next() = 0) or (AddedForSource >= 15);
    end;

    local procedure AddCommonItem(var Item: JsonObject; SourceType: Text; DocumentNo: Code[20]; Direction: Text; StageKey: Text; Stage: Text; Status: Text; Party: Text; Origin: Text; Destination: Text; Carrier: Text; Service: Text; BookingReference: Text; ETD: Date; ETA: Date; Quantity: Decimal; LineCount: Integer)
    begin
        Item.Add('id', SourceType + ':' + DocumentNo);
        Item.Add('sourceType', SourceType);
        Item.Add('documentNo', DocumentNo);
        Item.Add('direction', Direction);
        Item.Add('stageKey', StageKey);
        Item.Add('stage', Stage);
        Item.Add('status', Status);
        Item.Add('party', Party);
        Item.Add('origin', Origin);
        Item.Add('destination', Destination);
        Item.Add('carrier', Carrier);
        Item.Add('service', Service);
        Item.Add('bookingReference', BookingReference);
        Item.Add('etd', FormatDate(ETD));
        Item.Add('eta', FormatDate(ETA));
        Item.Add('quantity', Quantity);
        Item.Add('lineCount', LineCount);
    end;

    local procedure AddMovementLine(var MovementLines: JsonArray; ItemNo: Code[20]; Description: Text; VariantCode: Code[10]; Quantity: Decimal; UnitOfMeasureCode: Code[10]; QuantityBasis: Text; InTransitQuantity: Decimal)
    var
        MovementLine: JsonObject;
    begin
        MovementLine.Add('itemNo', ItemNo);
        MovementLine.Add('description', Description);
        MovementLine.Add('variantCode', VariantCode);
        MovementLine.Add('quantity', Quantity);
        MovementLine.Add('unitOfMeasure', UnitOfMeasureCode);
        MovementLine.Add('quantityBasis', QuantityBasis);
        MovementLine.Add('inTransitQuantity', InTransitQuantity);
        MovementLines.Add(MovementLine);
    end;

    local procedure RegisterForwardItem(PlannedDate: Date; ShippingAgentCode: Code[10]; BookingReference: Text)
    begin
        ForwardCount += 1;
        if BookingReference <> '' then
            ReferenceCount += 1;
        if PlannedDate = 0D then
            MissingDateCount += 1;
    end;

    local procedure ResolveForwardStage(ShippingAgentCode: Code[10]; BookingReference: Text): Text
    begin
        if BookingReference <> '' then
            exit('Reference recorded');
        if ShippingAgentCode <> '' then
            exit('Carrier selected');
        exit('Forward booking not modelled');
    end;

    local procedure ResolveTransferStage(ShippingAgentCode: Code[10]; InTransitQuantity: Decimal): Text
    begin
        if InTransitQuantity > 0 then
            exit('In transit');
        if ShippingAgentCode <> '' then
            exit('Carrier selected');
        exit('Forward booking not modelled');
    end;

    local procedure ResolveTransferStageKey(InTransitQuantity: Decimal): Text
    begin
        if InTransitQuantity > 0 then
            exit('in-transit');
        exit('forward-planned');
    end;

    local procedure ResolveDispatchedStage(BookingReference: Text): Text
    begin
        if BookingReference <> '' then
            exit('Dispatched / reference available');
        exit('Dispatched / tracking not connected');
    end;

    local procedure GetShippingAgentName(ShippingAgentCode: Code[10]): Text
    var
        ShippingAgent: Record "Shipping Agent";
    begin
        if ShippingAgentCode = '' then
            exit('Not supplied');
        if ShippingAgent.Get(ShippingAgentCode) then
            exit(ShippingAgent.Name);
        exit(ShippingAgentCode);
    end;

    local procedure AddSALPlanContext(var Item: JsonObject; SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; SourceReleased: Boolean)
    var
        PlanHeader: Record "SAL Plan Header";
        PendingDraftHeader: Record "SAL Plan Header";
        PlanComponent: Record "SAL Plan Component";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ActualPalletDetails: JsonArray;
        PalletDetails: JsonArray;
        SizeItem: JsonObject;
        SizeSummary: JsonArray;
        DescriptionByProduct: Dictionary of [Text, Text];
        PlannedByProduct: Dictionary of [Text, Decimal];
        ProductCodeByProduct: Dictionary of [Text, Text];
        RequiredByProduct: Dictionary of [Text, Decimal];
        UnitByProduct: Dictionary of [Text, Text];
        PalletNos: List of [Integer];
        ProductKeys: List of [Text];
        AllRoutingConfirmed: Boolean;
        CustomPalletCount: Integer;
        HasSource: Boolean;
        HasPendingDraft: Boolean;
        MixedPalletCount: Integer;
        PackingActionable: Boolean;
        StandardPalletCount: Integer;
        CurrentPlannedQuantity: Decimal;
        CurrentRequiredQuantity: Decimal;
        CurrentRoute: Text;
        CurrentWorkType: Text;
        DocumentPlannedQuantity: Decimal;
        DocumentRequiredQuantity: Decimal;
        PackingStatusKey: Text;
        PackingStatusLabel: Text;
        PalletNo: Integer;
        ProductCode: Text;
        ProductKey: Text;
        RouteSummary: Text;
        WorkTypeSummary: Text;
    begin
        BuildActualPalletDetails(SourceType, DocumentNo, ActualPalletDetails);
        Item.Add('actualPalletCount', ActualPalletDetails.Count());
        Item.Add('actualPalletDetails', ActualPalletDetails);

        if (DocumentNo = '') or not FindActiveSALPlan(SourceType, DocumentNo, PlanHeader) then begin
            if SourceReleased then
                AddEmptySALPlanContext(Item, 'Marketer not confirmed', 'awaiting-plan', 'Awaiting plan')
            else
                AddEmptySALPlanContext(Item, 'Marketer not confirmed', 'awaiting-release', 'Awaiting release');
            exit;
        end;

        AllRoutingConfirmed := true;
        PlanSource.SetRange("Plan No.", PlanHeader."No.");
        PlanSource.SetRange("Version No.", PlanHeader."Version No.");
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        if PlanSource.FindSet() then
            repeat
                HasSource := true;
                PlanSource.CalcFields("Planned Quantity");
                CurrentRoute := Format(PlanSource."Execution Route");
                CurrentWorkType := Format(PlanSource."Facility Work Type");
                if RouteSummary = '' then
                    RouteSummary := CurrentRoute
                else
                    if (RouteSummary <> CurrentRoute) and (RouteSummary <> 'Multiple routes') then
                        RouteSummary := 'Multiple routes';
                if WorkTypeSummary = '' then
                    WorkTypeSummary := CurrentWorkType
                else
                    if (WorkTypeSummary <> CurrentWorkType) and (WorkTypeSummary <> 'Multiple work types') then
                        WorkTypeSummary := 'Multiple work types';
                if (PlanSource."Execution Route" = PlanSource."Execution Route"::ManjimupPack) and
                   (PlanSource."Facility Work Type" in [PlanSource."Facility Work Type"::PackNew,
                                                         PlanSource."Facility Work Type"::RepackOrRelabel]) and
                   PlanSource."Routing Confirmed"
                then
                    PackingActionable := true;
                if not PlanSource."Routing Confirmed" then
                    AllRoutingConfirmed := false;

                ProductCode := PlanSource."Item No.";
                if PlanSource."Variant Code" <> '' then
                    ProductCode := StrSubstNo('%1 / %2', ProductCode, PlanSource."Variant Code");
                ProductKey := ProductCode + '|' + PlanSource."Unit of Measure Code";
                if not ProductKeys.Contains(ProductKey) then begin
                    ProductKeys.Add(ProductKey);
                    RequiredByProduct.Add(ProductKey, 0);
                    PlannedByProduct.Add(ProductKey, 0);
                    ProductCodeByProduct.Add(ProductKey, ProductCode);
                    DescriptionByProduct.Add(ProductKey, PlanSource."Item Description");
                    UnitByProduct.Add(ProductKey, PlanSource."Unit of Measure Code");
                end;
                RequiredByProduct.Get(ProductKey, CurrentRequiredQuantity);
                PlannedByProduct.Get(ProductKey, CurrentPlannedQuantity);
                RequiredByProduct.Set(ProductKey, CurrentRequiredQuantity + PlanSource.Quantity);
                PlannedByProduct.Set(ProductKey, CurrentPlannedQuantity + PlanSource."Planned Quantity");
                DocumentRequiredQuantity += PlanSource.Quantity;
                DocumentPlannedQuantity += PlanSource."Planned Quantity";

                PlanComponent.Reset();
                PlanComponent.SetRange("Plan No.", PlanSource."Plan No.");
                PlanComponent.SetRange("Version No.", PlanSource."Version No.");
                PlanComponent.SetRange("Source Line No.", PlanSource."Line No.");
                if PlanComponent.FindSet() then
                    repeat
                        if not PalletNos.Contains(PlanComponent."Pallet No.") then
                            PalletNos.Add(PlanComponent."Pallet No.");
                    until PlanComponent.Next() = 0;
            until PlanSource.Next() = 0;
        if not HasSource then
            AllRoutingConfirmed := false;

        if PlanHeader.Status = PlanHeader.Status::Released then
            HasPendingDraft := FindLatestDraftSALPlan(SourceType, DocumentNo, PendingDraftHeader);

        foreach ProductKey in ProductKeys do begin
            ProductCodeByProduct.Get(ProductKey, ProductCode);
            DescriptionByProduct.Get(ProductKey, CurrentRoute);
            UnitByProduct.Get(ProductKey, CurrentWorkType);
            RequiredByProduct.Get(ProductKey, CurrentRequiredQuantity);
            PlannedByProduct.Get(ProductKey, CurrentPlannedQuantity);
            Clear(SizeItem);
            SizeItem.Add('productCode', ProductCode);
            SizeItem.Add('description', CurrentRoute);
            SizeItem.Add('requiredQuantity', CurrentRequiredQuantity);
            SizeItem.Add('plannedQuantity', CurrentPlannedQuantity);
            SizeItem.Add('unitOfMeasure', CurrentWorkType);
            SizeSummary.Add(SizeItem);
        end;

        foreach PalletNo in PalletNos do
            if PlanPallet.Get(PlanHeader."No.", PlanHeader."Version No.", PalletNo) then
                case PlanPallet."Pallet Type" of
                    PlanPallet."Pallet Type"::Standard:
                        StandardPalletCount += 1;
                    PlanPallet."Pallet Type"::Custom:
                        CustomPalletCount += 1;
                    PlanPallet."Pallet Type"::Mixed:
                        MixedPalletCount += 1;
                end;

        BuildPalletDetails(PlanHeader, PalletNos, PalletDetails);

        case PlanHeader.Status of
            PlanHeader.Status::Draft:
                begin
                    PackingStatusKey := 'planning';
                    PackingStatusLabel := 'Planning';
                end;
            PlanHeader.Status::Released:
                if PackingActionable then begin
                    PackingStatusKey := 'facility-status-unavailable';
                    PackingStatusLabel := 'Cloud plan released · facility status unavailable';
                end else begin
                    PackingStatusKey := 'logistics-planned';
                    PackingStatusLabel := 'Logistics plan released';
                end;
        end;

        Item.Add('salPlanNo', PlanHeader."No.");
        Item.Add('salPlanVersionNo', PlanHeader."Version No.");
        Item.Add('salPlanStatus', Format(PlanHeader.Status));
        Item.Add('hasPendingDraft', HasPendingDraft);
        if HasPendingDraft then begin
            Item.Add('pendingDraftPlanNo', PendingDraftHeader."No.");
            Item.Add('pendingDraftVersionNo', PendingDraftHeader."Version No.");
        end else begin
            Item.Add('pendingDraftPlanNo', '');
            Item.Add('pendingDraftVersionNo', 0);
        end;
        Item.Add('salPriority', PlanHeader.Priority);
        Item.Add('requiredFinishDate', FormatDate(PlanHeader."Required Finish Date"));
        Item.Add('dispatchDate', FormatDate(PlanHeader."Dispatch Date"));
        Item.Add('salPlanValidated', PlanHeader."Validated Date Time" <> 0DT);
        Item.Add('salRequiredQuantity', DocumentRequiredQuantity);
        Item.Add('salPlannedQuantity', DocumentPlannedQuantity);
        Item.Add('salPlanBalanced', DocumentRequiredQuantity = DocumentPlannedQuantity);
        Item.Add('palletCount', PalletNos.Count());
        Item.Add('standardPalletCount', StandardPalletCount);
        Item.Add('customPalletCount', CustomPalletCount);
        Item.Add('mixedPalletCount', MixedPalletCount);
        Item.Add('palletDetails', PalletDetails);
        Item.Add('route', RouteSummary);
        Item.Add('workType', WorkTypeSummary);
        Item.Add('routingConfirmed', AllRoutingConfirmed);
        Item.Add('packingActionable', PackingActionable);
        Item.Add('packingStatusKey', PackingStatusKey);
        Item.Add('packingStatus', PackingStatusLabel);
        Item.Add('facilityConnected', false);
        Item.Add('packingProgressKnown', false);
        Item.Add('completedPalletCountKnown', false);
        Item.Add('facilityStatus', 'Not connected');
        Item.Add('unconsignedAvailable', false);
        Item.Add('sizeSummary', SizeSummary);
        if PlanHeader."Marketer Confirmed" then
            Item.Add('marketer', PlanHeader."Marketer Description")
        else
            Item.Add('marketer', 'Marketer not confirmed');
    end;

    local procedure BuildPalletDetails(PlanHeader: Record "SAL Plan Header"; PalletNos: List of [Integer]; var PalletDetails: JsonArray)
    var
        PlanComponent: Record "SAL Plan Component";
        PlanPallet: Record "SAL Plan Pallet";
        PlanSource: Record "SAL Plan Source";
        ComponentItem: JsonObject;
        Components: JsonArray;
        PalletItem: JsonObject;
        ProductCode: Text;
    begin
        Clear(PalletDetails);
        PlanPallet.SetRange("Plan No.", PlanHeader."No.");
        PlanPallet.SetRange("Version No.", PlanHeader."Version No.");
        if not PlanPallet.FindSet() then
            exit;
        repeat
            if PalletNos.Contains(PlanPallet."Pallet No.") then begin
                Clear(Components);
                PlanComponent.SetRange("Plan No.", PlanPallet."Plan No.");
                PlanComponent.SetRange("Version No.", PlanPallet."Version No.");
                PlanComponent.SetRange("Pallet No.", PlanPallet."Pallet No.");
                if PlanComponent.FindSet() then
                    repeat
                        ProductCode := PlanComponent."Item No.";
                        if PlanComponent."Variant Code" <> '' then
                            ProductCode := StrSubstNo('%1 / %2', ProductCode, PlanComponent."Variant Code");
                        Clear(ComponentItem);
                        ComponentItem.Add('lineNo', PlanComponent."Line No.");
                        ComponentItem.Add('sourceLineNo', PlanComponent."Source Line No.");
                        ComponentItem.Add('productCode', ProductCode);
                        ComponentItem.Add('description', PlanComponent.Description);
                        ComponentItem.Add('quantity', PlanComponent.Quantity);
                        ComponentItem.Add('unitOfMeasure', PlanComponent."Unit of Measure Code");
                        ComponentItem.Add('fulfilmentMode', Format(PlanComponent."Fulfilment Mode"));
                        if PlanSource.Get(PlanComponent."Plan No.", PlanComponent."Version No.", PlanComponent."Source Line No.") then
                            ComponentItem.Add('sourceDocumentNo', PlanSource."Source Document No.")
                        else
                            ComponentItem.Add('sourceDocumentNo', '');
                        Components.Add(ComponentItem);
                    until PlanComponent.Next() = 0;

                PlanPallet.CalcFields("Planned Quantity", "No. of Components");
                Clear(PalletItem);
                PalletItem.Add('sequenceNo', PlanPallet."Pallet No.");
                PalletItem.Add('plannedPalletId', StrSubstNo('Pallet %1', PlanPallet."Pallet No."));
                PalletItem.Add('physicalPalletId', '');
                PalletItem.Add('physicalIdStatus', 'Awaiting Packing Facility ID');
                PalletItem.Add('palletType', Format(PlanPallet."Pallet Type"));
                PalletItem.Add('description', PlanPallet.Description);
                PalletItem.Add('targetQuantity', PlanPallet."Target Quantity");
                PalletItem.Add('plannedQuantity', PlanPallet."Planned Quantity");
                PalletItem.Add('componentCount', PlanPallet."No. of Components");
                PalletItem.Add('packingStatus', 'Packing Facility feed not connected');
                PalletItem.Add('components', Components);
                PalletDetails.Add(PalletItem);
            end;
        until PlanPallet.Next() = 0;
    end;

    local procedure BuildActualPalletDetails(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; var ActualPalletDetails: JsonArray)
    var
        Allocation: Record "DIY_Pallet Allocation";
        PalletInfo: Record "DIY_Pallet Information";
        ComponentItem: JsonObject;
        Components: JsonArray;
        PalletItem: JsonObject;
        PalletNos: List of [Code[20]];
        ComponentKeys: List of [Text];
        ComponentKey: Text;
        PalletNo: Code[20];
        LotSummary: Text;
        LocationSummary: Text;
        StatusSummary: Text;
        SSCCSummary: Text;
        DispatchSummary: Text;
        OriginalPalletSummary: Text;
        TotalInventory: Decimal;
        EarliestPackingDate: Date;
        LatestExpirationDate: Date;
    begin
        Clear(ActualPalletDetails);
        if DocumentNo = '' then
            exit;

        Allocation.SetRange("Sales Order No.", DocumentNo);
        case SourceType of
            SourceType::SalesOrder:
                Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
            SourceType::TransferOrder:
                Allocation.SetRange("Document Type", Allocation."Document Type"::"Transfer Order");
            else
                exit;
        end;

        if Allocation.FindSet() then
            repeat
                if (Allocation."Pallet No." <> '') and not PalletNos.Contains(Allocation."Pallet No.") then
                    PalletNos.Add(Allocation."Pallet No.");
            until Allocation.Next() = 0;

        foreach PalletNo in PalletNos do begin
            Clear(Components);
            Clear(ComponentKeys);
            Clear(LotSummary);
            Clear(LocationSummary);
            Clear(StatusSummary);
            Clear(SSCCSummary);
            Clear(DispatchSummary);
            Clear(OriginalPalletSummary);
            Clear(TotalInventory);
            Clear(EarliestPackingDate);
            Clear(LatestExpirationDate);

            Allocation.Reset();
            Allocation.SetRange("Pallet No.", PalletNo);
            Allocation.SetRange("Sales Order No.", DocumentNo);
            case SourceType of
                SourceType::SalesOrder:
                    Allocation.SetRange("Document Type", Allocation."Document Type"::Order);
                SourceType::TransferOrder:
                    Allocation.SetRange("Document Type", Allocation."Document Type"::"Transfer Order");
            end;
            if Allocation.FindSet() then
                repeat
                    ComponentKey := Allocation."Item No." + '|' + Allocation."Variant Code";
                    if not ComponentKeys.Contains(ComponentKey) then begin
                        ComponentKeys.Add(ComponentKey);
                        Clear(ComponentItem);
                        ComponentItem.Add('itemNo', Allocation."Item No.");
                        ComponentItem.Add('variantCode', Allocation."Variant Code");
                        ComponentItem.Add('palletNo', Allocation."Pallet No.");
                        ComponentItem.Add('sourceLineNo', Allocation."Sales Line No.");

                        if PalletInfo.Get(Allocation."Item No.", Allocation."Variant Code", Allocation."Pallet No.") then begin
                            PalletInfo.CalcFields(Inventory, "Current Location", "Expiration Date");
                            ComponentItem.Add('description', PalletInfo.Description);
                            ComponentItem.Add('lotNo', PalletInfo."Lot No.");
                            ComponentItem.Add('inventory', PalletInfo.Inventory);
                            ComponentItem.Add('unitOfMeasure', PalletInfo."Base Unit of Measure");
                            ComponentItem.Add('status', Format(PalletInfo.Status));
                            ComponentItem.Add('sscc', PalletInfo.SSCC);
                            ComponentItem.Add('currentLocation', PalletInfo."Current Location");
                            ComponentItem.Add('expirationDate', FormatDate(PalletInfo."Expiration Date"));
                            ComponentItem.Add('originalPackingDate', FormatDate(PalletInfo."Original Packing Date"));

                            AddDelimitedValue(LotSummary, PalletInfo."Lot No.");
                            AddDelimitedValue(LocationSummary, PalletInfo."Current Location");
                            AddDelimitedValue(StatusSummary, Format(PalletInfo.Status));
                            AddDelimitedValue(SSCCSummary, PalletInfo.SSCC);
                            AddDelimitedValue(DispatchSummary, PalletInfo."Dispatch No.");
                            AddDelimitedValue(OriginalPalletSummary, PalletInfo."Original Pallet No.");
                            TotalInventory += PalletInfo.Inventory;
                            if (PalletInfo."Original Packing Date" <> 0D) and
                               ((EarliestPackingDate = 0D) or (PalletInfo."Original Packing Date" < EarliestPackingDate))
                            then
                                EarliestPackingDate := PalletInfo."Original Packing Date";
                            if PalletInfo."Expiration Date" > LatestExpirationDate then
                                LatestExpirationDate := PalletInfo."Expiration Date";
                        end else begin
                            ComponentItem.Add('description', 'Pallet master record not found');
                            ComponentItem.Add('lotNo', '');
                            ComponentItem.Add('inventory', 0);
                            ComponentItem.Add('unitOfMeasure', '');
                            ComponentItem.Add('status', 'Allocation only');
                            ComponentItem.Add('sscc', '');
                            ComponentItem.Add('currentLocation', '');
                            ComponentItem.Add('expirationDate', '');
                            ComponentItem.Add('originalPackingDate', '');
                        end;
                        Components.Add(ComponentItem);
                    end;
                until Allocation.Next() = 0;

            Clear(PalletItem);
            PalletItem.Add('palletNo', PalletNo);
            PalletItem.Add('lotNumbers', LotSummary);
            PalletItem.Add('sscc', SSCCSummary);
            PalletItem.Add('status', StatusSummary);
            PalletItem.Add('currentLocation', LocationSummary);
            PalletItem.Add('inventory', TotalInventory);
            PalletItem.Add('componentCount', Components.Count());
            PalletItem.Add('originalPackingDate', FormatDate(EarliestPackingDate));
            PalletItem.Add('expirationDate', FormatDate(LatestExpirationDate));
            PalletItem.Add('dispatchNo', DispatchSummary);
            PalletItem.Add('originalPalletNo', OriginalPalletSummary);
            PalletItem.Add('components', Components);
            ActualPalletDetails.Add(PalletItem);
        end;
    end;

    local procedure AddDelimitedValue(var Summary: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        if Summary = '' then begin
            Summary := Value;
            exit;
        end;
        if StrPos(' · ' + Summary + ' · ', ' · ' + Value + ' · ') = 0 then
            Summary += ' · ' + Value;
    end;

    local procedure AddNoSALPlanContext(var Item: JsonObject; Marketer: Text)
    var
        ActualPalletDetails: JsonArray;
    begin
        Item.Add('actualPalletCount', 0);
        Item.Add('actualPalletDetails', ActualPalletDetails);
        AddEmptySALPlanContext(Item, Marketer, 'not-applicable', 'Not applicable');
    end;

    local procedure AddEmptySALPlanContext(var Item: JsonObject; Marketer: Text; PackingStatusKey: Text; PackingStatusLabel: Text)
    var
        PalletDetails: JsonArray;
        SizeSummary: JsonArray;
    begin
        Item.Add('salPlanNo', '');
        Item.Add('salPlanVersionNo', 0);
        Item.Add('salPlanStatus', '');
        Item.Add('hasPendingDraft', false);
        Item.Add('pendingDraftPlanNo', '');
        Item.Add('pendingDraftVersionNo', 0);
        Item.Add('salPriority', 0);
        Item.Add('requiredFinishDate', '');
        Item.Add('dispatchDate', '');
        Item.Add('salPlanValidated', false);
        Item.Add('salRequiredQuantity', 0);
        Item.Add('salPlannedQuantity', 0);
        Item.Add('salPlanBalanced', false);
        Item.Add('palletCount', 0);
        Item.Add('standardPalletCount', 0);
        Item.Add('customPalletCount', 0);
        Item.Add('mixedPalletCount', 0);
        Item.Add('palletDetails', PalletDetails);
        Item.Add('route', '');
        Item.Add('workType', '');
        Item.Add('routingConfirmed', false);
        Item.Add('packingActionable', false);
        Item.Add('packingStatusKey', PackingStatusKey);
        Item.Add('packingStatus', PackingStatusLabel);
        Item.Add('facilityConnected', false);
        Item.Add('packingProgressKnown', false);
        Item.Add('completedPalletCountKnown', false);
        Item.Add('facilityStatus', 'Not connected');
        Item.Add('unconsignedAvailable', false);
        Item.Add('sizeSummary', SizeSummary);
        Item.Add('marketer', Marketer);
    end;

    local procedure FindActiveSALPlan(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; var ActivePlanHeader: Record "SAL Plan Header"): Boolean
    var
        CandidatePlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        Found: Boolean;
    begin
        Clear(ActivePlanHeader);
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        if not PlanSource.FindSet() then
            exit(false);

        repeat
            if CandidatePlanHeader.Get(PlanSource."Plan No.", PlanSource."Version No.") and
               (CandidatePlanHeader.Status in [CandidatePlanHeader.Status::Draft, CandidatePlanHeader.Status::Released])
            then
                if (not Found) or IsBetterActivePlan(CandidatePlanHeader, ActivePlanHeader) then begin
                    ActivePlanHeader := CandidatePlanHeader;
                    Found := true;
                end;
        until PlanSource.Next() = 0;
        exit(Found);
    end;

    local procedure IsBetterActivePlan(CandidatePlanHeader: Record "SAL Plan Header"; ActivePlanHeader: Record "SAL Plan Header"): Boolean
    begin
        if (CandidatePlanHeader.Status = CandidatePlanHeader.Status::Released) and
           (ActivePlanHeader.Status <> ActivePlanHeader.Status::Released)
        then
            exit(true);
        if (ActivePlanHeader.Status = ActivePlanHeader.Status::Released) and
           (CandidatePlanHeader.Status <> CandidatePlanHeader.Status::Released)
        then
            exit(false);
        if CandidatePlanHeader.Status <> ActivePlanHeader.Status then
            exit(false);
        if CandidatePlanHeader.Status = CandidatePlanHeader.Status::Released then begin
            if CandidatePlanHeader."Released Date Time" <> ActivePlanHeader."Released Date Time" then
                exit(CandidatePlanHeader."Released Date Time" > ActivePlanHeader."Released Date Time");
        end else
            if CandidatePlanHeader."Created Date Time" <> ActivePlanHeader."Created Date Time" then
                exit(CandidatePlanHeader."Created Date Time" > ActivePlanHeader."Created Date Time");
        if CandidatePlanHeader."No." <> ActivePlanHeader."No." then
            exit(CandidatePlanHeader."No." > ActivePlanHeader."No.");
        exit(CandidatePlanHeader."Version No." > ActivePlanHeader."Version No.");
    end;

    local procedure FindLatestDraftSALPlan(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]; var DraftPlanHeader: Record "SAL Plan Header"): Boolean
    var
        CandidatePlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
        Found: Boolean;
    begin
        Clear(DraftPlanHeader);
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        if not PlanSource.FindSet() then
            exit(false);

        repeat
            if CandidatePlanHeader.Get(PlanSource."Plan No.", PlanSource."Version No.") and
               (CandidatePlanHeader.Status = CandidatePlanHeader.Status::Draft)
            then
                if (not Found) or
                   (CandidatePlanHeader."Created Date Time" > DraftPlanHeader."Created Date Time") or
                   ((CandidatePlanHeader."Created Date Time" = DraftPlanHeader."Created Date Time") and
                    (CandidatePlanHeader."No." > DraftPlanHeader."No.")) or
                   ((CandidatePlanHeader."Created Date Time" = DraftPlanHeader."Created Date Time") and
                    (CandidatePlanHeader."No." = DraftPlanHeader."No.") and
                    (CandidatePlanHeader."Version No." > DraftPlanHeader."Version No."))
                then begin
                    DraftPlanHeader := CandidatePlanHeader;
                    Found := true;
                end;
        until PlanSource.Next() = 0;
        exit(Found);
    end;

    local procedure AddSalesInvoiceLink(var Item: JsonObject; OrderNo: Code[20]; ShipmentNo: Code[20])
    var
        InvoiceCount: Integer;
        InvoiceNo: Code[20];
    begin
        FindPostedSalesInvoice(OrderNo, ShipmentNo, InvoiceNo, InvoiceCount);
        AddInvoiceLink(Item, 'Customer invoice', InvoiceNo, InvoiceCount);
    end;

    local procedure AddPurchaseInvoiceLink(var Item: JsonObject; OrderNo: Code[20]; ReceiptNo: Code[20])
    var
        InvoiceCount: Integer;
        InvoiceNo: Code[20];
    begin
        FindPostedPurchaseInvoice(OrderNo, ReceiptNo, InvoiceNo, InvoiceCount);
        AddInvoiceLink(Item, 'Supplier goods invoice', InvoiceNo, InvoiceCount);
    end;

    local procedure AddNoInvoiceLink(var Item: JsonObject)
    begin
        AddInvoiceLink(Item, 'Not applicable', '', 0);
    end;

    local procedure AddInvoiceLink(var Item: JsonObject; CommercialInvoiceType: Text; CommercialInvoiceNo: Code[20]; CommercialInvoiceCount: Integer)
    begin
        Item.Add('commercialInvoiceType', CommercialInvoiceType);
        Item.Add('commercialInvoiceNo', CommercialInvoiceNo);
        Item.Add('commercialInvoiceCount', CommercialInvoiceCount);
        Item.Add('freightInvoiceState', 'Not connected');
    end;

    local procedure FindPostedSalesInvoice(OrderNo: Code[20]; ShipmentNo: Code[20]; var LatestInvoiceNo: Code[20]; var InvoiceCount: Integer)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        InvoiceNos: List of [Code[20]];
        LatestPostingDate: Date;
    begin
        Clear(LatestInvoiceNo);
        InvoiceCount := 0;

        if ShipmentNo <> '' then begin
            SalesInvoiceLine.SetCurrentKey("Shipment No.");
            SalesInvoiceLine.SetRange("Shipment No.", ShipmentNo);
        end else begin
            if OrderNo = '' then
                exit;
            SalesInvoiceLine.SetCurrentKey("Order No.");
            SalesInvoiceLine.SetRange("Order No.", OrderNo);
        end;

        if SalesInvoiceLine.FindSet() then
            repeat
                if not InvoiceNos.Contains(SalesInvoiceLine."Document No.") then begin
                    InvoiceNos.Add(SalesInvoiceLine."Document No.");
                    InvoiceCount += 1;
                    if SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.") and
                       ((LatestInvoiceNo = '') or
                        (SalesInvoiceHeader."Posting Date" > LatestPostingDate) or
                        ((SalesInvoiceHeader."Posting Date" = LatestPostingDate) and (SalesInvoiceHeader."No." > LatestInvoiceNo)))
                    then begin
                        LatestInvoiceNo := SalesInvoiceHeader."No.";
                        LatestPostingDate := SalesInvoiceHeader."Posting Date";
                    end;
                end;
            until SalesInvoiceLine.Next() = 0;
    end;

    local procedure FindPostedPurchaseInvoice(OrderNo: Code[20]; ReceiptNo: Code[20]; var LatestInvoiceNo: Code[20]; var InvoiceCount: Integer)
    var
        PurchInvoiceHeader: Record "Purch. Inv. Header";
        PurchInvoiceLine: Record "Purch. Inv. Line";
        InvoiceNos: List of [Code[20]];
        LatestPostingDate: Date;
    begin
        Clear(LatestInvoiceNo);
        InvoiceCount := 0;

        if ReceiptNo <> '' then begin
            PurchInvoiceLine.SetCurrentKey("Receipt No.");
            PurchInvoiceLine.SetRange("Receipt No.", ReceiptNo);
        end else begin
            if OrderNo = '' then
                exit;
            PurchInvoiceLine.SetCurrentKey("Order No.");
            PurchInvoiceLine.SetRange("Order No.", OrderNo);
        end;

        if PurchInvoiceLine.FindSet() then
            repeat
                if not InvoiceNos.Contains(PurchInvoiceLine."Document No.") then begin
                    InvoiceNos.Add(PurchInvoiceLine."Document No.");
                    InvoiceCount += 1;
                    if PurchInvoiceHeader.Get(PurchInvoiceLine."Document No.") and
                       ((LatestInvoiceNo = '') or
                        (PurchInvoiceHeader."Posting Date" > LatestPostingDate) or
                        ((PurchInvoiceHeader."Posting Date" = LatestPostingDate) and (PurchInvoiceHeader."No." > LatestInvoiceNo)))
                    then begin
                        LatestInvoiceNo := PurchInvoiceHeader."No.";
                        LatestPostingDate := PurchInvoiceHeader."Posting Date";
                    end;
                end;
            until PurchInvoiceLine.Next() = 0;
    end;

    local procedure OpenSource(SourceTypeText: Text; DocumentNoText: Text)
    var
        PurchaseHeader: Record "Purchase Header";
        PurchInvoiceHeader: Record "Purch. Inv. Header";
        PurchReceiptHeader: Record "Purch. Rcpt. Header";
        SalesHeader: Record "Sales Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesShipmentHeader: Record "Sales Shipment Header";
        TransferHeader: Record "Transfer Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        DocumentNo: Code[20];
    begin
        DocumentNo := CopyStr(DocumentNoText, 1, MaxStrLen(DocumentNo));
        case LowerCase(SourceTypeText) of
            'sales order':
                begin
                    SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo);
                    Page.Run(Page::"Sales Order", SalesHeader);
                end;
            'transfer order':
                begin
                    TransferHeader.Get(DocumentNo);
                    Page.Run(Page::"Transfer Order", TransferHeader);
                end;
            'purchase order':
                begin
                    PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, DocumentNo);
                    Page.Run(Page::"Purchase Order", PurchaseHeader);
                end;
            'posted sales shipment':
                begin
                    SalesShipmentHeader.Get(DocumentNo);
                    Page.Run(Page::"Posted Sales Shipment", SalesShipmentHeader);
                end;
            'posted transfer receipt':
                begin
                    TransferReceiptHeader.Get(DocumentNo);
                    Page.Run(Page::"Posted Transfer Receipt", TransferReceiptHeader);
                end;
            'posted purchase receipt':
                begin
                    PurchReceiptHeader.Get(DocumentNo);
                    Page.Run(Page::"Posted Purchase Receipt", PurchReceiptHeader);
                end;
            'posted sales invoice':
                begin
                    SalesInvoiceHeader.Get(DocumentNo);
                    Page.Run(Page::"Posted Sales Invoice", SalesInvoiceHeader);
                end;
            'posted purchase invoice':
                begin
                    PurchInvoiceHeader.Get(DocumentNo);
                    Page.Run(Page::"Posted Purchase Invoice", PurchInvoiceHeader);
                end;
            else
                Error(SourceTypeErr, SourceTypeText);
        end;
    end;

    local procedure OpenPlan(PlanNoText: Text; VersionNo: Integer)
    var
        PlanHeader: Record "SAL Plan Header";
        PlanNo: Code[20];
    begin
        PlanNo := CopyStr(PlanNoText, 1, MaxStrLen(PlanNo));
        if not PlanHeader.Get(PlanNo, VersionNo) then
            Error(PlanNotFoundErr, PlanNo, VersionNo);
        Page.Run(Page::"SAL Stock & Logistics Planner", PlanHeader);
    end;

    local procedure OpenActualPallet(ItemNoText: Text; VariantCodeText: Text; PalletNoText: Text)
    var
        PalletInfo: Record "DIY_Pallet Information";
        ItemNo: Code[20];
        VariantCode: Code[20];
        PalletNo: Code[20];
    begin
        ItemNo := CopyStr(ItemNoText, 1, MaxStrLen(ItemNo));
        VariantCode := CopyStr(VariantCodeText, 1, MaxStrLen(VariantCode));
        PalletNo := CopyStr(PalletNoText, 1, MaxStrLen(PalletNo));
        if not PalletInfo.Get(ItemNo, VariantCode, PalletNo) then
            Error(ActualPalletNotFoundErr, PalletNo, ItemNo, VariantCode);
        Page.Run(Page::"DIY_Pallet No. Info. Card", PalletInfo);
    end;

    local procedure FormatDate(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    var
        AddInReady: Boolean;
        ArrivedCount: Integer;
        ArrivingSoonCount: Integer;
        DispatchedCount: Integer;
        ForwardCount: Integer;
        InTransitCount: Integer;
        ItemCount: Integer;
        MissingDateCount: Integer;
        ReferenceCount: Integer;
        PlanNotFoundErr: Label 'SAL plan %1 version %2 was not found.', Comment = '%1 = plan no., %2 = version no.';
        ActualPalletNotFoundErr: Label 'Pallet %1 for item %2 and variant %3 was not found in Avocados Core.', Comment = '%1 = pallet no., %2 = item no., %3 = variant code';
        SourceTypeErr: Label '%1 is not a supported packing and logistics monitor source type.', Comment = '%1 = supplied source type';
}
