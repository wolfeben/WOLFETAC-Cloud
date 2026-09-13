codeunit 50277 "TAC Pool Subscribers"
{
    #region EventSubscriber Codeunit 80 OnAfterPostSalesDoc
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', true, true)]
    local procedure OnAfterPostSalesDoc_C80(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20]; SalesCrMemoHdrNo: Code[20]; CommitIsSuppressed: Boolean; InvtPickPutaway: Boolean; var CustLedgerEntry: Record "Cust. Ledger Entry"; WhseShip: Boolean; WhseReceiv: Boolean; PreviewMode: Boolean)
    var
        PoolConsignmentPost: Codeunit "TAC Pool Consignment Post";
    begin
        if PreviewMode then exit;
        if SalesShptHdrNo <> '' then PoolConsignmentPost.ProcessPostedSalesShipment(SalesShptHdrNo);
        if SalesInvHdrNo <> '' then PoolConsignmentPost.ProcessPostedSalesInvoice(SalesInvHdrNo);
        if SalesCrMemoHdrNo <> '' then PoolConsignmentPost.ProcessPostedSalesCreditMemo(SalesCrMemoHdrNo, CustLedgerEntry."Applies-to Doc. No.");
    end;
    #endregion EventSubscriber Codeunit 80 OnAfterPostSalesDoc
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
}
