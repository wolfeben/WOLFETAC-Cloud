tableextension 50206 "TAC Trans. Header Ext." extends "Transfer Header"
{
    trigger OnBeforeInsert()
    var
        NoSeries: Codeunit "No. Series";
    begin
        if "DIY_Consignment No." = '' then begin
            PoolSetup.Get();
            PoolSetup.TestField("Consignment Nos.");
            "DIY_Consignment No." := NoSeries.GetNextNo(PoolSetup."Consignment Nos.");
        end;
    end;

    var
        PoolSetup: Record "TAC Pool Setup";
}
