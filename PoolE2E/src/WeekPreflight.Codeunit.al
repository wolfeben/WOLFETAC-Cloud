codeunit 59352 "WLF Pool Week Preflight"
{
    procedure Snapshot(): Text
    var
        Guard: Codeunit "WLF Pool E2E Management";
        I: Record Item;
        V: Record Vendor;
        U: Record "Item Unit of Measure";
        D: Record "Default Dimension";
        T: Record "Item Tracking Code";
        W: Record "TAC Pool Week";
        B: Record "TAC Batch Plan Header";
        Setup: Record "TAC Pool Setup";
        InventorySetup: Record "Inventory Setup";
        GLSetup: Record "General Ledger Setup";
        UserSetup: Record "User Setup";
        Root: JsonObject;
        Items: JsonArray;
        Growers: JsonArray;
        R: RecordRef;
        Row: JsonObject;
        Fields: List of [Text];
        ItemNo: Text;
        Result: Text;
    begin
        Guard.CheckTarget();
        Root.Add('environment', 'Pool_Sandbox');
        Root.Add('company', CompanyName());
        Root.Add('readAt', CurrentDateTime());
        Root.Add('workDate', WorkDate());
        Root.Add('today', Today());
        Root.Add('requestedStart', DMY2Date(21, 9, 2026));
        Root.Add('requestedEnd', DMY2Date(27, 9, 2026));
        Fields := 'PKD-HATYGL25PR|PKD-HATYGL23PR|PKD-HATYGL20PR|PKD-HATYAV25C1|PKD-HATYAV23C1|PKD-HATYAV20C1|PKD-HABKGL1KPR|PKD-HAKGMXPG|PKD-HABKBN1KPP'.Split('|');
        foreach ItemNo in Fields do begin
            Clear(Row);
            Row.Add('requestedItem', ItemNo);
            Row.Add('exists', I.Get(ItemNo));
            if I.Get(ItemNo) then begin
                R.GetTable(I);
                Row.Add('item', SelectedFields(R, 'No.|Description|Base Unit of Measure|Sales Unit of Measure|Purch. Unit of Measure|Item Tracking Code|Blocked|Purchasing Blocked|Sales Blocked|Net Weight|Gross Weight|Gen. Prod. Posting Group|Inventory Posting Group|Replenishment System|Production BOM No.|Routing No.|Flushing Method|DIY_Label Tag No.'));
                U.SetRange("Item No.", I."No.");
                R.GetTable(U);
                Row.Add('units', ReadRows(R, '', 100));
                D.Reset(); D.SetRange("Table ID", Database::Item); D.SetRange("No.", I."No.");
                R.GetTable(D);
                Row.Add('dimensions', ReadRows(R, '', 100));
                if T.Get(I."Item Tracking Code") then begin
                    R.GetTable(T);
                    Row.Add('tracking', SelectedFields(R, ''));
                end;
            end;
            Items.Add(Row);
        end;
        Root.Add('items', Items);
        V.SetFilter("No.", '*100|*102|*030|*064|*049');
        if V.Count() > 50 then Error('Grower candidate filter is too broad. Resolve exact vendor IDs first.');
        if V.FindSet() then repeat
            Clear(Row);
            R.GetTable(V);
            Row.Add('vendor', SelectedFields(R, 'No.|Name|Blocked|Vendor Posting Group|Gen. Bus. Posting Group|VAT Bus. Posting Group|Currency Code|TAC Grower Pool Type|Pool Type|Grower Pool Type'));
            D.Reset(); D.SetRange("Table ID", Database::Vendor); D.SetRange("No.", V."No.");
            R.GetTable(D);
            Row.Add('dimensions', ReadRows(R, '', 100));
            R.Close(); R.Open(50905); R.Field(1).SetRange(V."No.");
            Row.Add('blocks', ReadRows(R, '', 100)); R.Close();
            Growers.Add(Row);
        until V.Next() = 0;
        Root.Add('growerCandidates', Growers);
        Setup.Get(); R.GetTable(Setup);
        Root.Add('poolSetup', SelectedFields(R, ''));
        InventorySetup.Get(); R.GetTable(InventorySetup);
        Root.Add('inventorySetup', SelectedFields(R, 'Location Mandatory|Item Nos.|TAC Batch Plan Item No.|TAC Batch No. Series|TAC Batch Plan Nos.|TAC Production Location Code|TAC Batch Output Item No.|TAC Block Dimension Code|TAC Grower Dimension Code|TAC Batch Plan Family No.'));
        GLSetup.Get(); R.GetTable(GLSetup);
        Root.Add('postingDates', SelectedFields(R, 'Allow Posting From|Allow Posting To|Global Dimension 1 Code|Global Dimension 2 Code|Shortcut Dimension 3 Code|Shortcut Dimension 4 Code|Shortcut Dimension 5 Code|Shortcut Dimension 6 Code|Shortcut Dimension 7 Code|Shortcut Dimension 8 Code'));
        if UserSetup.Get(UserId()) then begin
            R.GetTable(UserSetup);
            Root.Add('userPostingDates', SelectedFields(R, 'Allow Posting From|Allow Posting To'));
        end;
        W.SetFilter("Start Date", '<=%1', DMY2Date(27, 9, 2026));
        W.SetFilter("End Date", '>=%1', DMY2Date(21, 9, 2026));
        R.GetTable(W); Root.Add('overlappingPoolWeeks', ReadRows(R, '', 100));
        B.SetRange("Plan Date", DMY2Date(21, 9, 2026), DMY2Date(27, 9, 2026));
        R.GetTable(B); Root.Add('existingBatchPlans', ReadRows(R, '', 100));
        I.Reset(); I.SetRange("Base Unit of Measure", Setup."Bin UoM Code");
        R.GetTable(I);
        Root.Add('binItems', ReadRows(R, 'No.|Description|Base Unit of Measure|Net Weight|Gross Weight|Item Tracking Code|Blocked|Gen. Prod. Posting Group|Inventory Posting Group', 100));
        R.Close(); R.Open(50109);
        Root.Add('palletPostingSetup', ReadRows(R, 'Primary Key|Pallet Unit of Measure Code|Auto Post Pallet Output|Pallet Output Template|Pallet Output Journal|BC Online Upload Job Queue', 1));
        R.Close();
        Root.WriteTo(Result);
        exit(Result);
    end;

    local procedure ReadRows(var R: RecordRef; Allowed: Text; Maximum: Integer): JsonArray
    var
        Rows: JsonArray;
    begin
        if R.Count() > Maximum then Error('Read-only check stopped: table %1 exceeds the limit of %2 matching records.', R.Name, Maximum);
        if R.FindSet() then repeat
            Rows.Add(SelectedFields(R, Allowed));
        until R.Next() = 0;
        exit(Rows);
    end;

    local procedure SelectedFields(var R: RecordRef; Allowed: Text): JsonObject
    var
        J: JsonObject;
        F: FieldRef;
        N: Integer;
    begin
        for N := 1 to R.FieldCount do begin
            F := R.FieldIndex(N);
            if (F.Class = FieldClass::Normal) and (F.Number < 2000000000) then
                if (Allowed = '') or (StrPos('|' + Allowed + '|', '|' + F.Name + '|') > 0) then
                    if not (F.Type in [FieldType::Blob, FieldType::Media, FieldType::MediaSet]) then
                        J.Add(F.Name, Format(F.Value));
        end;
        exit(J);
    end;

    procedure DownloadSnapshot(Contents: Text)
    var
        Guard: Codeunit "WLF Pool E2E Management";
        Blob: Codeunit "Temp Blob";
        OutS: OutStream;
        InS: InStream;
        FileName: Text;
    begin
        Guard.CheckTarget();
        Blob.CreateOutStream(OutS, TextEncoding::UTF8); OutS.WriteText(Contents);
        Blob.CreateInStream(InS, TextEncoding::UTF8);
        FileName := 'pool-week-20260921-preflight.json';
        DownloadFromStream(InS, '', '', '', FileName);
    end;
}
