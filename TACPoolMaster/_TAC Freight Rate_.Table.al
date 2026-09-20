table 50202 "TAC Freight Rate"
{
    Caption = 'Freight Rate';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Shipping Agent Code"; Code[10])
        {
            Caption = 'Shipping Agent Code';
            TableRelation = "Shipping Agent".Code;
            ToolTip = 'Specifies the shipping agent (carrier) for this freight rate.';
        }
        field(2; "From Freight Location"; Code[20])
        {
            Caption = 'From Freight Location';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies the origin freight location for this rate.';
        }
        field(3; "To Freight Location"; Code[20])
        {
            Caption = 'To Freight Location';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies the destination freight location for this rate.';
        }
        field(4; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            ToolTip = 'Specifies the date this freight rate starts being effective.';
            trigger OnValidate()
            begin
                ValidateDateRange();
            end;
        }
        field(5; "Ending Date"; Date)
        {
            Caption = 'Ending Date';
            ToolTip = 'Specifies the date this freight rate stops being effective. Leave blank for open-ended.';
            trigger OnValidate()
            begin
                ValidateDateRange();
            end;
        }
        field(6; "Pallet Space Rate"; Decimal)
        {
            Caption = 'Pallet Space Rate';
            ToolTip = 'Specifies the base rate per pallet space, excluding GST and fuel surcharge.';
        }
        field(7; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            TableRelation = Currency.Code;
            ToolTip = 'Specifies the currency code for the freight rate. Leave blank for local currency.';
        }
        field(8; Blocked; Boolean)
        {
            Caption = 'Blocked';
            ToolTip = 'Specifies whether this freight rate row is blocked from use.';
        }
    }

    keys
    {
        key(PK; "Shipping Agent Code", "From Freight Location", "To Freight Location", "Starting Date")
        {
            Clustered = true;
        }
    }
    trigger OnInsert()
    begin
        TestField("Shipping Agent Code");
        TestField("From Freight Location");
        TestField("To Freight Location");
        ValidateDateRange();
    end;

    procedure ValidateDateRange()
    var
        FreightRate: Record "TAC Freight Rate";
    begin
        FreightRate.SetRange("Shipping Agent Code", "Shipping Agent Code");
        FreightRate.SetRange("From Freight Location", "From Freight Location");
        FreightRate.SetRange("To Freight Location", "To Freight Location");

        if "Ending Date" <> 0D then
            FreightRate.SetFilter("Starting Date", '<=%1', "Ending Date");

        if "Starting Date" <> 0D then
            FreightRate.SetFilter("Ending Date", '>=%1', "Starting Date");

        if not FreightRate.IsEmpty() then
            Error(ErrOverlappingLocation, "Starting Date", "Ending Date");
    end;

    var
        ErrOverlappingLocation: Label 'Date range %1 to %2 overlaps an existing unblocked row for the same agent and route';
}