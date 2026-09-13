table 50208 "TAC Pool"
{
    Caption = 'Pool';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Pool Code"; Code[20])
        {
            Caption = 'Pool Code';
            ToolTip = 'Specifies the generated pool code.';
        }
        field(2; "Season Code"; Code[20])
        {
            Caption = 'Season Code';
            ToolTip = 'Specifies the season code for this pool.';
        }
        field(3; "Pool Week"; Integer)
        {
            Caption = 'Pool Week';
            ToolTip = 'Specifies the ISO week number for this pool.';
        }
        field(4; "Pool Type";enum "TAC Grower Pool Type")
        {
            Caption = 'Pool Type';
            ToolTip = 'Specifies the pool type.';
        }
        field(5; "Variety Code"; Code[20])
        {
            Caption = 'Variety Code';
            ToolTip = 'Specifies the variety code for this pool.';
        }
        field(6; "Grower No."; Code[20])
        {
            Caption = 'Grower No.';
            TableRelation = Vendor."No.";
            ToolTip = 'Specifies the grower for grower-type pools.';
        }
        field(7; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the descriptive name of the pool.';
        }
        field(8; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Open, "Provisionally Closed", Closed;
            ToolTip = 'Specifies whether the pool is open, provisionally closed, or closed.';
        }
        field(9; "Provisional Count"; Integer)
        {
            Caption = 'Provisional Count';
            ToolTip = 'Specifies how many provisional closes have been run for this pool.';
        }
        field(10; "Closed DateTime"; DateTime)
        {
            Caption = 'Closed DateTime';
            ToolTip = 'Specifies the date and time when the pool was finally closed.';
        }
        field(11; "Closed By"; Code[50])
        {
            Caption = 'Closed By';
            ToolTip = 'Specifies the user who finally closed the pool.';
        }
        field(12; "Total Kilograms"; Decimal)
        {
            Caption = 'Total Kilograms';
            FieldClass = FlowField;
            CalcFormula = sum("TAC Pool Ledger Entry"."Quantity (Kg)" where("Pool Code"=field("Pool Code")));
            Editable = false;
            ToolTip = 'Shows the total kilograms posted to this pool.';
        }
        field(13; "Gross Value"; Decimal)
        {
            Caption = 'Gross Value';
            FieldClass = FlowField;
            CalcFormula = sum("TAC Pool Ledger Entry".Amount where("Pool Code"=field("Pool Code"), "Entry Type"=const(Revenue)));
            Editable = false;
            ToolTip = 'Shows the gross value from revenue entries only.';
        }
        field(14; "Net Value"; Decimal)
        {
            Caption = 'Net Value';
            FieldClass = FlowField;
            CalcFormula = sum("TAC Pool Ledger Entry".Amount where("Pool Code"=field("Pool Code")));
            Editable = false;
            ToolTip = 'Shows the net value from all ledger entries for this pool.';
        }
        /*field(15; "Pool ID"; Integer)
        {
            Caption = 'Pool ID';
            AutoIncrement = true;
            ToolTip = 'Specifies the internal pool identifier.';
        }*/
        field(16; "Pool Group ID"; Integer)
        {
            Caption = 'Pool Group ID';
            TableRelation = "TAC Pool Group Header"."Pool Group ID";
            ToolTip = 'Specifies the pool group this pool belongs to.';
        }
        field(17; "Grade Code"; Code[10])
        {
            Caption = 'Grade Code';
            ToolTip = 'Specifies the fruit grade for this pool.';
        }
        field(18; "Size Code"; Code[10])
        {
            Caption = 'Size Code';
            ToolTip = 'Specifies the fruit size for this pool.';
        }
        field(19; "Manual Pool Flag"; Boolean)
        {
            Caption = 'Manual Pool Flag';
            ToolTip = 'Specifies whether this pool was created manually.';
        }
        field(21; "Close Sequence"; Integer)
        {
            Caption = 'Close Sequence';
            ToolTip = 'Specifies the sequence number of the last close for this pool.';
        }
        field(22; "Payment Model"; Option)
        {
            Caption = 'Payment Model';
            OptionMembers = Retention, "Full Payout";
            ToolTip = 'Specifies the payment model for this pool.';
        }
    }
    keys
    {
        key(PK; "Pool Code")
        {
            Clustered = true;
        }
        //key(PoolId; "Pool ID") { }
        key(Resolution; "Season Code", "Pool Week", "Pool Type", "Variety Code", "Grower No.")
        {
        }
        key(VGS; "Pool Group ID", "Variety Code", "Grade Code", "Size Code")
        {
            Unique = true;
        }
    }
    trigger OnInsert()
    begin
        if "Pool Code" <> '' then exit;
        "Pool Code":=GetPoolCode();
    end;
    procedure GetPoolCode(): Code[20]var
        PoolWeekText: Text[2];
    begin
        PoolWeekText:=Format("Pool Week", 0, '');
        if StrLen(PoolWeekText) < 2 then PoolWeekText:='0' + PoolWeekText;
        exit(Format("Season Code") + '-' + PoolWeekText + '-' + Format("Pool Type") + '-' + Format("Variety Code") + '-' + Format("Grower No."));
    end;
    /// <summary>
    /// Returns the Pool ID for this Group + Variety + Grade + Size, creating it
    /// on first use. Idempotent via the unique V/G/S key (F-02).
    /// </summary>
    procedure FindOrCreate(NewPoolGroupID: Integer; NewVariety: Code[10]; NewGrade: Code[10]; NewSize: Code[10]; NewGrower: Code[20]): Code[20]var
        PoolGroup: Record "TAC Pool Group Header";
        PoolWeek: Record "TAC Pool Week";
        Pool: Record "TAC Pool";
    begin
        Pool.Reset();
        Pool.SetRange("Pool Group ID", NewPoolGroupID);
        Pool.SetRange("Variety Code", NewVariety);
        Pool.SetRange("Grade Code", NewGrade);
        Pool.SetRange("Size Code", NewSize);
        Pool.SetRange("Grower No.", NewGrower);
        if Pool.FindFirst()then exit(Pool."Pool Code");
        PoolGroup.Get(NewPoolGroupID);
        PoolWeek.Get(PoolGroup."Pool Week Code");
        Init();
        "Pool Group ID":=NewPoolGroupID;
        "Season Code":=PoolWeek."Season Code";
        "Pool Week":=PoolWeek."Week No.";
        "Pool Type":=PoolGroup."Grower Pool Type";
        "Variety Code":=NewVariety;
        "Grade Code":=NewGrade;
        "Size Code":=NewSize;
        "Grower No.":=NewGrower;
        Description:=CopyStr(StrSubstNo('%1 / %2 / %3 / %4', NewVariety, NewGrade, NewSize, NewGrower), 1, MaxStrLen(Description));
        "Pool Code":=GetPoolCode();
        if not Pool.Get("Pool Code")then Insert(true);
        exit("Pool Code");
    end;
}
