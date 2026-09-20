codeunit 50276 "TAC Pool Dimension Mgt"
{
    // AL-16: resolves Season / Pool Week / Variety / Grade / Size (+ Grower and
    // Grower Pool Type) for a pooling source by reading its Dimension Set.
    //
    // This codeunit also owns WHICH dimension is which. All seven codes are TAC
    // configuration on Pool Payment Setup, never literals: dimension names
    // differ per tenant (the grower dimension is "Grower Code" here, not
    // "GROWER") and a wrong literal resolves to blank silently — collapsing
    // every pool into one, or leaving a Pool Group with no week (ADR-004).
    //
    // The getters error when their code is unset, so an unconfigured system
    // fails at the source rather than pooling into nothing. The one exception
    // is HasPoolDimensions — see its comment.
    var PoolSetup: Record "TAC Pool Setup";
    SetupRead: Boolean;
    DimensionNotSetErr: Label 'The %1 is not set on Pool Payment Setup. Set the pool dimension codes before pooling.', Comment = '%1 = the setup field caption, e.g. Variety Dimension Code';
    DimensionValueMissingErr: Label 'The pool source is missing a value for %1. Complete the source-line dimensions before posting.', Comment = '%1 = configured Pool Setup field caption';
    GrowerPoolTypeValueErr: Label 'Grower Pool Type dimension value %1 is invalid. Use I, E or G.', Comment = '%1 = dimension value';
    procedure ResolveFromProductionOrder(var ProductionOrder: Record "Production Order"; //var SeasonCode: Code[20]; var PoolWeekCode: Code[20]; 
    var VarietyCode: Code[20]; var GradeCode: Code[20]; var SizeCode: Code[20]; var GrowerCode: Code[20]; var GrowerPoolType: Enum "TAC Grower Pool Type")
    begin
        ResolveFromDimensionSet(ProductionOrder."Dimension Set ID", //SeasonCode, //PoolWeekCode, 
 VarietyCode, GradeCode, SizeCode, //GrowerCode, 
 GrowerPoolType);
        ProductionOrder.CalcFields("Grower ID");
        GrowerCode:=ProductionOrder."Grower ID";
    end;
    procedure ResolveFromDimensionSet(DimensionSetID: Integer; //var SeasonCode: Code[20];
    //var PoolWeekCode: Code[20];
    var VarietyCode: Code[20]; var GradeCode: Code[20]; var SizeCode: Code[20]; //var GrowerCode: Code[20];
    var GrowerPoolType: Enum "TAC Grower Pool Type")
    begin
        //SeasonCode := GetDimensionValue(DimensionSetID, SeasonDimensionCode());
        //PoolWeekCode := GetDimensionValue(DimensionSetID, PoolWeekDimensionCode());
        VarietyCode:=GetDimensionValue(DimensionSetID, VarietyDimensionCode());
        GradeCode:=GetDimensionValue(DimensionSetID, GradeDimensionCode());
        SizeCode:=GetDimensionValue(DimensionSetID, SizeDimensionCode());
        //GrowerCode := GetDimensionValue(DimensionSetID, GrowerDimensionCode());
        GrowerPoolType:=MapGrowerPoolType(GetDimensionValue(DimensionSetID, GrowerPoolTypeDimensionCode()));
    end;
    /// <summary>Resolves all pool matching attributes from a production output line.</summary>
    procedure ResolveFromProductionOrderLine(var ProductionOrderLine: Record "Prod. Order Line"; //var SeasonCode: Code[20]; var PoolWeekCode: Code[20]; 
    var VarietyCode: Code[20]; var GradeCode: Code[20]; var SizeCode: Code[20]; //var GrowerCode: Code[20]; 
 var GrowerPoolType: Enum "TAC Grower Pool Type"; var PackTypeCode: Code[20]; var PackTypeCategoryCode: Code[20])
    begin
        //ResolveFromDimensionSetWithPacking(ProductionOrderLine."Dimension Set ID", SeasonCode, PoolWeekCode, VarietyCode, GradeCode, SizeCode, GrowerCode, GrowerPoolType, PackTypeCode, PackTypeCategoryCode);
        ResolveFromDimensionSetWithPacking(ProductionOrderLine."Dimension Set ID", //SeasonCode, //PoolWeekCode, 
 VarietyCode, GradeCode, SizeCode, //GrowerCode, 
 GrowerPoolType, PackTypeCode, PackTypeCategoryCode);
    end;
    /// <summary>Resolves all pool matching attributes from one source dimension set.</summary>
    procedure ResolveFromDimensionSetWithPacking(DimensionSetID: Integer; //var SeasonCode: Code[20]; 
    //var PoolWeekCode: Code[20]; 
    var VarietyCode: Code[20]; var GradeCode: Code[20]; var SizeCode: Code[20]; //var GrowerCode: Code[20];
    var GrowerPoolType: Enum "TAC Grower Pool Type"; var PackTypeCode: Code[20]; var PackTypeCategoryCode: Code[20])
    begin
        //ResolveFromDimensionSet(DimensionSetID, SeasonCode, PoolWeekCode, VarietyCode, GradeCode, SizeCode, GrowerCode, GrowerPoolType);
        ResolveFromDimensionSet(DimensionSetID, //SeasonCode, //PoolWeekCode, 
 VarietyCode, GradeCode, SizeCode, //GrowerCode, 
 GrowerPoolType);
        PackTypeCode:=GetDimensionValue(DimensionSetID, PackTypeDimensionCode());
        PackTypeCategoryCode:=GetDimensionValue(DimensionSetID, PackTypeCategoryDimensionCode());
    end;
    /// <summary>Ensures an identified pooling source has every configured matching attribute.</summary>
    procedure ValidatePoolDimensionValues(DimensionSetID: Integer)
    begin
        //ValidateDimensionValue(DimensionSetID, SeasonDimensionCode(), PoolSetup.FieldCaption("Season Dimension Code"));
        //ValidateDimensionValue(DimensionSetID, PoolWeekDimensionCode(), PoolSetup.FieldCaption("Pool Week Dimension Code"));
        ValidateDimensionValue(DimensionSetID, VarietyDimensionCode(), PoolSetup.FieldCaption("Variety Dimension Code"));
        ValidateDimensionValue(DimensionSetID, GradeDimensionCode(), PoolSetup.FieldCaption("Grade Dimension Code"));
        ValidateDimensionValue(DimensionSetID, SizeDimensionCode(), PoolSetup.FieldCaption("Size Dimension Code"));
        ValidateDimensionValue(DimensionSetID, GrowerDimensionCode(), PoolSetup.FieldCaption("Grower Dimension Code"));
        ValidateDimensionValue(DimensionSetID, GrowerPoolTypeDimensionCode(), PoolSetup.FieldCaption("Grower Pool Type Dim. Code"));
        ValidateDimensionValue(DimensionSetID, PackTypeDimensionCode(), PoolSetup.FieldCaption("Pack Type Dimension Code"));
        ValidateDimensionValue(DimensionSetID, PackTypeCategoryDimensionCode(), PoolSetup.FieldCaption("Pack Type Category Dim. Code"));
    end;
    /// <summary>True when the dimension set carries pool dimensions (a Variety).</summary>
    procedure HasPoolDimensions(DimensionSetID: Integer): Boolean begin
        // Deliberately does NOT error on incomplete setup. This is a probe run
        // against every settled sales invoice, including invoices that have
        // nothing to do with pooling; erroring here would block unrelated
        // customer payments company-wide. Unconfigured means "cannot tell" —
        // treat the line as not a pool line. The production-order path is
        // narrower (it is already behind the PKD- gate) and does error.
        if not DimensionSetupComplete()then exit(false);
        exit(GetDimensionValue(DimensionSetID, VarietyDimensionCode()) <> '');
    end;
    procedure GetDimensionValue(DimensionSetID: Integer; DimensionCode: Code[20]): Code[20]var
        DimSetEntry: Record "Dimension Set Entry";
    begin
        if DimSetEntry.Get(DimensionSetID, DimensionCode)then exit(DimSetEntry."Dimension Value Code");
        exit('');
    end;
    procedure MapGrowerPoolType(DimensionValue: Code[20]): Enum "TAC Grower Pool Type" begin
        // A source value is authoritative. Defaulting an unknown value to
        // Internal would place charges and revenue in the wrong pool group.
        case UpperCase(DimensionValue)of 'I': exit(Enum::"TAC Grower Pool Type"::Internal);
        'E': exit(Enum::"TAC Grower Pool Type"::External);
        'G': exit(Enum::"TAC Grower Pool Type"::"Contract Pack");
        else
            Error(GrowerPoolTypeValueErr, DimensionValue);
        end;
    end;
    // --- configured dimension codes ---
    procedure SeasonDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Season Dimension Code", PoolSetup.FieldCaption("Season Dimension Code")));
    end;
    procedure PoolWeekDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Pool Week Dimension Code", PoolSetup.FieldCaption("Pool Week Dimension Code")));
    end;
    procedure VarietyDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Variety Dimension Code", PoolSetup.FieldCaption("Variety Dimension Code")));
    end;
    procedure GradeDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Grade Dimension Code", PoolSetup.FieldCaption("Grade Dimension Code")));
    end;
    procedure SizeDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Size Dimension Code", PoolSetup.FieldCaption("Size Dimension Code")));
    end;
    procedure GrowerDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Grower Dimension Code", PoolSetup.FieldCaption("Grower Dimension Code")));
    end;
    /// <summary>Gets the configured grower dimension without erroring when setup is incomplete.</summary>
    procedure GetConfiguredGrowerDimensionCode(var GrowerDimensionCode: Code[20]): Boolean begin
        GetSetup();
        GrowerDimensionCode:=PoolSetup."Grower Dimension Code";
        exit(GrowerDimensionCode <> '');
    end;
    procedure GrowerPoolTypeDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Grower Pool Type Dim. Code", PoolSetup.FieldCaption("Grower Pool Type Dim. Code")));
    end;
    procedure PackTypeDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Pack Type Dimension Code", PoolSetup.FieldCaption("Pack Type Dimension Code")));
    end;
    procedure PackTypeCategoryDimensionCode(): Code[20]begin
        GetSetup();
        exit(RequiredCode(PoolSetup."Pack Type Category Dim. Code", PoolSetup.FieldCaption("Pack Type Category Dim. Code")));
    end;
    /// <summary>True when all nine pool dimensions are configured. Never errors.</summary>
    procedure DimensionSetupComplete(): Boolean begin
        GetSetup();
        exit((PoolSetup."Season Dimension Code" <> '') and (PoolSetup."Pool Week Dimension Code" <> '') and (PoolSetup."Variety Dimension Code" <> '') and (PoolSetup."Grade Dimension Code" <> '') and (PoolSetup."Size Dimension Code" <> '') and (PoolSetup."Grower Dimension Code" <> '') and (PoolSetup."Grower Pool Type Dim. Code" <> '') and (PoolSetup."Pack Type Dimension Code" <> '') and (PoolSetup."Pack Type Category Dim. Code" <> ''));
    end;
    /// <summary>Drop the cached setup — for tests and long-running sessions.</summary>
    procedure ClearCache()
    begin
        Clear(PoolSetup);
        SetupRead:=false;
    end;
    local procedure GetSetup()
    begin
        // Read once per instance: the resolve path touches seven codes per
        // pooling source, and the callers hold this codeunit for one document.
        if SetupRead then exit;
        if not PoolSetup.Get()then PoolSetup.Init();
        SetupRead:=true;
    end;
    local procedure RequiredCode(DimensionCode: Code[20]; SetupFieldCaption: Text): Code[20]begin
        if DimensionCode = '' then Error(DimensionNotSetErr, SetupFieldCaption);
        exit(DimensionCode);
    end;
    local procedure ValidateDimensionValue(DimensionSetID: Integer; DimensionCode: Code[20]; SetupFieldCaption: Text)
    begin
        if GetDimensionValue(DimensionSetID, DimensionCode) = '' then Error(DimensionValueMissingErr, SetupFieldCaption);
    end;
}
