codeunit 50270 "TAC Pool Charge Engine"
{
    // The single, data-driven Charge Template matcher (design §6.4, ADR-003).
    // Precedence and rate-source logic live ONLY here; all three callers
    // (RunClose / ConsignmentPost / GroupClose) pass a populated Charge Context
    // and choose Write or Validate mode. Validate resolves every row and rate
    // but writes nothing (ADR-001 dry-run).
    SingleInstance = false;

    var TrayPackTypeCategoryTok: Label 'TRAY', Locked = true;
    NoMatchMandatoryErr: Label 'No charge template row matched for mandatory trans type %1 — check Sheet 3.4 configuration.', Comment = '%1 = Trans Type Code';
    NoMatchOptionalMsg: Label 'No charge template row matched optional trans type %1 for this action.', Comment = '%1 = Trans Type Code';
    MissingOptionalTemplateMsg: Label 'Optional transaction type %1 has no active non-bin charge template for this action.', Comment = '%1 = Trans Type Code';
    EqualSpecificityErr: Label 'Charge template configuration error: two rows of equal specificity match trans type %1 for grower %2.', Comment = '%1 = Trans Type Code, %2 = Grower Code';
    MissingMandatoryTemplateErr: Label 'Mandatory transaction type %1 has no active non-bin charge template for this action.', Comment = '%1 = Trans Type Code';
    RateDefinitionErr: Label 'Charge template %1 does not agree with transaction type %2 for rate type or rate source.', Comment = '%1 = Template ID, %2 = Trans Type Code';
    /// <summary>
    /// Match and (in Write mode) post every charge for the given action against
    /// the supplied context. One Pool Ledger Entry per winning template row,
    /// including a zero-amount entry for a winning zero-rate row.
    /// </summary>
    procedure ApplyCharges(ChargeAction: Enum "TAC Pool Charge Action"; var Ctx: Record "TAC Pool Charge Context" temporary; Mode: Enum "TAC Pool Charge Mode")
    var
        Evaluation: Record "TAC Pool Charge Evaluation" temporary;
        Template: Record "TAC Pool Charge Template";
    begin
        EvaluateCharges(ChargeAction, Ctx, Evaluation);
        if Evaluation.FindSet()then repeat // Each Trans Type in scope is resolved once. Iterating the
                // sorted key means all rows of a Trans Type are contiguous.
                case Evaluation.Result of Evaluation.Result::Expected: begin
                    Template.Get(Evaluation."Template ID");
                    PostCharge(Template, Ctx, Mode);
                end;
                Evaluation.Result::"No Template": if Evaluation.Mandatory then Error(MissingMandatoryTemplateErr, Evaluation."Trans Type Code");
                Evaluation.Result::"No Match": if Evaluation.Mandatory then Error(NoMatchMandatoryErr, Evaluation."Trans Type Code");
                Evaluation.Result::Ambiguous: Error(EqualSpecificityErr, Evaluation."Trans Type Code", Ctx."Grower Code");
                Evaluation.Result::Invalid: Error(Evaluation.Details);
                end;
            until Evaluation.Next() = 0;
    end;
    /// <summary>Evaluates every active transaction type without writing or raising configuration errors.</summary>
    procedure EvaluateCharges(ChargeAction: Enum "TAC Pool Charge Action"; var Ctx: Record "TAC Pool Charge Context" temporary; var Result: Record "TAC Pool Charge Evaluation" temporary)
    var
        TransType: Record "TAC Pool Trans Type";
        Winner: Record "TAC Pool Charge Template";
        HasTemplate: Boolean;
        HasWinner: Boolean;
        IsAmbiguous: Boolean;
    begin
        Result.Reset();
        Result.DeleteAll();
        TransType.SetRange(Active, true);
        TransType.SetRange("Charge Action", ChargeAction);
        if TransType.FindSet()then repeat HasTemplate:=HasActiveNonBinTemplate(TransType.Code, ChargeAction);
                HasWinner:=FindWinningRow(TransType.Code, ChargeAction, Ctx, Winner, IsAmbiguous);
                AddEvaluation(Result, TransType, Winner, HasTemplate, HasWinner, IsAmbiguous, Ctx);
            until TransType.Next() = 0;
    end;
    local procedure AddEvaluation(var Result: Record "TAC Pool Charge Evaluation" temporary; var TransType: Record "TAC Pool Trans Type"; var Winner: Record "TAC Pool Charge Template"; HasTemplate: Boolean; HasWinner: Boolean; IsAmbiguous: Boolean; var Ctx: Record "TAC Pool Charge Context" temporary)
    var
        Amount: Decimal;
    begin
        Result.Init();
        Result."Entry No.":=NextEvaluationEntryNo(Result);
        Result."Trans Type Code":=TransType.Code;
        Result.Mandatory:=TransType.Mandatory;
        if not HasTemplate then begin
            Result.Result:=Result.Result::"No Template";
            if TransType.Mandatory then Result.Details:=StrSubstNo(MissingMandatoryTemplateErr, TransType.Code)
            else
                Result.Details:=StrSubstNo(MissingOptionalTemplateMsg, TransType.Code);
        end
        else if IsAmbiguous then begin
                Result.Result:=Result.Result::Ambiguous;
                Result.Details:=StrSubstNo(EqualSpecificityErr, TransType.Code, Ctx."Grower Code");
            end
            else if not HasWinner then begin
                    Result.Result:=Result.Result::"No Match";
                    if TransType.Mandatory then Result.Details:=StrSubstNo(NoMatchMandatoryErr, TransType.Code)
                    else
                        Result.Details:=StrSubstNo(NoMatchOptionalMsg, TransType.Code);
                end
                else
                begin
                    Result."Template ID":=Winner.ID;
                    Result."Rate Source":=Winner."Rate Source";
                    Result."Rate Type":=Winner."Rate Type";
                    if not TemplateDefinitionIsValid(Winner, TransType, Result.Details)then Result.Result:=Result.Result::Invalid
                    else if Winner."Rate Source" = Winner."Rate Source"::Calculated then begin
                            Result.Result:=Result.Result::Calculated;
                            Result.Details:='Calculated transaction; it is not posted by this action.';
                        end
                        else
                        begin
                            Result.Rate:=ResolveRate(Winner, Ctx);
                            Result."Calculation Base":=MeasureBase(Winner."Rate Type", Ctx);
                            Amount:=-(Result.Rate * Result."Calculation Base");
                            if Ctx.Reversal then Amount:=-Amount;
                            Result."Expected Amount":=Amount;
                            Result."GST Amount":=Amount * TransType."GST Rate" / 100;
                            Result.Result:=Result.Result::Expected;
                        end;
                end;
        Result.Insert();
    end;
    local procedure HasActiveNonBinTemplate(TransTypeCode: Code[10]; ChargeAction: Enum "TAC Pool Charge Action"): Boolean var
        Template: Record "TAC Pool Charge Template";
    begin
        Template.SetRange("Trans Type Code", TransTypeCode);
        Template.SetRange("Charge Action", ChargeAction);
        Template.SetRange(Active, true);
        Template.SetFilter("Rate Type", '<>%1', Template."Rate Type"::Bin);
        exit(not Template.IsEmpty());
    end;
    local procedure TemplateDefinitionIsValid(var Template: Record "TAC Pool Charge Template"; var TransType: Record "TAC Pool Trans Type"; var Details: Text[250]): Boolean begin
        if(Template."Rate Type" = TransType."Charge Rate Type") and (Template."Rate Source" = TransType."Rate Source")then exit(true);
        Details:=StrSubstNo(RateDefinitionErr, Template.ID, TransType.Code);
        exit(false);
    end;
    local procedure NextEvaluationEntryNo(var Result: Record "TAC Pool Charge Evaluation" temporary): Integer begin
        if Result.FindLast()then exit(Result."Entry No." + 1);
        exit(1);
    end;
    local procedure ProcessTransType(TransTypeCode: Code[20]; ChargeAction: Enum "TAC Pool Charge Action"; var Ctx: Record "TAC Pool Charge Context" temporary; Mode: Enum "TAC Pool Charge Mode")
    var
        Winner: Record "TAC Pool Charge Template";
        TransType: Record "TAC Pool Trans Type";
        Found: Boolean;
        IsAmbiguous: Boolean;
    begin
        Found:=FindWinningRow(TransTypeCode, ChargeAction, Ctx, Winner, IsAmbiguous);
        if not Found then begin
            // No-match (§6.4.3): mandatory errors before posting; otherwise skip.
            TransType.Get(TransTypeCode);
            if TransType.Mandatory then Error(NoMatchMandatoryErr, TransTypeCode);
            exit;
        end;
        // Calculated (FR) rate is computed in the close (F-07 Step 2) and is
        // blocked by OI-04; the engine never writes an FR amount here.
        if(Winner."Rate Source" = Winner."Rate Source"::Calculated) or (Winner."Rate Type" = Winner."Rate Type"::Bin)then exit;
        PostCharge(Winner, Ctx, Mode);
    end;
    /// <summary>
    /// Apply §6.4.2 precedence: most non-blank filters wins; tie broken by a
    /// populated Grower Code Filter; a residual tie is a configuration error.
    /// </summary>
    local procedure FindWinningRow(TransTypeCode: Code[20]; ChargeAction: Enum "TAC Pool Charge Action"; var Ctx: Record "TAC Pool Charge Context" temporary; var Winner: Record "TAC Pool Charge Template"; var IsAmbiguous: Boolean): Boolean var
        Template: Record "TAC Pool Charge Template";
        HaveWinner: Boolean;
        RowCount: Integer;
        WinnerCount: Integer;
        RowHasGrower: Boolean;
        WinnerHasGrower: Boolean;
    begin
        IsAmbiguous:=false;
        Template.SetCurrentKey("Trans Type Code", "Charge Action", Active);
        Template.SetRange("Trans Type Code", TransTypeCode);
        Template.SetRange("Charge Action", ChargeAction);
        Template.SetRange(Active, true);
        if Template.FindSet()then repeat if(Template."Rate Type" <> Template."Rate Type"::Bin) and IsEligible(Template, Ctx)then begin
                    RowCount:=NonBlankFilterCount(Template);
                    RowHasGrower:=Template."Grower Code Filter" <> '';
                    if not HaveWinner then begin
                        Winner:=Template;
                        WinnerCount:=RowCount;
                        WinnerHasGrower:=RowHasGrower;
                        HaveWinner:=true;
                        IsAmbiguous:=false;
                    end
                    else if RowCount > WinnerCount then begin
                            Winner:=Template;
                            WinnerCount:=RowCount;
                            WinnerHasGrower:=RowHasGrower;
                            IsAmbiguous:=false;
                        end
                        else if RowCount = WinnerCount then case true of RowHasGrower and not WinnerHasGrower: begin
                                    Winner:=Template;
                                    WinnerHasGrower:=true;
                                    IsAmbiguous:=false;
                                end;
                                WinnerHasGrower and not RowHasGrower: IsAmbiguous:=false; // keep current winner
                                else
                                    IsAmbiguous:=true; // equal specificity, same grower-filter status
                                end;
                end;
            until Template.Next() = 0;
        exit(HaveWinner);
    end;
    local procedure IsEligible(var Template: Record "TAC Pool Charge Template"; var Ctx: Record "TAC Pool Charge Context" temporary): Boolean var
        RipenerFilter: Integer;
    begin
        // Eligibility (§6.4.1): every non-blank filter must match exactly.
        if not MatchCode(Template."Supplier Type Filter", SupplierTypeLetter(Ctx."Supplier Type"))then exit(false);
        if not MatchCode(Template."Grower Type Filter", GrowerTypeLetter(Ctx."Grower Type"))then exit(false);
        if not MatchCode(Template."Variety Filter", Ctx."Variety Code")then exit(false);
        if not MatchCode(Template."Pack Type Filter", Ctx."Pack Type Code")then exit(false);
        if not MatchCode(Template."Pack Type Category Filter", Ctx."Pack Type Category Code")then exit(false);
        if not MatchCode(Template."Grade Filter", Ctx."Grade Code")then exit(false);
        if not MatchCode(Template."Grower Code Filter", Ctx."Grower Code")then exit(false);
        // Ripener Required Filter (Option " ",Y,N): blank = don't care,
        // Y = condition must be true, N = condition must be false.
        RipenerFilter:=Template."Ripener Required Filter";
        case RipenerFilter of 1: if not RipenerConditionMet(Ctx)then exit(false);
        2: if RipenerConditionMet(Ctx)then exit(false);
        end;
        // Grade exclusion (50223) rejects an otherwise-eligible row.
        if GradeExcluded(Template.ID, Ctx."Grade Code")then exit(false);
        exit(true);
    end;
    local procedure NonBlankFilterCount(var Template: Record "TAC Pool Charge Template"): Integer var
        Count: Integer;
    begin
        if Template."Supplier Type Filter" <> '' then Count+=1;
        if Template."Grower Type Filter" <> '' then Count+=1;
        if Template."Variety Filter" <> '' then Count+=1;
        if Template."Pack Type Filter" <> '' then Count+=1;
        if Template."Pack Type Category Filter" <> '' then Count+=1;
        if Template."Grade Filter" <> '' then Count+=1;
        if Template."Grower Code Filter" <> '' then Count+=1;
        if Template."Ripener Required Filter" <> Template."Ripener Required Filter"::" " then Count+=1;
        exit(Count);
    end;
    local procedure MatchCode(FilterValue: Code[20]; ContextValue: Code[20]): Boolean begin
        // Blank filter applies to all (§6.4.1).
        if FilterValue = '' then exit(true);
        exit(FilterValue = ContextValue);
    end;
    local procedure GradeExcluded(TemplateID: Integer; GradeCode: Code[10]): Boolean var
        GradeExcl: Record "TAC Pool Chg Tmpl Grade Excl";
    begin
        if GradeCode = '' then exit(false);
        exit(GradeExcl.Get(TemplateID, GradeCode));
    end;
    local procedure RipenerConditionMet(var Ctx: Record "TAC Pool Charge Context" temporary): Boolean var
        RipeningPrice: Record "TAC Ripening Price";
    begin
        // Eligible only when Customer.Ripening Required = Y AND the pack type
        // category is a tray type (§6.4.1). The tray category code is a config
        // assumption (TRAY) pending confirmation — see implementation note.
        if Ctx."Customer No." = '' then exit(false);
        RipeningPrice.SetRange("Customer No.", Ctx."Customer No.");
        RipeningPrice.SetRange("Item No.", Ctx."Source Item No.");
        RipeningPrice.SetRange("Unit of Measure Code", Ctx."UOM Code");
        RipeningPrice.SetRange(Active, true);
        RipeningPrice.FindLast();
        exit(Ctx."Pack Type Category Code" = TrayPackTypeCategoryTok);
    end;
    local procedure PostCharge(var Template: Record "TAC Pool Charge Template"; var Ctx: Record "TAC Pool Charge Context" temporary; Mode: Enum "TAC Pool Charge Mode")
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
        TransType: Record "TAC Pool Trans Type";
        GrowerMgt: Codeunit "TAC Pool Grower Mgt";
        Rate: Decimal;
        Amount: Decimal;
        GSTAmount: Decimal;
        GrowerNo: Code[20];
    begin
        TransType.Get(Template."Trans Type Code");
        ValidateTemplateDefinition(Template, TransType);
        Rate:=ResolveRate(Template, Ctx);
        // Charges are deductions from pool value -> negative (out). A winning
        // zero-rate row still posts a zero-amount entry (§6.4.4).
        Amount:=-(Rate * MeasureBase(Template."Rate Type", Ctx));
        if Ctx.Reversal then Amount:=-Amount;
        GSTAmount:=Amount * TransType."GST Rate" / 100;
        if Mode = "TAC Pool Charge Mode"::Validate then exit; // dry-run: rate + amount resolved, nothing written (ADR-001).
        if ChargeAlreadyPosted(Ctx."Pool Code", Template."Trans Type Code", Ctx."Source Document No.", Ctx."Source Line No.")then exit;
        // Grower Code is the pool dimension value.  The ledger's Grower No.
        // is the corresponding vendor, resolved from that grower's default
        // dimension assignment.
        if Ctx."Grower Code" <> '' then GrowerNo:=GrowerMgt.VendorNoForGrower(Ctx."Grower Code");
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code":=Ctx."Pool Code";
        PoolLedgerEntry."Pool Group ID":=Ctx."Pool Group ID";
        PoolLedgerEntry."Entry Type":=PoolLedgerEntry."Entry Type"::Charge;
        PoolLedgerEntry."Trans Type Code":=Template."Trans Type Code";
        PoolLedgerEntry."Grower Code":=Ctx."Grower Code";
        PoolLedgerEntry."Grower No.":=GrowerNo;
        PoolLedgerEntry."Item No.":=Ctx."Source Item No.";
        PoolLedgerEntry."UOM Code":=Ctx."UOM Code";
        PoolLedgerEntry.Amount:=Amount;
        PoolLedgerEntry."VAT Amount":=GSTAmount;
        PoolLedgerEntry."Transaction Date":=Ctx."Transaction Date";
        PoolLedgerEntry."Posting Date":=Ctx."Posting Date";
        PoolLedgerEntry."Source Document No.":=Ctx."Source Document No.";
        PoolLedgerEntry."Source Line No.":=Ctx."Source Line No.";
        PoolLedgerEntry."Source Type":=Ctx."Source Type";
        PoolLedgerEntry."Source System ID":=Ctx."Source System ID";
        PoolLedgerEntry."Pool Payment ID":=Ctx."Pool Payment ID";
        PoolLedgerEntry."Product Code":=Ctx."Source Item No.";
        SetDocumentFieldsFromSource(PoolLedgerEntry, Ctx);
        PoolLedgerEntry.Insert(true);
    end;
    local procedure SetDocumentFieldsFromSource(var PoolLedgerEntry: Record "TAC Pool Ledger Entry"; var Ctx: Record "TAC Pool Charge Context" temporary)
    begin
        PoolLedgerEntry."Document No.":=Ctx."Source Document No.";
        case Ctx."Source Type" of Ctx."Source Type"::"Production Output": PoolLedgerEntry."Document Type":=PoolLedgerEntry."Document Type"::"Run Close";
        Ctx."Source Type"::"Sales Invoice", Ctx."Source Type"::"Sales Credit Memo": PoolLedgerEntry."Document Type":=PoolLedgerEntry."Document Type"::"Sales Invoice";
        Ctx."Source Type"::Consignment: begin
            PoolLedgerEntry."Document Type":=PoolLedgerEntry."Document Type"::Consignment;
            PoolLedgerEntry."Source Consignment No.":=Ctx."Source Document No.";
        end;
        else
            PoolLedgerEntry."Document Type":=PoolLedgerEntry."Document Type"::Manual;
        end;
    end;
    local procedure EnsureMandatoryTransTypesAreConfigured(ChargeAction: Enum "TAC Pool Charge Action")
    var
        TransType: Record "TAC Pool Trans Type";
        Template: Record "TAC Pool Charge Template";
    begin
        TransType.SetRange(Active, true);
        TransType.SetRange(Mandatory, true);
        TransType.SetRange("Charge Action", ChargeAction);
        if TransType.FindSet()then repeat Template.Reset();
                Template.SetRange("Trans Type Code", TransType.Code);
                Template.SetRange("Charge Action", ChargeAction);
                Template.SetRange(Active, true);
                Template.SetFilter("Rate Type", '<>%1', Template."Rate Type"::Bin);
                if Template.IsEmpty()then Error(MissingMandatoryTemplateErr, TransType.Code);
            until TransType.Next() = 0;
    end;
    local procedure ValidateTemplateDefinition(var Template: Record "TAC Pool Charge Template"; var TransType: Record "TAC Pool Trans Type")
    begin
        if(Template."Rate Type" <> TransType."Charge Rate Type") or (Template."Rate Source" <> TransType."Rate Source")then Error(RateDefinitionErr, Template.ID, TransType.Code);
    end;
    local procedure ChargeAlreadyPosted(PoolCode: Code[20]; TransTypeCode: Code[10]; SourceDocumentNo: Code[20]; SourceLineNo: Integer): Boolean var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        if SourceDocumentNo = '' then exit(false);
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Source Document No.", SourceDocumentNo);
        PoolLedgerEntry.SetRange("Source Line No.", SourceLineNo);
        PoolLedgerEntry.SetRange("Trans Type Code", TransTypeCode);
        exit(not PoolLedgerEntry.IsEmpty());
    end;
    /// <summary>
    /// Resolve the per-row rate by Rate Source (§2.6). Fixed = row rate;
    /// Customer = a Customer field; Calculated = FR (handled in F-07, returns 0
    /// here); System = no rate.
    /// </summary>
    procedure ResolveRate(var Template: Record "TAC Pool Charge Template"; var Ctx: Record "TAC Pool Charge Context" temporary): Decimal var
        Customer: Record Customer;
        RipeningPrice: Record "TAC Ripening Price";
    begin
        case Template."Rate Source" of Template."Rate Source"::Fixed: exit(Template.Rate);
        Template."Rate Source"::Customer: begin
            if Ctx."Customer No." = '' then exit(0);
            //if not Customer.Get(Ctx."Customer No.") then
            //exit(0);
            // Ripener charges (Ripener Required Filter = Y) read the
            // Ripening Rate; all other Customer-source charges
            // (SR/WR/DR) read the Default Settlement Rebate Rate.
            //if Template."Ripener Required Filter" = Template."Ripener Required Filter"::Y then
            //exit(Customer."Ripening Rate");
            RipeningPrice.SetRange("Customer No.", Ctx."Customer No.");
            RipeningPrice.SetRange("Item No.", Ctx."Source Item No.");
            RipeningPrice.SetRange("Unit of Measure Code", Ctx."UOM Code");
            RipeningPrice.SetRange(Active, true);
            RipeningPrice.FindLast();
            exit(RipeningPrice."Unit Price");
        end;
        Template."Rate Source"::Calculated: exit(0); // FR — computed in the close (OI-04).
        Template."Rate Source"::System: exit(0);
        end;
    end;
    local procedure MeasureBase(RateType: Enum "TAC Pool Rate Type"; var Ctx: Record "TAC Pool Charge Context" temporary): Decimal begin
        case RateType of RateType::Kg: exit(Ctx.Kgs);
        RateType::Unit: exit(Ctx.Units);
        RateType::Value: exit(Ctx.Value);
        else
            exit(0); // Calc / System carry no simple multiplier base.
        end;
    end;
    local procedure SupplierTypeLetter(SupplierType: Enum "TAC Grower Pool Type"): Code[10]begin
        case SupplierType of SupplierType::Internal: exit('I');
        SupplierType::External: exit('E');
        SupplierType::"Contract Pack": exit('G');
        end;
    end;
    local procedure GrowerTypeLetter(GrowerType: Enum "TAC Grower Type"): Code[10]begin
        case GrowerType of GrowerType::Internal: exit('I');
        GrowerType::External: exit('E');
        GrowerType::"Contract Pack": exit('G');
        GrowerType::Consolidator: exit('C');
        GrowerType::"Fixed FruitBank": exit('F');
        end;
    end;
}
