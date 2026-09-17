page 58012 "SAL Product Groups"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'SAL Fill Group Layouts';
    AdditionalSearchTerms = 'SAL,Fill Order,Flexible Order,Product Group,WebSAM,Layout,Template';

    layout
    {
        area(Content)
        {
            usercontrol(Workspace; "SAL Fill Group Workspace")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    AddInReady := true;
                    LoadScreen('', false);
                end;

                trigger RefreshRequested()
                begin
                    LoadScreen('Fill group layouts refreshed.', false);
                end;

                trigger SaveTemplateRequested(GroupCode: Text; Description: Text; MarketerCustomerNo: Text; AllowMixedPallets: Boolean; DefaultPalletQuantity: Decimal; MaximumTotalPallets: Decimal; MembersJson: Text)
                begin
                    SaveTemplate(GroupCode, Description, MarketerCustomerNo, AllowMixedPallets, DefaultPalletQuantity, MaximumTotalPallets, MembersJson);
                end;

                trigger SetTemplateActiveRequested(GroupCode: Text; Active: Boolean)
                begin
                    SetTemplateActive(GroupCode, Active);
                end;
            }
        }
    }

    local procedure LoadScreen(StatusMessage: Text; IsError: Boolean)
    var
        StateJson: Text;
    begin
        if not AddInReady then
            exit;
        BuildState(StateJson);
        CurrPage.Workspace.SetState(StateJson, StatusMessage, IsError);
    end;

    local procedure BuildState(var StateJson: Text)
    var
        Groups: JsonArray;
        Items: JsonArray;
        Marketers: JsonArray;
        Root: JsonObject;
    begin
        Root.Add('schemaVersion', 1);
        Root.Add('company', CompanyName());
        BuildGroups(Groups);
        BuildItems(Items);
        BuildMarketers(Marketers);
        Root.Add('groups', Groups);
        Root.Add('items', Items);
        Root.Add('marketers', Marketers);
        Root.WriteTo(StateJson);
    end;

    local procedure BuildGroups(var Groups: JsonArray)
    var
        Group: JsonObject;
        Members: JsonArray;
        ProductGroup: Record "SAL Product Group";
    begin
        if ProductGroup.FindSet() then
            repeat
                Clear(Group);
                Clear(Members);
                ProductGroup.CalcFields("Marketer Description");
                Group.Add('code', ProductGroup.Code);
                Group.Add('description', ProductGroup.Description);
                Group.Add('active', ProductGroup.Active);
                Group.Add('marketerCustomerNo', ProductGroup."Marketer Customer No.");
                Group.Add('marketerDescription', ProductGroup."Marketer Description");
                Group.Add('allowMixedPallets', ProductGroup."Allow Mixed Pallets");
                Group.Add('defaultPalletQuantity', ProductGroup."Default Pallet Quantity");
                Group.Add('maximumTotalPallets', ProductGroup."Maximum Total Pallets");
                BuildMembers(ProductGroup.Code, Members);
                Group.Add('members', Members);
                Groups.Add(Group);
            until ProductGroup.Next() = 0;
    end;

    local procedure BuildMembers(GroupCode: Code[20]; var Members: JsonArray)
    var
        Member: JsonObject;
        ProductGroupMember: Record "SAL Product Group Member";
    begin
        ProductGroupMember.SetCurrentKey("Group Code", Preference, "Line No.");
        ProductGroupMember.SetRange("Group Code", GroupCode);
        ProductGroupMember.SetRange(Active, true);
        if ProductGroupMember.FindSet() then
            repeat
                Clear(Member);
                Member.Add('lineNo', ProductGroupMember."Line No.");
                Member.Add('itemNo', ProductGroupMember."Item No.");
                Member.Add('variantCode', ProductGroupMember."Variant Code");
                Member.Add('uom', ProductGroupMember."Unit of Measure Code");
                Member.Add('description', ProductGroupMember.Description);
                Member.Add('minimumQuantity', ProductGroupMember."Minimum Quantity");
                Member.Add('maximumQuantity', ProductGroupMember."Maximum Quantity");
                Member.Add('maximumPallets', ProductGroupMember."Maximum Pallets");
                Member.Add('defaultPalletQuantity', ProductGroupMember."Default Pallet Quantity");
                Member.Add('preference', ProductGroupMember.Preference);
                Members.Add(Member);
            until ProductGroupMember.Next() = 0;
    end;

    local procedure BuildItems(var Items: JsonArray)
    var
        Item: Record Item;
        ItemJson: JsonObject;
        ItemCount: Integer;
    begin
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        if Item.FindSet() then
            repeat
                Clear(ItemJson);
                ItemJson.Add('itemNo', Item."No.");
                ItemJson.Add('description', Item.Description);
                ItemJson.Add('searchDescription', Item."Search Description");
                ItemJson.Add('uom', Item."Base Unit of Measure");
                ItemJson.Add('itemCategoryCode', Item."Item Category Code");
                Items.Add(ItemJson);
                ItemCount += 1;
            until (Item.Next() = 0) or (ItemCount >= 1000);
    end;

    local procedure BuildMarketers(var Marketers: JsonArray)
    var
        Customer: Record Customer;
        ProductGroup: Record "SAL Product Group";
        Seen: Dictionary of [Code[20], Boolean];
    begin
        ProductGroup.SetFilter("Marketer Customer No.", '<>%1', '');
        if ProductGroup.FindSet() then
            repeat
                if Customer.Get(ProductGroup."Marketer Customer No.") then
                    AddMarketer(Customer, Seen, Marketers);
            until ProductGroup.Next() = 0;

        Customer.Reset();
        if Customer.FindSet() then
            repeat
                if IsSupportedMarketer(Customer.Name) then
                    AddMarketer(Customer, Seen, Marketers);
            until Customer.Next() = 0;
    end;

    local procedure AddMarketer(Customer: Record Customer; var Seen: Dictionary of [Code[20], Boolean]; var Marketers: JsonArray)
    var
        Marketer: JsonObject;
    begin
        if Seen.ContainsKey(Customer."No.") then
            exit;
        Seen.Add(Customer."No.", true);
        Marketer.Add('customerNo', Customer."No.");
        Marketer.Add('name', Customer.Name);
        Marketers.Add(Marketer);
    end;

    local procedure IsSupportedMarketer(CustomerName: Text): Boolean
    var
        NormalizedName: Text;
    begin
        NormalizedName := UpperCase(CustomerName);
        exit(
            (StrPos(NormalizedName, 'COSTA') > 0) or
            ((StrPos(NormalizedName, 'AVOCADO') > 0) and (StrPos(NormalizedName, 'COLLECTIVE') > 0)) or
            (NormalizedName = 'TAC') or (CopyStr(NormalizedName, 1, 4) = 'TAC '));
    end;

    local procedure SaveTemplate(GroupCodeText: Text; DescriptionText: Text; MarketerCustomerNoText: Text; AllowMixedPallets: Boolean; DefaultPalletQuantity: Decimal; MaximumTotalPallets: Decimal; MembersJson: Text)
    var
        Customer: Record Customer;
        ProductGroup: Record "SAL Product Group";
        GroupCode: Code[20];
        MarketerCustomerNo: Code[20];
        IsNew: Boolean;
    begin
        if not ProductGroup.WritePermission() then
            Error(TemplatePermissionErr);

        GroupCode := CopyStr(UpperCase(GroupCodeText), 1, MaxStrLen(GroupCode));
        if GroupCode = '' then
            Error(GroupCodeRequiredErr);
        if DescriptionText = '' then
            Error(GroupNameRequiredErr);
        MarketerCustomerNo := CopyStr(MarketerCustomerNoText, 1, MaxStrLen(MarketerCustomerNo));
        if not Customer.Get(MarketerCustomerNo) then
            Error(MarketerRequiredErr);
        if DefaultPalletQuantity <= 0 then
            Error(PalletQuantityErr);
        if MaximumTotalPallets < 0 then
            Error(MaximumTotalPalletsErr);

        IsNew := not ProductGroup.Get(GroupCode);
        if IsNew then begin
            ProductGroup.Init();
            ProductGroup.Code := GroupCode;
            ProductGroup.Insert(true);
        end;
        ProductGroup.Validate(Description, CopyStr(DescriptionText, 1, MaxStrLen(ProductGroup.Description)));
        ProductGroup.Validate("Marketer Customer No.", MarketerCustomerNo);
        ProductGroup.Validate("Allow Mixed Pallets", AllowMixedPallets);
        ProductGroup.Validate("Default Pallet Quantity", DefaultPalletQuantity);
        ProductGroup.Validate("Maximum Total Pallets", MaximumTotalPallets);
        ProductGroup.Validate(Active, true);
        ProductGroup.Modify(true);

        SaveMembers(ProductGroup, MembersJson);
        LoadScreen(StrSubstNo(TemplateSavedMsg, ProductGroup.Code), false);
    end;

    local procedure SaveMembers(ProductGroup: Record "SAL Product Group"; MembersJson: Text)
    var
        Item: Record Item;
        Member: Record "SAL Product Group Member";
        Members: JsonArray;
        MemberObject: JsonObject;
        MemberToken: JsonToken;
        ValueToken: JsonToken;
        ItemNo: Code[20];
        UomCode: Code[10];
        MaximumQuantity: Decimal;
        MaximumPallets: Decimal;
        Preference: Integer;
        SelectedCount: Integer;
    begin
        if not Members.ReadFrom(MembersJson) then
            Error(MemberJsonErr);

        Member.SetRange("Group Code", ProductGroup.Code);
        if Member.FindSet(true) then
            repeat
                Member.Active := false;
                Member.Modify(true);
            until Member.Next() = 0;

        Preference := 10;
        foreach MemberToken in Members do begin
            if not MemberToken.IsObject() then
                Error(MemberJsonErr);
            MemberObject := MemberToken.AsObject();
            if not MemberObject.Get('itemNo', ValueToken) then
                Error(MemberJsonErr);
            ItemNo := CopyStr(ValueToken.AsValue().AsText(), 1, MaxStrLen(ItemNo));
            Item.Get(ItemNo);
            UomCode := Item."Base Unit of Measure";
            MaximumQuantity := 0;
            MaximumPallets := 0;
            if MemberObject.Get('maximumQuantity', ValueToken) then
                MaximumQuantity := ValueToken.AsValue().AsDecimal();
            if MemberObject.Get('maximumPallets', ValueToken) then
                MaximumPallets := ValueToken.AsValue().AsDecimal();

            Member.Reset();
            Member.SetRange("Group Code", ProductGroup.Code);
            Member.SetRange("Item No.", ItemNo);
            Member.SetRange("Variant Code", '');
            Member.SetRange("Unit of Measure Code", UomCode);
            if not Member.FindFirst() then begin
                // Init preserves primary-key values on a reused record variable. Clear the
                // record so OnInsert can allocate the next member line instead of trying
                // to reuse the last line visited while deactivating or matching members.
                Clear(Member);
                Member.Init();
                Member."Group Code" := ProductGroup.Code;
                Member."Line No." := 0;
                Member.Validate("Item No.", ItemNo);
                Member.Validate("Unit of Measure Code", UomCode);
                Member."Default Pallet Quantity" := ProductGroup."Default Pallet Quantity";
                Member.Active := true;
                Member.Preference := Preference;
                Member."Maximum Quantity" := MaximumQuantity;
                Member."Maximum Pallets" := MaximumPallets;
                Member.Insert(true);
            end else begin
                Member.Active := true;
                Member.Preference := Preference;
                Member."Default Pallet Quantity" := ProductGroup."Default Pallet Quantity";
                Member."Maximum Quantity" := MaximumQuantity;
                Member."Maximum Pallets" := MaximumPallets;
                Member.Modify(true);
            end;
            Preference += 10;
            SelectedCount += 1;
        end;

        if SelectedCount = 0 then
            Error(NoMembersErr);
    end;

    local procedure SetTemplateActive(GroupCodeText: Text; Active: Boolean)
    var
        ProductGroup: Record "SAL Product Group";
        GroupCode: Code[20];
    begin
        if not ProductGroup.WritePermission() then
            Error(TemplatePermissionErr);
        GroupCode := CopyStr(GroupCodeText, 1, MaxStrLen(GroupCode));
        ProductGroup.Get(GroupCode);
        ProductGroup.Validate(Active, Active);
        ProductGroup.Modify(true);
        LoadScreen(StrSubstNo(TemplateStatusMsg, ProductGroup.Code), false);
    end;

    var
        AddInReady: Boolean;
        GroupCodeRequiredErr: Label 'Enter a short code for the fill group layout.';
        GroupNameRequiredErr: Label 'Enter a name for the fill group layout.';
        MarketerRequiredErr: Label 'Select TAC or Costa as the marketer for this layout.';
        MemberJsonErr: Label 'The selected fill group products could not be read.';
        NoMembersErr: Label 'Select at least one eligible product or size before saving the layout.';
        PalletQuantityErr: Label 'Enter a default pallet quantity greater than zero.';
        MaximumTotalPalletsErr: Label 'The maximum total pallets cannot be negative. Use zero for no overall limit.';
        TemplatePermissionErr: Label 'You need the SAL Administrator permission set to maintain fill group layouts.';
        TemplateSavedMsg: Label 'Fill group layout %1 saved.', Comment = '%1 = fill group code';
        TemplateStatusMsg: Label 'Fill group layout %1 status updated.', Comment = '%1 = fill group code';
}
