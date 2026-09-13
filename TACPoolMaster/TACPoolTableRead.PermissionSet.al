permissionset 50297 "TAC-POOL-TABLE-READ"
{
    Assignable = false;
    Caption = 'Pool table read definitions';
    // Packaging coverage only. Not included in or assigned to any user role.
    Permissions =
        tabledata "TAC Carrier Manifest" = R,
        tabledata "TAC Consignment Freight Leg" = R,
        tabledata "TAC Consignment Fruit Payment" = R,
        tabledata "TAC Consignment Header" = R,
        tabledata "TAC Consignment Line" = R,
        tabledata "TAC Freight Loc. Market Rule" = R,
        tabledata "TAC Freight Location" = R,
        tabledata "TAC Freight Rate" = R,
        tabledata "TAC Grower GL Override" = R,
        tabledata "TAC Grower Market Rule" = R,
        tabledata "TAC Market Rule" = R,
        tabledata "TAC Pool" = R,
        tabledata "TAC Pool Adjustment" = R,
        tabledata "TAC Pool Charge Context" = R,
        tabledata "TAC Pool Charge Evaluation" = R,
        tabledata "TAC Pool Charge Preview" = R,
        tabledata "TAC Pool Charge Rate" = R,
        tabledata "TAC Pool Charge Template" = R,
        tabledata "TAC Pool Charge Type" = R,
        tabledata "TAC Pool Chg Tmpl Grade Excl" = R,
        tabledata "TAC Pool Credit Memo State" = R,
        tabledata "TAC Pool Expense Detail" = R,
        tabledata "TAC Pool Expense Header" = R,
        tabledata "TAC Pool Group Header" = R,
        tabledata "TAC Pool Grower Charge" = R,
        tabledata "TAC Pool Invoice Post State" = R,
        tabledata "TAC Pool Ledger Entry" = R,
        tabledata "TAC Pool Payment Header" = R,
        tabledata "TAC Pool Payment Schedule" = R,
        tabledata "TAC Pool Recon Line" = R,
        tabledata "TAC Pool Reconciliation" = R,
        tabledata "TAC Pool Setup" = R,
        tabledata "TAC Pool Trans Type" = R,
        tabledata "TAC Pool Week" = R,
        tabledata "TAC Ripening Price" = R;
}

