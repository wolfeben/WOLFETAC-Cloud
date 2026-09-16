(function () {
    'use strict';

    const state = {
        data: { schemaVersion: 2, summary: {}, items: [] },
        selectedId: '',
        query: '',
        direction: 'all',
        view: 'all',
        layout: 'queue',
        calendarCursor: new Date(new Date().getFullYear(), new Date().getMonth(), 1),
        compact: false,
        fullscreenPending: false,
        fullscreenNotice: ''
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

    function movementLines(item) {
        return Array.isArray(item && item.movementLines) ? item.movementLines : [];
    }

    function movementLineCode(line) {
        return text(line.itemNo || 'Item') + (line.variantCode ? ' / ' + text(line.variantCode) : '');
    }

    function movementLineQuantity(line) {
        const unit = text(line.unitOfMeasure || 'units');
        const quantity = Number(line.quantity || 0);
        const inTransit = Number(line.inTransitQuantity || 0);
        if (line.quantityBasis === 'Transfer') {
            const parts = [];
            if (quantity)
                parts.push(number(quantity) + ' ' + unit + ' outstanding');
            if (inTransit)
                parts.push(number(inTransit) + ' ' + unit + ' in transit');
            return parts.join(' · ') || '0 ' + unit;
        }
        return number(quantity) + ' ' + unit + (line.quantityBasis ? ' ' + text(line.quantityBasis).toLowerCase() : '');
    }

    function movementLinePreview(item) {
        const lines = movementLines(item);
        if (!lines.length)
            return number(item.lineCount || 0) + ' item lines';
        const shown = lines.slice(0, 2).map(function (line) {
            return movementLineCode(line) + ' · ' + movementLineQuantity(line).replace(/ (outstanding|shipped|received)$/i, '');
        });
        if (lines.length > 2)
            shown.push('+' + (lines.length - 2) + ' lines');
        return shown.join(' | ');
    }

    function movementQuantitySummary(item) {
        const totals = {};
        movementLines(item).forEach(function (line) {
            const unit = text(line.unitOfMeasure || 'units');
            const value = line.quantityBasis === 'Transfer' && Number(line.inTransitQuantity || 0) > 0 ?
                Number(line.inTransitQuantity || 0) : Number(line.quantity || 0);
            totals[unit] = (totals[unit] || 0) + value;
        });
        const units = Object.keys(totals);
        if (!units.length)
            return number(item.quantity);
        if (units.length === 1)
            return number(totals[units[0]]) + ' ' + units[0];
        return units.map(function (unit) { return number(totals[unit]) + ' ' + unit; }).join(' · ');
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

    function nav() {
        return globalThis.Microsoft && Microsoft.Dynamics && Microsoft.Dynamics.NAV;
    }

    function resource(path) {
        try {
            return nav() && typeof nav().GetImageResource === 'function' ? nav().GetImageResource(path) : path;
        } catch (_error) {
            return path;
        }
    }

    function isFullscreen() {
        return Boolean(elements.root && document.fullscreenElement === elements.root);
    }

    function syncFullscreen() {
        if (!elements.root)
            return;
        const button = elements.root.querySelector('[data-action="fullscreen"]');
        if (button) {
            button.textContent = isFullscreen() ? 'Exit full screen' : 'Full screen';
            button.setAttribute('aria-pressed', String(isFullscreen()));
            button.disabled = state.fullscreenPending;
        }
        const notice = elements.root.querySelector('#frm-fullscreen-notice');
        if (notice)
            notice.textContent = state.fullscreenNotice;
    }

    async function toggleFullscreen() {
        if (!elements.root || state.fullscreenPending)
            return;
        state.fullscreenPending = true;
        state.fullscreenNotice = '';
        syncFullscreen();
        try {
            if (isFullscreen())
                await document.exitFullscreen();
            else {
                if (!elements.root.requestFullscreen || !document.fullscreenEnabled)
                    throw new Error('Fullscreen unavailable');
                await elements.root.requestFullscreen();
            }
        } catch (_error) {
            state.fullscreenNotice = 'Full screen is unavailable here. Expand the BC page or use the browser full-screen command.';
        } finally {
            state.fullscreenPending = false;
            syncFullscreen();
        }
    }

    function toggleDensity() {
        state.compact = !state.compact;
        elements.root.classList.toggle('is-compact', state.compact);
        const button = elements.root.querySelector('[data-action="density"]');
        if (button) {
            button.textContent = state.compact ? 'Comfortable view' : 'Compact view';
            button.setAttribute('aria-pressed', String(state.compact));
        }
    }

    async function openNative(name, args) {
        if (state.fullscreenPending)
            return;
        if (isFullscreen()) {
            state.fullscreenPending = true;
            syncFullscreen();
            try {
                await document.exitFullscreen();
            } catch (_error) {
                state.fullscreenNotice = 'Exit full screen before opening a Business Central page.';
                state.fullscreenPending = false;
                syncFullscreen();
                return;
            }
            state.fullscreenPending = false;
        }
        invoke(name, args || []);
    }

    document.addEventListener('fullscreenchange', syncFullscreen);

    function invoke(name, args) {
        if (!nav() || typeof nav().InvokeExtensibilityMethod !== 'function')
            return false;
        nav().InvokeExtensibilityMethod(name, args || [], false);
        return true;
    }

    function buildShell() {
        const host = document.getElementById('controlAddIn') || document.body;
        host.innerHTML = [
            '<div class="frm-app">',
                '<header class="frm-header">',
                    '<div class="frm-brand"><img class="frm-wordmark" src="', escapeHtml(resource('ControlAddIn/Shared/images/avocado-wordmark.png')), '" alt="The Avocados Collective"></div>',
                    '<div class="frm-heading"><span class="frm-header-eyebrow">The Avocados Collective</span><strong>Packing &amp; Logistics Monitor</strong><small>See demand move from plan to packing, dispatch, transit and arrival.</small></div>',
                    '<div class="frm-actions"><div class="frm-header-buttons">',
                        '<button class="frm-header-button" data-action="density" aria-pressed="false" type="button">Compact view</button>',
                        '<button class="frm-header-button" data-action="fullscreen" aria-pressed="false" type="button">Full screen</button>',
                        '<button class="frm-header-button is-primary" data-action="refresh" type="button">Refresh</button>',
                    '</div><div class="frm-header-context"><span class="frm-live-badge">Cloud · live BC</span><span>Read-only workspace</span><span id="frm-company">Business Central</span></div>',
                    '<span class="frm-fullscreen-notice" id="frm-fullscreen-notice" role="status"></span></div>',
                '</header>',
                '<section class="frm-concept">',
                    '<div><strong>Live Business Central documents · Packing Facility feed not connected</strong><span>Follow demand from planning through dispatch, transit, arrival and invoice evidence. Facility acknowledgements, scans, completion and Unconsigned stock remain unavailable until the on-prem connection is active.</span></div>',
                    '<span class="frm-chip is-warning">Unconsigned · Not connected</span>',
                '</section>',
                '<section class="frm-kpis" id="frm-kpis"></section>',
                '<nav class="frm-tabs" id="frm-tabs">',
                    '<button type="button" data-view="all" aria-pressed="true">All movements</button>',
                    '<button type="button" data-view="packing" aria-pressed="false">Packing</button>',
                    '<button type="button" data-view="ready" aria-pressed="false">Ready</button>',
                    '<button type="button" data-view="dispatched" aria-pressed="false">Dispatched</button>',
                    '<button type="button" data-view="in-transit" aria-pressed="false">In transit</button>',
                    '<button type="button" data-view="arrived" aria-pressed="false">Arrived</button>',
                    '<button type="button" data-view="unconsigned" aria-pressed="false">Unconsigned</button>',
                    '<button type="button" data-view="exceptions" aria-pressed="false">Data gaps</button>',
                '</nav>',
                '<section class="frm-viewbar">',
                    '<div><strong>Packing &amp; logistics</strong><span>Switch between the operational queue and planned movement calendar.</span></div>',
                    '<div class="frm-view-toggle" id="frm-view-toggle">',
                        '<button type="button" data-layout="queue" aria-pressed="true">Queue &amp; details</button>',
                        '<button type="button" data-layout="calendar" aria-pressed="false">Calendar</button>',
                    '</div>',
                '</section>',
                '<div class="frm-layout" id="frm-layout">',
                    '<aside class="frm-queue">',
                        '<div class="frm-search"><span>⌕</span><input id="frm-search" type="search" placeholder="Order, plan, customer, destination or reference"></div>',
                        '<div class="frm-directions" id="frm-directions">',
                            '<button type="button" data-direction="all" aria-pressed="true">All</button>',
                            '<button type="button" data-direction="outbound" aria-pressed="false">Outbound</button>',
                            '<button type="button" data-direction="inbound" aria-pressed="false">Inbound</button>',
                            '<button type="button" data-direction="inter-dc" aria-pressed="false">Inter-DC</button>',
                        '</div>',
                        '<div class="frm-queue-head"><strong>Operational queue</strong><span id="frm-count">0</span></div>',
                        '<div class="frm-list" id="frm-list"></div>',
                    '</aside>',
                    '<main class="frm-detail" id="frm-detail"></main>',
                '</div>',
                '<section class="frm-calendar-view" id="frm-calendar-view" hidden>',
                    '<div class="frm-calendar-head">',
                        '<div><span class="frm-eyebrow">MOVEMENT CALENDAR</span><h2 id="frm-calendar-title">Calendar</h2>',
                        '<p>Planned dispatches, expected arrivals and posted arrivals from the same monitor data.</p></div>',
                        '<div class="frm-calendar-actions">',
                            '<button class="frm-button" type="button" data-action="calendar-prev">Previous</button>',
                            '<button class="frm-button" type="button" data-action="calendar-today">Today</button>',
                            '<button class="frm-button" type="button" data-action="calendar-next">Next</button>',
                        '</div>',
                    '</div>',
                    '<div class="frm-calendar-legend"><span class="is-dispatch">Dispatch / ETD</span><span class="is-eta">Expected arrival</span><span class="is-arrived">Posted arrival</span></div>',
                    '<div class="frm-calendar-grid" id="frm-calendar-grid"></div>',
                    '<div class="frm-calendar-note" id="frm-calendar-note"></div>',
                '</section>',
                '<div class="frm-toast" id="frm-toast"></div>',
            '</div>'
        ].join('');

        elements = {
            host: host,
            root: host.querySelector('.frm-app'),
            company: host.querySelector('#frm-company'),
            kpis: host.querySelector('#frm-kpis'),
            tabs: host.querySelector('#frm-tabs'),
            viewToggle: host.querySelector('#frm-view-toggle'),
            layout: host.querySelector('#frm-layout'),
            search: host.querySelector('#frm-search'),
            directions: host.querySelector('#frm-directions'),
            count: host.querySelector('#frm-count'),
            list: host.querySelector('#frm-list'),
            detail: host.querySelector('#frm-detail'),
            calendarView: host.querySelector('#frm-calendar-view'),
            calendarTitle: host.querySelector('#frm-calendar-title'),
            calendarGrid: host.querySelector('#frm-calendar-grid'),
            calendarNote: host.querySelector('#frm-calendar-note'),
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
        if (!parsed || Number(parsed.schemaVersion) !== 2 || !Array.isArray(parsed.items)) {
            showToast('Business Central returned an unexpected packing and logistics projection.', true);
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
        const limitNote = state.data.projectionLimited ? ' · current snapshot, up to ' + number(state.data.projectionLimit) + ' records' : '';
        elements.company.textContent = text(state.data.company || 'Business Central') + ' · as at ' + text(state.data.asOf || 'now') + limitNote;
        renderKpis();
        renderList();
        renderDetail();
        renderCalendar();
        syncLayout();
        elements.root.classList.toggle('is-compact', state.compact);
        syncFullscreen();
    }

    function syncLayout() {
        const showCalendar = state.layout === 'calendar';
        elements.layout.hidden = showCalendar;
        elements.calendarView.hidden = !showCalendar;
        elements.viewToggle.querySelectorAll('[data-layout]').forEach(function (button) {
            button.setAttribute('aria-pressed', String(button.dataset.layout === state.layout));
        });
    }

    function parseDate(value) {
        const parts = text(value).slice(0, 10).split('-');
        if (parts.length !== 3)
            return null;
        const result = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return Number.isNaN(result.getTime()) ? null : result;
    }

    function dateKey(value) {
        const parsed = value instanceof Date ? value : parseDate(value);
        if (!parsed)
            return '';
        return [parsed.getFullYear(), String(parsed.getMonth() + 1).padStart(2, '0'), String(parsed.getDate()).padStart(2, '0')].join('-');
    }

    function movementEvents() {
        const events = [];
        filteredItems().forEach(function (item) {
            if (item.etd)
                events.push({ date: text(item.etd).slice(0, 10), kind: 'dispatch', label: 'Dispatch', item: item });
            if (item.actualArrival)
                events.push({ date: text(item.actualArrival).slice(0, 10), kind: 'arrived', label: 'Arrived', item: item });
            else if (item.eta)
                events.push({ date: text(item.eta).slice(0, 10), kind: 'eta', label: 'ETA', item: item });
        });
        return events.filter(function (event) { return Boolean(parseDate(event.date)); });
    }

    function renderCalendar() {
        const cursor = state.calendarCursor;
        const monthStart = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
        const monthEnd = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0);
        const gridStart = new Date(monthStart);
        gridStart.setDate(monthStart.getDate() - ((monthStart.getDay() + 6) % 7));
        const events = movementEvents();
        const eventsByDate = {};
        events.forEach(function (event) {
            if (!eventsByDate[event.date])
                eventsByDate[event.date] = [];
            eventsByDate[event.date].push(event);
        });
        elements.calendarTitle.textContent = new Intl.DateTimeFormat('en-AU', { month: 'long', year: 'numeric' }).format(monthStart);
        const headings = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map(function (day) {
            return '<div class="frm-calendar-weekday">' + day + '</div>';
        });
        const cells = [];
        for (let index = 0; index < 42; index += 1) {
            const current = new Date(gridStart);
            current.setDate(gridStart.getDate() + index);
            const key = dateKey(current);
            const dayEvents = eventsByDate[key] || [];
            const outside = current < monthStart || current > monthEnd;
            const today = key === dateKey(new Date());
            const shown = dayEvents.slice(0, 4).map(function (event) {
                const item = event.item;
                return '<button type="button" class="frm-calendar-event is-' + event.kind + '" data-action="open-source" data-source-type="' +
                    escapeHtml(item.sourceType) + '" data-document-no="' + escapeHtml(item.documentNo) + '" title="' +
                    escapeHtml(event.label + ' · ' + item.documentNo + ' · ' + (item.destination || item.party || '') + ' · ' + movementLinePreview(item)) + '"><span>' +
                    escapeHtml(event.label) + '</span><strong>' + escapeHtml(item.documentNo) + '</strong><small>' +
                    escapeHtml(item.destination || item.party || '') + '</small><small class="frm-calendar-lines">' +
                    escapeHtml(movementLinePreview(item)) + '</small></button>';
            }).join('');
            cells.push('<div class="frm-calendar-day' + (outside ? ' is-outside' : '') + (today ? ' is-today' : '') + '"><div class="frm-calendar-date"><strong>' +
                current.getDate() + '</strong><span>' + (dayEvents.length ? dayEvents.length + ' movement' + (dayEvents.length === 1 ? '' : 's') : '') +
                '</span></div>' + shown + (dayEvents.length > 4 ? '<div class="frm-calendar-more">+' + (dayEvents.length - 4) + ' more</div>' : '') + '</div>');
        }
        elements.calendarGrid.innerHTML = headings.concat(cells).join('');
        const monthEvents = events.filter(function (event) {
            const value = parseDate(event.date);
            return value && value >= monthStart && value <= monthEnd;
        });
        const dateless = filteredItems().filter(function (item) { return !item.etd && !item.eta && !item.actualArrival; }).length;
        elements.calendarNote.textContent = monthEvents.length + ' dated movement milestone' + (monthEvents.length === 1 ? '' : 's') +
            ' in this month' + (dateless ? ' · ' + dateless + ' filtered record' + (dateless === 1 ? '' : 's') + ' need a dispatch or arrival date.' : '.');
    }

    function countWhere(predicate) {
        return (state.data.items || []).filter(predicate).length;
    }

    function renderKpis() {
        const cards = [
            ['Awaiting plan', countWhere(function (item) { return isLivePlanningDemand(item) && item.packingStatusKey === 'awaiting-plan'; }), 'Released demand without an active SAL plan'],
            ['Planning', countWhere(function (item) { return isLivePlanningDemand(item) && item.packingStatusKey === 'planning'; }), 'Draft SAL plans in this projected snapshot'],
            ['Yet to pack', '—', 'Requires facility acknowledgement and zero progress'],
            ['Packing', '—', 'Requires authoritative on-prem scan progress'],
            ['Ready', '—', 'Requires authoritative physical completion'],
            ['Dispatched', countWhere(function (item) { return item.stageKey === 'dispatched'; }), 'Posted Sales Shipment evidence'],
            ['In transit', countWhere(function (item) { return item.stageKey === 'in-transit'; }), 'Transfer quantity recorded in transit'],
            ['Arrived', countWhere(function (item) { return item.stageKey === 'arrived'; }), 'Posted receipt evidence'],
            ['Data gaps', countWhere(isDataGap), 'Missing Cloud data; facility exceptions unavailable']
        ];
        elements.kpis.innerHTML = cards.map(function (card) {
            const unknown = card[1] === '—';
            return '<article class="frm-kpi' + (unknown ? ' is-unknown' : '') + '"><span>' +
                escapeHtml(card[0]) + '</span><strong>' + escapeHtml(unknown ? card[1] : number(card[1])) + '</strong><small>' +
                escapeHtml(card[2]) + '</small></article>';
        }).join('');
    }

    function isOrder(item) {
        return ['Sales Order', 'Transfer Order', 'Purchase Order'].indexOf(item.sourceType) >= 0;
    }

    function isLivePlanningDemand(item) {
        return ['Sales Order', 'Transfer Order'].indexOf(item.sourceType) >= 0;
    }

    function isPackingDemand(item) {
        return ['Sales Order', 'Transfer Order'].indexOf(item.sourceType) >= 0 && Boolean(item.packingActionable) && item.stageKey !== 'in-transit';
    }

    function isDataGap(item) {
        if (item.stageKey === 'arrived')
            return false;
        const carrierMissing = isOrder(item) && (!item.carrier || text(item.carrier).toLowerCase().indexOf('not supplied') >= 0);
        const dateMissing = isOrder(item) && !item.etd && !item.eta;
        const marketerMissing = Boolean(item.salPlanNo) && text(item.marketer).toLowerCase().indexOf('not confirmed') >= 0;
        const routeMissing = Boolean(item.salPlanNo) && !item.routingConfirmed;
        return carrierMissing || dateMissing || marketerMissing || routeMissing;
    }

    function displayStageKey(item) {
        if (['dispatched', 'in-transit', 'arrived'].indexOf(item.stageKey) >= 0)
            return item.stageKey;
        if (item.packingStatusKey && item.packingStatusKey !== 'not-applicable')
            return item.packingStatusKey;
        return item.stageKey || statusKey(item.stage);
    }

    function displayStage(item) {
        if (['dispatched', 'in-transit', 'arrived'].indexOf(item.stageKey) >= 0)
            return item.stage;
        if (item.packingStatus && item.packingStatusKey !== 'not-applicable')
            return item.packingStatus;
        return item.stage;
    }

    function matchesView(item) {
        if (state.view === 'all') return true;
        if (state.view === 'packing') return isPackingDemand(item);
        if (state.view === 'ready') return item.packingStatusKey === 'ready-to-dispatch' && item.packingProgressKnown;
        if (state.view === 'dispatched') return item.stageKey === 'dispatched';
        if (state.view === 'in-transit') return item.stageKey === 'in-transit';
        if (state.view === 'arrived') return item.stageKey === 'arrived';
        if (state.view === 'unconsigned') return false;
        if (state.view === 'exceptions') return isDataGap(item);
        return true;
    }

    function filteredItems() {
        const query = state.query.trim().toLowerCase();
        return (state.data.items || []).filter(function (item) {
            const directionMatch = state.direction === 'all' || statusKey(item.direction) === state.direction;
            const movementSearch = movementLines(item).map(function (line) {
                return [line.itemNo, line.variantCode, line.description, line.unitOfMeasure].join(' ');
            }).join(' ');
            const haystack = [item.documentNo, item.relatedDocumentNo, item.party, item.origin, item.destination,
                item.carrier, item.bookingReference, item.stage, item.packingStatus, item.salPlanNo, item.marketer,
                item.route, item.workType, movementSearch].join(' ').toLowerCase();
            return directionMatch && matchesView(item) && (!query || haystack.indexOf(query) >= 0);
        }).sort(function (a, b) {
            const aRank = queueRank(a);
            const bRank = queueRank(b);
            if (aRank !== bRank)
                return aRank - bRank;
            const aPriority = Number(a.salPriority) > 0 ? Number(a.salPriority) : 99;
            const bPriority = Number(b.salPriority) > 0 ? Number(b.salPriority) : 99;
            if (aPriority !== bPriority)
                return aPriority - bPriority;
            const aDate = text(a.actualArrival || a.eta || a.dispatchDate || a.requiredFinishDate || a.etd || '9999-12-31');
            const bDate = text(b.actualArrival || b.eta || b.dispatchDate || b.requiredFinishDate || b.etd || '9999-12-31');
            return aDate.localeCompare(bDate);
        });
    }

    function queueRank(item) {
        if (isPackingDemand(item)) return 0;
        if (isLivePlanningDemand(item)) return 1;
        if (['dispatched', 'in-transit'].indexOf(item.stageKey) >= 0) return 2;
        if (item.sourceType === 'Purchase Order') return 3;
        if (item.stageKey === 'arrived') return 4;
        return 5;
    }

    function emptyMessage() {
        if (state.view === 'ready')
            return 'Ready-to-dispatch status is unavailable until the Packing Facility completion feed is connected.';
        if (state.view === 'unconsigned')
            return 'Unconsigned pallet data is owned on-prem and is not connected to Cloud yet.';
        return 'No movements match this view.';
    }

    function renderList() {
        const items = filteredItems();
        elements.count.textContent = 'Showing ' + String(items.length);
        if (!items.length) {
            elements.list.innerHTML = '<div class="frm-empty">' + escapeHtml(emptyMessage()) + '</div>';
            elements.detail.innerHTML = '<div class="frm-empty is-large">' + escapeHtml(emptyMessage()) + '</div>';
            return;
        }
        if (!items.some(function (item) { return text(item.id) === state.selectedId; }))
            state.selectedId = text(items[0].id);
        elements.list.innerHTML = items.map(function (item) {
            const selected = text(item.id) === state.selectedId;
            const posted = item.sourceType.indexOf('Posted') === 0;
            const badge = item.sourceType.indexOf('Receipt') >= 0 ? 'RCPT' : item.sourceType === 'Posted Sales Shipment' ? 'SHIP' :
                item.sourceType === 'Purchase Order' ? 'PO' : item.sourceType === 'Transfer Order' ? 'TO' : 'SO';
            const stage = displayStage(item);
            const priority = Number(item.salPriority) > 0 ? '<span>Priority ' + escapeHtml(number(item.salPriority)) + '</span>' : '';
            return [
                '<button type="button" class="frm-row', selected ? ' is-selected' : '', '" data-action="select" data-id="', escapeHtml(item.id), '">',
                    '<span class="frm-source">', escapeHtml(badge), '</span>',
                    '<span class="frm-row-main"><strong>', escapeHtml(item.documentNo), ' · ', escapeHtml(item.party || 'Party not supplied'), '</strong>',
                    '<small>', escapeHtml(item.origin || 'Origin not supplied'), ' → ', escapeHtml(item.destination || 'Destination not supplied'), '</small>',
                    '<span class="frm-row-meta"><span class="frm-tag is-', escapeHtml(displayStageKey(item)), '">', escapeHtml(stage), '</span>',
                    '<span class="frm-record-kind">', posted ? 'Posted movement' : 'Demand', '</span>', priority,
                    '<span>', escapeHtml(item.actualArrival ? 'Arrived ' + dateLabel(item.actualArrival) : item.eta ? 'Planned ' + dateLabel(item.eta) : 'ETD ' + dateLabel(item.etd)), '</span></span></span>',
                '</button>'
            ].join('');
        }).join('');
    }

    function selectedItem() {
        return filteredItems().find(function (item) { return text(item.id) === state.selectedId; }) || null;
    }

    function renderDetail() {
        const item = selectedItem();
        if (!item) {
            elements.detail.innerHTML = '<div class="frm-empty is-large">' + escapeHtml(emptyMessage()) + '</div>';
            return;
        }
        const hasPlan = Boolean(item.salPlanNo);
        const hasArrived = item.stageKey === 'arrived' || Boolean(item.actualArrival);
        const isInTransit = item.stageKey === 'in-transit';
        const isDispatched = item.stageKey === 'dispatched' || isInTransit;
        const isReady = item.packingStatusKey === 'ready-to-dispatch' && item.packingProgressKnown;
        const hasReference = Boolean(item.bookingReference);
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
        const planAction = hasPlan ? '<button class="frm-button" type="button" data-action="open-plan" data-plan-no="' +
            escapeHtml(item.salPlanNo) + '" data-version-no="' + escapeHtml(item.salPlanVersionNo) + '">Open SAL plan</button>' : '';
        const packingDetail = item.packingProgressKnown ? item.packingStatus :
            item.packingActionable ? 'Packing Facility feed not connected' : (item.packingStatus || 'Not applicable');
        const planValue = hasPlan ? item.salPlanNo + ' · v' + number(item.salPlanVersionNo) : 'Not linked';
        const planNote = hasPlan ? item.salPlanStatus + (item.salPlanValidated ? ' · validated' : ' · validation not current') +
            (item.hasPendingDraft ? ' · draft ' + text(item.pendingDraftPlanNo) + ' v' + number(item.pendingDraftVersionNo) + ' pending' : '') :
            'Select in Planner to create one';
        const priorityValue = Number(item.salPriority) > 0 ? number(item.salPriority) : 'Not set';
        const palletValue = hasPlan ? number(item.palletCount) + ' involved' : 'No pallet plan';
        const palletNote = hasPlan ? 'Selected document · ' + number(item.standardPalletCount) + ' standard · ' + number(item.customPalletCount) + ' custom · ' + number(item.mixedPalletCount) + ' mixed' : 'Create a SAL plan to define physical pallets';
        const quantityValue = movementQuantitySummary(item);
        const quantityNote = number(item.lineCount) + ' BC item lines · original unit of measure retained';

        elements.detail.innerHTML = [
            '<section class="frm-detail-head">',
                '<div><span class="frm-eyebrow">', escapeHtml(item.direction), ' · ', escapeHtml(item.sourceType), '</span>',
                '<h1>', escapeHtml(item.documentNo), ' · ', escapeHtml(item.party || 'Party not supplied'), '</h1>',
                '<p>', escapeHtml(item.origin || 'Origin not supplied'), ' → ', escapeHtml(item.destination || 'Destination not supplied'), '</p></div>',
                '<div class="frm-detail-actions"><span class="frm-chip">', escapeHtml(item.marketer || 'Marketer not confirmed'), '</span>',
                Number(item.salPriority) > 0 ? '<span class="frm-chip">Priority ' + escapeHtml(number(item.salPriority)) + '</span>' : '',
                planAction,
                '<button class="frm-button is-primary" type="button" data-action="open-source" data-source-type="', escapeHtml(item.sourceType), '" data-document-no="', escapeHtml(item.documentNo), '">Open BC source</button></div>',
            '</section>',
            '<section class="frm-journey">',
                journeyStep('Demand', true, item.status || item.sourceType),
                journeyStep('SAL plan', hasPlan, hasPlan ? item.salPlanStatus + ' · v' + number(item.salPlanVersionNo) : 'No active plan'),
                journeyStep('Packing', Boolean(item.packingProgressKnown), packingDetail),
                journeyStep('Ready', isReady, isReady ? 'Facility completion confirmed' : 'Requires facility completion feed'),
                journeyStep('Dispatched', isDispatched, isDispatched ? dateLabel(item.etd) : hasArrived ? 'Not separately projected; receipt is posted' : 'Awaiting posted movement'),
                journeyStep('In transit', isInTransit, isInTransit ? number(item.inTransitQuantity) + ' units in transit' : hasArrived ? 'Not separately projected; receipt is posted' : 'No authoritative transit event'),
                journeyStep('Arrived', hasArrived, hasArrived ? dateLabel(item.actualArrival) : 'No posted receipt evidence'),
            '</section>',
            '<section class="frm-grid">',
                metricCard('SAL plan', planValue, planNote),
                metricCard('Priority / finish', priorityValue, item.requiredFinishDate ? 'Finish ' + dateLabel(item.requiredFinishDate) + ' · dispatch ' + dateLabel(item.dispatchDate) : 'SAL dates not set'),
                metricCard('Physical pallet plan', palletValue, palletNote),
                metricCard('Selected document units', quantityValue, quantityNote),
                metricCard('Facility packing status', item.packingProgressKnown ? item.packingStatus : '—', packingDetail),
                metricCard('Route / work', item.route || 'Not set', item.workType || 'Not set'),
                metricCard('Carrier / reference', item.carrier || 'Not supplied', hasReference ? item.bookingReference : item.service || 'Reference not supplied'),
                metricCard(hasArrived ? 'Actual arrival' : 'Planned / expected arrival', hasArrived ? dateLabel(item.actualArrival) : dateLabel(item.eta), hasArrived ? item.dateSource : item.eta ? item.dateSource : 'Carrier ETA not connected'),
            '</section>',
            renderMovementLines(item),
            renderSizeSummary(item),
            '<section class="frm-panels">',
                '<article><span class="frm-eyebrow">CURRENT DATA TRUTH</span><h3>', escapeHtml(item.connectionState || 'BC document data'), '</h3><p>', escapeHtml(item.dataNote || 'No additional data note supplied.'), '</p></article>',
                '<article><span class="frm-eyebrow">UNCONSIGNED &amp; PACKING EXCEPTIONS</span><h3>Not connected</h3><p>Physical pallet IDs, scan mismatches, completion and Unconsigned composition remain on-prem. No zero count is shown because the Cloud value is unknown.</p></article>',
                '<article><span class="frm-eyebrow">FINANCE &amp; INVOICE</span><h3>', escapeHtml(commercialInvoiceNo), '</h3><p>', escapeHtml(commercialInvoiceNote), '. Freight supplier invoices remain a separate future workflow and will require Finance approval.</p>', commercialInvoiceAction, '</article>',
                '<article><span class="frm-eyebrow">NEXT CONNECTIONS</span><h3>Packing Facility, carrier and FruitBank</h3><p>Versioned facility acknowledgement and pallet events will activate Yet to pack, Packing, Ready and Unconsigned. Carrier milestones and FruitBank can then share the same movement identity.</p></article>',
            '</section>'
        ].join('');
    }

    function renderMovementLines(item) {
        const lines = movementLines(item);
        if (!lines.length)
            return '<section class="frm-movement-lines"><div class="frm-section-head"><div><span class="frm-eyebrow">BC SOURCE LINES</span><h3>No item-line detail available</h3></div></div></section>';
        return '<section class="frm-movement-lines"><div class="frm-section-head"><div><span class="frm-eyebrow">BC SOURCE LINES</span><h3>Products, quantities and recorded UOM</h3></div><span class="frm-chip">' +
            escapeHtml(number(lines.length)) + ' line' + (lines.length === 1 ? '' : 's') + '</span></div><div class="frm-movement-line-grid">' +
            lines.map(function (line) {
                return '<article><div><strong>' + escapeHtml(movementLineCode(line)) + '</strong><small>' + escapeHtml(line.description || 'No description') +
                    '</small></div><span>' + escapeHtml(movementLineQuantity(line)) + '</span></article>';
            }).join('') + '</div><p class="frm-uom-note">Quantities use the unit recorded on the BC line. TE is shown as TE and is not assumed to mean an individual tray.</p></section>';
    }

    function renderSizeSummary(item) {
        const sizes = Array.isArray(item.sizeSummary) ? item.sizeSummary : [];
        if (!sizes.length)
            return '<section class="frm-sizes"><div class="frm-section-head"><div><span class="frm-eyebrow">PRODUCT / SIZE PLAN</span><h3>No SAL size plan linked</h3></div><span class="frm-chip">Packing completion unavailable</span></div></section>';
        return '<section class="frm-sizes"><div class="frm-section-head"><div><span class="frm-eyebrow">PRODUCT / SIZE PLAN</span><h3>Required and planned quantities</h3></div><span class="frm-chip is-warning">Packing completion unavailable</span></div><div class="frm-size-grid">' +
            sizes.map(function (size) {
                return '<article><strong>' + escapeHtml(size.productCode || 'Product') + '</strong><span>' +
                    escapeHtml(number(size.plannedQuantity)) + ' / ' + escapeHtml(number(size.requiredQuantity)) + ' ' +
                    escapeHtml(size.unitOfMeasure || 'units') + '</span><small>' + escapeHtml(size.description || '') + '</small></article>';
            }).join('') + '</div></section>';
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
        const target = event.target.closest('[data-action], [data-view], [data-direction], [data-layout]');
        if (!target) return;
        if (target.dataset.action === 'fullscreen') {
            toggleFullscreen();
            return;
        }
        if (target.dataset.action === 'density') {
            toggleDensity();
            return;
        }
        if (target.dataset.action === 'refresh') {
            invoke('RefreshRequested', []);
            return;
        }
        if (target.dataset.action === 'calendar-prev' || target.dataset.action === 'calendar-next') {
            const step = target.dataset.action === 'calendar-prev' ? -1 : 1;
            state.calendarCursor = new Date(state.calendarCursor.getFullYear(), state.calendarCursor.getMonth() + step, 1);
            renderCalendar();
            return;
        }
        if (target.dataset.action === 'calendar-today') {
            const today = new Date();
            state.calendarCursor = new Date(today.getFullYear(), today.getMonth(), 1);
            renderCalendar();
            return;
        }
        if (target.dataset.action === 'select') {
            state.selectedId = text(target.dataset.id);
            renderList();
            renderDetail();
            return;
        }
        if (target.dataset.action === 'open-source') {
            openNative('OpenSourceRequested', [text(target.dataset.sourceType), text(target.dataset.documentNo)]);
            return;
        }
        if (target.dataset.action === 'open-plan') {
            openNative('OpenPlanRequested', [text(target.dataset.planNo), Number(target.dataset.versionNo || 0)]);
            return;
        }
        if (target.dataset.view) {
            state.view = target.dataset.view;
            elements.tabs.querySelectorAll('[data-view]').forEach(function (button) {
                button.setAttribute('aria-pressed', String(button === target));
            });
            renderAll();
            return;
        }
        if (target.dataset.layout) {
            state.layout = target.dataset.layout;
            if (state.layout === 'calendar') {
                state.query = '';
                state.direction = 'all';
                elements.search.value = '';
                elements.directions.querySelectorAll('[data-direction]').forEach(function (button) {
                    button.setAttribute('aria-pressed', String(button.dataset.direction === 'all'));
                });
            }
            renderAll();
            return;
        }
        if (target.dataset.direction) {
            state.direction = target.dataset.direction;
            elements.directions.querySelectorAll('[data-direction]').forEach(function (button) {
                button.setAttribute('aria-pressed', String(button === target));
            });
            renderAll();
        }
    }

    function handleInput(event) {
        if (event.target === elements.search) {
            state.query = event.target.value || '';
            renderAll();
        }
    }

    globalThis.SetState = applyState;
    globalThis.SALStockLogisticsWorkspace = {
        start: function () {
            buildShell();
            renderAll();
            invoke('ControlReady', []);
        }
    };
}());
