page 58152 "SAL Facility Pallets API"
{
    PageType = API;
    APIPublisher = 'wolfe'; APIGroup = 'sal'; APIVersion = 'v1.0';
    EntityName = 'facilityPallet'; EntitySetName = 'facilityPallets';
    SourceTable = "SAL Plan Pallet"; ODataKeyFields = SystemId;
    InsertAllowed = false; ModifyAllowed = false; DeleteAllowed = false;

    layout { area(Content) { repeater(Pallets) {
        field(id; Rec.SystemId) { }
        field(planNo; Rec."Plan No.") { }
        field(versionNo; Rec."Version No.") { }
        field(palletNo; Rec."Pallet No.") { }
        field(palletType; Rec."Pallet Type") { }
        field(description; Rec.Description) { }
        field(targetQuantity; Rec."Target Quantity") { }
        field(palletTemplateCode; Rec."Pallet Template Code") { }
        field(physicalPalletType; Rec."Physical Pallet Type") { }
        field(mixedPalletPolicy; Rec."Mixed Pallet Policy") { }
    } } }
}
