table 50230 "TAC Pool Group Header"
{
    Caption = 'Pool Group Header';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Pool Group List";
    DrillDownPageId = "TAC Pool Group List";

    fields
    {
        field(1; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            AutoIncrement = true;
        }
        field(2; "Pool Group Code"; Code[20])
        {
            Caption = 'Pool Group Code';
        // e.g. PG-2026-W01-I, from No. Series.
        }
        field(3; "Pool Week Code"; Code[20])
        {
            Caption = 'Pool Week Code';
            TableRelation = "TAC Pool Week"."Code";
        }
        field(4; "Grower Pool Type";Enum "TAC Grower Pool Type")
        {
            Caption = 'Grower Pool Type';
        }
        field(5; Status;Enum "TAC Pool Group Status")
        {
            Caption = 'Status';
        }
        field(6; "Provisional Close Count"; Integer)
        {
            Caption = 'Provisional Close Count';
        }
        field(7; "Last Prov. Closed DateTime"; DateTime)
        {
            Caption = 'Last Provisional Closed DateTime';
        }
        field(8; "Final Closed DateTime"; DateTime)
        {
            Caption = 'Final Closed DateTime';
        }
        field(9; "Closed By User"; Code[50])
        {
            Caption = 'Closed By User';
        }
        field(10; Description; Text[100])
        {
            Caption = 'Description';
        // Auto-built, e.g. "Hass Week 1 I (29 Jun-05 Jul 2026)" (F-02).
        }
    }
    keys
    {
        key(PK; "Pool Group ID")
        {
            Clustered = true;
        }
        key(GroupCode; "Pool Group Code")
        {
            Unique = true;
        }
        key(WeekType; "Pool Week Code", "Grower Pool Type")
        {
            Unique = true;
        // FindOrCreatePoolGroup keys on Week + Type (F-02).
        }
    }
    var NotOpenErr: Label 'Pool Group %1 is not Open; adjustments and expenses are not allowed.', Comment = '%1 = Pool Group Code';
    BlankPoolWeekErr: Label 'No Pool Week could be determined for this transaction. Check that the POOL-WEEK dimension is set on the source document.';
    UnknownPoolWeekErr: Label 'Pool Week %1 does not exist. Load the Pool Week table (Sheet 3.1) before pooling into this week.', Comment = '%1 = Pool Week Code';
    /// <summary>Errors unless this Pool Group is still Open (F-06 guard).</summary>
    procedure TestStatusOpen()
    begin
        if Status <> Status::Open then Error(NotOpenErr, "Pool Group Code");
    end;
    /// <summary>
    /// Returns the Pool Group ID for this Week + Type, creating it (Open, with a
    /// composed PG-{season}-W{nn}-{type} code) on first use. Idempotent via the
    /// unique Week+Type key (F-02). The Pool Group Nos. series in setup stays
    /// available if a sequential code scheme is later preferred over composing.
    /// </summary>
    procedure FindOrCreate(NewPoolWeekCode: Code[10]; NewGrowerPoolType: Enum "TAC Grower Pool Type"): Integer var
        PoolWeek: Record "TAC Pool Week";
        PoolGroup: Record "TAC Pool Group Header";
    begin
        // Validated before the lookup so a blank week can never resolve to a
        // group of its own. A missing Pool Week used to degrade silently to a
        // malformed code (PG--W0-I); it now fails at the source, where a
        // dimension gap or an unloaded Sheet 3.1 can still be fixed.
        if NewPoolWeekCode = '' then Error(BlankPoolWeekErr);
        if not PoolWeek.Get(NewPoolWeekCode)then Error(UnknownPoolWeekErr, NewPoolWeekCode);
        PoolGroup.Reset();
        PoolGroup.SetCurrentKey("Pool Week Code", "Grower Pool Type");
        PoolGroup.SetRange("Pool Week Code", NewPoolWeekCode);
        PoolGroup.SetRange("Grower Pool Type", NewGrowerPoolType);
        if PoolGroup.FindFirst()then begin
            TestStatusOpen();
            exit(PoolGroup."Pool Group ID");
        end;
        PoolGroup.Init();
        PoolGroup."Pool Week Code":=NewPoolWeekCode;
        PoolGroup."Grower Pool Type":=NewGrowerPoolType;
        PoolGroup.Status:=Status::Open;
        PoolGroup."Pool Group Code":=BuildGroupCode(PoolWeek, NewGrowerPoolType);
        PoolGroup.Description:=BuildGroupDescription(PoolWeek, NewGrowerPoolType);
        //if not PoolGroup.Get("Pool Group ID") then
        PoolGroup.Insert(true);
        exit(PoolGroup."Pool Group ID");
    end;
    local procedure BuildGroupCode(var PoolWeek: Record "TAC Pool Week"; GrowerPoolType: Enum "TAC Grower Pool Type"): Code[20]var
        WeekText: Text;
    begin
        WeekText:=Format(PoolWeek."Week No.");
        if StrLen(WeekText) < 2 then WeekText:='0' + WeekText;
        exit(CopyStr(StrSubstNo('PG-%1-W%2-%3', PoolWeek."Season Code", WeekText, TypeLetter(GrowerPoolType)), 1, MaxStrLen("Pool Group Code")));
    end;
    local procedure BuildGroupDescription(var PoolWeek: Record "TAC Pool Week"; GrowerPoolType: Enum "TAC Grower Pool Type"): Text[100]begin
        exit(CopyStr(StrSubstNo('%1 %2 (%3 - %4)', PoolWeek.Description, TypeLetter(GrowerPoolType), PoolWeek."Start Date", PoolWeek."End Date"), 1, 100));
    end;
    local procedure TypeLetter(GrowerPoolType: Enum "TAC Grower Pool Type"): Text[1]begin
        case GrowerPoolType of GrowerPoolType::Internal: exit('I');
        GrowerPoolType::External: exit('E');
        GrowerPoolType::"Contract Pack": exit('G');
        end;
    end;
}
