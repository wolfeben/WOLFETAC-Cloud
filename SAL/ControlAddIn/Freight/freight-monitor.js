(function () {
    'use strict';

    const state = {
        data: { schemaVersion: 1, summary: {}, items: [] },
        selectedId: '',
        query: '',
        direction: 'all',
        view: 'all'
    };
    let elements = {};

    function text(value) {
        return value == null ? '' : String(value);
    }

    function escapeHtml(value) {
        return text(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function number(value) {
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed.toLocaleString('en-AU', { maximumFractionDigits: 1 }) : '0';
    }

    function dateLabel(value) {
        if (!value)
            return 'Not supplied';
        const parts = text(value).slice(0, 10).split('-');
        if (parts.length !== 3)
            return text(value);
        const parsed = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        if (Number.isNaN(parsed.getTime()))
            return text(value);
        return new Intl.DateTimeFormat('en-AU', { day: '2-digit', month: 'short', year: 'numeric' }).format(parsed);
    }

    function statusKey(value) {
        return text(value).toLowerCase().replace(/[^a-z0-9]+/g, '-');
    }

    function invoke(name, args) {
        if (!globalThis.Microsoft || !Microsoft.Dynamics || !Microsoft.Dynamics.NAV ||
            typeof Microsoft.Dynamics.NAV.InvokeExtensibilityMethod !== 'function')
            return false;
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(name, args || [], false);
        return true;
    }

    function buildShell() {
        const host = document.getElementById('controlAddIn') || document.body;
        host.innerHTML = [
            '<div class="frm-app">',
                '<header class="frm-header">',
                    '<div class="frm-brand"><span class="frm-mark">TAC</span><span><strong>Freight &amp; Arrivals Monitor</strong><small id="frm-company">Business Central</small></span></div>',
                    '<div class="frm-actions"><span class="frm-chip is-cloud">Cloud concept</span><button class="frm-button" data-action="refresh" type="button">Refresh</button></div>',
                '</header>',
                '<section class="frm-concept">',
                    '<div><strong>Workflow concept for Luke</strong><span>Current orders, transfer movements and posted shipments are live BC data. Booking milestones, carrier ETA and pallet/FruitBank movement events remain clearly marked until their authoritative source is agreed.</span></div>',
                    '<span class="frm-chip is-warning">Read only · no freight records created</span>',
                '</section>',
                '<section class="frm-kpis" id="frm-kpis"></section>',
                '<nav class="frm-tabs" id="frm-tabs">',
                    '<button type="button" data-view="all" aria-pressed="true">All movements</button>',
                    '<button type="button" data-view="forward" aria-pressed="false">Forward bookings</button>',
                    '<button type="button" data-view="inter-dc" aria-pressed="false">Pallet / inter-DC</button>',
                    '<button type="button" data-view="dispatched" aria-pressed="false">Dispatched</button>',
                    '<button type="button" data-view="arrived" aria-pressed="false">Arrived</button>',
                    '<button type="button" data-view="inbound" aria-pressed="false">Inbound arrivals</button>',
                    '<button type="button" data-view="exceptions" aria-pressed="false">Data gaps</button>',
                '</nav>',
                '<div class="frm-layout">',
                    '<aside class="frm-queue">',
                        '<div class="frm-search"><span>⌕</span><input id="frm-search" type="search" placeholder="Order, carrier, destination or reference"></div>',
                        '<div class="frm-directions" id="frm-directions">',
                            '<button type="button" data-direction="all" aria-pressed="true">All</button>',
                            '<button type="button" data-direction="outbound" aria-pressed="false">Outbound</button>',
                            '<button type="button" data-direction="inbound" aria-pressed="false">Inbound</button>',
                            '<button type="button" data-direction="inter-dc" aria-pressed="false">Inter-DC</button>',
                        '</div>',
                        '<div class="frm-queue-head"><strong>Movement queue</strong><span id="frm-count">0</span></div>',
                        '<div class="frm-list" id="frm-list"></div>',
                    '</aside>',
                    '<main class="frm-detail" id="frm-detail"></main>',
                '</div>',
                '<div class="frm-toast" id="frm-toast"></div>',
            '</div>'
        ].join('');

        elements = {
            host: host,
            company: host.querySelector('#frm-company'),
            kpis: host.querySelector('#frm-kpis'),
            tabs: host.querySelector('#frm-tabs'),
            search: host.querySelector('#frm-search'),
            directions: host.querySelector('#frm-directions'),
            count: host.querySelector('#frm-count'),
            list: host.querySelector('#frm-list'),
            detail: host.querySelector('#frm-detail'),
            toast: host.querySelector('#frm-toast')
        };
        host.addEventListener('click', handleClick);
        host.addEventListener('input', handleInput);
    }

    function applyState(stateJson, statusMessage, isError) {
        let parsed = null;
        try {
            parsed = stateJson ? JSON.parse(stateJson) : null;
        } catch (_error) {
            parsed = null;
        }
        if (!parsed || Number(parsed.schemaVersion) !== 1 || !Array.isArray(parsed.items)) {
            showToast('Business Central returned an unexpected freight projection.', true);
            return;
        }
        state.data = parsed;
        if (!state.selectedId || !parsed.items.some(function (item) { return text(item.id) === state.selectedId; }))
            state.selectedId = parsed.items.length ? text(parsed.items[0].id) : '';
        renderAll();
        if (statusMessage)
            showToast(statusMessage, Boolean(isError));
    }

    function showToast(message, isError) {
        if (!elements.toast || !message)
            return;
        elements.toast.textContent = message;
        elements.toast.classList.toggle('is-error', Boolean(isError));
        elements.toast.classList.add('is-visible');
        window.clearTimeout(elements.toast.timer);
        elements.toast.timer = window.setTimeout(function () { elements.toast.classList.remove('is-visible'); }, 4500);
    }

    function renderAll() {
        elements.company.textContent = text(state.data.company || 'Business Central') + ' · as at ' + text(state.data.asOf || 'now');
        renderKpis();
        renderList();
        renderDetail();
    }

    function renderKpis() {
        const summary = state.data.summary || {};
        const cards = [
            ['Forward demand', summary.forwardCount, 'Orders and transfers still requiring a freight journey'],
            ['Carrier reference', summary.referenceCount, 'Reference recorded in BC; this does not prove a booking'],
            ['In transit', summary.inTransitCount, 'Transfer quantities currently recorded in transit by BC'],
            ['Dispatched', summary.dispatchedCount, 'Posted Sales Shipments in the last 60 days'],
            ['Arrived', summary.arrivedCount, 'Posted Transfer and Purchase Receipts in the last 60 days'],
            ['Expected ≤ 7 days', summary.arrivingSoonCount, 'Based on BC receipt dates, not carrier ETA'],
            ['Live tracking', summary.trackingConnectedCount, 'Carrier API or webhook not connected'],
            ['Missing dates', summary.missingDateCount, 'Documents requiring planning attention']
        ];
        elements.kpis.innerHTML = cards.map(function (card, index) {
            return '<article class="frm-kpi' + (index === 4 ? ' is-muted' : '') + '"><span>' +
                escapeHtml(card[0]) + '</span><strong>' + escapeHtml(number(card[1])) + '</strong><small>' +
                escapeHtml(card[2]) + '</small></article>';
        }).join('');
    }

    function isDataGap(item) {
        if (statusKey(item.stage) === 'arrived')
            return false;
        const carrierMissing = !item.carrier || text(item.carrier).toLowerCase().indexOf('not supplied') >= 0;
        const dateMissing = !item.etd && !item.eta && !item.actualArrival;
        return carrierMissing || dateMissing;
    }

    function matchesView(item) {
        if (state.view === 'all') return true;
        if (state.view === 'forward') return ['Sales Order', 'Transfer Order', 'Purchase Order'].indexOf(item.sourceType) >= 0;
        if (state.view === 'inter-dc') return statusKey(item.direction) === 'inter-dc';
        if (state.view === 'dispatched') return item.sourceType === 'Posted Sales Shipment';
        if (state.view === 'arrived') return statusKey(item.stage) === 'arrived';
        if (state.view === 'inbound') return statusKey(item.direction) === 'inbound';
        if (state.view === 'exceptions') return isDataGap(item);
        return true;
    }

    function filteredItems() {
        const query = state.query.trim().toLowerCase();
        return (state.data.items || []).filter(function (item) {
            const directionMatch = state.direction === 'all' || statusKey(item.direction) === state.direction;
            const haystack = [item.documentNo, item.relatedDocumentNo, item.party, item.origin, item.destination,
                item.carrier, item.bookingReference, item.stage, item.salPlanNo].join(' ').toLowerCase();
            return directionMatch && matchesView(item) && (!query || haystack.indexOf(query) >= 0);
        }).sort(function (a, b) {
            const aDate = text(a.actualArrival || a.eta || a.etd || '9999-12-31');
            const bDate = text(b.actualArrival || b.eta || b.etd || '9999-12-31');
            return aDate.localeCompare(bDate);
        });
    }

    function renderList() {
        const items = filteredItems();
        elements.count.textContent = String(items.length);
        if (!items.length) {
            elements.list.innerHTML = '<div class="frm-empty">No movements match this view.</div>';
            elements.detail.innerHTML = '<div class="frm-empty is-large">Adjust a filter or refresh Business Central.</div>';
            return;
        }
        if (!items.some(function (item) { return text(item.id) === state.selectedId; }))
            state.selectedId = text(items[0].id);
        elements.list.innerHTML = items.map(function (item) {
            const selected = text(item.id) === state.selectedId;
            const badge = item.sourceType.indexOf('Receipt') >= 0 ? 'RCPT' : item.sourceType === 'Posted Sales Shipment' ? 'SHIP' :
                item.sourceType === 'Purchase Order' ? 'PO' : item.sourceType === 'Transfer Order' ? 'TO' : 'SO';
            return [
                '<button type="button" class="frm-row', selected ? ' is-selected' : '', '" data-action="select" data-id="', escapeHtml(item.id), '">',
                    '<span class="frm-source">', escapeHtml(badge), '</span>',
                    '<span class="frm-row-main"><strong>', escapeHtml(item.documentNo), ' · ', escapeHtml(item.party || 'Party not supplied'), '</strong>',
                    '<small>', escapeHtml(item.origin || 'Origin not supplied'), ' → ', escapeHtml(item.destination || 'Destination not supplied'), '</small>',
                    '<span class="frm-row-meta"><span class="frm-tag is-', escapeHtml(statusKey(item.stage)), '">', escapeHtml(item.stage), '</span>',
                    '<span>', escapeHtml(item.direction), '</span><span>', escapeHtml(item.actualArrival ? 'Arrived ' + dateLabel(item.actualArrival) : item.eta ? 'Planned ' + dateLabel(item.eta) : 'ETD ' + dateLabel(item.etd)), '</span></span></span>',
                '</button>'
            ].join('');
        }).join('');
    }

    function selectedItem() {
        return (state.data.items || []).find(function (item) { return text(item.id) === state.selectedId; }) || null;
    }

    function renderDetail() {
        const item = selectedItem();
        if (!item) {
            elements.detail.innerHTML = '<div class="frm-empty is-large">Select a movement.</div>';
            return;
        }
        const isPosted = item.sourceType === 'Posted Sales Shipment';
        const isInbound = statusKey(item.direction) === 'inbound';
        const hasArrived = Boolean(item.actualArrival);
        const hasReference = Boolean(item.bookingReference);
        const linkedPlan = item.salPlanNo || 'Not linked';
        const commercialInvoiceType = item.commercialInvoiceType || 'Commercial invoice';
        const commercialInvoiceNo = item.commercialInvoiceNo || (commercialInvoiceType === 'Not applicable' ? 'Not applicable' : 'Not posted / not linked');
        const commercialInvoiceCount = Number(item.commercialInvoiceCount || 0);
        const commercialInvoiceNote = commercialInvoiceCount > 1 ?
            'Latest of ' + commercialInvoiceCount + ' linked posted invoices' :
            item.commercialInvoiceNo ? 'Matched through the related BC order or posted movement' : 'No posted commercial invoice link found';
        const commercialInvoiceSourceType = commercialInvoiceType === 'Customer invoice' ? 'Posted Sales Invoice' :
            commercialInvoiceType === 'Supplier goods invoice' ? 'Posted Purchase Invoice' : '';
        const commercialInvoiceAction = item.commercialInvoiceNo && commercialInvoiceSourceType ?
            '<button class="frm-button frm-panel-action" type="button" data-action="open-source" data-source-type="' +
                escapeHtml(commercialInvoiceSourceType) + '" data-document-no="' + escapeHtml(item.commercialInvoiceNo) + '">Open posted invoice</button>' : '';
        elements.detail.innerHTML = [
            '<section class="frm-detail-head">',
                '<div><span class="frm-eyebrow">', escapeHtml(item.direction), ' · ', escapeHtml(item.sourceType), '</span>',
                '<h1>', escapeHtml(item.documentNo), ' · ', escapeHtml(item.party || 'Party not supplied'), '</h1>',
                '<p>', escapeHtml(item.origin || 'Origin not supplied'), ' → ', escapeHtml(item.destination || 'Destination not supplied'), '</p></div>',
                '<div class="frm-detail-actions"><span class="frm-chip">', escapeHtml(item.marketer || 'Marketer not confirmed'), '</span>',
                '<button class="frm-button is-primary" type="button" data-action="open-source" data-source-type="', escapeHtml(item.sourceType), '" data-document-no="', escapeHtml(item.documentNo), '">Open BC source</button></div>',
            '</section>',
            '<section class="frm-journey">',
                journeyStep('Demand / booking', true, item.sourceType + ' · ' + item.status),
                journeyStep('Carrier / reference recorded', hasReference || (item.carrier && item.carrier !== 'Not supplied'), hasReference ? item.bookingReference : item.carrier),
                journeyStep('Dispatched', isPosted, isPosted ? dateLabel(item.etd) : 'Awaiting posted movement'),
                journeyStep('Arrived', hasArrived, hasArrived ? dateLabel(item.actualArrival) : isInbound && item.eta ? 'Planned / expected ' + dateLabel(item.eta) : 'Arrival event not connected'),
            '</section>',
            '<section class="frm-grid">',
                metricCard('Planned departure', dateLabel(item.etd), item.dateSource || 'BC document'),
                metricCard(hasArrived ? 'Actual arrival' : 'Planned / expected arrival', hasArrived ? dateLabel(item.actualArrival) : dateLabel(item.eta), hasArrived ? item.dateSource : item.eta ? item.dateSource : 'Carrier ETA not connected'),
                metricCard('Carrier', item.carrier || 'Not supplied', item.service || 'Service not supplied'),
                metricCard('Reference / tracking', item.bookingReference || 'Not supplied', item.connectionState || 'Not connected'),
                metricCard('Outstanding / moved quantity', number(item.quantity), number(item.lineCount) + ' item lines · source units'),
                metricCard('Linked SAL plan', linkedPlan, item.relatedDocumentNo ? 'Related order ' + item.relatedDocumentNo : 'No related document supplied'),
                metricCard(commercialInvoiceType, commercialInvoiceNo, commercialInvoiceNote),
                metricCard('Freight supplier invoice', item.freightInvoiceState || 'Not connected', 'Carrier charges require an agreed Finance workflow'),
            '</section>',
            '<section class="frm-panels">',
                '<article><span class="frm-eyebrow">CURRENT DATA TRUTH</span><h3>', escapeHtml(item.connectionState || 'Order data only'), '</h3><p>', escapeHtml(item.dataNote || 'No additional data note supplied.'), '</p></article>',
                '<article><span class="frm-eyebrow">FINANCE &amp; INVOICE MATCHING</span><h3>', escapeHtml(commercialInvoiceNo), '</h3><p>', escapeHtml(commercialInvoiceNote), '. Freight supplier invoices remain separate: one invoice can cover several loads, and one load can attract carrier, port, customs or cold-store charges. Future suggested matches should require Finance approval and never auto-post.</p>', commercialInvoiceAction, '</article>',
                '<article><span class="frm-eyebrow">FUTURE CARRIER CONNECTION</span><h3>API, webhook or tracking feed</h3><p>Normalised milestones can retain the carrier event, received time, revised ETA and last successful sync without putting carrier-specific logic in this screen.</p></article>',
                '<article><span class="frm-eyebrow">PALLETS &amp; FRUITBANK</span><h3>One movement, shared physical identity</h3><p>Attach scanned pallet IDs to the load or transfer. FruitBank can then show source site, in-transit state and receiving site from the same movement events rather than duplicating stock.</p></article>',
            '</section>'
        ].join('');
    }

    function journeyStep(label, complete, detail) {
        return '<article class="frm-step' + (complete ? ' is-complete' : '') + '"><span></span><div><strong>' +
            escapeHtml(label) + '</strong><small>' + escapeHtml(detail || 'Not supplied') + '</small></div></article>';
    }

    function metricCard(label, value, note) {
        return '<article class="frm-metric"><span>' + escapeHtml(label) + '</span><strong>' + escapeHtml(value) +
            '</strong><small>' + escapeHtml(note) + '</small></article>';
    }

    function handleClick(event) {
        const target = event.target.closest('[data-action], [data-view], [data-direction]');
        if (!target) return;
        if (target.dataset.action === 'refresh') {
            invoke('RefreshRequested', []);
            return;
        }
        if (target.dataset.action === 'select') {
            state.selectedId = text(target.dataset.id);
            renderList();
            renderDetail();
            return;
        }
        if (target.dataset.action === 'open-source') {
            invoke('OpenSourceRequested', [text(target.dataset.sourceType), text(target.dataset.documentNo)]);
            return;
        }
        if (target.dataset.view) {
            state.view = target.dataset.view;
            elements.tabs.querySelectorAll('[data-view]').forEach(function (button) {
                button.setAttribute('aria-pressed', String(button === target));
            });
            renderList();
            renderDetail();
            return;
        }
        if (target.dataset.direction) {
            state.direction = target.dataset.direction;
            elements.directions.querySelectorAll('[data-direction]').forEach(function (button) {
                button.setAttribute('aria-pressed', String(button === target));
            });
            renderList();
            renderDetail();
        }
    }

    function handleInput(event) {
        if (event.target === elements.search) {
            state.query = event.target.value || '';
            renderList();
            renderDetail();
        }
    }

    globalThis.SetState = applyState;
    globalThis.SALFreightMonitorWorkspace = {
        start: function () {
            buildShell();
            renderAll();
            invoke('ControlReady', []);
        }
    };
}());
