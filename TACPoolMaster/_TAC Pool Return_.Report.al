report 50290 "TAC Pool Return"
{
    Caption = 'Pool Return';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;

    // AL-15: one report, three request-page variants (Tax Invoice / Provisional
    // Statement / Summary). The Word layout (legal tax-invoice wording, both
    // ABNs, GST summary, bank details) is a separate binary deliverable; the
    // dataset and variant selector are defined here.
    dataset
    {
        dataitem(PoolGroupHeader; "TAC Pool Group Header")
        {
            RequestFilterFields = "Pool Group ID";

            column(PoolGroupCode; "Pool Group Code")
            {
            }
            column(PoolGroupDescription; Description)
            {
            }
            column(GrowerPoolType; "Grower Pool Type")
            {
            }
            column(VariantCaption; Format(VariantType))
            {
            }
            column(IsTaxInvoice; VariantType = VariantType::TaxInvoice)
            {
            }
            dataitem(Pool; "TAC Pool")
            {
                DataItemLink = "Season Code"=field("Pool Group Code");

                column(PoolDescription; Description)
                {
                }
                column(VarietyCode; "Variety Code")
                {
                }
                column(TotalKgs; "Total Kilograms")
                {
                }
                column(NetAmount; "Net Value")
                {
                }
                dataitem(PoolGrowerCharge; "TAC Pool Grower Charge")
                {
                    DataItemLink = "Pool Code"=field("Pool Code");

                    column(ChargeTransType; "Trans Type Code")
                    {
                    }
                    column(ChargeGrower; "Grower Code")
                    {
                    }
                    column(ChargeAmount; Amount)
                    {
                    }
                    column(ChargeGST; "GST Amount")
                    {
                    }
                }
                trigger OnAfterGetRecord()
                begin
                    Pool.CalcFields("Total Kilograms", "Net Value");
                end;
            }
        }
    }
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';

                    field(VariantTypeField; VariantType)
                    {
                        ApplicationArea = All;
                        Caption = 'Statement Type';
                        ToolTip = 'Specifies which Pool Return variant to produce.';
                    }
                }
            }
        }
    }
    var VariantType: Enum "TAC Pool Return Variant";
}
