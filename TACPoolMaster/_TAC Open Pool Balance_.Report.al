report 50292 "TAC Open Pool Balance"
{
    Caption = 'Open Pool Balance';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    // Live balance for pools whose group is Open or Provisionally Closed
    // (design §F-09): PR total, charges, and current net per pool.

    dataset
    {
        dataitem(PoolGroupHeader; "TAC Pool Group Header")
        {
            DataItemTableView = where(Status = filter(Open | "Provisionally Closed"));
            column(PoolGroupCode; "Pool Group Code") { }
            column(Status; Status) { }

            dataitem(Pool; "TAC Pool")
            {
                DataItemLink = "Season Code" = field("Pool Group ID");
                column(PoolDescription; Description) { }
                column(TotalKgs; "Total Kilograms") { }
                column(NetAmount; "Net Value") { }

                trigger OnAfterGetRecord()
                begin
                    Pool.CalcFields("Total Kilograms", "Net Value");
                end;
            }
        }
    }
}
