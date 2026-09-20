codeunit 50277 "TAC Pool Subscribers"
{
    #region EventSubscriber Codeunit 5704 OnRunOnBeforeCommit
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnRunOnBeforeCommit', '', true, true)]
    local procedure OnRunOnBeforeCommit_C5704(var TransferHeader: Record "Transfer Header"; var TransferShipmentHeader: Record "Transfer Shipment Header"; PostedWhseShptHeader: Record "Posted Whse. Shipment Header"; var SuppressCommit: Boolean; PreviewMode: Boolean)
    var
        PoolConsignmentPost: Codeunit "TAC Pool Consignment Post";
    begin
        if PreviewMode then exit;
        if TransferShipmentHeader."No." <> '' then PoolConsignmentPost.ProcessPostedShipment(TransferShipmentHeader."No.", database::"Transfer Shipment Line");
    end;
    #endregion EventSubscriber Codeunit 5704 OnRunOnBeforeCommit
    #region EventSubscriber Codeunit 80 OnAfterFinalizePostingOnBeforeCommit
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterFinalizePostingOnBeforeCommit', '', true, true)]
    local procedure OnAfterFinalizePostingOnBeforeCommit_C80(var SalesHeader: Record "Sales Header"; var SalesShipmentHeader: Record "Sales Shipment Header"; var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var ReturnReceiptHeader: Record "Return Receipt Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; var CommitIsSuppressed: Boolean; var PreviewMode: Boolean; WhseShip: Boolean; WhseReceive: Boolean; var EverythingInvoiced: Boolean)
    var
        PoolConsignmentPost: Codeunit "TAC Pool Consignment Post";
    begin
        if PreviewMode then exit;
        if SalesShipmentHeader."No." <> '' then PoolConsignmentPost.ProcessPostedShipment(SalesShipmentHeader."No.", database::"Sales Shipment Line");
        if SalesInvoiceHeader."No." <> '' then PoolConsignmentPost.ProcessPostedSalesInvoice(SalesInvoiceHeader."No.");
        if SalesCrMemoHeader."No." <> '' then PoolConsignmentPost.ProcessPostedSalesCreditMemo(SalesCrMemoHeader."No.", SalesCrMemoHeader."Applies-to Doc. No.");
    end;
    #endregion EventSubscriber Codeunit 80 OnAfterFinalizePostingOnBeforeCommit
    // House rule: subscribers carry NO business logic — they only delegate.
    #region EventSubscriber Codeunit 22 OnAfterPostItemJnlLine
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterPostItemJnlLine', '', true, true)]
    local procedure OnAfterPostItemJnlLine_C22(var ItemJournalLine: Record "Item Journal Line"; ItemLedgerEntry: Record "Item Ledger Entry"; var ValueEntryNo: Integer; var InventoryPostingToGL: Codeunit "Inventory Posting To G/L"; CalledFromAdjustment: Boolean; CalledFromInvtPutawayPick: Boolean; var ItemRegister: Record "Item Register"; var ItemLedgEntryNo: Integer; var ItemApplnEntryNo: Integer; var WhseJnlRegisterLine: Codeunit "Whse. Jnl.-Register Line")
    var
        PoolConsumptionGrower: Codeunit "TAC Pool Consumption Grower";
    begin
        PoolConsumptionGrower.UpdateProductionOrderFromConsumption(ItemLedgerEntry);
    end;
    #endregion EventSubscriber Codeunit 22 OnAfterPostItemJnlLine
    #region Vendor grower code synchronisation
    [EventSubscriber(ObjectType::Table, Database::"Default Dimension", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDefaultDimension(var Rec: Record "Default Dimension"; RunTrigger: Boolean)
    var
        VendorGrowerSync: Codeunit "TAC Pool Vendor Grower Sync";
    begin
        VendorGrowerSync.SyncFromDefaultDimension(Rec);
    end;
    [EventSubscriber(ObjectType::Table, Database::"Default Dimension", 'OnAfterModifyEvent', '', false, false)]
    local procedure OnAfterModifyDefaultDimension(var Rec: Record "Default Dimension"; var xRec: Record "Default Dimension"; RunTrigger: Boolean)
    var
        VendorGrowerSync: Codeunit "TAC Pool Vendor Grower Sync";
    begin
        VendorGrowerSync.SyncFromDefaultDimension(Rec);
        if(xRec."Table ID" = Database::Vendor) and (xRec."Dimension Code" <> Rec."Dimension Code")then VendorGrowerSync.SyncFromDefaultDimension(xRec);
    end;
    [EventSubscriber(ObjectType::Table, Database::"Default Dimension", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnAfterDeleteDefaultDimension(var Rec: Record "Default Dimension"; RunTrigger: Boolean)
    var
        VendorGrowerSync: Codeunit "TAC Pool Vendor Grower Sync";
    begin
        VendorGrowerSync.SyncFromDefaultDimension(Rec);
    end;
    [EventSubscriber(ObjectType::Table, Database::"TAC Pool Setup", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertPoolSetup(var Rec: Record "TAC Pool Setup"; RunTrigger: Boolean)
    var
        VendorGrowerSync: Codeunit "TAC Pool Vendor Grower Sync";
    begin
        VendorGrowerSync.SyncAllVendors();
    end;
    [EventSubscriber(ObjectType::Table, Database::"TAC Pool Setup", 'OnAfterModifyEvent', '', false, false)]
    local procedure OnAfterModifyPoolSetup(var Rec: Record "TAC Pool Setup"; var xRec: Record "TAC Pool Setup"; RunTrigger: Boolean)
    var
        VendorGrowerSync: Codeunit "TAC Pool Vendor Grower Sync";
    begin
        if Rec."Grower Dimension Code" <> xRec."Grower Dimension Code" then VendorGrowerSync.SyncAllVendors();
    end;
    #endregion Vendor grower code synchronisation
    /*[EventSubscriber(ObjectType::Table, Database::"Production Order", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertProductionOrder(var Rec: Record "Production Order"; RunTrigger: Boolean)
    var
        PoolProdOrderPost: Codeunit "TAC Pool Prod Order Post";
    begin
        // A finished PKD- order surfaces as a new Status::Finished header. The
        // canonical "finished" event for the client's BC version is a design
        // hedge (§F-04); confirm and re-point if a more precise event exists.
        if Rec.IsTemporary() then
            exit;
        if Rec.Status <> Rec.Status::Finished then
            exit;
        PoolProdOrderPost.RunCloseFromProductionOrder(Rec);
    end;
*/
    #region EventSubscriber Codeunit 5407 OnAfterChangeStatusOnProdOrder
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Prod. Order Status Management", 'OnAfterChangeStatusOnProdOrder', '', true, true)]
    local procedure OnAfterChangeStatusOnProdOrder_C5407(var ProdOrder: Record "Production Order"; var ToProdOrder: Record "Production Order"; NewStatus: Enum "Production Order Status"; NewPostingDate: Date; NewUpdateUnitCost: Boolean; var SuppressCommit: Boolean; xProductionOrder: Record "Production Order")
    var
        PoolProdOrderPost: Codeunit "TAC Pool Prod Order Post";
    begin
        if NewStatus = NewStatus::Finished then PoolProdOrderPost.RunCloseFromProductionOrder(ProdOrder, NewPostingDate);
    end;
    #endregion EventSubscriber Codeunit 5407 OnAfterChangeStatusOnProdOrder
    #region EventSubscriber Codeunit 414 OnAfterReleaseSalesDoc
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnAfterReleaseSalesDoc', '', true, true)]
    local procedure OnAfterReleaseSalesDoc_C414(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; var LinesWereModified: Boolean; SkipWhseRequestOperations: Boolean)
    var
        Consignment: Record "TAC Consignment Header";
    begin
        if not Consignment.Get(SalesHeader."DIY_Consignment No.")then Consignment.InitiateFromSalesOrder(SalesHeader);
    end;
    #endregion EventSubscriber Codeunit 414 OnAfterReleaseSalesDoc
    #region EventSubscriber Codeunit 5708 OnAfterReleaseTransferDoc
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Transfer Document", 'OnAfterReleaseTransferDoc', '', true, true)]
    local procedure OnAfterReleaseTransferDoc_C5708(var TransferHeader: Record "Transfer Header")
    var
        Consignment: Record "TAC Consignment Header";
    begin
        if not Consignment.Get(TransferHeader."DIY_Consignment No.")then Consignment.InitiateFromTransfer(TransferHeader);
    end;
#endregion EventSubscriber Codeunit 5708 OnAfterReleaseTransferDoc
}
