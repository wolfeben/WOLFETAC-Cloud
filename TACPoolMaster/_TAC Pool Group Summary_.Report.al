report 50291 "TAC Pool Group Summary"
{
    Caption = 'Pool Group Summary';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    // Internal: Pool Ledger aggregated by Grower x Trans Type (design §F-09).

    dataset
    {
        dataitem(PoolLedgerEntry; "TAC Pool Ledger Entry")
        {
            RequestFilterFields = "Pool Group ID", "Grower Code";
            column(PoolGroupID; "Pool Group ID") { }
            column(GrowerCode; "Grower Code") { }
            column(TransTypeCode; "Entry Type") { }
            column(Kgs; "Quantity (Kg)") { }
            column(Amount; Amount) { }
            column(GSTAmount; "VAT Amount") { }
        }
    }
}
