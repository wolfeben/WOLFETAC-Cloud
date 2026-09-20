codeunit 50283 "TAC Pool Preview"
{
    procedure ShowPreview(ProductionOrderNo: Code[20])
    var
        Preview: Record "TAC Pool Charge Preview" temporary;
    begin
        BuildPreview(ProductionOrderNo, Preview);
        Page.RunModal(Page::"TAC Pool Charge Preview", Preview);
    end;

    procedure BuildPreview(ProductionOrderNo: Code[20]; var Preview: Record "TAC Pool Charge Preview" temporary)
    var
        ProductionOrder: Record "Production Order";
        ProductionOrderLine: Record "Prod. Order Line";
    begin
        Preview.Reset();
        Preview.DeleteAll();
        if not FindProductionOrder(ProductionOrderNo, ProductionOrder) then begin
            AddSimpleIssue(Preview, ProductionOrderNo, 0, '', Preview.Severity::Blocking, 'Production order does not exist.');
            exit;
        end;

        ProductionOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if not ProductionOrderLine.FindSet() then begin
            AddSimpleIssue(Preview, ProductionOrder."No.", 0, '', Preview.Severity::Warning, 'The order has no production lines.');
            exit;
        end;
        repeat
            PreviewLine(ProductionOrder, ProductionOrderLine, Preview);
        until ProductionOrderLine.Next() = 0;
    end;

    local procedure PreviewLine(var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line"; var Preview: Record "TAC Pool Charge Preview" temporary)
    var
        PoolProdOrderPost: Codeunit "TAC Pool Prod Order Post";
        ChargeEngine: Codeunit "TAC Pool Charge Engine";
        Evaluation: Record "TAC Pool Charge Evaluation" temporary;
        ChargeContext: Record "TAC Pool Charge Context" temporary;
        OutputItemNo: Code[20];
        Season: Code[20];
        PoolWeek: Code[20];
        Variety: Code[20];
        Grade: Code[20];
        Size: Code[20];
        GrowerCode: Code[20];
        PackType: Code[20];
        PackTypeCategory: Code[20];
        PoolGroupCode: Code[20];
        PoolCode: Code[20];
        GrowerPoolType: Enum "TAC Grower Pool Type";
        PoolGroupID: Integer;
        Kgs: Decimal;
        Units: Decimal;
        HasBlockingIssue: Boolean;
        ChargeTotal: Decimal;
        AlreadyTR: Boolean;
    begin
        PoolProdOrderPost.GetPackedLineQuantities(ProductionOrder."No.", ProductionOrderLine."Line No.", Kgs, Units, OutputItemNo);
        AddLine(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, '', 0, '', '', '', '', '', '', Enum::"TAC Grower Pool Type"::Internal, '', '', Units, Kgs);
        if not PoolProdOrderPost.GetPackedOutputLine(ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo) then begin
            AddSimpleIssue(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, Preview.Severity::Information, 'Will not pool: this line has no posted packed output.');
            exit;
        end;
        if not PoolProdOrderPost.IsOriginalPackRun(ProductionOrder."No.") then begin
            AddSimpleIssue(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, Preview.Severity::Information, 'Will not pool: the order has no consumed configured bin input (repack guard).');
            exit;
        end;
        if Units <= 0 then begin
            AddSimpleIssue(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, Preview.Severity::Blocking, 'Packed output resolves to zero units. Check item unit-of-measure conversions.');
            exit;
        end;

        HasBlockingIssue := not ResolveDimensions(ProductionOrderLine."Dimension Set ID", Season, PoolWeek, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, Units, Kgs, Preview);
        if HasBlockingIssue then
            exit;
        if not ResolveTarget(PoolWeek, GrowerPoolType, Variety, Grade, Size, PoolGroupID, PoolGroupCode, PoolCode, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, Season, GrowerCode, PackType, PackTypeCategory, Units, Kgs, Preview) then
            exit;

        UpdateLineDetails(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", PoolGroupID, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory);

        AlreadyTR := LedgerEntryExists(PoolCode, ProductionOrder."No.", ProductionOrderLine."Line No.", 'TR');
        AddTransaction(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, PoolGroupID, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, 'TR', 0, Enum::"TAC Pool Rate Source"::System, Enum::"TAC Pool Rate Type"::System, 0, 0, 0, AlreadyTR, 'Transfer receipt');

        BuildContext(ChargeContext, ProductionOrder, ProductionOrderLine, OutputItemNo, PoolCode, PoolGroupID, GrowerCode, GrowerPoolType, Variety, Grade, Size, PackType, PackTypeCategory, Units, Kgs);
        ChargeEngine.EvaluateCharges(Enum::"TAC Pool Charge Action"::RunClose, ChargeContext, Evaluation);
        if Evaluation.FindSet() then
            repeat
                case Evaluation.Result of
                    Evaluation.Result::Expected:
                        begin
                            ChargeTotal += Evaluation."Expected Amount";
                            AddTransaction(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, PoolGroupID, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Evaluation."Trans Type Code", Evaluation."Template ID", Evaluation."Rate Source", Evaluation."Rate Type", Evaluation.Rate, Evaluation."Expected Amount", Evaluation."GST Amount", LedgerEntryExists(PoolCode, ProductionOrder."No.", ProductionOrderLine."Line No.", Evaluation."Trans Type Code"), Evaluation.Details);
                        end;
                    Evaluation.Result::Calculated:
                        AddIssue(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Information, StrSubstNo('%1 is calculated freight and is not a Run Close transaction.', Evaluation."Trans Type Code"));
                    else
                        if Evaluation.Mandatory then
                            AddIssue(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Blocking, Evaluation.Details)
                        else
                            AddIssue(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", OutputItemNo, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Warning, Evaluation.Details);
                end;
            until Evaluation.Next() = 0;
        UpdateLineChargeTotal(Preview, ProductionOrder."No.", ProductionOrderLine."Line No.", ChargeTotal);
    end;

    local procedure ResolveDimensions(DimensionSetID: Integer; var Season: Code[20]; var PoolWeek: Code[20]; var Variety: Code[20]; var Grade: Code[20]; var Size: Code[20]; var GrowerCode: Code[20]; var GrowerPoolType: Enum "TAC Grower Pool Type"; var PackType: Code[20]; var PackTypeCategory: Code[20]; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; Units: Decimal; Kgs: Decimal; var Preview: Record "TAC Pool Charge Preview" temporary): Boolean
    var
        Setup: Record "TAC Pool Setup";
        DimSetEntry: Record "Dimension Set Entry";
        PoolTypeValue: Code[20];
        Complete: Boolean;
    begin
        if not Setup.Get() then begin
            AddSimpleIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Preview.Severity::Blocking, 'Pool setup does not exist.');
            exit(false);
        end;
        Complete := true;
        Season := ReadDimension(DimSetEntry, DimensionSetID, Setup."Season Dimension Code", 'Season', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        PoolWeek := ReadDimension(DimSetEntry, DimensionSetID, Setup."Pool Week Dimension Code", 'Pool Week', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        Variety := ReadDimension(DimSetEntry, DimensionSetID, Setup."Variety Dimension Code", 'Variety', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        Grade := ReadDimension(DimSetEntry, DimensionSetID, Setup."Grade Dimension Code", 'Grade', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        Size := ReadDimension(DimSetEntry, DimensionSetID, Setup."Size Dimension Code", 'Size', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        GrowerCode := ReadDimension(DimSetEntry, DimensionSetID, Setup."Grower Dimension Code", 'Grower', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        PoolTypeValue := ReadDimension(DimSetEntry, DimensionSetID, Setup."Grower Pool Type Dim. Code", 'Grower Pool Type', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        PackType := ReadDimension(DimSetEntry, DimensionSetID, Setup."Pack Type Dimension Code", 'Pack Type', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        PackTypeCategory := ReadDimension(DimSetEntry, DimensionSetID, Setup."Pack Type Category Dim. Code", 'Pack Type Category', Complete, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Units, Kgs, Preview);
        if not Complete then
            exit(false);
        case UpperCase(PoolTypeValue) of
            'I':
                GrowerPoolType := GrowerPoolType::Internal;
            'E':
                GrowerPoolType := GrowerPoolType::External;
            'G':
                GrowerPoolType := GrowerPoolType::"Contract Pack";
            else begin
                AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, '', '', PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Blocking, 'Grower Pool Type must be I, E or G.');
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ReadDimension(var DimSetEntry: Record "Dimension Set Entry"; DimensionSetID: Integer; DimensionCode: Code[20]; DimensionName: Text; var Complete: Boolean; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; Units: Decimal; Kgs: Decimal; var Preview: Record "TAC Pool Charge Preview" temporary): Code[20]
    begin
        if DimensionCode = '' then begin
            Complete := false;
            AddSimpleIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Preview.Severity::Blocking, StrSubstNo('%1 dimension code is not configured.', DimensionName));
            exit('');
        end;
        if not DimSetEntry.Get(DimensionSetID, DimensionCode) or (DimSetEntry."Dimension Value Code" = '') then begin
            Complete := false;
            AddSimpleIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, Preview.Severity::Blocking, StrSubstNo('%1 is blank on the production order line.', DimensionName));
            exit('');
        end;
        exit(DimSetEntry."Dimension Value Code");
    end;

    local procedure ResolveTarget(PoolWeekCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; var PoolGroupID: Integer; var PoolGroupCode: Code[20]; var PoolCode: Code[20]; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; Season: Code[20]; GrowerCode: Code[20]; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal; var Preview: Record "TAC Pool Charge Preview" temporary): Boolean
    var
        PoolWeek: Record "TAC Pool Week";
        PoolGroup: Record "TAC Pool Group Header";
        Pool: Record "TAC Pool";
        PoolPrototype: Record "TAC Pool" temporary;
    begin
        if not PoolWeek.Get(CopyStr(PoolWeekCode, 1, MaxStrLen(PoolWeek.Code))) then begin
            AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, '', '', PoolWeekCode, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Blocking, StrSubstNo('Pool Week %1 is not configured.', PoolWeekCode));
            exit(false);
        end;
        PoolPrototype."Season Code" := PoolWeek."Season Code";
        PoolPrototype."Pool Week" := PoolWeek."Week No.";
        PoolPrototype."Pool Type" := GrowerPoolType;
        PoolPrototype."Variety Code" := CopyStr(Variety, 1, MaxStrLen(PoolPrototype."Variety Code"));
        PoolCode := PoolPrototype.GetPoolCode();
        PoolGroup.SetRange("Pool Week Code", CopyStr(PoolWeekCode, 1, MaxStrLen(PoolGroup."Pool Week Code")));
        PoolGroup.SetRange("Grower Pool Type", GrowerPoolType);
        if PoolGroup.FindFirst() then begin
            PoolGroupID := PoolGroup."Pool Group ID";
            PoolGroupCode := PoolGroup."Pool Group Code";
            if PoolGroup.Status <> PoolGroup.Status::Open then begin
                AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, PoolGroupCode, PoolCode, PoolWeekCode, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Blocking, 'The target Pool Group is not Open.');
                exit(false);
            end;
            Pool.SetRange("Pool Group ID", PoolGroupID);
            Pool.SetRange("Variety Code", CopyStr(Variety, 1, MaxStrLen(Pool."Variety Code")));
            Pool.SetRange("Grade Code", CopyStr(Grade, 1, MaxStrLen(Pool."Grade Code")));
            Pool.SetRange("Size Code", CopyStr(Size, 1, MaxStrLen(Pool."Size Code")));
            if Pool.FindFirst() then
                PoolCode := Pool."Pool Code"
            else
                AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, PoolGroupCode, PoolCode, PoolWeekCode, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Information, 'The target Pool will be created when the line is posted.');
        end else begin
            PoolGroupCode := CopyStr(StrSubstNo('PG-%1-W%2-%3', PoolWeek."Season Code", PoolWeek."Week No.", CopyStr(Format(GrowerPoolType), 1, 1)), 1, 20);
            AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, PoolGroupCode, PoolCode, PoolWeekCode, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Information, 'The target Pool Group and Pool will be created when the line is posted.');
        end;
        exit(true);
    end;

    local procedure BuildContext(var ChargeContext: Record "TAC Pool Charge Context" temporary; var ProductionOrder: Record "Production Order"; var ProductionOrderLine: Record "Prod. Order Line"; OutputItemNo: Code[20]; PoolCode: Code[20]; PoolGroupID: Integer; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal)
    begin
        ChargeContext.Init();
        ChargeContext."Pool Code" := PoolCode;
        ChargeContext."Pool Group ID" := PoolGroupID;
        ChargeContext."Grower Code" := GrowerCode;
        ChargeContext."Supplier Type" := GrowerPoolType;
        if GrowerPoolType = GrowerPoolType::External then
            ChargeContext."Grower Type" := ChargeContext."Grower Type"::External
        else
            if GrowerPoolType = GrowerPoolType::"Contract Pack" then
                ChargeContext."Grower Type" := ChargeContext."Grower Type"::"Contract Pack"
            else
                ChargeContext."Grower Type" := ChargeContext."Grower Type"::Internal;
        ChargeContext."Variety Code" := CopyStr(Variety, 1, MaxStrLen(ChargeContext."Variety Code"));
        ChargeContext."Grade Code" := CopyStr(Grade, 1, MaxStrLen(ChargeContext."Grade Code"));
        ChargeContext."Size Code" := CopyStr(Size, 1, MaxStrLen(ChargeContext."Size Code"));
        ChargeContext."Pack Type Code" := PackType;
        ChargeContext."Pack Type Category Code" := PackTypeCategory;
        ChargeContext.Units := Units;
        ChargeContext.Kgs := Kgs;
        ChargeContext."Transaction Date" := ProductionOrder."Due Date";
        ChargeContext."Posting Date" := WorkDate();
        ChargeContext."Source Document No." := ProductionOrder."No.";
        ChargeContext."Source Line No." := ProductionOrderLine."Line No.";
        ChargeContext."Source Item No." := OutputItemNo;
        ChargeContext."UOM Code" := ProductionOrderLine."Unit of Measure Code";
        ChargeContext."Source Type" := ChargeContext."Source Type"::"Production Output";
        ChargeContext."Source System ID" := ProductionOrderLine.SystemId;
    end;

    local procedure LedgerEntryExists(PoolCode: Code[20]; SourceDocumentNo: Code[20]; SourceLineNo: Integer; TransTypeCode: Code[10]): Boolean
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolLedgerEntry.SetRange("Pool Code", PoolCode);
        PoolLedgerEntry.SetRange("Source Document No.", SourceDocumentNo);
        PoolLedgerEntry.SetRange("Source Line No.", SourceLineNo);
        PoolLedgerEntry.SetRange("Trans Type Code", TransTypeCode);
        exit(not PoolLedgerEntry.IsEmpty());
    end;

    local procedure FindProductionOrder(ProductionOrderNo: Code[20]; var ProductionOrder: Record "Production Order"): Boolean
    begin
        ProductionOrder.Reset();
        ProductionOrder.SetRange("No.", ProductionOrderNo);
        exit(ProductionOrder.FindFirst());
    end;

    local procedure AddLine(var Preview: Record "TAC Pool Charge Preview" temporary; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; PoolGroupCode: Code[20]; PoolGroupID: Integer; PoolCode: Code[20]; PoolWeek: Code[20]; Season: Code[20]; Variety: Code[20]; Grade: Code[20]; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal)
    begin
        Preview.Init();
        Preview."Entry No." := NextPreviewEntryNo(Preview);
        Preview."Production Order No." := ProductionOrderNo;
        Preview."Production Order Line No." := ProductionOrderLineNo;
        Preview."Row Type" := Preview."Row Type"::Line;
        Preview.Severity := Preview.Severity::Information;
        Preview.Outcome := Preview.Outcome::"Will Pool";
        Preview.Finding := 'Packed production output line.';
        Preview."Output Item No." := OutputItemNo;
        Preview."Pool Group ID" := PoolGroupID;
        Preview."Pool Group Code" := PoolGroupCode;
        Preview."Pool Code" := PoolCode;
        Preview."Pool Week" := PoolWeek;
        Preview.Season := Season;
        Preview.Variety := Variety;
        Preview.Grade := Grade;
        Preview."Grower Code" := GrowerCode;
        Preview."Grower Pool Type" := GrowerPoolType;
        Preview."Pack Type" := PackType;
        Preview."Pack Type Category" := PackTypeCategory;
        Preview.Units := Units;
        Preview.Kgs := Kgs;
        Preview.Insert();
    end;

    local procedure AddTransaction(var Preview: Record "TAC Pool Charge Preview" temporary; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; PoolGroupID: Integer; PoolGroupCode: Code[20]; PoolCode: Code[20]; PoolWeek: Code[20]; Season: Code[20]; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal; TransType: Code[10]; TemplateID: Integer; RateSource: Enum "TAC Pool Rate Source"; RateType: Enum "TAC Pool Rate Type"; Rate: Decimal; Amount: Decimal; GSTAmount: Decimal; AlreadyExists: Boolean; Details: Text)
    begin
        AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, PoolGroupCode, PoolCode, PoolWeek, Season, Variety, Grade, Size, GrowerCode, GrowerPoolType, PackType, PackTypeCategory, Units, Kgs, Preview.Severity::Information, Details);
        Preview."Row Type" := Preview."Row Type"::"Expected Transaction";
        Preview."Transaction Type" := TransType;
        Preview."Template ID" := TemplateID;
        Preview."Rate Source" := RateSource;
        Preview."Rate Type" := RateType;
        Preview.Rate := Rate;
        Preview."Expected Amount" := Amount;
        Preview."GST Amount" := GSTAmount;
        if AlreadyExists then begin
            Preview.Outcome := Preview.Outcome::"Already Pooled";
            Preview.Finding := 'Already pooled; no new entry would be created.';
        end else
            Preview.Outcome := Preview.Outcome::"Will Pool";
        Preview.Modify();
    end;

    local procedure AddIssue(var Preview: Record "TAC Pool Charge Preview" temporary; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; PoolGroupCode: Code[20]; PoolCode: Code[20]; PoolWeek: Code[20]; Season: Code[20]; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; PackType: Code[20]; PackTypeCategory: Code[20]; Units: Decimal; Kgs: Decimal; Severity: Option; Finding: Text)
    begin
        Preview.Init();
        Preview."Entry No." := NextPreviewEntryNo(Preview);
        Preview."Production Order No." := ProductionOrderNo;
        Preview."Production Order Line No." := ProductionOrderLineNo;
        Preview."Row Type" := Preview."Row Type"::Issue;
        Preview.Severity := Severity;
        if Severity = Preview.Severity::Blocking then
            Preview.Outcome := Preview.Outcome::"Needs Attention"
        else
            Preview.Outcome := Preview.Outcome::"Will Not Pool";
        Preview.Finding := Finding;
        Preview."Output Item No." := OutputItemNo;
        Preview."Pool Group Code" := PoolGroupCode;
        Preview."Pool Code" := PoolCode;
        Preview."Pool Week" := PoolWeek;
        Preview.Season := Season;
        Preview.Variety := Variety;
        Preview.Grade := Grade;
        Preview.Size := Size;
        Preview."Grower Code" := GrowerCode;
        Preview."Grower Pool Type" := GrowerPoolType;
        Preview."Pack Type" := PackType;
        Preview."Pack Type Category" := PackTypeCategory;
        Preview.Units := Units;
        Preview.Kgs := Kgs;
        Preview.Insert();
    end;

    local procedure AddSimpleIssue(var Preview: Record "TAC Pool Charge Preview" temporary; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; OutputItemNo: Code[20]; Severity: Option; Finding: Text)
    begin
        AddIssue(Preview, ProductionOrderNo, ProductionOrderLineNo, OutputItemNo, '', '', '', '', '', '', '', '', Enum::"TAC Grower Pool Type"::Internal, '', '', 0, 0, Severity, Finding);
    end;

    local procedure UpdateLineChargeTotal(var Preview: Record "TAC Pool Charge Preview" temporary; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; ChargeTotal: Decimal)
    begin
        Preview.SetRange("Production Order No.", ProductionOrderNo);
        Preview.SetRange("Production Order Line No.", ProductionOrderLineNo);
        if Preview.FindSet() then
            repeat
                Preview."Expected Line Charge Total" := ChargeTotal;
                Preview.Modify();
            until Preview.Next() = 0;
        Preview.Reset();
    end;

    local procedure UpdateLineDetails(var Preview: Record "TAC Pool Charge Preview" temporary; ProductionOrderNo: Code[20]; ProductionOrderLineNo: Integer; PoolGroupID: Integer; PoolGroupCode: Code[20]; PoolCode: Code[20]; PoolWeek: Code[20]; Season: Code[20]; Variety: Code[20]; Grade: Code[20]; Size: Code[20]; GrowerCode: Code[20]; GrowerPoolType: Enum "TAC Grower Pool Type"; PackType: Code[20]; PackTypeCategory: Code[20])
    begin
        Preview.SetRange("Production Order No.", ProductionOrderNo);
        Preview.SetRange("Production Order Line No.", ProductionOrderLineNo);
        Preview.SetRange("Row Type", Preview."Row Type"::Line);
        if Preview.FindFirst() then begin
            Preview."Pool Group ID" := PoolGroupID;
            Preview."Pool Group Code" := PoolGroupCode;
            Preview."Pool Code" := PoolCode;
            Preview."Pool Week" := PoolWeek;
            Preview.Season := Season;
            Preview.Variety := Variety;
            Preview.Grade := Grade;
            Preview.Size := Size;
            Preview."Grower Code" := GrowerCode;
            Preview."Grower Pool Type" := GrowerPoolType;
            Preview."Pack Type" := PackType;
            Preview."Pack Type Category" := PackTypeCategory;
            Preview.Modify();
        end;
        Preview.Reset();
    end;

    local procedure NextPreviewEntryNo(var Preview: Record "TAC Pool Charge Preview" temporary): Integer
    begin
        Preview.Reset();
        if Preview.FindLast() then
            exit(Preview."Entry No." + 1);
        exit(1);
    end;
}
