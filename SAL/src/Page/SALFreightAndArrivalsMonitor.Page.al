page 58016 "SAL Freight & Arrivals Monitor"
{
    PageType = UserControlHost;
    Caption = 'Freight Movement Details';
    ApplicationArea = All;
    Permissions =
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
        tabledata Location = r;

    layout
    {
        area(Content)
        {
            usercontrol(Workspace; "SAL Freight Monitor Workspace")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    AddInReady := true;
                    LoadScreen('Freight concept loaded from current Business Central documents.', false);
                end;

                trigger RefreshRequested()
                begin
                    LoadScreen('Freight document projection refreshed.', false);
                end;

                trigger OpenSourceRequested(SourceType: Text; DocumentNo: Text)
                begin
                    OpenSource(SourceType, DocumentNo);
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

        Root.Add('schemaVersion', 1);
        Root.Add('company', CompanyName());
        Root.Add('asOf', Format(CurrentDateTime(), 0, 9));
        Root.Add('conceptMode', true);
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
            FirstShipmentDate := SalesHeader."Shipment Date";
            if SalesLine.FindSet() then
                repeat
                    LineCount += 1;
                    OutstandingQuantity += SalesLine."Outstanding Quantity";
                    if (FirstShipmentDate = 0D) and (SalesLine."Shipment Date" <> 0D) then
                        FirstShipmentDate := SalesLine."Shipment Date";
                until SalesLine.Next() = 0;

            if LineCount > 0 then begin
                CarrierName := GetShippingAgentName(SalesHeader."Shipping Agent Code");
                DestinationName := SalesHeader."Ship-to Name";
                if DestinationName = '' then
                    DestinationName := SalesHeader."Sell-to Customer Name";
                Clear(Item);
                AddCommonItem(Item, 'Sales Order', SalesHeader."No.", 'Outbound',
                    ResolveForwardStage(SalesHeader."Shipping Agent Code", SalesHeader."Package Tracking No."),
                    Format(SalesHeader.Status), SalesHeader."Sell-to Customer Name", SalesHeader."Location Code", DestinationName,
                    CarrierName, SalesHeader."Shipping Agent Service Code", SalesHeader."Package Tracking No.",
                    FirstShipmentDate, 0D, OutstandingQuantity, LineCount);
                Item.Add('relatedDocumentNo', '');
                Item.Add('salPlanNo', GetActiveSALPlanNo(SourceType::SalesOrder, SalesHeader."No."));
                AddSalesInvoiceLink(Item, SalesHeader."No.", '');
                Item.Add('marketer', GetConfirmedSALMarketer(SourceType::SalesOrder, SalesHeader."No."));
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
            TransferLine.SetFilter("Outstanding Quantity", '>0');
            LineCount := 0;
            OutstandingQuantity := 0;
            InTransitQuantity := 0;
            FirstShipmentDate := TransferHeader."Shipment Date";
            FirstReceiptDate := TransferHeader."Receipt Date";
            if TransferLine.FindSet() then
                repeat
                    LineCount += 1;
                    OutstandingQuantity += TransferLine."Outstanding Quantity";
                    InTransitQuantity += TransferLine."Qty. in Transit";
                    if (FirstShipmentDate = 0D) and (TransferLine."Shipment Date" <> 0D) then
                        FirstShipmentDate := TransferLine."Shipment Date";
                    if (FirstReceiptDate = 0D) and (TransferLine."Receipt Date" <> 0D) then
                        FirstReceiptDate := TransferLine."Receipt Date";
                until TransferLine.Next() = 0;

            if LineCount > 0 then begin
                DestinationName := TransferHeader."Transfer-to Code";
                if DestinationLocation.Get(TransferHeader."Transfer-to Code") then
                    DestinationName := DestinationLocation.Name;
                CarrierName := GetShippingAgentName(TransferHeader."Shipping Agent Code");
                Clear(Item);
                AddCommonItem(Item, 'Transfer Order', TransferHeader."No.", 'Inter-DC',
                    ResolveTransferStage(TransferHeader."Shipping Agent Code", InTransitQuantity), Format(TransferHeader.Status),
                    StrSubstNo('%1 to %2', TransferHeader."Transfer-from Code", TransferHeader."Transfer-to Code"),
                    TransferHeader."Transfer-from Code", DestinationName, CarrierName,
                    TransferHeader."Shipping Agent Service Code", '', FirstShipmentDate, FirstReceiptDate,
                    OutstandingQuantity, LineCount);
                Item.Add('relatedDocumentNo', '');
                Item.Add('salPlanNo', GetActiveSALPlanNo(SourceType::TransferOrder, TransferHeader."No."));
                AddNoInvoiceLink(Item);
                Item.Add('marketer', GetConfirmedSALMarketer(SourceType::TransferOrder, TransferHeader."No."));
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
            FirstExpectedReceiptDate := 0D;
            if PurchaseLine.FindSet() then
                repeat
                    LineCount += 1;
                    OutstandingQuantity += PurchaseLine."Outstanding Quantity";
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
                AddCommonItem(Item, 'Purchase Order', PurchaseHeader."No.", 'Inbound', 'Inbound planned',
                    Format(PurchaseHeader.Status), PurchaseHeader."Buy-from Vendor Name", 'Vendor', DestinationName,
                    'Not supplied in this projection', '', '', 0D, FirstExpectedReceiptDate,
                    OutstandingQuantity, LineCount);
                Item.Add('relatedDocumentNo', '');
                Item.Add('salPlanNo', '');
                AddPurchaseInvoiceLink(Item, PurchaseHeader."No.", '');
                Item.Add('marketer', 'Not applicable / not confirmed');
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
            if SalesShipmentLine.FindSet() then
                repeat
                    LineCount += 1;
                    ShipmentQuantity += SalesShipmentLine.Quantity;
                until SalesShipmentLine.Next() = 0;

            DestinationName := SalesShipmentHeader."Ship-to Name";
            if DestinationName = '' then
                DestinationName := SalesShipmentHeader."Sell-to Customer Name";
            Clear(Item);
            AddCommonItem(Item, 'Posted Sales Shipment', SalesShipmentHeader."No.", 'Outbound',
                ResolveDispatchedStage(SalesShipmentHeader."Package Tracking No."), 'Posted',
                SalesShipmentHeader."Sell-to Customer Name", SalesShipmentHeader."Location Code", DestinationName,
                GetShippingAgentName(SalesShipmentHeader."Shipping Agent Code"),
                SalesShipmentHeader."Shipping Agent Service Code", SalesShipmentHeader."Package Tracking No.",
                SalesShipmentHeader."Shipment Date", 0D, ShipmentQuantity, LineCount);
            Item.Add('relatedDocumentNo', SalesShipmentHeader."Order No.");
            Item.Add('salPlanNo', '');
            AddSalesInvoiceLink(Item, SalesShipmentHeader."Order No.", SalesShipmentHeader."No.");
            Item.Add('marketer', GetConfirmedSALMarketer(SourceType::SalesOrder, SalesShipmentHeader."Order No."));
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
        Item: JsonObject;
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
            if TransferReceiptLine.FindSet() then
                repeat
                    LineCount += 1;
                    ReceivedQuantity += TransferReceiptLine.Quantity;
                until TransferReceiptLine.Next() = 0;

            Clear(Item);
            AddCommonItem(Item, 'Posted Transfer Receipt', TransferReceiptHeader."No.", 'Inter-DC', 'Arrived', 'Posted',
                StrSubstNo('%1 to %2', TransferReceiptHeader."Transfer-from Code", TransferReceiptHeader."Transfer-to Code"),
                TransferReceiptHeader."Transfer-from Code", TransferReceiptHeader."Transfer-to Code", 'Not supplied', '', '',
                0D, 0D, ReceivedQuantity, LineCount);
            Item.Add('actualArrival', FormatDate(TransferReceiptHeader."Receipt Date"));
            Item.Add('relatedDocumentNo', TransferReceiptHeader."Transfer Order No.");
            Item.Add('salPlanNo', '');
            AddNoInvoiceLink(Item);
            Item.Add('marketer', 'Not confirmed');
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
            if PurchReceiptLine.FindSet() then
                repeat
                    LineCount += 1;
                    ReceivedQuantity += PurchReceiptLine.Quantity;
                until PurchReceiptLine.Next() = 0;

            Clear(Item);
            AddCommonItem(Item, 'Posted Purchase Receipt', PurchReceiptHeader."No.", 'Inbound', 'Arrived', 'Posted',
                PurchReceiptHeader."Buy-from Vendor Name", 'Vendor', PurchReceiptHeader."Location Code", 'Not supplied', '', '',
                0D, 0D, ReceivedQuantity, LineCount);
            Item.Add('actualArrival', FormatDate(PurchReceiptHeader."Posting Date"));
            Item.Add('relatedDocumentNo', PurchReceiptHeader."Order No.");
            Item.Add('salPlanNo', '');
            AddPurchaseInvoiceLink(Item, PurchReceiptHeader."Order No.", PurchReceiptHeader."No.");
            Item.Add('marketer', 'Not applicable / not confirmed');
            Item.Add('dateSource', 'Posted Purchase Receipt date');
            Item.Add('connectionState', 'Arrival posted in BC');
            Item.Add('dataNote', 'The posted purchase receipt is reliable evidence that the inbound stock arrived.');
            Items.Add(Item);
            ArrivedCount += 1;
            ItemCount += 1;
            AddedForSource += 1;
        until (PurchReceiptHeader.Next() = 0) or (AddedForSource >= 15);
    end;

    local procedure AddCommonItem(var Item: JsonObject; SourceType: Text; DocumentNo: Code[20]; Direction: Text; Stage: Text; Status: Text; Party: Text; Origin: Text; Destination: Text; Carrier: Text; Service: Text; BookingReference: Text; ETD: Date; ETA: Date; Quantity: Decimal; LineCount: Integer)
    begin
        Item.Add('id', SourceType + ':' + DocumentNo);
        Item.Add('sourceType', SourceType);
        Item.Add('documentNo', DocumentNo);
        Item.Add('direction', Direction);
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

    local procedure GetActiveSALPlanNo(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]): Code[20]
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        if PlanSource.FindSet() then
            repeat
                if PlanHeader.Get(PlanSource."Plan No.", PlanSource."Version No.") and
                   (PlanHeader.Status in [PlanHeader.Status::Draft, PlanHeader.Status::Released])
                then
                    exit(PlanHeader."No.");
            until PlanSource.Next() = 0;
        exit('');
    end;

    local procedure GetConfirmedSALMarketer(SourceType: Enum "SAL Source Type"; DocumentNo: Code[20]): Text
    var
        PlanHeader: Record "SAL Plan Header";
        PlanSource: Record "SAL Plan Source";
    begin
        if DocumentNo = '' then
            exit('Not confirmed');
        PlanSource.SetRange("Source Type", SourceType);
        PlanSource.SetRange("Source Document No.", DocumentNo);
        if PlanSource.FindSet() then
            repeat
                if PlanHeader.Get(PlanSource."Plan No.", PlanSource."Version No.") and PlanHeader."Marketer Confirmed" then
                    exit(PlanHeader."Marketer Description");
            until PlanSource.Next() = 0;
        exit('Not confirmed');
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
        SourceTypeErr: Label '%1 is not a supported freight monitor source type.', Comment = '%1 = supplied source type';
}
