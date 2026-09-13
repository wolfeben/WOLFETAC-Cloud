codeunit 50280 "TAC Pool Grower Mgt"
{
    // The grower key used throughout the engine is a value of the grower
    // Dimension. This codeunit turns one into a Vendor, for the single boundary
    // that needs one: the grower Purchase Invoice (50279, close step 11).
    //
    // The mapping is the vendor's own Default Dimension for that dimension —
    // i.e. the grower code set on the Vendor card. Both sides of the comparison
    // are therefore Dimension Value codes drawn from one list, so the match is
    // exact with no normalisation.
    //
    // A grower code identifies exactly one vendor; a second match is a
    // master-data fault, not something to disambiguate here (ADR-004).
    //
    // WHICH dimension is the grower dimension belongs to 50276, which owns all
    // seven configured pool dimension codes.
    var DimensionMgt: Codeunit "TAC Pool Dimension Mgt";
    VendorNoCache: Dictionary of[Code[20], Code[20]];
    BlankGrowerErr: Label 'A blank Grower Code cannot be resolved to a vendor.';
    NoVendorErr: Label 'Grower %1 has no vendor. Set the %2 dimension to %1 on the grower''s vendor card.', Comment = '%1 = Grower Code, %2 = Grower Dimension Code';
    NoGrowerOnVendorErr: Label 'Vendor %1 has no %2 default dimension. Set the Grower Code on the vendor card before consuming the received lot.', Comment = '%1 = Vendor No., %2 = Grower Dimension Code';
    AmbiguousVendorErr: Label 'Grower %1 maps to more than one vendor (%2 and %3). A grower code must identify exactly one vendor.', Comment = '%1 = Grower Code, %2 = first Vendor No., %3 = second Vendor No.';
    UnknownGrowerErr: Label 'Grower %1 is not a value of the %2 dimension.', Comment = '%1 = Grower Code, %2 = Grower Dimension Code';
    /// <summary>
    /// The Vendor No. carrying this grower code as its default grower
    /// dimension. Errors when the grower has no vendor — a close cannot pay a
    /// grower it cannot identify.
    /// </summary>
    procedure VendorNoForGrower(GrowerCode: Code[20]): Code[20]var
        VendorNo: Code[20];
    begin
        if GrowerCode = '' then Error(BlankGrowerErr);
        if not FindVendorNoForGrower(GrowerCode, VendorNo)then Error(NoVendorErr, GrowerCode, DimensionMgt.GrowerDimensionCode());
        exit(VendorNo);
    end;
    /// <summary>
    /// Resolve without erroring on a missing vendor, so the close's validate
    /// pass can name the unmapped grower itself. An ambiguous code still
    /// errors — the caller cannot resolve that.
    /// </summary>
    procedure FindVendorNoForGrower(GrowerCode: Code[20]; var VendorNo: Code[20]): Boolean begin
        VendorNo:='';
        if GrowerCode = '' then exit(false);
        // Cached for the life of this codeunit instance: the close resolves the
        // same growers repeatedly (the V7 pass, then one invoice each).
        if not VendorNoCache.ContainsKey(GrowerCode)then VendorNoCache.Set(GrowerCode, FindVendorNo(GrowerCode));
        VendorNo:=VendorNoCache.Get(GrowerCode);
        exit(VendorNo <> '');
    end;
    /// <summary>Returns the configured Grower dimension value on a vendor card.</summary>
    procedure GrowerCodeForVendor(VendorNo: Code[20]): Code[20]var
        DefaultDimension: Record "Default Dimension";
        GrowerCode: Code[20];
    begin
        if not DefaultDimension.Get(Database::Vendor, VendorNo, DimensionMgt.GrowerDimensionCode())then Error(NoGrowerOnVendorErr, VendorNo, DimensionMgt.GrowerDimensionCode());
        GrowerCode:=DefaultDimension."Dimension Value Code";
        ValidateGrowerCode(GrowerCode);
        if GrowerCode = '' then Error(NoGrowerOnVendorErr, VendorNo, DimensionMgt.GrowerDimensionCode());
        exit(GrowerCode);
    end;
    local procedure FindVendorNo(GrowerCode: Code[20])FoundVendorNo: Code[20]var
        DefaultDimension: Record "Default Dimension";
    begin
        DefaultDimension.SetRange("Table ID", Database::Vendor);
        DefaultDimension.SetRange("Dimension Code", DimensionMgt.GrowerDimensionCode());
        DefaultDimension.SetRange("Dimension Value Code", GrowerCode);
        if not DefaultDimension.FindSet()then exit('');
        FoundVendorNo:=CopyStr(DefaultDimension."No.", 1, MaxStrLen(FoundVendorNo));
        if DefaultDimension.Next() <> 0 then Error(AmbiguousVendorErr, GrowerCode, FoundVendorNo, DefaultDimension."No.");
    end;
    /// <summary>
    /// Look up a grower code from the grower dimension's values. Used by the
    /// hand-entry tables, which cannot carry a static TableRelation because the
    /// dimension is configuration.
    /// </summary>
    procedure LookupGrowerCode(var GrowerCode: Code[20]): Boolean var
        DimensionValue: Record "Dimension Value";
    begin
        DimensionValue.SetRange("Dimension Code", DimensionMgt.GrowerDimensionCode());
        if DimensionValue.Get(DimensionMgt.GrowerDimensionCode(), GrowerCode)then;
        if Page.RunModal(Page::"Dimension Values", DimensionValue) <> Action::LookupOK then exit(false);
        GrowerCode:=DimensionValue.Code;
        exit(true);
    end;
    /// <summary>Errors unless the code is a value of the grower dimension. Blank is allowed (pool-level rows carry no grower).</summary>
    procedure ValidateGrowerCode(GrowerCode: Code[20])
    var
        DimensionValue: Record "Dimension Value";
    begin
        if GrowerCode = '' then exit;
        if not DimensionValue.Get(DimensionMgt.GrowerDimensionCode(), GrowerCode)then Error(UnknownGrowerErr, GrowerCode, DimensionMgt.GrowerDimensionCode());
    end;
    /// <summary>Drop the cached resolutions and the cached dimension setup — for tests and long-running sessions.</summary>
    procedure ClearCache()
    begin
        Clear(VendorNoCache);
        DimensionMgt.ClearCache();
    end;
}
