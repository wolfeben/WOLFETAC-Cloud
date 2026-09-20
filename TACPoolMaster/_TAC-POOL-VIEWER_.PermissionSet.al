permissionset 50299 "TAC-POOL-VIEWER"
{
    Assignable = true;
    Caption = 'Pool Viewer';

    // Read-only data + page/report execute. Deliberately EXCLUDES execute on
    // close (50273), adjust (50274), expense (50275), and GL posting (50279)
    // (design §10.2) — viewers cannot close, adjust, or expense. The remaining
    // codeunits (engine/posting seams, subscribers, install) run in system
    // context and are granted execute so read flows resolve.
    Permissions =
        tabledata "TAC Pool Week" = R,
        tabledata "TAC Pool Trans Type" = R,
        tabledata "TAC Pool Charge Template" = R,
        tabledata "TAC Pool Chg Tmpl Grade Excl" = R,
        tabledata "TAC Grower GL Override" = R,
        tabledata "TAC Pool Setup" = R,
        tabledata "TAC Pool Group Header" = R,
        tabledata "TAC Pool" = R,
        tabledata "TAC Pool Ledger Entry" = R,
        tabledata "TAC Pool Payment Header" = R,
        tabledata "TAC Pool Adjustment" = R,
        tabledata "TAC Pool Expense Header" = R,
        tabledata "TAC Pool Expense Detail" = R,
        tabledata "TAC Pool Grower Charge" = R,
        tabledata "TAC Pool Reconciliation" = R,
        tabledata "TAC Pool Recon Line" = R,
        page "TAC Pool Group List" = X,
        page "TAC Pool Group Card" = X,
        page "TAC Pool Subpage" = X,
        page "TAC Pool Ledger Entries" = X,
        page "TAC Pool Adjustment" = X,
        page "TAC Pool Expense" = X,
        page "TAC Pool Expense Detail Sub" = X,
        page "TAC Pool Trans Types" = X,
        page "TAC Pool Charge Template" = X,
        page "TAC Pool Weeks" = X,
        page "TAC Grower GL Overrides" = X,
        page "TAC Pool Grower Charges" = X,
        page "TAC Pool Setup" = X,
        page "TAC Pool Charge Preview" = X,
        page "TAC Pool Reconciliation List" = X,
        page "TAC Pool Reconciliation Card" = X,
        page "TAC Pool Recon Lines" = X,
        codeunit "TAC Pool Charge Engine" = X,
        codeunit "TAC Pool Prod Order Post" = X,
        codeunit "TAC Pool Consignment Post" = X,
        codeunit "TAC Pool Dimension Mgt" = X,
        codeunit "TAC Pool Grower Mgt" = X,
        codeunit "TAC Pool Consumption Grower" = X,
        codeunit "TAC Pool Vendor Grower Sync" = X,
        codeunit "TAC Pool Post Diagnostic" = X,
        codeunit "TAC Pool Preview" = X,
        codeunit "TAC Pool Subscribers" = X,
        codeunit "TAC Pool Install" = X,
        report "TAC Pool Return" = X,
        report "TAC Pool Group Summary" = X,
        report "TAC Open Pool Balance" = X;
}
