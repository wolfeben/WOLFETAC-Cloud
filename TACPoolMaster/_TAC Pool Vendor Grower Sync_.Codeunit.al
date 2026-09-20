codeunit 50286 "TAC Pool Vendor Grower Sync"
{
    // TAC Grower Code is a display/integration field owned by Avocados Core.
    // Its value must mirror the Vendor Default Dimension selected by Pool
    // Payment Setup, never be independently maintained by the user.

    procedure SyncVendor(var Vendor: Record Vendor)
    var
        DefaultDimension: Record "Default Dimension";
        GrowerDimensionCode: Code[20];
        GrowerCode: Code[20];
    begin
        GrowerDimensionCode := ConfiguredGrowerDimensionCode();
        if GrowerDimensionCode = '' then
            GrowerCode := ''
        else
            if DefaultDimension.Get(Database::Vendor, Vendor."No.", GrowerDimensionCode) then
                GrowerCode := DefaultDimension."Dimension Value Code";

        if Vendor."TAC Grower Code" = GrowerCode then
            exit;
        Vendor."TAC Grower Code" := GrowerCode;
        Vendor.Modify(true);
    end;

    procedure SyncVendorNo(VendorNo: Code[20])
    var
        Vendor: Record Vendor;
    begin
        if Vendor.Get(VendorNo) then
            SyncVendor(Vendor);
    end;

    procedure SyncAllVendors()
    var
        Vendor: Record Vendor;
    begin
        if Vendor.FindSet() then
            repeat
                SyncVendor(Vendor);
            until Vendor.Next() = 0;
    end;

    procedure SyncFromDefaultDimension(DefaultDimension: Record "Default Dimension")
    var
        GrowerDimensionCode: Code[20];
    begin
        if DefaultDimension."Table ID" <> Database::Vendor then
            exit;
        GrowerDimensionCode := ConfiguredGrowerDimensionCode();
        if GrowerDimensionCode = '' then
            exit;
        if DefaultDimension."Dimension Code" <> GrowerDimensionCode then
            exit;
        SyncVendorNo(DefaultDimension."No.");
    end;

    local procedure ConfiguredGrowerDimensionCode(): Code[20]
    var
        PoolSetup: Record "TAC Pool Setup";
    begin
        if not PoolSetup.Get() then
            exit('');
        exit(PoolSetup."Grower Dimension Code");
    end;
}
