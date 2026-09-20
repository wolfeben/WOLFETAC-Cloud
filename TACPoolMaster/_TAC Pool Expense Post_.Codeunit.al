codeunit 50275 "TAC Pool Expense Post"
{
    // AL-13: posts a one-off cost split across pools — one Pool Ledger Entry
    // per detail line, using any Active Trans Type (design §4.6, §F-06).
    // Blocked once the Pool Group is provisionally or finally closed.

    var
        NoLinesErr: Label 'Expense %1 has no detail lines to post.', Comment = '%1 = Expense ID';
        AlreadyPostedErr: Label 'Expense %1 has already been posted.', Comment = '%1 = Expense ID';

    procedure PostExpense(var PoolExpenseHeader: Record "TAC Pool Expense Header")
    var
        PoolExpenseDetail: Record "TAC Pool Expense Detail";
        PoolGroup: Record "TAC Pool Group Header";
    begin
        if PoolExpenseHeader.Posted then
            Error(AlreadyPostedErr, PoolExpenseHeader."Expense ID");

        PoolGroup.Get(PoolExpenseHeader."Pool Group ID");
        PoolGroup.TestStatusOpen();

        PoolExpenseHeader.TestField(Comment); // mandatory (design §4.6)
        PoolExpenseHeader.TestField("Trans Type");

        PoolExpenseDetail.SetRange("Expense ID", PoolExpenseHeader."Expense ID");
        if not PoolExpenseDetail.FindSet() then
            Error(NoLinesErr, PoolExpenseHeader."Expense ID");

        repeat
            WriteEntry(PoolExpenseHeader, PoolExpenseDetail);
        until PoolExpenseDetail.Next() = 0;

        PoolExpenseHeader.Posted := true;
        PoolExpenseHeader.Modify();
    end;

    procedure PostExpenseDetailLine(var PoolExpenseHeader: Record "TAC Pool Expense Header"; var PoolExpenseDetail: Record "TAC Pool Expense Detail")
    var
        PoolGroup: Record "TAC Pool Group Header";
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        PoolGroup.Get(PoolExpenseHeader."Pool Group ID");
        PoolGroup.TestStatusOpen();
        PoolLedgerEntry.SetRange("Pool Code", PoolExpenseDetail."Pool Code");
        PoolLedgerEntry.SetRange("Source Document No.", Format(PoolExpenseHeader."Expense ID"));
        PoolLedgerEntry.SetRange("Source Line No.", PoolExpenseDetail."Line No.");
        PoolLedgerEntry.SetRange("Trans Type Code", PoolExpenseHeader."Trans Type");
        if not PoolLedgerEntry.IsEmpty() then
            exit;
        WriteEntry(PoolExpenseHeader, PoolExpenseDetail);
    end;

    local procedure WriteEntry(var PoolExpenseHeader: Record "TAC Pool Expense Header"; var PoolExpenseDetail: Record "TAC Pool Expense Detail")
    var
        PoolLedgerEntry: Record "TAC Pool Ledger Entry";
    begin
        // Each detail line writes its amount verbatim (design §F-06).
        PoolLedgerEntry.Init();
        PoolLedgerEntry."Pool Code" := PoolExpenseDetail."Pool Code";
        PoolLedgerEntry."Pool Group ID" := PoolExpenseHeader."Pool Group ID";
        PoolLedgerEntry."Trans Type Code" := PoolExpenseHeader."Trans Type";
        PoolLedgerEntry.Amount := PoolExpenseDetail.Amount;
        PoolLedgerEntry."Transaction Date" := PoolExpenseHeader."Date";
        PoolLedgerEntry."Posting Date" := Today();
        PoolLedgerEntry."Pool Expense ID" := PoolExpenseHeader."Expense ID";
        PoolLedgerEntry."Source Document No." := Format(PoolExpenseHeader."Expense ID");
        PoolLedgerEntry."Source Line No." := PoolExpenseDetail."Line No.";
        PoolLedgerEntry."Source Type" := PoolLedgerEntry."Source Type"::Expense;
        PoolLedgerEntry."Source System ID" := PoolExpenseDetail.SystemId;
        PoolLedgerEntry.Comment := PoolExpenseHeader.Comment;
        PoolLedgerEntry.Insert(true);
    end;
}
