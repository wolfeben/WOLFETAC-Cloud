tableextension 58014 "SAL Customer Extension" extends Customer
{
    fields
    {
        field(58000; "SAL Pallet Quantity UOM"; Code[10])
        {
            Caption = 'Pallet Quantity UOM';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
            ToolTip = 'Specifies the sales-line unit of measure to which this customer''s default pallet quantity applies, such as TE or BK.';

            trigger OnValidate()
            begin
                if ("SAL Pallet Quantity UOM" = '') and ("SAL Units per Pallet" > 0) then
                    Error(PalletUomRequiredErr);
            end;
        }
        field(58001; "SAL Units per Pallet"; Decimal)
        {
            Caption = 'Units per Pallet';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies this customer''s default number of the selected units on one pallet. Detailed customer, ship-to or item rules override this value.';

            trigger OnValidate()
            begin
                if "SAL Units per Pallet" > 0 then
                    TestField("SAL Pallet Quantity UOM");
            end;
        }
    }

    var
        PalletUomRequiredErr: Label 'Clear Units per Pallet before clearing the Pallet Quantity UOM.';
}
