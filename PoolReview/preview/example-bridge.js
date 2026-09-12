(function () {
'use strict';
const buckets=['Not checked','Mismatches','Needs review','Unable to check','No exception in checked scope'];
const groups=[
{id:101,code:'26-W36-I',season:'2026',week:'2026-W36',type:0,typeCaption:'Internal',businessStatus:'Open',bucket:1,scanComplete:true,poolCount:8,movementKg:24800,allKg:24800,ledgerNet:81240,mismatchCount:2,warningCount:0,unresolvedCount:0,lastScanText:'11/09/2026 16:30',detail:'Two recorded mismatches need investigation.',invoiceCandidates:14,attributedInvoices:10,ledgerCount:96,paymentCount:1},
{id:102,code:'26-W36-E',season:'2026',week:'2026-W36',type:1,typeCaption:'External',businessStatus:'Provisional',bucket:2,scanComplete:true,poolCount:6,movementKg:18320,allKg:54960,ledgerNet:46500,mismatchCount:0,warningCount:1,unresolvedCount:0,lastScanText:'11/09/2026 16:32',detail:'Quantity bases differ across transaction types.',invoiceCandidates:14,attributedInvoices:4,ledgerCount:71,paymentCount:1},
{id:103,code:'26-W36-G',season:'2026',week:'2026-W36',type:2,typeCaption:'Contract Pack',businessStatus:'Open',bucket:0,scanComplete:false,poolCount:0,movementKg:0,allKg:0,ledgerNet:0,mismatchCount:0,warningCount:0,unresolvedCount:0,lastScanText:'',detail:'No checks have run in this session.'},
{id:104,code:'26-W37-I',season:'2026',week:'2026-W37',type:0,typeCaption:'Internal',businessStatus:'Open',bucket:1,scanComplete:true,poolCount:5,movementKg:12400,allKg:12400,ledgerNet:42900,mismatchCount:1,warningCount:0,unresolvedCount:0,lastScanText:'11/09/2026 16:34',detail:'A source and assigned pool record different sizes.',invoiceCandidates:6,attributedInvoices:6,ledgerCount:38,paymentCount:0},
{id:105,code:'26-W37-E',season:'2026',week:'2026-W37',type:1,typeCaption:'External',businessStatus:'Open',bucket:3,scanComplete:false,poolCount:0,movementKg:0,allKg:0,ledgerNet:0,mismatchCount:0,warningCount:1,unresolvedCount:0,lastScanText:'11/09/2026 16:35',detail:'Invoice information could not be read. Partial results were discarded.'},
{id:106,code:'26-W37-G',season:'2026',week:'2026-W37',type:2,typeCaption:'Contract Pack',businessStatus:'Open',bucket:4,scanComplete:true,poolCount:3,movementKg:9400,allKg:9400,ledgerNet:12100,mismatchCount:0,warningCount:0,unresolvedCount:0,lastScanText:'11/09/2026 16:36',detail:'No exception found in the included checks.',invoiceCandidates:0,attributedInvoices:0,ledgerCount:12,paymentCount:0},
{id:107,code:'26-W35-I',season:'2026',week:'2026-W35',type:0,typeCaption:'Internal',businessStatus:'Closed',bucket:4,scanComplete:true,poolCount:9,movementKg:31900,allKg:31900,ledgerNet:0,mismatchCount:0,warningCount:0,unresolvedCount:0,lastScanText:'11/09/2026 16:28',detail:'No exception found in the included checks.',invoiceCandidates:18,attributedInvoices:18,ledgerCount:184,paymentCount:2},
{id:108,code:'26-W35-E',season:'2026',week:'2026-W35',type:1,typeCaption:'External',businessStatus:'Provisional',bucket:0,scanComplete:false,poolCount:0,movementKg:0,allKg:0,ledgerNet:0,mismatchCount:0,warningCount:0,unresolvedCount:0,lastScanText:'',detail:'No checks have run in this session.'}
];
const issues=[
{id:1,groupId:101,rule:'INV-GROUP',severity:2,summary:'Invoice revenue records a different group',details:'The invoice source was attributed to group 101, but its active revenue entry records group 99. Review the invoice and allocation history before any engine correction.',pool:'DEMO-POOL-18',grower:'DEMO-GR-02',document:'DEMO-1042',line:10000,payment:0,expected:101,actual:99,measure:'group ID',canSource:true,canRelated:true},
{id:2,groupId:101,rule:'POOL-GROUP',severity:2,summary:'Ledger group differs from its pool group',details:'The assigned pool belongs to group 101. The ledger entry records group 99. These are example records for exploring the interface.',pool:'DEMO-POOL-18',grower:'DEMO-GR-02',document:'DEMO-ADJ-07',line:10000,payment:0,expected:101,actual:99,measure:'group ID',canSource:true,canRelated:true},
{id:3,groupId:102,rule:'KG-BASIS',severity:1,summary:'Kilogram totals use different transaction bases',details:'Movement transactions total 18,320 kg. All ledger transactions total 54,960 kg. Revenue and charge entries can also carry kilograms. This is not a certified physical stock variance.',pool:'',grower:'',document:'',line:0,payment:0,expected:18320,actual:54960,measure:'raw signed kg',canSource:true,canRelated:false},
{id:4,groupId:104,rule:'SOURCE-CLASS',severity:2,summary:'Source dimensions differ from the assigned pool',details:'The source records HASS / CLASS1 / 18. The assigned pool records HASS / CLASS1 / 20. Inspect both classifications and any reassignment history.',pool:'DEMO-POOL-27',grower:'DEMO-GR-04',document:'DEMO-PRD-18',line:10000,payment:0,expected:0,actual:0,measure:'variety / grade / size',canSource:true,canRelated:true},
{id:5,groupId:105,rule:'SCAN-FAILED',severity:1,summary:'Scan could not complete',details:'Read permission for posted invoice information was unavailable in this example. Partial results are discarded. The group is not a completed check.',pool:'',grower:'',document:'',line:0,payment:0,expected:0,actual:0,measure:'',canSource:false,canRelated:false}
];
const paymentRows=[
{id:301,groupId:101,number:1,type:'Provisional',pool:'DEMO-POOL-18',provisional:true,status:'Run completed',reversed:false,reversedBy:0,closedAt:'10/09/2026 14:05',completedAt:'10/09/2026 14:08',closedBy:'DEMO USER',completedBy:'DEMO USER',journalBatch:'POOL-DEMO',invoiceReferences:'DEMO-PINV-0041, DEMO-PINV-0042'},
{id:302,groupId:102,number:1,type:'Provisional',pool:'DEMO-POOL-23',provisional:true,status:'Completion not recorded',reversed:false,reversedBy:0,closedAt:'11/09/2026 09:15',completedAt:'',closedBy:'DEMO USER',completedBy:'',journalBatch:'POOL-DEMO',invoiceReferences:'DEMO-PINV-0050'},
{id:290,groupId:107,number:1,type:'Provisional',pool:'DEMO-POOL-09',provisional:true,status:'Reversed',reversed:true,reversedBy:291,closedAt:'04/09/2026 11:20',completedAt:'04/09/2026 11:22',closedBy:'DEMO USER',completedBy:'DEMO USER',journalBatch:'POOL-DEMO',invoiceReferences:'DEMO-PINV-0018'},
{id:291,groupId:107,number:2,type:'Final',pool:'DEMO-POOL-09',provisional:false,status:'Run completed',reversed:false,reversedBy:0,closedAt:'07/09/2026 15:00',completedAt:'07/09/2026 15:04',closedBy:'DEMO USER',completedBy:'DEMO USER',journalBatch:'POOL-DEMO',invoiceReferences:'DEMO-PINV-0023'}
];
let payments={};
let scope={season:'2026',week:'',type:-1,focus:-1}, selected=101;
function currentRows(ignoreFocus){return groups.filter(g=>(!scope.season||g.season===scope.season)&&(!scope.week||g.week===scope.week)&&(scope.type<0||g.type===scope.type)&&(ignoreFocus||scope.focus<0||g.bucket===scope.focus));}
function state(message,error){
const scoped=currentRows(true),rows=currentRows(false);if(!rows.some(g=>g.id===selected))selected=rows.length?rows[0].id:0;
if(payments.groupId!==selected)payments={};
const summary={all:scoped.length,unchecked:0,mismatches:0,review:0,unable:0,clear:0,latestScanText:'Example session'};
scoped.forEach(g=>summary[['unchecked','mismatches','review','unable','clear'][g.bucket]]++);
return {version:'0.4.0.1',company:'The Avocado Collective — example data',environment:'LOCAL PREVIEW',scope:Object.assign({},scope),options:{seasons:['2026'],weeks:[{code:'2026-W35',season:'2026',number:35},{code:'2026-W36',season:'2026',number:36},{code:'2026-W37',season:'2026',number:37}]},summary,payments,groups:rows.map(g=>Object.assign({},g,{status:buckets[g.bucket]})),selectedId:selected,issues:issues.filter(x=>x.groupId===selected),shown:rows.length,total:rows.length,hasMore:false,issueTotal:issues.filter(x=>x.groupId===selected).length,issueHasMore:false,coverage:'Included: visible pool and ledger ownership, available product classification, raw signed kilogram bases, invoice identity and payment indicators. Outside this version: full production-source, tax, freight, charge-template, market-rule and purchase-document reconciliation. Results are session snapshots, not approval to pay or close.',message:message||'Example data only. This preview is not connected to Business Central.',error:!!error};
}
function respond(msg,err){window.SetState(JSON.stringify(state(msg,err)));}
window.Microsoft={Dynamics:{NAV:{
GetImageResource:function(name){return window.poolPreviewImages&&window.poolPreviewImages[name]||name;},
InvokeExtensibilityMethod:function(event,args,skip,success,failure){
try{
if(event==='Ready'){respond();if(success)success();return;}
if(event!=='ActionRequested')throw new Error('Unsupported preview event');
const action=args[0],payload=JSON.parse(args[1]||'{}');let message='Example data only. This preview is not connected to Business Central.';
if(action==='scope'){scope={season:String(payload.season||''),week:String(payload.week||''),type:Number(payload.type),focus:Number(payload.focus)};}
else if(action==='select'){selected=Number(payload.groupId);}
else if(action==='check'||action==='batch'){message='Preview only: no Business Central scan was run. Example results are unchanged.';}
else if(action==='reload'){payments={};message='Preview refreshed. Example data only; no Business Central records were read.';}
else if(action==='groupSource'){message='Example group '+payload.groupId+'. The installed BC page opens its read-only source fields here.';}
else if(action==='source'){const issue=issues.find(x=>x.id===Number(payload.issueId)&&x.groupId===selected);if(!issue)throw new Error('No issue selected');message='Example evidence: '+issue.summary+'. '+issue.details+' In BC this opens the linked record.';}
else if(action==='payments'){
if(Number(payload.groupId)!==selected)throw new Error('Select the group first');
if(selected===105){payments={groupId:selected,loaded:false,loadedAt:'',rows:[],total:0,hasMore:false,error:'Example: payment header read permission is unavailable.'};}
else {const list=paymentRows.filter(p=>p.groupId===selected);payments={groupId:selected,loaded:true,loadedAt:'11/09/2026 17:05 — example',rows:list,total:list.length,hasMore:false,error:''};}
message='Example payment history only. No Business Central records were read.';
}
else if(action==='paymentSource'){if(!payments.rows||!payments.rows.some(p=>p.id===Number(payload.paymentId)))throw new Error('Load this payment first');message='Example payment header '+payload.paymentId+'. In BC this opens the selected payment header fields.';}
else if(action==='report'||action==='paymentExport'){message='Preview only: no report was downloaded. In BC this downloads a CSV of '+(action==='paymentExport'?'the loaded payment headers':payload.kind+' results in the current scope')+'.';}
else if(action==='standard'){message='Preview only: the installed extension can open the standard review list.';}
else throw new Error('Unsupported preview action');
respond(message);if(success)success();
}catch(e){respond('Preview error: '+e.message,true);if(failure)failure(e);}
}
}}};
})();
