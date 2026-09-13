table 50203 "TAC Carrier Manifest"
{
    Caption = 'Carrier Manifest';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the manifest number.';
        }
        field(2; "Shipping Agent Code"; Code[10])
        {
            Caption = 'Shipping Agent Code';
            TableRelation = "Shipping Agent".Code;
            ToolTip = 'Specifies the carrier assigned to this manifest.';

            trigger OnValidate()
            begin
                CalcFreightAmt();
            end;
        }
        field(3; "From Freight Location"; Code[20])
        {
            Caption = 'From Freight Location';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies the origin freight location on the manifest.';

            trigger OnValidate()
            begin
                CalcFreightAmt();
            end;
        }
        field(4; "To Freight Location"; Code[20])
        {
            Caption = 'To Freight Location';
            TableRelation = "TAC Freight Location".Code;
            ToolTip = 'Specifies the destination freight location on the manifest.';

            trigger OnValidate()
            begin
                CalcFreightAmt();
            end;
        }
        field(5; "Manifest Date"; Date)
        {
            Caption = 'Manifest Date';
            ToolTip = 'Specifies the manifest date used for freight rate resolution.';

            trigger OnValidate()
            begin
                CalcFreightAmt();
            end;
        }
        field(6; "Pallet Space Rate"; Decimal)
        {
            Caption = 'Pallet Space Rate';
            ToolTip = 'Specifies the pallet space rate applied to this manifest.';
        }
        field(7; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Open, Despatched, Closed;
            ToolTip = 'Specifies whether the manifest is open, despatched, or closed.';
        }
        field(8; "Carrier Invoice No."; Code[20])
        {
            Caption = 'Carrier Invoice No.';
            ToolTip = 'Specifies the carrier invoice number used for reconciliation.';
        }
        field(9; "Carrier Invoice Amount"; Decimal)
        {
            Caption = 'Carrier Invoice Amount';
            ToolTip = 'Specifies the carrier invoice amount used for variance checking.';
        }
        field(10; Blocked; Boolean)
        {
            Caption = 'Blocked';
            ToolTip = 'Specifies whether this manifest is blocked from new use.';
        }
    }
    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(AgentDate; "Shipping Agent Code", "Manifest Date")
        {
        }
    }
    trigger OnInsert()
    var
        NoSeries: Codeunit "No. Series";
        ShippingAgent: Record "Shipping Agent";
    begin
        if "No." <> '' then exit;
        ShippingAgent.Get("Shipping Agent Code");
        ShippingAgent.TestField("Manifest Nos.");
        "No.":=NoSeries.GetNextNo(ShippingAgent."Manifest Nos.");
    end;
    procedure CalcFreightAmt()
    var
        FreightRate: Record "TAC Freight Rate";
    begin
        if("Shipping Agent Code" = '') or ("From Freight Location" = '') or ("To Freight Location" = '') or ("Manifest Date" = 0D)then exit;
        FreightRate.SETRANGE("Shipping Agent Code", "Shipping Agent Code");
        FreightRate.SETRANGE("From Freight Location", "From Freight Location");
        FreightRate.SETRANGE("To Freight Location", "To Freight Location");
        FreightRate.SETRANGE(Blocked, false);
        FreightRate.SETFILTER("Starting Date", '<=%1', "Manifest Date");
        FreightRate.SETFILTER("Ending Date", '%1|>=%2', 0D, "Manifest Date");
        FreightRate.SETCURRENTKEY("Starting Date");
        if FreightRate.FindLast()then "Pallet Space Rate":=FreightRate."Pallet Space Rate";
    end;
}
