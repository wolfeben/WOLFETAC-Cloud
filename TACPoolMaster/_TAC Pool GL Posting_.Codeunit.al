codeunit 50279 "TAC Pool GL Posting"
{
    // F-08 / §9 / ADR-002. The ONLY feature that posts financial documents.
    // Aggregates Pool Ledger lines by G/L Account + dimensions (TR/TRA/TRD
    // produce no GL line), applies the Grower GL Override per grower line, and
    // posts a named Gen. Journal batch; then builds one grower Purchase Invoice
    // per grower per Pool Group. Posting requires the §12 prerequisites
    // (LOCAL/GROWER posting groups, gen-journal template, balancing account);
    // when those are absent the documents/journal are built but left unposted
    // so the close never hard-fails pre-config.
    var // Held at codeunit level so its resolution cache lives for the whole
    // close rather than per invoice (ADR-004).
    GrowerMgt: Codeunit "TAC Pool Grower Mgt";
    GenJnlTemplateTok: Label 'POOLPAY', Locked = true;
    SourceCodeTok: Label 'POOLPAY', Locked = true;
    LocalGenBusTok: Label 'LOCAL', Locked = true;
    TRCodeTok: Label 'TR', Locked = true;
    TRACodeTok: Label 'TRA', Locked = true;
    TRDCodeTok: Label 'TRD', Locked = true;
    /// <summary>Steps 11-12 of the close: build + post the GL journal and the grower Purchase Invoices.</summary>
    procedure PostClose(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type"; PoolPaymentID: Integer; BatchName: Code[10])
    begin
        BuildAndPostGLJournal(PoolGroup, BatchName);
        BuildGrowerInvoices(PoolGroup, PaymentType, PoolPaymentID);
    end;
    /// <summary>
    /// Completes the invoice stage of a close that stopped after its general
    /// journal was posted. It never rebuilds payment entries or posts G/L.
    /// </summary>
    procedure ResumePaymentInvoices(var PoolGroup: Record "TAC Pool Group Header"; PoolPaymentID: Integer; PaymentType: Enum "TAC Pool Payment Type")
    begin
        if not PaymentFinancialEntriesPosted(PoolGroup."Pool Group ID", PoolPaymentID)then Error('The financial entries for Pool Payment %1 have not been posted to G/L, so this close cannot be resumed.', PoolPaymentID);
        // Gen. Jnl. posting commits independently. If a later Purchase Invoice
        // error aborts this codeunit call, the Pool Ledger flags can roll back
        // even though the G/L Entries remain posted. Reconstruct the completed
        // G/L stage before completing the invoice and status stages.
        MarkLedgerEntriesPosted(PoolGroup);
        BuildGrowerInvoices(PoolGroup, PaymentType, PoolPaymentID);
    end;
    local procedure PaymentFinancialEntriesPosted(PoolGroupID: Integer; PoolPaymentID: Integer): Boolean var
        PoolPaymentHeader: Record "TAC Pool Payment Header";
        GLEntry: Record "G/L Entry";
    begin
        if not PoolPaymentHeader.Get(PoolPaymentID)then exit(false);
        if(PoolPaymentHeader."Pool Group ID" <> PoolGroupID) or (PoolPaymentHeader."GL Journal Batch Name" = '')then exit(false);
        // Every generated close journal line has Document No. = the payment
        // batch and Source Code = POOLPAY. This is the durable evidence of a
        // completed G/L posting; Pool Ledger flags are not reliable after a
        // subsequent invoice-posting error rolls back the outer transaction.
        GLEntry.SetRange("Document No.", PoolPaymentHeader."GL Journal Batch Name");
        GLEntry.SetRange("Source Code", SourceCodeTok);
        exit(not GLEntry.IsEmpty());
    end;
    local procedure BuildAndPostGLJournal(var PoolGroup: Record "TAC Pool Group Header"; BatchName: Code[10])
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        AmountByKey: Dictionary of[Text, Decimal];
        AggKey: Text;
    begin
        // Aggregate every GL-affecting ledger line for the group by
        // account + grower. TR/TRA/TRD are kg movements with no GL impact.
        //PoolLedgerEntry.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolLedgerEntry.SetRange("Posted to G/L", false);
        if PoolLedgerEntry.FindSet()then repeat if not IsKgMovement(PoolLedgerEntry."Trans Type Code")then begin
                    AggKey:=AggregationKey(PoolGroup, PoolLedgerEntry);
                    if AmountByKey.ContainsKey(AggKey)then AmountByKey.Set(AggKey, AmountByKey.Get(AggKey) + PoolLedgerEntry.Amount)
                    else
                        AmountByKey.Add(AggKey, PoolLedgerEntry.Amount);
                end;
            until PoolLedgerEntry.Next() = 0;
        WriteJournalLines(BatchName, AmountByKey);
        if PostingEnabled()then begin
            PostBatch(BatchName);
            MarkLedgerEntriesPosted(PoolGroup);
        end;
    end;
    local procedure MarkLedgerEntriesPosted(var PoolGroup: Record "TAC Pool Group Header")
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolLedgerEntry.SetRange("Posted to G/L", false);
        if PoolLedgerEntry.FindSet(true)then repeat if not IsKgMovement(PoolLedgerEntry."Trans Type Code")then begin
                    PoolLedgerEntry."Posted to G/L":=true;
                    PoolLedgerEntry."G/L Posted At":=CurrentDateTime();
                    PoolLedgerEntry.Modify(true);
                end;
            until PoolLedgerEntry.Next() = 0;
    end;
    local procedure AggregationKey(var PoolGroup: Record "TAC Pool Group Header"; var PoolLedgerEntry: Record "TAC Pool Ledger Entry"): Text var
        GLAccountNo: Code[20];
    begin
        GLAccountNo:=ResolveGLAccount(PoolGroup, PoolLedgerEntry."Trans Type Code", PoolLedgerEntry."Grower Code");
        // Grower-specific account (an override) keeps the grower in the key so
        // its dimension can be stamped per line; shared accounts aggregate.
        if IsGrowerSpecific(PoolLedgerEntry."Trans Type Code", PoolLedgerEntry."Grower Code")then exit(StrSubstNo('%1|%2', GLAccountNo, PoolLedgerEntry."Grower Code"));
        exit(StrSubstNo('%1|', GLAccountNo));
    end;
    local procedure ResolveGLAccount(var PoolGroup: Record "TAC Pool Group Header"; TransTypeCode: Code[10]; GrowerCode: Code[20]): Code[20]var
        TransType: Record "TAC Pool Trans Type";
        GrowerGLOverride: Record "TAC Grower GL Override";
    begin
        // Grower GL Override wins for a grower-specific line (design §9.3).
        if(GrowerCode <> '') and GrowerGLOverride.Get(GrowerCode, TransTypeCode)then exit(GrowerGLOverride."Override GL Account");
        if not TransType.Get(TransTypeCode)then exit('');
        if PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::External then exit(TransType."GL Account External");
        exit(TransType."GL Account Internal");
    end;
    local procedure IsGrowerSpecific(TransTypeCode: Code[10]; GrowerCode: Code[20]): Boolean var
        GrowerGLOverride: Record "TAC Grower GL Override";
    begin
        exit((GrowerCode <> '') and GrowerGLOverride.Get(GrowerCode, TransTypeCode));
    end;
    local procedure WriteJournalLines(BatchName: Code[10]; var AmountByKey: Dictionary of[Text, Decimal])
    var
        GenJournalLine: Record "Gen. Journal Line";
        PoolSetup: Record "TAC Pool Setup";
        AggKey: Text;
        Parts: List of[Text];
        GLAccountNo: Code[20];
        GrowerCode: Code[20];
        JournalAmount: Decimal;
        LineNo: Integer;
    begin
        PoolSetup.Get();
        PoolSetup.TestField("Pool Charge Clearing Account");
        EnsureJournalBatch(BatchName);
        GenJournalLine.SetRange("Journal Template Name", GenJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", BatchName);
        GenJournalLine.DeleteAll();
        LineNo:=0;
        foreach AggKey in AmountByKey.Keys()do begin
            Parts:=AggKey.Split('|');
            GLAccountNo:=CopyStr(Parts.Get(1), 1, MaxStrLen(GLAccountNo));
            if Parts.Count >= 2 then GrowerCode:=CopyStr(Parts.Get(2), 1, MaxStrLen(GrowerCode))
            else
                GrowerCode:='';
            if GLAccountNo = '' then begin
                // No mandatory GL account is caught by the close validate pass;
                // a blank here is a non-mandatory/export type pending OI-08.
                continue;
            end;
            // A group can contain equal and opposite entries for the same
            // account (for example, a charge and its proration contra). They
            // aggregate to zero and must not become a general journal line:
            // standard BC rejects a zero Amount during posting.
            JournalAmount:=AmountByKey.Get(AggKey);
            if JournalAmount = 0 then continue;
            LineNo+=10000;
            GenJournalLine.Init();
            GenJournalLine."Journal Template Name":=GenJnlTemplateTok;
            GenJournalLine."Journal Batch Name":=BatchName;
            GenJournalLine."Line No.":=LineNo;
            GenJournalLine."Posting Date":=Today();
            // The batch represents one Pool Payment close. Use that stable
            // close identifier on every line so standard journal posting has
            // the mandatory document reference and the resulting G/L entries
            // can be traced back to the payment run.
            GenJournalLine."Document No.":=CopyStr(BatchName, 1, MaxStrLen(GenJournalLine."Document No."));
            GenJournalLine."Account Type":=GenJournalLine."Account Type"::"G/L Account";
            GenJournalLine.Validate("Account No.", GLAccountNo);
            GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
            GenJournalLine.Validate("Bal. Account No.", PoolSetup."Pool Charge Clearing Account");
            GenJournalLine.Validate(Amount, JournalAmount);
            GenJournalLine."Source Code":=SourceCodeTok;
            // TODO §9.1: stamp Season + Pool Week on every line and Grower on
            // grower-specific lines via a built Dimension Set (DimensionManagement).
            if GrowerCode <> '' then GenJournalLine.Description:=CopyStr(StrSubstNo('Pool payment %1', GrowerCode), 1, MaxStrLen(GenJournalLine.Description));
            GenJournalLine.Insert(true);
        end;
    end;
    local procedure BuildGrowerInvoices(var PoolGroup: Record "TAC Pool Group Header"; PaymentType: Enum "TAC Pool Payment Type"; PoolPaymentID: Integer)
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        GrowerList: List of[Code[20]];
        GrowerCode: Code[20];
    begin
        // One Purchase Invoice per grower per Pool Group (design §8).
        PoolLedgerEntry.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolLedgerEntry.SetRange("Pool Payment ID", PoolPaymentID);
        PoolLedgerEntry.SetFilter("Grower Code", '<>%1', '');
        if PoolLedgerEntry.FindSet()then repeat if not GrowerList.Contains(PoolLedgerEntry."Grower Code")then GrowerList.Add(PoolLedgerEntry."Grower Code");
            until PoolLedgerEntry.Next() = 0;
        foreach GrowerCode in GrowerList do BuildGrowerInvoice(PoolGroup, GrowerCode, PaymentType, PoolPaymentID);
    end;
    local procedure BuildGrowerInvoice(var PoolGroup: Record "TAC Pool Group Header"; GrowerCode: Code[20]; PaymentType: Enum "TAC Pool Payment Type"; PoolPaymentID: Integer)
    var
        PurchaseHeader: Record "Purchase Header";
        VendorNo: Code[20];
        PoolSetup: Record "TAC Pool Setup";
        SettlementAmount: Decimal;
    begin
        if not PostingEnabled()then exit; // documents require posting-group config (§12) — see header note.
        VendorNo:=GrowerMgt.VendorNoForGrower(GrowerCode);
        if FindPostedGrowerDocument(VendorNo, PoolPaymentID, PoolGroup."Pool Group Code")then exit;
        SettlementAmount:=GrowerSettlementAmount(PoolGroup, GrowerCode, PoolPaymentID);
        if SettlementAmount = 0 then exit;
        PoolSetup.Get();
        PurchaseHeader.Init();
        if SettlementAmount > 0 then PurchaseHeader."Document Type":=PurchaseHeader."Document Type"::Invoice
        else
            PurchaseHeader."Document Type":=PurchaseHeader."Document Type"::"Credit Memo";
        PurchaseHeader.Insert(true); // assigns No. from Purchases & Payables Setup
        // The grower key is a grower dimension value; the vendor carrying it is
        // the invoice's buy-from party (ADR-004). The close's V7 has already
        // proved every grower in the group resolves, so this cannot fail here
        // unless the vendor card changed mid-close.
        PurchaseHeader.Validate("Buy-from Vendor No.", VendorNo);
        PurchaseHeader.Validate("Posting Date", Today());
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo" then PoolSetup.TestField("Grower Settlement Reason Code");
        if PoolSetup."Grower Settlement Reason Code" <> '' then PurchaseHeader.Validate("Reason Code", PoolSetup."Grower Settlement Reason Code");
        // Positive settlements are self-billed Purchase Invoices. A net charge
        // to the grower is a Purchase Credit Memo. Keep the payment reference
        // stable in the appropriate external-reference field for retry safety.
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Invoice then PurchaseHeader.Validate("Vendor Invoice No.", PoolPaymentReference(PoolPaymentID, PoolGroup."Pool Group Code"))
        else
            PurchaseHeader.Validate("Vendor Cr. Memo No.", PoolPaymentReference(PoolPaymentID, PoolGroup."Pool Group Code"));
        PurchaseHeader."Your Reference":=PoolGroup."Pool Group Code";
        PurchaseHeader.Validate("Gen. Bus. Posting Group", LocalGenBusTok);
        if PoolGroup."Grower Pool Type" = PoolGroup."Grower Pool Type"::External then begin
            if PoolSetup."Grower Ext. Posting Group" <> '' then PurchaseHeader.Validate("Vendor Posting Group", PoolSetup."Grower Ext. Posting Group");
        end
        else if PoolSetup."Grower Posting Group" <> '' then PurchaseHeader.Validate("Vendor Posting Group", PoolSetup."Grower Posting Group");
        PurchaseHeader.Modify(true);
        BuildInvoiceLines(PurchaseHeader, PoolGroup, GrowerCode, PaymentType, PoolPaymentID);
        PostPurchaseInvoice(PurchaseHeader);
        AddCreatedPurchaseInvoiceNo(PoolPaymentID, PostedGrowerDocumentNo(VendorNo, PoolPaymentID, PoolGroup."Pool Group Code"));
    // PostInvoice(PurchaseHeader); // enable once §12 posting config is in place.
    end;
    local procedure FindPostedGrowerDocument(VendorNo: Code[20]; PoolPaymentID: Integer; PoolGroupCode: Code[20]): Boolean begin
        exit(PostedGrowerDocumentNo(VendorNo, PoolPaymentID, PoolGroupCode) <> '');
    end;
    local procedure PostedGrowerDocumentNo(VendorNo: Code[20]; PoolPaymentID: Integer; PoolGroupCode: Code[20]): Code[20]var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
    begin
        PurchInvHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchInvHeader.SetRange("Vendor Invoice No.", PoolPaymentReference(PoolPaymentID, PoolGroupCode));
        if PurchInvHeader.FindFirst()then exit(PurchInvHeader."No.");
        PurchCrMemoHdr.SetRange("Buy-from Vendor No.", VendorNo);
        PurchCrMemoHdr.SetRange("Vendor Cr. Memo No.", PoolPaymentReference(PoolPaymentID, PoolGroupCode));
        if PurchCrMemoHdr.FindFirst()then exit(PurchCrMemoHdr."No.");
    end;
    local procedure PoolPaymentReference(PoolPaymentID: Integer; PoolGroupCode: Code[20]): Code[35]begin
        exit(CopyStr(StrSubstNo('POOLPAY-%1-%2', PoolPaymentID, PoolGroupCode), 1, 35));
    end;
    local procedure AddCreatedPurchaseInvoiceNo(PoolPaymentID: Integer; InvoiceNo: Code[20])
    var
        PoolPaymentHeader: Record "TAC Pool Payment Header";
        UpdatedInvoiceNos: Text[250];
    begin
        if(InvoiceNo = '') or not PoolPaymentHeader.Get(PoolPaymentID)then exit;
        if StrPos(PoolPaymentHeader."Created Purchase Invoice Nos.", InvoiceNo) <> 0 then exit;
        UpdatedInvoiceNos:=PoolPaymentHeader."Created Purchase Invoice Nos.";
        if UpdatedInvoiceNos <> '' then UpdatedInvoiceNos+=',';
        UpdatedInvoiceNos:=CopyStr(UpdatedInvoiceNos + InvoiceNo, 1, MaxStrLen(UpdatedInvoiceNos));
        PoolPaymentHeader."Created Purchase Invoice Nos.":=UpdatedInvoiceNos;
        PoolPaymentHeader.Modify(true);
    end;
    local procedure GrowerSettlementAmount(var PoolGroup: Record "TAC Pool Group Header"; GrowerCode: Code[20]; PoolPaymentID: Integer): Decimal var
        Pool: Record "TAC Pool";
        PoolGrowerCharge: Record "TAC Pool Grower Charge";
        TransType: Record "TAC Pool Trans Type";
        SettlementAmount: Decimal;
    begin
        Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        if Pool.FindSet()then repeat SettlementAmount+=Abs(GrowerPaymentForPool(Pool."Pool Code", GrowerCode, PoolPaymentID));
            until Pool.Next() = 0;
        PoolGrowerCharge.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolGrowerCharge.SetRange("Grower Code", GrowerCode);
        PoolGrowerCharge.SetRange("Pool Payment ID", PoolPaymentID);
        if PoolGrowerCharge.FindSet()then repeat if TransType.Get(PoolGrowerCharge."Trans Type Code")then if not TransType."Suppress on Grower Invoice" then SettlementAmount-=PoolGrowerCharge.Amount;
            until PoolGrowerCharge.Next() = 0;
        exit(SettlementAmount);
    end;
    local procedure BuildInvoiceLines(var PurchaseHeader: Record "Purchase Header"; var PoolGroup: Record "TAC Pool Group Header"; GrowerCode: Code[20]; PaymentType: Enum "TAC Pool Payment Type"; PoolPaymentID: Integer)
    var
        PoolGrowerCharge: Record "TAC Pool Grower Charge";
        TransType: Record "TAC Pool Trans Type";
        LineNo: Integer;
    begin
        // Pool payment lines (PP/PPV) are GST-free; above-the-line charges carry
        // the Trans Type GST rate and are excluded when Suppress = Y (§8).
        LineNo:=AppendPoolPaymentLines(PurchaseHeader, PoolGroup, GrowerCode, PoolPaymentID, 0);
        PoolGrowerCharge.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        PoolGrowerCharge.SetRange("Grower Code", GrowerCode);
        if PoolPaymentID <> 0 then PoolGrowerCharge.SetRange("Pool Payment ID", PoolPaymentID);
        if PoolGrowerCharge.FindSet()then repeat if TransType.Get(PoolGrowerCharge."Trans Type Code")then if not TransType."Suppress on Grower Invoice" then begin
                        LineNo+=10000;
                        AppendChargeLine(PurchaseHeader, PoolGrowerCharge, LineNo);
                    end;
            until PoolGrowerCharge.Next() = 0;
    end;
    local procedure AppendPoolPaymentLines(var PurchaseHeader: Record "Purchase Header"; var PoolGroup: Record "TAC Pool Group Header"; GrowerCode: Code[20]; PoolPaymentID: Integer; StartLineNo: Integer): Integer var
        Pool: Record "TAC Pool";
        PurchaseLine: Record "Purchase Line";
        PoolSetup: Record "TAC Pool Setup";
        Amount: Decimal;
        LineAmount: Decimal;
        LineNo: Integer;
    begin
        PoolSetup.Get();
        LineNo:=StartLineNo;
        Pool.SetRange("Pool Group ID", PoolGroup."Pool Group ID");
        if Pool.FindSet()then repeat //Amount := GrowerPaymentForPool(Pool."Pool ID", GrowerCode);
                Amount:=GrowerPaymentForPool(Pool."Pool Code", GrowerCode, PoolPaymentID);
                if Amount <> 0 then begin
                    LineNo+=10000;
                    PurchaseLine.Init();
                    PurchaseLine."Document Type":=PurchaseHeader."Document Type";
                    PurchaseLine."Document No.":=PurchaseHeader."No.";
                    PurchaseLine."Line No.":=LineNo;
                    PurchaseLine.Validate(Type, PurchaseLine.Type::"G/L Account");
                    PurchaseLine.Validate("No.", PoolSetup."Pool Charge Clearing Account");
                    // Pool payment is GST-free. Credit memos reverse the line
                    // signs so a net grower charge posts as a vendor debit.
                    PurchaseLine.Description:=CopyStr(Pool.Description, 1, MaxStrLen(PurchaseLine.Description));
                    PurchaseLine.Validate(Quantity, 1);
                    LineAmount:=Abs(Amount);
                    if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo" then LineAmount:=-LineAmount;
                    PurchaseLine.Validate("Direct Unit Cost", LineAmount);
                    PurchaseLine.Insert(true);
                end;
            until Pool.Next() = 0;
        exit(LineNo);
    end;
    local procedure AppendChargeLine(var PurchaseHeader: Record "Purchase Header"; var PoolGrowerCharge: Record "TAC Pool Grower Charge"; LineNo: Integer)
    var
        PurchaseLine: Record "Purchase Line";
        PoolSetup: Record "TAC Pool Setup";
        LineAmount: Decimal;
    begin
        PoolSetup.Get();
        PurchaseLine.Init();
        PurchaseLine."Document Type":=PurchaseHeader."Document Type";
        PurchaseLine."Document No.":=PurchaseHeader."No.";
        PurchaseLine."Line No.":=LineNo;
        PurchaseLine.Validate(Type, PurchaseLine.Type::"G/L Account");
        PurchaseLine.Validate("No.", PoolSetup."Pool Charge Clearing Account");
        PurchaseLine.Description:=CopyStr(StrSubstNo('Charge %1', PoolGrowerCharge."Trans Type Code"), 1, MaxStrLen(PurchaseLine.Description));
        PurchaseLine.Validate(Quantity, 1);
        LineAmount:=-PoolGrowerCharge.Amount; // charge reduces the payment
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo" then LineAmount:=-LineAmount;
        PurchaseLine.Validate("Direct Unit Cost", LineAmount);
        PurchaseLine.Insert(true);
    end;
    local procedure PostPurchaseInvoice(var PurchaseHeader: Record "Purchase Header")
    var
        PurchPost: Codeunit "Purch.-Post";
    begin
        PurchPost.Run(PurchaseHeader);
    end;
    local procedure GrowerPaymentForPool(PoolCode: Code[20]; GrowerCode: Code[20]; PoolPaymentID: Integer): Decimal var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        // Sum of the grower's PP/PPV entries in the pool (written by the close).
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Grower Code", GrowerCode);
        PoolLedgerEntry.SetRange("Pool Payment ID", PoolPaymentID);
        PoolLedgerEntry.SetFilter("Trans Type Code", '%1|%2', 'PP', 'PPV');
        //PoolLedgerEntry.SetRange("Entry Type", PoolLedgerEntry."Entry Type"::Payment);
        PoolLedgerEntry.CalcSums(Amount);
        exit(PoolLedgerEntry.Amount);
    end;
    local procedure IsKgMovement(TransTypeCode: Code[10]): Boolean begin
        exit(TransTypeCode in[TRCodeTok, TRACodeTok, TRDCodeTok]);
    end;
    local procedure EnsureJournalBatch(BatchName: Code[10])
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
    begin
        if not GenJournalTemplate.Get(GenJnlTemplateTok)then begin
            GenJournalTemplate.Init();
            GenJournalTemplate.Name:=GenJnlTemplateTok;
            GenJournalTemplate.Validate(Type, GenJournalTemplate.Type::General);
            GenJournalTemplate.Insert(true);
        end;
        if not GenJournalBatch.Get(GenJnlTemplateTok, BatchName)then begin
            GenJournalBatch.Init();
            GenJournalBatch."Journal Template Name":=GenJnlTemplateTok;
            GenJournalBatch.Name:=BatchName;
            GenJournalBatch.Insert(true);
        end;
    end;
    local procedure PostBatch(BatchName: Code[10])
    var
        GenJournalLine: Record "Gen. Journal Line";
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
    begin
        GenJournalLine.SetRange("Journal Template Name", GenJnlTemplateTok);
        GenJournalLine.SetRange("Journal Batch Name", BatchName);
        if GenJournalLine.IsEmpty()then exit;
        GenJournalLine.FindFirst();
        GenJnlPost.Run(GenJournalLine);
    end;
    local procedure PostingEnabled(): Boolean var
        PoolSetup: Record "TAC Pool Setup";
    begin
        // ADR-002 / §12: only post when the prerequisites are configured. This
        // also gates the provisional advance posting until OI-PE-01 confirms it.
        if not PoolSetup.Get()then exit(false);
        exit((PoolSetup."Pool Charge Clearing Account" <> '') and (PoolSetup."Grower Posting Group" <> ''));
    end;
}
