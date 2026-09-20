codeunit 50284 "TAC Pool Reconciliation"
{
    procedure RunReconciliation(PoolGroupID: Integer): Integer var
        PoolGroup: Record "TAC Pool Group Header";
        Reconciliation: Record "TAC Pool Reconciliation";
    begin
        PoolGroup.Get(PoolGroupID);
        PoolGroup.TestStatusOpen();
        Reconciliation.Init();
        Reconciliation."Pool Group ID":=PoolGroupID;
        Reconciliation."Pool Group Code":=PoolGroup."Pool Group Code";
        Reconciliation."Created DateTime":=CurrentDateTime();
        Reconciliation."Created By":=CopyStr(UserId(), 1, MaxStrLen(Reconciliation."Created By"));
        Reconciliation."As-at DateTime":=CurrentDateTime();
        Reconciliation.Insert(true);
        ScanProductionOutput(Reconciliation);
        ScanPostedSalesInvoices(Reconciliation);
        ScanPostedSalesCreditMemos(Reconciliation);
        ScanPostedConsignments(Reconciliation);
        ScanPostedExpenses(Reconciliation);
        ScanPostedAdjustments(Reconciliation);
        UpdateCounts(Reconciliation);
        exit(Reconciliation."Reconciliation ID");
    end;
    procedure CreateMissingPoolEntries(ReconciliationID: Integer)
    var
        Reconciliation: Record "TAC Pool Reconciliation";
        ReconLine: Record "TAC Pool Recon Line";
    begin
        Reconciliation.Get(ReconciliationID);
        VerifyGroupOpen(Reconciliation."Pool Group ID");
        ReconLine.SetRange("Reconciliation ID", ReconciliationID);
        ReconLine.SetRange(Status, ReconLine.Status::Missing);
        if ReconLine.FindSet(true)then repeat CreateMissingLine(Reconciliation, ReconLine);
            until ReconLine.Next() = 0;
        UpdateCounts(Reconciliation);
    end;
    local procedure ScanProductionOutput(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        ProductionOrderLine: Record "Prod. Order Line";
        ProductionOrder: Record "Production Order";
        PoolProdOrderPost: Codeunit "TAC Pool Prod Order Post";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        Evaluation: Record "TAC Pool Charge Evaluation" temporary;
        Context: Record "TAC Pool Charge Context" temporary;
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        OutputItemNo: Code[20];
        Season: Code[20];
        PoolWeek: Code[20];
        Variety: Code[20];
        Grade: Code[20];
        Size: Code[20];
        Grower: Code[20];
        PackType: Code[20];
        PackTypeCategory: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        Kgs: Decimal;
        Units: Decimal;
        PoolCode: Code[20];
    begin
        ProductionOrderLine.SetRange(Status, ProductionOrderLine.Status::Finished);
        if ProductionOrderLine.FindSet()then repeat if ProductionOrder.Get(ProductionOrderLine.Status, ProductionOrderLine."Prod. Order No.")then begin
                    if not PoolProdOrderPost.GetPackedOutputLine(ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo)then continue;
                    if not PoolProdOrderPost.IsOriginalPackRun(ProductionOrder."No.")then continue;
                    PoolProdOrderPost.GetPackedLineQuantities(ProductionOrder."No.", ProductionOrderLine."Line No.", Kgs, Units, OutputItemNo);
                    if Units <= 0 then continue;
                    if not TryResolveProductionDimensions(ProductionOrderLine, Season, PoolWeek, Variety, Grade, Size, Grower, GrowerPoolType, PackType, PackTypeCategory)then begin
                        AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Production Output", ProductionOrder."No.", ProductionOrderLine."Line No.", ProductionOrderLine.SystemId, 0, '', 'TR', 4, Units, Kgs, 0, 0, 0, 'Production output has invalid pool dimensions.');
                        continue;
                    end;
                    PoolGroup.Reset();
                    PoolGroup.SetRange("Pool Week Code", CopyStr(PoolWeek, 1, MaxStrLen(PoolGroup."Pool Week Code")));
                    PoolGroup.SetRange("Grower Pool Type", GrowerPoolType);
                    if not PoolGroup.FindFirst() or (PoolGroup."Pool Group ID" <> Reconciliation."Pool Group ID")then continue;
                    Pool.SetRange("Pool Group ID", Reconciliation."Pool Group ID");
                    Pool.SetRange("Variety Code", CopyStr(Variety, 1, MaxStrLen(Pool."Variety Code")));
                    Pool.SetRange("Grade Code", CopyStr(Grade, 1, MaxStrLen(Pool."Grade Code")));
                    Pool.SetRange("Size Code", CopyStr(Size, 1, MaxStrLen(Pool."Size Code")));
                    if not Pool.FindFirst()then begin
                        AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Production Output", ProductionOrder."No.", ProductionOrderLine."Line No.", ProductionOrderLine.SystemId, Reconciliation."Pool Group ID", '', 'TR', 4, Units, Kgs, 0, 0, 0, 'Target Pool does not exist.');
                        continue;
                    end;
                    PoolCode:=Pool."Pool Code";
                    AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Production Output", ProductionOrder."No.", ProductionOrderLine."Line No.", ProductionOrderLine.SystemId, Reconciliation."Pool Group ID", PoolCode, 'TR', 4, Units, Kgs, 0, 0, 0, 'Production transfer receipt.');
                    BuildProductionContext(Context, ProductionOrder, ProductionOrderLine, OutputItemNo, PoolCode, Reconciliation."Pool Group ID", Grower, GrowerPoolType, Variety, Grade, Size, PackType, PackTypeCategory, Units, Kgs);
                    ChargeEngine.EvaluateCharges(Enum::"TAC Pool Charge Action"::RunClose, Context, Evaluation);
                    if Evaluation.FindSet()then repeat if Evaluation.Result = Evaluation.Result::Expected then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Production Output", ProductionOrder."No.", ProductionOrderLine."Line No.", ProductionOrderLine.SystemId, Reconciliation."Pool Group ID", PoolCode, Evaluation."Trans Type Code", 1, 0, 0, Evaluation."Expected Amount", Evaluation."GST Amount", Evaluation."Template ID", 'Run Close charge.')
                            else if Evaluation.Mandatory then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Production Output", ProductionOrder."No.", ProductionOrderLine."Line No.", ProductionOrderLine.SystemId, Reconciliation."Pool Group ID", PoolCode, Evaluation."Trans Type Code", 1, 0, 0, 0, 0, Evaluation."Template ID", Evaluation.Details);
                        until Evaluation.Next() = 0;
                end;
            until ProductionOrderLine.Next() = 0;
    end;
    local procedure ScanPostedExpenses(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        Expense: Record "TAC Pool Expense Header";
        Detail: Record "TAC Pool Expense Detail";
    begin
        Expense.SetRange("Pool Group ID", Reconciliation."Pool Group ID");
        Expense.SetRange(Posted, true);
        if Expense.FindSet()then repeat Detail.SetRange("Expense ID", Expense."Expense ID");
                if Detail.FindSet()then repeat AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Expense, Format(Expense."Expense ID"), Detail."Line No.", Detail.SystemId, Reconciliation."Pool Group ID", Detail."Pool Code", Expense."Trans Type", 1, 0, 0, Detail.Amount, 0, 0, 'Posted expense detail.');
                    until Detail.Next() = 0;
            until Expense.Next() = 0;
    end;
    local procedure ScanPostedConsignments(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        Consignment: Record "TAC Consignment Header";
        ConsignmentLine: Record "TAC Consignment Line";
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        Evaluation: Record "TAC Pool Charge Evaluation" temporary;
        Context: Record "TAC Pool Charge Context" temporary;
        Season: Code[20];
        PoolWeek: Code[20];
        Variety: Code[20];
        Grade: Code[20];
        Size: Code[20];
        Grower: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
    begin
        Consignment.SetRange("Posted to Pool", true);
        if Consignment.FindSet()then repeat ConsignmentLine.SetRange("Consignment No.", Consignment."Consignment No.");
                if ConsignmentLine.FindSet()then repeat if not TryResolveConsignmentDimensions(ConsignmentLine, Season, PoolWeek, Variety, Grade, Size, Grower, GrowerPoolType)then continue;
                        PoolGroup.SetRange("Pool Week Code", CopyStr(PoolWeek, 1, MaxStrLen(PoolGroup."Pool Week Code")));
                        PoolGroup.SetRange("Grower Pool Type", GrowerPoolType);
                        if not PoolGroup.FindFirst() or (PoolGroup."Pool Group ID" <> Reconciliation."Pool Group ID")then continue;
                        Pool.SetRange("Pool Group ID", Reconciliation."Pool Group ID");
                        Pool.SetRange("Variety Code", CopyStr(Variety, 1, MaxStrLen(Pool."Variety Code")));
                        Pool.SetRange("Grade Code", CopyStr(Grade, 1, MaxStrLen(Pool."Grade Code")));
                        Pool.SetRange("Size Code", CopyStr(Size, 1, MaxStrLen(Pool."Size Code")));
                        if not Pool.FindFirst()then begin
                            AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Consignment, Consignment."Consignment No.", ConsignmentLine."Line No.", ConsignmentLine.SystemId, Reconciliation."Pool Group ID", '', 'FR', 2, ConsignmentLine.Quantity, ConsignmentLine."Quantity (Kg)", -ConsignmentLine."Allocated Freight Cost", 0, 0, 'Target Pool does not exist.');
                            continue;
                        end;
                        AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Consignment, Consignment."Consignment No.", ConsignmentLine."Line No.", ConsignmentLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", 'FR', 2, ConsignmentLine.Quantity, ConsignmentLine."Quantity (Kg)", -ConsignmentLine."Allocated Freight Cost", 0, 0, 'Posted consignment freight.');
                        BuildConsignmentContext(Context, Consignment, ConsignmentLine, Pool."Pool Code", Reconciliation."Pool Group ID", Grower, GrowerPoolType, Variety, Grade, Size);
                        ChargeEngine.EvaluateCharges(Enum::"TAC Pool Charge Action"::ConsignmentPost, Context, Evaluation);
                        if Evaluation.FindSet()then repeat if Evaluation.Result = Evaluation.Result::Expected then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Consignment, Consignment."Consignment No.", ConsignmentLine."Line No.", ConsignmentLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", Evaluation."Trans Type Code", 1, 0, 0, Evaluation."Expected Amount", Evaluation."GST Amount", Evaluation."Template ID", 'Consignment Post charge.')
                                else if Evaluation.Mandatory then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Consignment, Consignment."Consignment No.", ConsignmentLine."Line No.", ConsignmentLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", Evaluation."Trans Type Code", 1, 0, 0, 0, 0, Evaluation."Template ID", Evaluation.Details);
                            until Evaluation.Next() = 0;
                    until ConsignmentLine.Next() = 0;
            until Consignment.Next() = 0;
    end;
    local procedure ScanPostedSalesCreditMemos(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        Setup: Record "TAC Pool Setup";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        CustLedgerEntry: Record "Cust. Ledger Entry";
        InvoicePostState: Record "TAC Pool Invoice Post State";
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        Evaluation: Record "TAC Pool Charge Evaluation" temporary;
        Context: Record "TAC Pool Charge Context" temporary;
        AppliedInvoiceNo: Code[20];
        Season: Code[20];
        PoolWeek: Code[20];
        Variety: Code[20];
        Grade: Code[20];
        Size: Code[20];
        Grower: Code[20];
        PackType: Code[20];
        PackTypeCategory: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
    begin
        if not Setup.Get() or not Setup."Allow Invoice Credits" then exit;
        SalesCrMemoLine.SetRange(Type, SalesCrMemoLine.Type::Item);
        if SalesCrMemoLine.FindSet()then repeat if not SalesCrMemoHeader.Get(SalesCrMemoLine."Document No.")then continue;
                CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::"Credit Memo");
                CustLedgerEntry.SetRange("Document No.", SalesCrMemoHeader."No.");
                if not CustLedgerEntry.FindFirst()then continue;
                AppliedInvoiceNo:=CustLedgerEntry."Applies-to Doc. No.";
                if AppliedInvoiceNo = '' then continue;
                InvoicePostState.SetRange("Posted Invoice No.", AppliedInvoiceNo);
                if InvoicePostState.IsEmpty()then continue;
                if not TryResolveCreditDimensions(SalesCrMemoLine, Season, PoolWeek, Variety, Grade, Size, Grower, GrowerPoolType, PackType, PackTypeCategory)then continue;
                PoolGroup.SetRange("Pool Week Code", CopyStr(PoolWeek, 1, MaxStrLen(PoolGroup."Pool Week Code")));
                PoolGroup.SetRange("Grower Pool Type", GrowerPoolType);
                if not PoolGroup.FindFirst() or (PoolGroup."Pool Group ID" <> Reconciliation."Pool Group ID")then continue;
                Pool.SetRange("Pool Group ID", Reconciliation."Pool Group ID");
                Pool.SetRange("Variety Code", CopyStr(Variety, 1, MaxStrLen(Pool."Variety Code")));
                Pool.SetRange("Grade Code", CopyStr(Grade, 1, MaxStrLen(Pool."Grade Code")));
                Pool.SetRange("Size Code", CopyStr(Size, 1, MaxStrLen(Pool."Size Code")));
                if not Pool.FindFirst()then begin
                    AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Credit Memo", SalesCrMemoHeader."No.", SalesCrMemoLine."Line No.", SalesCrMemoLine.SystemId, Reconciliation."Pool Group ID", '', 'PR', 0, 0, 0, 0, 0, 0, 'Target Pool does not exist.');
                    continue;
                end;
                AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Credit Memo", SalesCrMemoHeader."No.", SalesCrMemoLine."Line No.", SalesCrMemoLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", 'PR', 0, -Abs(SalesCrMemoLine.Quantity), 0, -Abs(SalesCrMemoLine.Amount), 0, 0, StrSubstNo('Applied credit to invoice %1.', AppliedInvoiceNo));
                BuildCreditContext(Context, SalesCrMemoHeader, SalesCrMemoLine, Pool."Pool Code", Reconciliation."Pool Group ID", Grower, GrowerPoolType, Variety, Grade, Size, PackType, PackTypeCategory);
                ChargeEngine.EvaluateCharges(Enum::"TAC Pool Charge Action"::InvoicePost, Context, Evaluation);
                if Evaluation.FindSet()then repeat if Evaluation.Result = Evaluation.Result::Expected then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Credit Memo", SalesCrMemoHeader."No.", SalesCrMemoLine."Line No.", SalesCrMemoLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", Evaluation."Trans Type Code", 1, 0, 0, Evaluation."Expected Amount", Evaluation."GST Amount", Evaluation."Template ID", 'Reversing Invoice Post charge.')
                        else if Evaluation.Mandatory then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Credit Memo", SalesCrMemoHeader."No.", SalesCrMemoLine."Line No.", SalesCrMemoLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", Evaluation."Trans Type Code", 1, 0, 0, 0, 0, Evaluation."Template ID", Evaluation.Details);
                    until Evaluation.Next() = 0;
            until SalesCrMemoLine.Next() = 0;
    end;
    local procedure ScanPostedSalesInvoices(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        ConsignmentLine: Record "TAC Consignment Line";
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        Evaluation: Record "TAC Pool Charge Evaluation" temporary;
        Context: Record "TAC Pool Charge Context" temporary;
        Season: Code[20];
        PoolWeek: Code[20];
        Variety: Code[20];
        Grade: Code[20];
        Size: Code[20];
        Grower: Code[20];
        PackType: Code[20];
        PackTypeCategory: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        OriginalQuantity: Decimal;
        OriginalQuantityKg: Decimal;
    begin
        SalesInvoiceLine.SetRange(Type, SalesInvoiceLine.Type::Item);
        SalesInvoiceLine.SetFilter("Consignment No.", '<>%1', '');
        if SalesInvoiceLine.FindSet()then repeat if not SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.")then continue;
                if not FindConsignmentLine(SalesInvoiceLine, ConsignmentLine)then continue;
                if not TryResolveInvoiceDimensions(ConsignmentLine, Season, PoolWeek, Variety, Grade, Size, Grower, GrowerPoolType, PackType, PackTypeCategory)then continue;
                PoolGroup.SetRange("Pool Week Code", CopyStr(PoolWeek, 1, MaxStrLen(PoolGroup."Pool Week Code")));
                PoolGroup.SetRange("Grower Pool Type", GrowerPoolType);
                if not PoolGroup.FindFirst() or (PoolGroup."Pool Group ID" <> Reconciliation."Pool Group ID")then continue;
                Pool.SetRange("Pool Group ID", Reconciliation."Pool Group ID");
                Pool.SetRange("Variety Code", CopyStr(Variety, 1, MaxStrLen(Pool."Variety Code")));
                Pool.SetRange("Grade Code", CopyStr(Grade, 1, MaxStrLen(Pool."Grade Code")));
                Pool.SetRange("Size Code", CopyStr(Size, 1, MaxStrLen(Pool."Size Code")));
                if not Pool.FindFirst()then begin
                    AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Invoice", SalesInvoiceHeader."No.", SalesInvoiceLine."Line No.", SalesInvoiceLine.SystemId, Reconciliation."Pool Group ID", '', 'PR', 0, 0, 0, 0, 0, 0, 'Target Pool does not exist.');
                    continue;
                end;
                if SalesInvoiceLine."Original Quantity" <> 0 then OriginalQuantity:=SalesInvoiceLine."Original Quantity"
                else
                    OriginalQuantity:=SalesInvoiceLine.Quantity;
                OriginalQuantityKg:=ResolveInvoiceQuantityKg(SalesInvoiceLine, ConsignmentLine, OriginalQuantity);
                AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Invoice", SalesInvoiceHeader."No.", SalesInvoiceLine."Line No.", SalesInvoiceLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", 'PR', 0, OriginalQuantity, OriginalQuantityKg, SalesInvoiceLine.Amount, 0, 0, 'Posted sales invoice revenue.');
                BuildInvoiceContext(Context, SalesInvoiceHeader, SalesInvoiceLine, Pool."Pool Code", Reconciliation."Pool Group ID", Grower, GrowerPoolType, Variety, Grade, Size, PackType, PackTypeCategory, OriginalQuantity, OriginalQuantityKg);
                ChargeEngine.EvaluateCharges(Enum::"TAC Pool Charge Action"::InvoicePost, Context, Evaluation);
                if Evaluation.FindSet()then repeat if Evaluation.Result = Evaluation.Result::Expected then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Invoice", SalesInvoiceHeader."No.", SalesInvoiceLine."Line No.", SalesInvoiceLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", Evaluation."Trans Type Code", 1, 0, 0, Evaluation."Expected Amount", Evaluation."GST Amount", Evaluation."Template ID", 'Invoice Post charge.')
                        else if Evaluation.Mandatory then AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::"Sales Invoice", SalesInvoiceHeader."No.", SalesInvoiceLine."Line No.", SalesInvoiceLine.SystemId, Reconciliation."Pool Group ID", Pool."Pool Code", Evaluation."Trans Type Code", 1, 0, 0, 0, 0, Evaluation."Template ID", Evaluation.Details);
                    until Evaluation.Next() = 0;
            until SalesInvoiceLine.Next() = 0;
    end;
    local procedure FindConsignmentLine(var SalesInvoiceLine: Record "Sales Invoice Line"; var ConsignmentLine: Record "TAC Consignment Line"): Boolean var
        ConsignmentNo: Code[20];
        ItemNo: Code[20];
    begin
        ConsignmentNo:=CopyStr(SalesInvoiceLine."Consignment No.", 1, MaxStrLen(ConsignmentNo));
        if SalesInvoiceLine."Original Item No." <> '' then ItemNo:=SalesInvoiceLine."Original Item No."
        else
            ItemNo:=SalesInvoiceLine."No.";
        ConsignmentLine.SetRange("Consignment No.", ConsignmentNo);
        if SalesInvoiceLine."Pool Week" <> 0 then ConsignmentLine.SetRange("Pool Week", SalesInvoiceLine."Pool Week");
        if SalesInvoiceLine."Season Code" <> '' then ConsignmentLine.SetRange("Season Code", SalesInvoiceLine."Season Code");
        if ItemNo <> '' then ConsignmentLine.SetRange("Item No.", ItemNo);
        if ConsignmentLine.FindFirst()then exit(true);
        ConsignmentLine.Reset();
        ConsignmentLine.SetRange("Consignment No.", ConsignmentNo);
        exit(ConsignmentLine.FindFirst());
    end;
    local procedure ResolveInvoiceQuantityKg(var SalesInvoiceLine: Record "Sales Invoice Line"; var ConsignmentLine: Record "TAC Consignment Line"; OriginalQuantity: Decimal): Decimal begin
        if(ConsignmentLine.Quantity <> 0) and (ConsignmentLine."Quantity (Kg)" <> 0)then exit((ConsignmentLine."Quantity (Kg)" / ConsignmentLine.Quantity) * OriginalQuantity);
        if ConsignmentLine."Quantity (Kg)" <> 0 then exit(ConsignmentLine."Quantity (Kg)");
        exit(OriginalQuantity);
    end;
    local procedure ScanPostedAdjustments(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        Adjustment: Record "TAC Pool Adjustment";
    begin
        Adjustment.SetRange("Pool Group ID", Reconciliation."Pool Group ID");
        Adjustment.SetRange(Posted, true);
        if Adjustment.FindSet()then repeat AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Adjustment, Format(Adjustment."Adjustment ID"), 0, Adjustment.SystemId, Reconciliation."Pool Group ID", Adjustment."From Pool Code", 'TRD', 4, 0, -Adjustment.Kgs, 0, 0, 0, 'Posted adjustment out.');
                AddExpected(Reconciliation, Enum::"TAC Pool Recon Source Type"::Adjustment, Format(Adjustment."Adjustment ID"), 0, Adjustment.SystemId, Reconciliation."Pool Group ID", Adjustment."To Pool Code", 'TRA', 4, 0, Adjustment.Kgs, 0, 0, 0, 'Posted adjustment in.');
            until Adjustment.Next() = 0;
    end;
    local procedure AddExpected(var Reconciliation: Record "TAC Pool Reconciliation"; SourceType: Enum "TAC Pool Recon Source Type"; SourceDocumentNo: Code[20]; SourceLineNo: Integer; SourceSystemID: Guid; PoolGroupID: Integer; PoolCode: Code[20]; TransType: Code[10]; ExpectedEntryType: Option; ExpectedQuantity: Decimal; ExpectedKg: Decimal; ExpectedAmount: Decimal; ExpectedGST: Decimal; TemplateID: Integer; Details: Text)
    var
        ReconLine: Record "TAC Pool Recon Line";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        ReconLine.Init();
        ReconLine."Reconciliation ID":=Reconciliation."Reconciliation ID";
        ReconLine."Line No.":=NextReconLineNo(Reconciliation."Reconciliation ID");
        ReconLine."Source Type":=SourceType;
        ReconLine."Source Document No.":=SourceDocumentNo;
        ReconLine."Source Line No.":=SourceLineNo;
        ReconLine."Source System ID":=SourceSystemID;
        ReconLine."Pool Group ID":=PoolGroupID;
        ReconLine."Pool Code":=PoolCode;
        ReconLine."Expected Transaction Type":=TransType;
        ReconLine."Expected Entry Type":=ExpectedEntryType;
        ReconLine."Expected Quantity":=ExpectedQuantity;
        ReconLine."Expected Kg":=ExpectedKg;
        ReconLine."Expected Amount":=ExpectedAmount;
        ReconLine."Expected GST":=ExpectedGST;
        ReconLine."Template ID":=TemplateID;
        ReconLine.Details:=Details;
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Source Document No.", SourceDocumentNo);
        PoolLedgerEntry.SetRange("Source Line No.", SourceLineNo);
        PoolLedgerEntry.SetRange("Trans Type Code", TransType);
        ReconLine."Actual Ledger Entry Count":=PoolLedgerEntry.Count();
        if PoolLedgerEntry.FindSet()then repeat ReconLine."Actual Ledger Amount"+=PoolLedgerEntry.Amount;
            until PoolLedgerEntry.Next() = 0;
        if ReconLine."Actual Ledger Entry Count" > 0 then ReconLine.Status:=ReconLine.Status::Found
        else
            ReconLine.Status:=ReconLine.Status::Missing;
        if(PoolCode = '') or (PoolGroupID = 0)then ReconLine.Status:=ReconLine.Status::Error;
        ReconLine.Insert(true);
    end;
    local procedure CreateMissingLine(var Reconciliation: Record "TAC Pool Reconciliation"; var ReconLine: Record "TAC Pool Recon Line")
    var
        ProductionOrderLine: Record "Prod. Order Line";
        ProductionOrder: Record "Production Order";
        SalesInvoiceLine: Record "Sales Invoice Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        CustLedgerEntry: Record "Cust. Ledger Entry";
        Consignment: Record "TAC Consignment Header";
        ConsignmentLine: Record "TAC Consignment Line";
        Expense: Record "TAC Pool Expense Header";
        ExpenseDetail: Record "TAC Pool Expense Detail";
        Adjustment: Record "TAC Pool Adjustment";
        PoolProdOrderPost: Codeunit "TAC Pool Prod Order Post";
        PoolConsignmentPost: Codeunit "TAC Pool Consignment Post";
        PoolExpensePost: Codeunit "TAC Pool Expense Post";
        PoolAdjustmentPost: Codeunit "TAC Pool Adjustment Post";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        PoolGroup: Record "TAC Pool Group Header";
        Season: Code[20];
        PoolWeek: Code[20];
        Variety: Code[20];
        Grade: Code[20];
        Size: Code[20];
        Grower: Code[20];
        PackType: Code[20];
        PackTypeCategory: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
    begin
        if ReconLine."Source Type" = ReconLine."Source Type"::"Sales Invoice" then begin
            SalesInvoiceLine.SetRange(SystemId, ReconLine."Source System ID");
            if not SalesInvoiceLine.FindFirst() or not SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.")then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The posted sales invoice source line no longer exists.';
                ReconLine.Modify();
                exit;
            end;
            if not TryProcessPostedSalesInvoiceLine(PoolConsignmentPost, SalesInvoiceHeader, SalesInvoiceLine)then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The posted sales invoice line could not be reprocessed.';
                ReconLine.Modify();
                exit;
            end;
            MarkCreatedIfFound(ReconLine);
            exit;
        end;
        if ReconLine."Source Type" = ReconLine."Source Type"::"Sales Credit Memo" then begin
            SalesCrMemoLine.SetRange(SystemId, ReconLine."Source System ID");
            if not SalesCrMemoLine.FindFirst() or not SalesCrMemoHeader.Get(SalesCrMemoLine."Document No.")then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The posted sales credit memo source line no longer exists.';
                ReconLine.Modify();
                exit;
            end;
            CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::"Credit Memo");
            CustLedgerEntry.SetRange("Document No.", SalesCrMemoHeader."No.");
            if not CustLedgerEntry.FindFirst() or (CustLedgerEntry."Applies-to Doc. No." = '') or not TryProcessPostedSalesCreditMemoLine(PoolConsignmentPost, SalesCrMemoHeader, SalesCrMemoLine, CustLedgerEntry."Applies-to Doc. No.")then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The credit memo line could not be reprocessed as an applied credit.';
                ReconLine.Modify();
                exit;
            end;
            MarkCreatedIfFound(ReconLine);
            exit;
        end;
        if ReconLine."Source Type" = ReconLine."Source Type"::Consignment then begin
            ConsignmentLine.SetRange(SystemId, ReconLine."Source System ID");
            if not ConsignmentLine.FindFirst() or not Consignment.Get(ConsignmentLine."Consignment No.") or not TryPostConsignmentLine(PoolConsignmentPost, Consignment, ConsignmentLine)then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The consignment line could not be reprocessed.';
                ReconLine.Modify();
                exit;
            end;
            MarkCreatedIfFound(ReconLine);
            exit;
        end;
        if ReconLine."Source Type" = ReconLine."Source Type"::Expense then begin
            ExpenseDetail.SetRange(SystemId, ReconLine."Source System ID");
            if not ExpenseDetail.FindFirst() or not Expense.Get(ExpenseDetail."Expense ID") or not TryPostExpenseDetailLine(PoolExpensePost, Expense, ExpenseDetail)then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The expense detail could not be reprocessed.';
                ReconLine.Modify();
                exit;
            end;
            MarkCreatedIfFound(ReconLine);
            exit;
        end;
        if ReconLine."Source Type" = ReconLine."Source Type"::Adjustment then begin
            Adjustment.SetRange(SystemId, ReconLine."Source System ID");
            if not Adjustment.FindFirst()then begin
                ReconLine.Status:=ReconLine.Status::Error;
                ReconLine.Details:='The adjustment source no longer exists.';
                ReconLine.Modify();
                exit;
            end;
            if ReconLine."Expected Transaction Type" = 'TRD' then begin
                if not TryPostAdjustmentEntry(PoolAdjustmentPost, Adjustment, 'TRD', Adjustment."From Pool Code", -Adjustment.Kgs)then begin
                    ReconLine.Status:=ReconLine.Status::Error;
                    ReconLine.Details:='The adjustment-out entry could not be reprocessed.';
                    ReconLine.Modify();
                    exit;
                end;
            end
            else if not TryPostAdjustmentEntry(PoolAdjustmentPost, Adjustment, 'TRA', Adjustment."To Pool Code", Adjustment.Kgs)then begin
                    ReconLine.Status:=ReconLine.Status::Error;
                    ReconLine.Details:='The adjustment-in entry could not be reprocessed.';
                    ReconLine.Modify();
                    exit;
                end;
            MarkCreatedIfFound(ReconLine);
            exit;
        end;
        if ReconLine."Source Type" <> ReconLine."Source Type"::"Production Output" then begin
            ReconLine.Status:=ReconLine.Status::Error;
            ReconLine.Details:='A line-safe corrective posting method is not available for this source type.';
            ReconLine.Modify();
            exit;
        end;
        ProductionOrderLine.SetRange(SystemId, ReconLine."Source System ID");
        if not ProductionOrderLine.FindFirst() or not ProductionOrder.Get(ProductionOrderLine.Status, ProductionOrderLine."Prod. Order No.")then begin
            ReconLine.Status:=ReconLine.Status::Error;
            ReconLine.Details:='The production source line no longer exists.';
            ReconLine.Modify();
            exit;
        end;
        if not TryResolveProductionDimensions(ProductionOrderLine, Season, PoolWeek, Variety, Grade, Size, Grower, GrowerPoolType, PackType, PackTypeCategory)then begin
            ReconLine.Status:=ReconLine.Status::Error;
            ReconLine.Details:='The production source line now has invalid pool dimensions.';
            ReconLine.Modify();
            exit;
        end;
        PoolGroup.SetRange("Pool Week Code", CopyStr(PoolWeek, 1, MaxStrLen(PoolGroup."Pool Week Code")));
        PoolGroup.SetRange("Grower Pool Type", GrowerPoolType);
        if not PoolGroup.FindFirst() or (PoolGroup."Pool Group ID" <> Reconciliation."Pool Group ID")then begin
            ReconLine.Status:=ReconLine.Status::Error;
            ReconLine.Details:='The source line no longer resolves to this Pool Group.';
            ReconLine.Modify();
            exit;
        end;
        if not TryRunCloseFromProductionOrderLine(PoolProdOrderPost, ProductionOrder, ProductionOrderLine)then begin
            ReconLine.Status:=ReconLine.Status::Error;
            ReconLine.Details:='The source line could not be reprocessed. Correct its data or pool configuration.';
            ReconLine.Modify();
            exit;
        end;
        MarkCreatedIfFound(ReconLine);
    end;
    local procedure BuildProductionContext(var Context: Record "TAC Pool Charge Context" temporary; var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line"; OutputItemNo: Code[20]; PoolCode: Code[20]; PoolGroupID: Integer; Grower: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal)
    begin
        Context.Init();
        Context."Pool Code":=PoolCode;
        Context."Pool Group ID":=PoolGroupID;
        Context."Grower Code":=Grower;
        Context."Supplier Type":=GrowerPoolType;
        if GrowerPoolType = GrowerPoolType::External then Context."Grower Type":=Context."Grower Type"::External
        else if GrowerPoolType = GrowerPoolType::"Contract Pack" then Context."Grower Type":=Context."Grower Type"::"Contract Pack"
            else
                Context."Grower Type":=Context."Grower Type"::Internal;
        Context."Variety Code":=CopyStr(Variety, 1, MaxStrLen(Context."Variety Code"));
        Context."Grade Code":=CopyStr(Grade, 1, MaxStrLen(Context."Grade Code"));
        Context."Size Code":=CopyStr(Size, 1, MaxStrLen(Context."Size Code"));
        Context."Pack Type Code":=PackType;
        Context."Pack Type Category Code":=PackTypeCategory;
        Context.Units:=Units;
        Context.Kgs:=Kgs;
        Context."Transaction Date":=ProductionOrder."Due Date";
        Context."Posting Date":=WorkDate();
        Context."Source Document No.":=ProductionOrder."No.";
        Context."Source Line No.":=ProductionOrderLine."Line No.";
        Context."Source Item No.":=OutputItemNo;
        Context."Source Type":=Context."Source Type"::"Production Output";
        Context."Source System ID":=ProductionOrderLine.SystemId;
        Context."UOM Code":=ProductionOrderLine."Unit of Measure Code";
    end;
    local procedure BuildInvoiceContext(var Context: Record "TAC Pool Charge Context" temporary; var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line"; PoolCode: Code[20]; PoolGroupID: Integer; Grower: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal)
    begin
        Context.Init();
        Context."Pool Code":=PoolCode;
        Context."Pool Group ID":=PoolGroupID;
        Context."Grower Code":=Grower;
        Context."Supplier Type":=GrowerPoolType;
        if GrowerPoolType = GrowerPoolType::External then Context."Grower Type":=Context."Grower Type"::External
        else if GrowerPoolType = GrowerPoolType::"Contract Pack" then Context."Grower Type":=Context."Grower Type"::"Contract Pack"
            else
                Context."Grower Type":=Context."Grower Type"::Internal;
        Context."Variety Code":=CopyStr(Variety, 1, MaxStrLen(Context."Variety Code"));
        Context."Grade Code":=CopyStr(Grade, 1, MaxStrLen(Context."Grade Code"));
        Context."Size Code":=CopyStr(Size, 1, MaxStrLen(Context."Size Code"));
        Context."Pack Type Code":=PackType;
        Context."Pack Type Category Code":=PackTypeCategory;
        Context.Units:=Units;
        Context.Kgs:=Kgs;
        Context.Value:=SalesInvoiceLine.Amount;
        Context."Customer No.":=SalesInvoiceHeader."Sell-to Customer No.";
        Context."Transaction Date":=SalesInvoiceHeader."Posting Date";
        Context."Posting Date":=WorkDate();
        Context."Source Document No.":=SalesInvoiceHeader."No.";
        Context."Source Line No.":=SalesInvoiceLine."Line No.";
        Context."Source Item No.":=SalesInvoiceLine."No.";
        Context."UOM Code":=SalesInvoiceLine."Unit of Measure Code";
        Context."Source Type":=Context."Source Type"::"Sales Invoice";
        Context."Source System ID":=SalesInvoiceLine.SystemId;
    end;
    local procedure BuildConsignmentContext(var Context: Record "TAC Pool Charge Context" temporary; var Consignment: Record "TAC Consignment Header"; var ConsignmentLine: Record "TAC Consignment Line"; PoolCode: Code[20]; PoolGroupID: Integer; Grower: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; Variety: Code[20]; Grade: Code[20]; Size: Code[20])
    begin
        Context.Init();
        Context."Pool Code":=PoolCode;
        Context."Pool Group ID":=PoolGroupID;
        Context."Grower Code":=Grower;
        Context."Supplier Type":=GrowerPoolType;
        if GrowerPoolType = GrowerPoolType::External then Context."Grower Type":=Context."Grower Type"::External
        else if GrowerPoolType = GrowerPoolType::"Contract Pack" then Context."Grower Type":=Context."Grower Type"::"Contract Pack"
            else
                Context."Grower Type":=Context."Grower Type"::Internal;
        Context."Variety Code":=CopyStr(Variety, 1, MaxStrLen(Context."Variety Code"));
        Context."Grade Code":=CopyStr(Grade, 1, MaxStrLen(Context."Grade Code"));
        Context."Size Code":=CopyStr(Size, 1, MaxStrLen(Context."Size Code"));
        Context."Pack Type Code":=ConsignmentLine."Pack Type Code";
        Context.Kgs:=ConsignmentLine."Quantity (Kg)";
        Context.Units:=ConsignmentLine.Quantity;
        Context.Value:=ConsignmentLine."Allocated Freight Cost";
        Context."Customer No.":=Consignment."Sell-to Customer No.";
        Context."Transaction Date":=Consignment."Despatch Date";
        Context."Posting Date":=WorkDate();
        Context."Source Document No.":=Consignment."Consignment No.";
        Context."Source Line No.":=ConsignmentLine."Line No.";
        Context."Source Type":=Context."Source Type"::Consignment;
        Context."Source System ID":=ConsignmentLine.SystemId;
    end;
    local procedure BuildCreditContext(var Context: Record "TAC Pool Charge Context" temporary; var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var SalesCrMemoLine: Record "Sales Cr.Memo Line"; PoolCode: Code[20]; PoolGroupID: Integer; Grower: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; PackType: Code[20]; PackTypeCategory: Code[20])
    begin
        Context.Init();
        Context."Pool Code":=PoolCode;
        Context."Pool Group ID":=PoolGroupID;
        Context."Grower Code":=Grower;
        Context."Supplier Type":=GrowerPoolType;
        if GrowerPoolType = GrowerPoolType::External then Context."Grower Type":=Context."Grower Type"::External
        else if GrowerPoolType = GrowerPoolType::"Contract Pack" then Context."Grower Type":=Context."Grower Type"::"Contract Pack"
            else
                Context."Grower Type":=Context."Grower Type"::Internal;
        Context."Variety Code":=CopyStr(Variety, 1, MaxStrLen(Context."Variety Code"));
        Context."Grade Code":=CopyStr(Grade, 1, MaxStrLen(Context."Grade Code"));
        Context."Size Code":=CopyStr(Size, 1, MaxStrLen(Context."Size Code"));
        Context."Pack Type Code":=PackType;
        Context."Pack Type Category Code":=PackTypeCategory;
        Context.Units:=Abs(SalesCrMemoLine.Quantity);
        Context.Kgs:=Abs(SalesCrMemoLine.Quantity);
        Context.Value:=Abs(SalesCrMemoLine.Amount);
        Context."Customer No.":=SalesCrMemoHeader."Sell-to Customer No.";
        Context."Transaction Date":=SalesCrMemoHeader."Posting Date";
        Context."Posting Date":=WorkDate();
        Context."Source Document No.":=SalesCrMemoHeader."No.";
        Context."Source Line No.":=SalesCrMemoLine."Line No.";
        Context."Source Item No.":=SalesCrMemoLine."No.";
        Context."UOM Code":=SalesCrMemoLine."Unit of Measure Code";
        Context.Reversal:=true;
        Context."Source Type":=Context."Source Type"::"Sales Credit Memo";
        Context."Source System ID":=SalesCrMemoLine.SystemId;
    end;
    [TryFunction]
    local procedure TryResolveProductionDimensions(var ProductionOrderLine: Record "Prod. Order Line"; var Season: Code[20]; var PoolWeek: Code[20]; var Variety: Code[20]; var Grade: Code[20]; var Size: Code[20]; var Grower: Code[20]; var GrowerPoolType: Enum "TAC Grower Pool Type"; var PackType: Code[20]; var PackTypeCategory: Code[20])
    var
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    begin
        DimensionMgt.ValidatePoolDimensionValues(ProductionOrderLine."Dimension Set ID");
        DimensionMgt.ResolveFromProductionOrderLine(ProductionOrderLine, //Season, PoolWeek, 
 Variety, Grade, Size, //Grower,
 GrowerPoolType, PackType, PackTypeCategory);
    end;
    [TryFunction]
    local procedure TryResolveInvoiceDimensions(var ConsignmentLine: Record "TAC Consignment Line"; var Season: Code[20]; var PoolWeek: Code[20]; var Variety: Code[20]; var Grade: Code[20]; var Size: Code[20]; var Grower: Code[20]; var GrowerPoolType: Enum "TAC Grower Pool Type"; var PackType: Code[20]; var PackTypeCategory: Code[20])
    var
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    begin
        DimensionMgt.ValidatePoolDimensionValues(ConsignmentLine."Dimension Set ID");
        DimensionMgt.ResolveFromDimensionSetWithPacking(ConsignmentLine."Dimension Set ID", //Season, PoolWeek, 
 Variety, Grade, Size, //Grower, 
 GrowerPoolType, PackType, PackTypeCategory);
        //if Grower = '' then
        Grower:=ConsignmentLine."Grower No.";
    end;
    [TryFunction]
    local procedure TryResolveConsignmentDimensions(var ConsignmentLine: Record "TAC Consignment Line"; var Season: Code[20]; var PoolWeek: Code[20]; var Variety: Code[20]; var Grade: Code[20]; var Size: Code[20]; var Grower: Code[20]; var GrowerPoolType: Enum "TAC Grower Pool Type")
    var
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    begin
        DimensionMgt.ResolveFromDimensionSet(ConsignmentLine."Dimension Set ID", //Season, PoolWeek, 
 Variety, Grade, Size, //Grower, 
        GrowerPoolType);
        //if Grower = '' then
        Grower:=ConsignmentLine."Grower No.";
    end;
    [TryFunction]
    local procedure TryResolveCreditDimensions(var SalesCrMemoLine: Record "Sales Cr.Memo Line"; var Season: Code[20]; var PoolWeek: Code[20]; var Variety: Code[20]; var Grade: Code[20]; var Size: Code[20]; var Grower: Code[20]; var GrowerPoolType: Enum "TAC Grower Pool Type"; var PackType: Code[20]; var PackTypeCategory: Code[20])
    var
        DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    begin
        DimensionMgt.ValidatePoolDimensionValues(SalesCrMemoLine."Dimension Set ID");
        DimensionMgt.ResolveFromDimensionSetWithPacking(SalesCrMemoLine."Dimension Set ID", //Season, PoolWeek, 
 Variety, Grade, Size, //Grower, 
 GrowerPoolType, PackType, PackTypeCategory);
    end;
    [TryFunction]
    local procedure TryRunCloseFromProductionOrderLine(var PoolProdOrderPost: Codeunit "TAC Pool Prod Order Post"; var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line")
    begin
        PoolProdOrderPost.RunCloseFromProductionOrderLine(ProductionOrder, ProductionOrderLine, WorkDate());
    end;
    [TryFunction]
    local procedure TryProcessPostedSalesInvoiceLine(var PoolConsignmentPost: Codeunit "TAC Pool Consignment Post"; var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line")
    begin
        PoolConsignmentPost.ProcessPostedSalesInvoiceLine(SalesInvoiceHeader, SalesInvoiceLine);
    end;
    [TryFunction]
    local procedure TryProcessPostedSalesCreditMemoLine(var PoolConsignmentPost: Codeunit "TAC Pool Consignment Post"; var SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var SalesCrMemoLine: Record "Sales Cr.Memo Line"; AppliedInvoiceNo: Code[20])
    begin
        PoolConsignmentPost.ProcessPostedSalesCreditMemoLine(SalesCrMemoHeader, SalesCrMemoLine, AppliedInvoiceNo);
    end;
    [TryFunction]
    local procedure TryPostConsignmentLine(var PoolConsignmentPost: Codeunit "TAC Pool Consignment Post"; var Consignment: Record "TAC Consignment Header"; var ConsignmentLine: Record "TAC Consignment Line")
    begin
        PoolConsignmentPost.PostConsignmentLine(Consignment, ConsignmentLine);
    end;
    [TryFunction]
    local procedure TryPostExpenseDetailLine(var PoolExpensePost: Codeunit "TAC Pool Expense Post"; var Expense: Record "TAC Pool Expense Header"; var ExpenseDetail: Record "TAC Pool Expense Detail")
    begin
        PoolExpensePost.PostExpenseDetailLine(Expense, ExpenseDetail);
    end;
    [TryFunction]
    local procedure TryPostAdjustmentEntry(var PoolAdjustmentPost: Codeunit "TAC Pool Adjustment Post"; var Adjustment: Record "TAC Pool Adjustment"; TransTypeCode: Code[10]; PoolCode: Code[20]; SignedKgs: Decimal)
    begin
        PoolAdjustmentPost.PostAdjustmentEntry(Adjustment, TransTypeCode, PoolCode, SignedKgs);
    end;
    local procedure MarkCreatedIfFound(var ReconLine: Record "TAC Pool Recon Line")
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", ReconLine."Pool Code");
        PoolLedgerEntry.SetRange("Source Document No.", ReconLine."Source Document No.");
        PoolLedgerEntry.SetRange("Source Line No.", ReconLine."Source Line No.");
        PoolLedgerEntry.SetRange("Trans Type Code", ReconLine."Expected Transaction Type");
        if PoolLedgerEntry.FindLast()then begin
            ReconLine.Status:=ReconLine.Status::Created;
            ReconLine."Created Entry No.":=PoolLedgerEntry."Entry No.";
            ReconLine."Created DateTime":=CurrentDateTime();
            ReconLine."Created By":=CopyStr(UserId(), 1, MaxStrLen(ReconLine."Created By"));
        end
        else
        begin
            ReconLine.Status:=ReconLine.Status::Error;
            ReconLine.Details:='The expected transaction was not created during revalidation.';
        end;
        ReconLine.Modify();
    end;
    local procedure UpdateCounts(var Reconciliation: Record "TAC Pool Reconciliation")
    var
        ReconLine: Record "TAC Pool Recon Line";
    begin
        ReconLine.SetRange("Reconciliation ID", Reconciliation."Reconciliation ID");
        ReconLine.SetRange(Status, ReconLine.Status::Found);
        Reconciliation."Found Entry Count":=ReconLine.Count();
        ReconLine.SetRange(Status, ReconLine.Status::Missing);
        Reconciliation."Missing Entry Count":=ReconLine.Count();
        ReconLine.SetRange(Status, ReconLine.Status::Excluded);
        Reconciliation."Excluded Entry Count":=ReconLine.Count();
        ReconLine.SetRange(Status, ReconLine.Status::Error);
        Reconciliation."Error Entry Count":=ReconLine.Count();
        ReconLine.SetRange(Status, ReconLine.Status::Created);
        Reconciliation."Created Entry Count":=ReconLine.Count();
        Reconciliation.Modify();
    end;
    local procedure NextReconLineNo(ReconciliationID: Integer): Integer var
        ReconLine: Record "TAC Pool Recon Line";
    begin
        ReconLine.SetRange("Reconciliation ID", ReconciliationID);
        if ReconLine.FindLast()then exit(ReconLine."Line No." + 10000);
        exit(10000);
    end;
    local procedure VerifyGroupOpen(PoolGroupID: Integer)
    var
        PoolGroup: Record "TAC Pool Group Header";
    begin
        PoolGroup.Get(PoolGroupID);
        PoolGroup.TestStatusOpen();
    end;
}
