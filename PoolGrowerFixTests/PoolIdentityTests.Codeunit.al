codeunit 59981 "Pool Identity Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Function;

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
