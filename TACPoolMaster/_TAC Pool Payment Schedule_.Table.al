table 50216 "TAC Pool Payment Schedule"
{
    Caption = 'Pool Payment Schedule';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Pool Type"; Option)
        {
            Caption = 'Pool Type';
            OptionMembers = Internal,External,Grower;
            ToolTip = 'Specifies the pool type this payment schedule row applies to.';

            trigger OnValidate()
            begin
                ValidateActiveSchedule("Pool Type");
            end;
        }
        field(2; "Sequence No."; Integer)
        {
            Caption = 'Sequence No.';
            MinValue = 1;
            ToolTip = 'Specifies the close sequence order for this pool type, for example 1, 2, and 3.';

            trigger OnValidate()
            begin
                ValidateActiveSchedule("Pool Type");
            end;
        }
        field(3; Description; Text[50])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the schedule description, such as Provisional 1 or Final.';
        }
        field(4; "Offset Weeks"; Integer)
        {
            Caption = 'Offset Weeks';
            MinValue = 0;
            ToolTip = 'Specifies the number of weeks after pool week end date when this close becomes due. Leave blank for user-initiated closes.';
        }
        field(5; "Payment Share %"; Decimal)
        {
            Caption = 'Payment Share %';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;
            ToolTip = 'Specifies the share of net pool value paid at this schedule step.';
        }
        field(6; "Cumulative Share %"; Decimal)
        {
            Caption = 'Cumulative Share %';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;
            ToolTip = 'Specifies the cumulative share of net pool value paid up to this schedule step.';

            trigger OnValidate()
            begin
                ValidateActiveSchedule("Pool Type");
            end;
        }
        field(7; "Is Final"; Boolean)
        {
            Caption = 'Is Final';
            ToolTip = 'Specifies whether this row is the final close step for the pool type.';

            trigger OnValidate()
            begin
                ValidateActiveSchedule("Pool Type");
            end;
        }
        field(8; Active; Boolean)
        {
            Caption = 'Active';
            InitValue = true;
            ToolTip = 'Specifies whether this schedule row is active.';

            trigger OnValidate()
            begin
                ValidateActiveSchedule("Pool Type");
            end;
        }
    }

    keys
    {
        key(PK; "Pool Type", "Sequence No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        ValidateActiveSchedule("Pool Type");
    end;

    trigger OnModify()
    begin
        ValidateActiveSchedule("Pool Type");
    end;

    trigger OnDelete()
    begin
        ValidateActiveSchedule("Pool Type");
    end;

    var
        FinalCumulativeMustBe100Err: Label 'For active schedule rows of pool type %1, the final row cumulative share must be 100.';
        ExactlyOneFinalErr: Label 'For active schedule rows of pool type %1, exactly one row must be marked as final.';
        FinalMustBeLastErr: Label 'For pool type %1, the final schedule row must have the highest sequence number.';

    local procedure ValidateActiveSchedule(PoolType: Option Internal,External,Grower)
    var
        Schedule: Record "TAC Pool Payment Schedule";
        ActiveRows: Integer;
        FinalRows: Integer;
        MaxSeqNo: Integer;
        FinalSeqNo: Integer;
        FinalCumulativePct: Decimal;
    begin
        Schedule.Reset();
        Schedule.SetRange("Pool Type", PoolType);
        Schedule.SetRange(Active, true);

        if not Schedule.FindSet() then
            exit;

        repeat
            ActiveRows += 1;
            if Schedule."Sequence No." > MaxSeqNo then
                MaxSeqNo := Schedule."Sequence No.";

            if Schedule."Is Final" then begin
                FinalRows += 1;
                FinalSeqNo := Schedule."Sequence No.";
                FinalCumulativePct := Schedule."Cumulative Share %";
            end;
        until Schedule.Next() = 0;

        if (ActiveRows > 0) and (FinalRows <> 1) then
            Error(ExactlyOneFinalErr, Format(PoolType));

        if FinalSeqNo <> MaxSeqNo then
            Error(FinalMustBeLastErr, Format(PoolType));

        if Round(FinalCumulativePct, 0.00001) <> 100 then
            Error(FinalCumulativeMustBe100Err, Format(PoolType));
    end;
}