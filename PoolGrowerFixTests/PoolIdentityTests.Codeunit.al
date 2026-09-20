codeunit 59981 "Pool Identity Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Function;

    [Test]
    procedure RepeatedBatchIdentityReusesPool()
    var
        Pool: Record "TAC Pool";
        GroupID: Integer;
        FirstCode: Code[20];
    begin
        GroupID := CreateWeekGroup('RUSE1', 1);
        FirstCode := Pool.FindOrCreate(GroupID, 'HA', 'PR', '20', 'RA');
        AssertSameCode(FirstCode, Pool.FindOrCreate(GroupID, 'HA', 'PR', '20', 'RA'));
        AssertSameCode(FirstCode, Pool.FindOrCreate(GroupID, 'HA', 'PR', '20', 'RA'));
        AssertPoolCount(GroupID, 1);
    end;

    [Test]
    procedure LegacyCollisionReusesWithoutOverwrite()
    var
        Pool: Record "TAC Pool";
        Original: Record "TAC Pool";
        GroupID: Integer;
        FirstCode: Code[20];
    begin
        GroupID := CreateWeekGroup('RUSE1', 1);
        FirstCode := Pool.FindOrCreate(GroupID, 'HA', 'PR', '20', 'RA');
        Original.Get(FirstCode);
        AssertSameCode(FirstCode, Pool.FindOrCreate(GroupID, 'HA', 'PR', '23', 'RA'));
        AssertSameCode(FirstCode, Pool.FindOrCreate(GroupID, 'HA', 'C1', '20', 'RA'));
        Pool.Reset();
        Pool.Get(FirstCode);
        Pool.TestField("Grade Code", 'PR');
        Pool.TestField("Size Code", '20');
        Pool.TestField("Pool Group ID", GroupID);
        Pool.TestField("Grower No.", 'RA');
        if (Pool.SystemId <> Original.SystemId) or (Pool.Description <> Original.Description) then
            Error('Legacy reuse must preserve the original pool record and description.');
        AssertPoolCount(GroupID, 1);
    end;

    [Test]
    procedure DifferentGrowerAndWeekRemainSeparate()
    var
        Pool: Record "TAC Pool";
        GroupID: Integer;
        NextGroupID: Integer;
        FirstCode: Code[20];
    begin
        GroupID := CreateWeekGroup('RUSE1', 1);
        NextGroupID := CreateWeekGroup('RUSE2', 2);
        FirstCode := Pool.FindOrCreate(GroupID, 'HA', 'PR', '20', 'RA');
        if FirstCode = Pool.FindOrCreate(GroupID, 'HA', 'PR', '20', 'RB') then
            Error('This temporary release must retain the existing grower separation.');
        if FirstCode = Pool.FindOrCreate(NextGroupID, 'HA', 'PR', '20', 'RA') then
            Error('Different weeks must remain separate.');
        AssertPoolCount(GroupID, 2);
        AssertPoolCount(NextGroupID, 1);
    end;

    [Test]
    procedure LegacyCheckFixturesAreAbsent()
    var
        Pool: Record "TAC Pool";
        PoolWeek: Record "TAC Pool Week";
        PoolGroup: Record "TAC Pool Group Header";
    begin
        Pool.SetRange("Season Code", 'RUSE');
        if not Pool.IsEmpty() then
            Error('Unexpected legacy reuse fixture pool remains.');
        PoolWeek.SetRange("Season Code", 'RUSE');
        if not PoolWeek.IsEmpty() then
            Error('Unexpected legacy reuse fixture week remains.');
        PoolGroup.SetFilter("Pool Week Code", 'RUSE1|RUSE2');
        if not PoolGroup.IsEmpty() then
            Error('Unexpected legacy reuse fixture group remains.');
    end;

    local procedure CreateWeekGroup(WeekCode: Code[10]; WeekNumber: Integer): Integer
    var
        PoolWeek: Record "TAC Pool Week";
        PoolGroup: Record "TAC Pool Group Header";
    begin
        PoolWeek.Code := WeekCode;
        PoolWeek."Season Code" := 'RUSE';
        PoolWeek."Week No." := WeekNumber;
        PoolWeek.Description := 'Rollback-only legacy pool reuse check';
        PoolWeek.Insert(false);
        exit(PoolGroup.FindOrCreate(WeekCode, Enum::"TAC Grower Pool Type"::Internal));
    end;

    local procedure AssertSameCode(ExpectedCode: Code[20]; ActualCode: Code[20])
    begin
        if ExpectedCode <> ActualCode then
            Error('Expected pool code %1; received %2.', ExpectedCode, ActualCode);
    end;

    local procedure AssertPoolCount(GroupID: Integer; ExpectedCount: Integer)
    var
        Pool: Record "TAC Pool";
    begin
        Pool.SetRange("Pool Group ID", GroupID);
        if Pool.Count() <> ExpectedCount then
            Error('Expected %1 pools in fixture group; found %2.', ExpectedCount, Pool.Count());
    end;

    [Test]
    procedure ExistingBusinessKeysAreUnique()
    var
        Company: Record Company;
        Pool: Record "TAC Pool";
        MatchingPool: Record "TAC Pool";
    begin
        Company.FindSet();
        repeat
            Pool.ChangeCompany(Company.Name);
            MatchingPool.ChangeCompany(Company.Name);
            Pool.Reset();
            if Pool.FindSet() then
                repeat
                    MatchingPool.Reset();
                    MatchingPool.SetRange("Pool Group ID", Pool."Pool Group ID");
                    MatchingPool.SetRange("Variety Code", Pool."Variety Code");
                    MatchingPool.SetRange("Grade Code", Pool."Grade Code");
                    MatchingPool.SetRange("Size Code", Pool."Size Code");
                    MatchingPool.SetRange("Grower No.", Pool."Grower No.");
                    if MatchingPool.Count() <> 1 then
                        Error('Company %1 has duplicate business identities for pool %2; do not add the unique identity index.', Company.Name, Pool."Pool Code");
                until Pool.Next() = 0;
        until Company.Next() = 0;
    end;
}
