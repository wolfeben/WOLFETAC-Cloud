codeunit 59302 "WLF Pool Review Export"
{
    procedure DownloadReview(var Groups: Record "WLF Pool Review Group"; var Issues: Record "WLF Pool Review Issue"; Kind: Text; EnvironmentName: Text; ScopeText: Text)
    var
        Rows: Record "WLF Pool Review Group";
        Findings: Record "WLF Pool Review Issue";
        Reader: Codeunit "WLF Pool Review Read";
        Line: Text;
        IncompleteCount: Integer;
        ExportedRows: Integer;
    begin
        if not (Kind in ['overview', 'findings']) then
            Error('Choose an overview or findings report.');
        Rows.Copy(Groups, true);
        if Rows.FindSet() then
            repeat
                if not Rows."Scan Complete" then
                    IncompleteCount += 1;
            until Rows.Next() = 0;
        StartReport('Pooling ' + Kind, EnvironmentName, ScopeText);
        Pair('Groups in scope', Format(Rows.Count(), 0, 9));
        Pair('Groups without a complete check', Format(IncompleteCount, 0, 9));
        Pair('Coverage', Reader.CoverageNotes());
        Pair('Reading this report', 'Existing session results only. Blank measures are not checked or incomplete; no findings does not approve closing or payment.');
        Output.WriteText();
        Rows.Copy(Groups, true);
        // Preserve the caller's exact season/week/type/focus filters.
        if Kind = 'overview' then
            Output.WriteText('Group ID,Group,Season,Week,Pool type,Business status,Review status,Scan complete,Scanned at,Pools,Movement kg,All ledger kg,Ledger net,Payment headers,Candidate invoice lines,Attributed invoice lines,Mismatches,Warnings,Unresolved,Detail')
        else
            Output.WriteText('Group ID,Group,Scan complete,Group scan time,Rule,Severity,Summary,Details,Pool,Grower,Document,Source line,Payment ID,Expected,Actual,Measure,Finding scan time');
        Output.WriteText();
        if Rows.FindSet() then
            repeat
                if Kind = 'overview' then begin
                    Line := Format(Rows."Group ID", 0, 9) + ',' + Cell(Rows."Group Code") + ',' + Cell(Rows.Season) + ',' + Cell(Rows."Week Code") + ',' + Cell(Rows."Pool Type Caption") + ',' + Cell(Rows."Business Status") + ',' + Cell(Rows."Review Status") + ',' + Format(Rows."Scan Complete", 0, 9) + ',' + Cell(Stamp(Rows."Scanned At"));
                    Line += ',' + Measure(Rows."Pool Count", Rows."Scan Complete") + ',' + Measure(Rows."Movement Kg", Rows."Scan Complete") + ',' + Measure(Rows."All Ledger Kg", Rows."Scan Complete") + ',' + Measure(Rows."Ledger Net", Rows."Scan Complete");
                    Line += ',' + Measure(Rows."Payment Count", Rows."Scan Complete") + ',' + Measure(Rows."Invoice Candidates", Rows."Scan Complete") + ',' + Measure(Rows."Attributed Invoices", Rows."Scan Complete") + ',' + Measure(Rows."Error Count", Rows."Scan Complete") + ',' + Measure(Rows."Warning Count", Rows."Scan Complete") + ',' + Measure(Rows."Unresolved Sources", Rows."Scan Complete") + ',' + Cell(Rows."Review Detail");
                    Output.WriteText(Line);
                    Output.WriteText();
                end else begin
                    Findings.Copy(Issues, true);
                    Findings.Reset();
                    Findings.SetRange("Group ID", Rows."Group ID");
                    if Findings.FindSet() then
                        repeat
                            Line := Format(Rows."Group ID", 0, 9) + ',' + Cell(Rows."Group Code") + ',' + Format(Rows."Scan Complete", 0, 9) + ',' + Cell(Stamp(Rows."Scanned At")) + ',' + Cell(Findings."Rule ID") + ',' + Cell(Format(Findings.Severity)) + ',' + Cell(Findings.Summary) + ',' + Cell(Findings.Details);
                            Line += ',' + Cell(Findings."Pool Code") + ',' + Cell(Findings."Grower Code") + ',' + Cell(Findings."Document No.") + ',' + Format(Findings."Source Line No.", 0, 9) + ',' + Format(Findings."Payment ID", 0, 9);
                            Line += ',' + Measure(Findings.Expected, NumericMeasure(Findings.Measure) and (Findings."Rule ID" <> 'RECOVERY')) + ',' + Measure(Findings.Actual, NumericMeasure(Findings.Measure)) + ',' + Cell(Findings.Measure) + ',' + Cell(Stamp(Findings."Scanned At"));
                            ExportedRows += 1;
                            if ExportedRows > 50000 then
                                Error('More than 50,000 findings match this report. Narrow the filters. No partial file was downloaded.');
                            Output.WriteText(Line);
                            Output.WriteText();
                        until Findings.Next() = 0;
                end;
            until Rows.Next() = 0;
        FinishReport('pooling-' + Kind + '.csv');
    end;

    procedure DownloadPayments(Payments: JsonObject; EnvironmentName: Text; GroupCode: Text)
    var
        RowsToken: JsonToken;
        RowToken: JsonToken;
        LoadedToken: JsonToken;
        Row: JsonObject;
        Line: Text;
        PropertyName: Text;
        Properties: List of [Text];
    begin
        if not Payments.Get('loaded', LoadedToken) then
            Error('Load payment history before exporting it.');
        if not LoadedToken.AsValue().AsBoolean() then
            Error('Payment history has not loaded successfully.');
        StartReport('Pool payment run headers', EnvironmentName, GroupCode);
        Pair('History loaded at', JsonText(Payments, 'loadedAt'));
        Pair('Total visible payment headers', JsonText(Payments, 'total'));
        Pair('More headers exist than exported rows', JsonText(Payments, 'hasMore'));
        Pair('Coverage', 'Only the loaded payment header rows, maximum 200. Invoice references are stored text, not verified payable balances. Run completion does not prove bank settlement. No calculated amount due or paid is supplied.');
        Output.WriteText();
        Output.WriteText('Payment ID,Group ID,Payment no.,Payment type,Pool,Provisional,Run status,Reversed,Reversed by payment ID,Closed at,Completed at,Closed by,Completed by,Journal batch,Recorded purchase invoice references');
        Output.WriteText();
        Properties := 'id,groupId,number,type,pool,provisional,status,reversed,reversedBy,closedAt,completedAt,closedBy,completedBy,journalBatch,invoiceReferences'.Split(',');
        Payments.Get('rows', RowsToken);
        foreach RowToken in RowsToken.AsArray() do begin
            Row := RowToken.AsObject();
            Line := '';
            foreach PropertyName in Properties do begin
                if Line <> '' then
                    Line += ',';
                Line += Cell(JsonText(Row, PropertyName));
            end;
            Output.WriteText(Line);
            Output.WriteText();
        end;
        FinishReport('pooling-payment-headers.csv');
    end;

    procedure Cell(Value: Text): Text
    var
        Probe: Text;
        TabChar: Char;
        CRChar: Char;
        LFChar: Char;
    begin
        TabChar := 9;
        CRChar := 13;
        LFChar := 10;
        Probe := DelChr(Value, '<', ' ' + Format(TabChar) + Format(CRChar) + Format(LFChar));
        // Neutralize spreadsheet formulas while retaining quoted commas, quotes and line breaks.
        if CopyStr(Probe, 1, 1) in ['=', '+', '-', '@'] then
            Value := '''' + Value;
        exit('"' + Value.Replace('"', '""') + '"');
    end;

    local procedure Measure(Value: Decimal; Available: Boolean): Text
    begin
        if not Available then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure NumericMeasure(Value: Text): Boolean
    begin
        exit(Value in ['raw signed kg', 'recorded amount', 'group ID', 'active PR matches']);
    end;

    local procedure Stamp(Value: DateTime): Text
    begin
        if Value = 0DT then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure JsonText(Value: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Value.Get(PropertyName, Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure StartReport(Title: Text; EnvironmentName: Text; ScopeText: Text)
    begin
        Clear(Blob);
        Blob.CreateOutStream(Output, TextEncoding::UTF8);
        Pair('Report', Title);
        Pair('Company', CompanyName());
        Pair('Environment', EnvironmentName);
        Pair('Exported at', Stamp(CurrentDateTime()));
        Pair('Scope', ScopeText);
    end;

    local procedure Pair(Name: Text; Value: Text)
    begin
        Output.WriteText(Cell(Name) + ',' + Cell(Value));
        Output.WriteText();
    end;

    local procedure FinishReport(FileName: Text)
    var
        Input: InStream;
    begin
        Blob.CreateInStream(Input, TextEncoding::UTF8);
        DownloadFromStream(Input, '', '', 'CSV files (*.csv)|*.csv', FileName);
    end;

    var
        Blob: Codeunit "Temp Blob";
        Output: OutStream;
}
