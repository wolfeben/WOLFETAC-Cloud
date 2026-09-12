# Branded Pooling UI contract (0.4.0.0)

User requested matching Batch Labels branding. Upload remains paused. Canonical project D:\WOLFETAC\Cloud\PoolReview. No engine changes; use existing Reader and Rules. Existing native page59300 retained as standard view (caption Pooling Review List); new branded page59303 WLF Pooling Workspace caption Pooling Overview. Controladdin WLF Pool Review Workspace UI. All data still temporary. No extra database tables.

Root owns protocol, version/build/guards, previews, asset copies, docs.
Frontend owns only ui/pooling.js, ui/pooling.css, ui/startup.js.
Backend owns only src/Page/PoolingWorkspace.Page.al, src/ControlAddIn/PoolingWorkspace.ControlAddIn.al, src/PermissionSet/PoolReview.PermissionSet.al and changing native page59300 Caption/AdditionalSearchTerms only as necessary to distinguish; no other nativepage changes.
Do not publish or make engine fixes.

AL controladdin methods: SetState(StateJson: Text).
Events: Ready(); ActionRequested(ActionName: Text; Payload: Text).
AL uses one handler with allowlisted actions, typed JSON inputs, no source writes; catches read failures and returns explicit error. Every action ends by sending a full state. Backend should always send explicit failure feedback on source/schema/access errors. No raw unhandled errors leave frontend busy indefinitely.

Client actions:
- scope payload {season:"" or exact code,week:"" or exact code,type:-1/0/1/2,focus:-1/0/1/2/3/4} (server validates supported type/focus; use exact SetRange, not expression parsing)
- select {groupId:integer}
- check {groupId:integer}
- batch {} (current focused list, max50 IDs captured before scan)
- reload {} (reload group metadata, discards session results; preserve season/week/type, reset focus toall)
- source {issueId:integer,related:boolean} opens Reader.ShowEvidence from matching issue in current selected group
- groupSource {groupId:integer} opens Reader.ShowEvidence from in-memory group evidence
- standard {} optional opens page59300 standard UI if supported.

SetState JSON (frontend may tolerate missing optional fields but never invent financial totals):
{
version:"0.4.0.0", company:string, environment:string,
scope:{season:string,week:string,type:integer,focus:integer},
options:{seasons:[string],weeks:[{code:string,season:string,number:integer}]},
summary:{all:integer,unchecked:integer,mismatches:integer,review:integer,unable:integer,clear:integer,latestScanText:string},
groups:[{
id:integer,code:string,season:string,week:string,typeCaption:string,businessStatus:string,
bucket:integer,status:string,scanComplete:boolean,poolCount:integer,movementKg:decimal,allKg:decimal,
ledgerNet:decimal,mismatchCount:integer,warningCount:integer,unresolvedCount:integer,
lastScanText:string,detail:string,invoiceCandidates:integer,attributedInvoices:integer,
ledgerCount:integer,paymentCount:integer
}],
selectedId:integer, issues:[{
id:integer,groupId:integer,rule:string,severity:integer,summary:string,details:string,pool:string,grower:string,
document:string,line:integer,payment:integer,expected:decimal,actual:decimal,measure:string,
canSource:boolean,canRelated:boolean
}],
shown:integer,total:integer,hasMore:boolean,coverage:string,message:string,error:boolean
}
Group bucket priority: neverchecked(ScannedAt0)=0; failedincomplete=3; completeerrorcount>0=1; completewarningorunresolved=2; completeotherwise=4.
Summary counts apply current season/week/type (ignore focus). Five buckets partition summary.all. List applies focus too. Limit transmitted list to200 rows and send total/hasMore (no apparent completeness); summary/batchusewholefilteredset. Select/currentissues onlycurrentselectedgroup. After filters selectfirstmatchingrow ifselectedoutside; ifno matching clearselected/issues.
Expose numeric group counters asnumber; frontend displays '-' when !scanComplete. Failed/unscanned must not present0asmeasured.
Environmentvia standard Environment Information codeunit optional ifrequires sourceunknownomitnoninvent.
Dates already formatted server strings no client parsing.
Issues are selectedgroup only; upperbounde.g500 with explicit issueTotal/issueHasMore optional ifneededavoidhugepayload. Include details directly; sourcebuttonsopenonlysupportedlinkedRecordID.

Brand copied assets will be ui/images/avocado-mark.png and ui/images/avocado-wordmark.png. Controladdin Images mustinclude both. Use Microsoft.Dynamics.NAV.GetImageResource forresourceURLs, no externalassets/network. Palette navy #002447/#003158, blue #064976/#0b5b91, brandred #f42f24/#d9251c, page #f5f7fa, ink #0d2745, line #d7dee7, whitecards. SegoeUI. Full logo masthead + compactnavyfooter inspiredexistinglabels. Roundedcards and generouscontrols. Readonlycompany/environment/lastscanfooterlabels (no printer/production controls). Preserve clear error/mismatch/unchecked labels. No greenreadytopaystatus.

JS API for testing: window.PoolReviewWorkspace.start() invoked by startup.js; window.SetState(StateJson) called byAL. JS renders under #controlAddIn or explicitlyset previewroot. No sampledata inproductionJS; no NAVavailable showsnotconnected and keepsactionsdisabled. Rootpreview will supply fake NAV bridge and sampledata external toproductionassets. Userinput &servertextmustbe escaped / textContent topreventHTMLinjection. Disable actionswhilebridgeoperationpending; errorcallback restorecontrols andshowerror. RenderinvalidJSONfailsclosedwithexpliciterror. No fetch/XHR/WebSocket, no writes exceptUI/ALsessionbuffers.



Version 0.4 additions:
- payments {groupId:int}: selected visible group only; independently loads bounded payment headers with explicit failure handling.
- paymentSource {paymentId:int}: ID must occur in the currently loaded selected-group payment list; reader rechecks current live group ownership before showing evidence.
- report {kind:"overview"|"findings"}: uses all server-filtered group snapshots, not the transmitted-row subset. Does not run scans. Local text search disables report buttons. CSV metadata includes incomplete group count and limits; findings above 50,000 fail before download.
- paymentExport {}: exports only the selected group's successful loaded payment snapshot, maximum 200 rows, with total/truncation metadata.
- State.payments is {} before load or after selection changes, otherwise {groupId,loaded,loadedAt,rows,total,hasMore,error}. On failure loaded=false, rows=[], error is explicit. Rows contain {id,groupId,number,type,pool,provisional,status,reversed,reversedBy,closedAt,completedAt,closedBy,completedBy,journalBatch,invoiceReferences}. All identifiers are server-verified. No monetary settlement claims are derived from these header fields.

Codeunit 59302 WLF Pool Review Export produces UTF-8 CSV through Temp Blob / DownloadFromStream, with no source writes. New Reader.PaymentHistory and Reader.ShowPaymentEvidence use the existing schema-checked RecordRef access to table50233; additional display fields are checked only for payment-history reads. Payment history is separate from the check snapshot and carries its own load time.
