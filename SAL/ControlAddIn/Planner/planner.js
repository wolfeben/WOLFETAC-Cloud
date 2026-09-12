(function () {
    'use strict';

    const localState = {
        data: { schemaVersion: 1, queue: [], plan: null, capabilities: {} },
        lastGood: null,
        query: '',
        marketer: 'all',
        tab: 'plan',
        activeSourceLine: 0,
        pending: false,
        pendingTimer: 0,
        compact: false,
        fullscreenPending: false,
        fullscreenNotice: '',
        dialogReturnFocus: null
    };

    let elements = {};

    function navAvailable() {
        return globalThis.Microsoft &&
            Microsoft.Dynamics &&
            Microsoft.Dynamics.NAV &&
            typeof Microsoft.Dynamics.NAV.InvokeExtensibilityMethod === 'function';
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
            button.disabled = localState.fullscreenPending || localState.pending;
        }
        const notice = elements.root.querySelector('#sal-fullscreen-notice');
        if (notice)
            notice.textContent = localState.fullscreenNotice;
    }

    async function toggleFullscreen() {
        if (!elements.root || localState.fullscreenPending || localState.pending)
            return;
        localState.fullscreenPending = true;
        localState.fullscreenNotice = '';
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
            localState.fullscreenNotice = 'Full screen is unavailable here. Expand the BC page or use the browser full-screen command.';
        } finally {
            localState.fullscreenPending = false;
            syncFullscreen();
        }
    }

    function toggleDensity() {
        localState.compact = !localState.compact;
        elements.root.classList.toggle('is-compact', localState.compact);
        const button = elements.root.querySelector('[data-action="density"]');
        if (button) {
            button.textContent = localState.compact ? 'Comfortable view' : 'Compact view';
            button.setAttribute('aria-pressed', String(localState.compact));
        }
    }

    async function openNative(eventName, args, mutation) {
        if (localState.fullscreenPending)
            return;
        if (isFullscreen()) {
            localState.fullscreenPending = true;
            syncFullscreen();
            try {
                await document.exitFullscreen();
            } catch (_error) {
                localState.fullscreenNotice = 'Exit full screen before opening a Business Central page.';
                localState.fullscreenPending = false;
                syncFullscreen();
                return;
            }
            localState.fullscreenPending = false;
        }
        invoke(eventName, args || [], Boolean(mutation));
    }

    document.addEventListener('fullscreenchange', syncFullscreen);

    function invoke(eventName, args, mutation) {
        if (!navAvailable()) {
            showToast('This planner is not connected to Business Central.', true);
            return false;
        }

        if (mutation)
            setBusy(true);

        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(eventName, args || [], false);
        return true;
    }

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

    function number(value, digits) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed))
            return '0';
        return parsed.toLocaleString('en-AU', {
            minimumFractionDigits: 0,
            maximumFractionDigits: digits == null ? 1 : digits
        });
    }

    function dateLabel(value) {
        if (!value)
            return 'Not set';
        const parts = text(value).slice(0, 10).split('-');
        if (parts.length !== 3)
            return text(value);
        const parsed = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        if (Number.isNaN(parsed.getTime()))
            return text(value);
        return new Intl.DateTimeFormat('en-AU', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        }).format(parsed);
    }

    function dateTimeLabel(value) {
        if (!value)
            return 'Not recorded';
        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime()))
            return text(value);
        return new Intl.DateTimeFormat('en-AU', {
            day: '2-digit',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit'
        }).format(parsed);
    }

    function percent(done, total) {
        const numerator = Number(done);
        const denominator = Number(total);
        if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0)
            return 0;
        return Math.max(0, Math.min(100, Math.round((numerator / denominator) * 100)));
    }

    function statusKey(value) {
        return text(value).toLowerCase().replace(/[^a-z0-9]+/g, '-');
    }

    function buildShell() {
        const host = document.getElementById('controlAddIn') || document.body;
        host.innerHTML = [
            '<div class="sal-app">',
                '<header class="sal-utility">',
                    '<div class="sal-brand"><img class="sal-wordmark" src="', escapeHtml(resource('ControlAddIn/Shared/images/avocado-wordmark.png')), '" alt="The Avocados Collective"></div>',
                    '<div class="sal-heading">',
                        '<span class="sal-eyebrow">The Avocados Collective</span>',
                        '<strong>Stock &amp; Logistics Planner</strong>',
                        '<small>Route demand. Build physical pallet plans. Release clear facility work.</small>',
                    '</div>',
                    '<div class="sal-utility-actions">',
                        '<div class="sal-header-buttons">',
                            '<button class="sal-header-button" type="button" data-action="open-plans">All plans</button>',
                            '<button class="sal-header-button" type="button" data-action="open-native">Plan details</button>',
                            '<button class="sal-header-button" type="button" data-action="density" aria-pressed="false">Compact view</button>',
                            '<button class="sal-header-button" type="button" data-action="fullscreen" aria-pressed="false">Full screen</button>',
                            '<button class="sal-header-button is-primary" type="button" data-action="refresh">Refresh</button>',
                        '</div>',
                        '<div class="sal-header-context"><span class="sal-environment" id="sal-context">Cloud · SAL planning</span><span id="sal-company">Business Central</span></div>',
                        '<span class="sal-fullscreen-notice" id="sal-fullscreen-notice" role="status"></span>',
                    '</div>',
                '</header>',
                '<nav class="sal-flow" aria-label="Planning workflow">',
                    '<span class="sal-step" data-step="demand"><span class="sal-step-number">1</span>Select demand</span>',
                    '<span class="sal-step" data-step="route"><span class="sal-step-number">2</span>Set route</span>',
                    '<span class="sal-step" data-step="pallet"><span class="sal-step-number">3</span>Build pallet plan</span>',
                    '<span class="sal-step" data-step="validate"><span class="sal-step-number">4</span>Validate</span>',
                    '<span class="sal-step" data-step="release"><span class="sal-step-number">5</span>Release</span>',
                '</nav>',
                '<div class="sal-layout">',
                    '<aside class="sal-queue">',
                        '<div class="sal-queue-header">',
                            '<div class="sal-queue-top"><h2>Demand queue</h2><span class="sal-count" id="sal-queue-count">0</span></div>',
                            '<label class="sal-search"><span>⌕</span><input id="sal-search" type="search" placeholder="Order, customer or destination" autocomplete="off"></label>',
                        '</div>',
                        '<div class="sal-filters" id="sal-filters">',
                            '<button class="sal-filter" type="button" data-action="filter-marketer" data-marketer="all" aria-pressed="true">All</button>',
                            '<button class="sal-filter" type="button" data-action="filter-marketer" data-marketer="tac" aria-pressed="false">TAC</button>',
                            '<button class="sal-filter" type="button" data-action="filter-marketer" data-marketer="costa" aria-pressed="false">Costa</button>',
                        '</div>',
                        '<div class="sal-queue-list" id="sal-queue-list"></div>',
                        '<div class="sal-queue-footer"><strong>Unconsigned stock</strong><br>Facility feed is not connected in this Cloud slice.</div>',
                    '</aside>',
                    '<main class="sal-workspace" id="sal-workspace"></main>',
                    '<aside class="sal-sidebar" id="sal-sidebar"></aside>',
                '</div>',
                '<div class="sal-dialog-backdrop" id="sal-dialog" hidden></div>',
                '<div class="sal-toast" id="sal-toast" role="status" aria-live="polite"></div>',
            '</div>'
        ].join('');

        elements = {
            host: host,
            root: host.querySelector('.sal-app'),
            context: host.querySelector('#sal-context'),
            company: host.querySelector('#sal-company'),
            queueCount: host.querySelector('#sal-queue-count'),
            search: host.querySelector('#sal-search'),
            filters: host.querySelector('#sal-filters'),
            queue: host.querySelector('#sal-queue-list'),
            workspace: host.querySelector('#sal-workspace'),
            sidebar: host.querySelector('#sal-sidebar'),
            dialog: host.querySelector('#sal-dialog'),
            toast: host.querySelector('#sal-toast')
        };

        host.addEventListener('click', handleClick);
        host.addEventListener('input', handleInput);
        host.addEventListener('change', handleChange);
        host.addEventListener('keydown', handleKeyDown);
    }

    function setBusy(isBusy) {
        localState.pending = Boolean(isBusy);
        if (localState.pendingTimer)
            window.clearTimeout(localState.pendingTimer);
        localState.pendingTimer = 0;

        if (elements.root)
            elements.root.querySelectorAll('[data-server-action]').forEach(function (control) {
                control.disabled = localState.pending;
            });
        syncFullscreen();

        if (localState.pending) {
            localState.pendingTimer = window.setTimeout(function () {
                localState.pending = true;
                showToast('The outcome is not confirmed. Refresh before repeating the action.', true);
                if (elements.root)
                    elements.root.querySelectorAll('[data-server-action]').forEach(function (control) {
                        control.disabled = true;
                    });
            }, 15000);
        }
    }

    function showToast(message, isError) {
        if (!elements.toast || !message)
            return;
        elements.toast.textContent = message;
        elements.toast.classList.toggle('is-error', Boolean(isError));
        elements.toast.classList.add('is-visible');
        window.clearTimeout(elements.toast.hideTimer);
        elements.toast.hideTimer = window.setTimeout(function () {
            elements.toast.classList.remove('is-visible');
        }, 5000);
    }

    function validateState(data) {
        return data &&
            Number(data.schemaVersion) === 1 &&
            Array.isArray(data.queue) &&
            typeof data.capabilities === 'object';
    }

    function applyState(stateJson, statusMessage, isError) {
        let parsed;
        try {
            parsed = stateJson ? JSON.parse(stateJson) : null;
        } catch (_error) {
            parsed = null;
        }

        if (!validateState(parsed)) {
            if (localState.lastGood)
                localState.data = localState.lastGood;
            showToast('Business Central returned planner data in an unexpected format.', true);
            setBusy(false);
            renderAll();
            return;
        }

        localState.data = parsed;
        localState.lastGood = parsed;
        if (parsed.plan && parsed.plan.sources && parsed.plan.sources.length) {
            const sourceStillExists = parsed.plan.sources.some(function (source) {
                return Number(source.lineNo) === Number(localState.activeSourceLine);
            });
            if (!sourceStillExists)
                localState.activeSourceLine = Number(parsed.plan.sources[0].lineNo);
        } else {
            localState.activeSourceLine = 0;
        }

        setBusy(false);
        renderAll();
        if (statusMessage)
            showToast(statusMessage, Boolean(isError));
    }

    function renderAll() {
        const data = localState.data;
        elements.context.textContent = text(data.environment || 'Cloud planner');
        elements.company.textContent = text(data.company || 'Business Central');
        renderQueue();
        renderWorkspace();
        renderSidebar();
        renderFlow();
        elements.root.classList.toggle('is-compact', localState.compact);
        syncFullscreen();
    }

    function renderQueue() {
        const data = localState.data;
        const selected = data.selectedKey || {};
        const query = localState.query.trim().toLowerCase();
        const marketerFilter = localState.marketer;
        const visible = (data.queue || []).filter(function (item) {
            const haystack = [
                item.sourceType,
                item.documentNo,
                item.planNo,
                item.description,
                item.marketer,
                item.customerName,
                item.destinationName,
                item.status,
                item.blockedReason
            ].join(' ').toLowerCase();
            const marketerMatches = marketerFilter === 'all' ||
                text(item.marketer).toLowerCase().indexOf(marketerFilter) >= 0;
            return marketerMatches && (!query || haystack.indexOf(query) >= 0);
        }).sort(compareQueueItems);

        elements.queueCount.textContent = String(visible.length);
        if (!visible.length) {
            elements.queue.innerHTML = '<div class="sal-queue-footer">No demand or plans match this view.</div>';
            return;
        }

        elements.queue.innerHTML = visible.map(function (item) {
            return isDemandCandidate(item) ? renderDemandCandidate(item, selected) : renderPlanQueueItem(item, selected);
        }).join('');
    }

    function compareQueueItems(left, right) {
        const leftPriority = Number(left.priority || 10);
        const rightPriority = Number(right.priority || 10);
        if (leftPriority !== rightPriority)
            return leftPriority - rightPriority;

        const leftDate = text(left.requiredFinishDate || left.shipmentDate || '9999-12-31');
        const rightDate = text(right.requiredFinishDate || right.shipmentDate || '9999-12-31');
        if (leftDate !== rightDate)
            return leftDate.localeCompare(rightDate);

        if (isDemandCandidate(left) !== isDemandCandidate(right))
            return isDemandCandidate(left) ? 1 : -1;

        return text(left.planNo || left.documentNo).localeCompare(text(right.planNo || right.documentNo));
    }

    function isDemandCandidate(item) {
        return text(item && item.kind).toLowerCase() === 'candidate';
    }

    function renderPlanQueueItem(item, selected) {
        const selectedItem = text(item.planNo) === text(selected.planNo) &&
            Number(item.versionNo) === Number(selected.versionNo);
        const required = Number(item.requiredQuantity || 0);
        const planned = Number(item.plannedQuantity || 0);
        return [
            '<button type="button" class="sal-queue-card',
            selectedItem ? ' is-selected' : '',
            '" data-action="select-plan" data-plan-no="', escapeHtml(item.planNo),
            '" data-version-no="', escapeHtml(item.versionNo),
            '" data-status="', escapeHtml(statusKey(item.status)), '">',
                '<span class="sal-inline">',
                    '<span class="sal-priority">', escapeHtml(item.priority || '–'), '</span>',
                    '<span class="sal-queue-copy"><strong>', escapeHtml(item.planNo), ' · ', escapeHtml(item.description || 'Untitled plan'),
                    '</strong><small>Version ', escapeHtml(item.versionNo), ' · ', escapeHtml(item.status), '</small></span>',
                '</span>',
                '<span class="sal-queue-meta">',
                    '<span class="sal-chip">', escapeHtml(item.marketer || 'Marketer not confirmed'), '</span>',
                    '<span class="sal-chip">', escapeHtml(item.palletCount || 0), ' pallets</span>',
                    '<span class="sal-chip">Finish ', escapeHtml(dateLabel(item.requiredFinishDate)), '</span>',
                '</span>',
                '<span class="sal-meter"><span style="width:', String(percent(planned, required)), '%"></span></span>',
                '<small class="sal-order-sub">', escapeHtml(number(planned)), ' / ', escapeHtml(number(required)), ' planned</small>',
            '</button>'
        ].join('');
    }

    function renderDemandCandidate(item, selected) {
        const sourceType = text(item.sourceType);
        const documentNo = text(item.documentNo);
        const isOpen = statusKey(item.status) === 'open';
        const isEligible = item.eligible === true && !isOpen;
        const selectedItem = text(selected.kind).toLowerCase() === 'candidate' &&
            text(selected.sourceType) === sourceType && text(selected.documentNo) === documentNo;
        const sourceBadge = sourceType.toLowerCase() === 'transfer order' ? 'TO' : 'SO';
        const party = item.customerName || item.destinationName || 'Destination not set';
        const destination = item.destinationName && text(item.destinationName) !== text(party) ? ' · ' + text(item.destinationName) : '';
        const availability = isEligible ? (item.hasActivePlan ? 'Additional demand' : 'Ready to plan') : (isOpen ? 'Awaiting release' : 'Not eligible');
        const detail = isEligible ? (item.hasActivePlan ? 'Select to refresh the current plan or create its next draft version' : 'Select to create a SAL plan') :
            (item.blockedReason || (isOpen ? 'Release this order before planning.' : 'This demand cannot be planned yet.'));

        return [
            '<button type="button" class="sal-queue-card sal-demand-candidate',
            selectedItem ? ' is-selected' : '',
            '" data-action="select-demand-candidate" data-source-type="', escapeHtml(sourceType),
            '" data-document-no="', escapeHtml(documentNo),
            '" data-eligible="', String(isEligible),
            '" data-status="', escapeHtml(statusKey(item.status)), '"',
            isEligible ? ' data-server-action' : ' disabled aria-disabled="true"',
            ' title="', escapeHtml(detail), '">',
                '<span class="sal-inline">',
                    '<span class="sal-priority" title="Default priority; 1 is highest">', escapeHtml(item.priority || 10), '</span>',
                    '<span class="sal-queue-copy"><strong>', escapeHtml(documentNo), ' · ', escapeHtml(party),
                    '</strong><small>Unplanned ', escapeHtml(sourceType || 'demand'), escapeHtml(destination), ' · ', escapeHtml(item.status || 'Status not set'), '</small></span>',
                '</span>',
                '<span class="sal-queue-meta">',
                    '<span class="sal-chip">', escapeHtml(availability), '</span>',
                    '<span class="sal-chip">', escapeHtml(sourceBadge), '</span>',
                    '<span class="sal-chip">', escapeHtml(item.marketer || 'Marketer not confirmed'), '</span>',
                    '<span class="sal-chip">', escapeHtml(number(item.outstandingQuantity)), ' outstanding</span>',
                    '<span class="sal-chip">', escapeHtml(number(item.itemLineCount, 0)), ' item lines</span>',
                    '<span class="sal-chip">Ship ', escapeHtml(dateLabel(item.shipmentDate)), '</span>',
                '</span>',
                '<small class="sal-order-sub">', escapeHtml(detail), '</small>',
            '</button>'
        ].join('');
    }

    function renderWorkspace() {
        const plan = localState.data.plan;
        if (!plan || !plan.header) {
            elements.workspace.innerHTML = [
                '<section class="sal-empty">',
                    '<div><h2>No SAL plan selected</h2>',
                    '<p>Select any released Sales Order or Transfer Order marked “Ready to plan” in the demand queue. SAL will create the draft plan and bring in all outstanding item lines.</p>',
                    '<button type="button" class="sal-button is-primary" data-action="refresh">Refresh demand</button></div>',
                '</section>'
            ].join('');
            return;
        }

        const header = plan.header;
        const caps = localState.data.capabilities || {};
        const sources = plan.sources || [];
        const selectedSource = sources.find(function (source) {
            return Number(source.lineNo) === Number(localState.activeSourceLine);
        }) || sources[0] || null;

        elements.workspace.innerHTML = [
            '<section class="sal-order-card">',
                '<div class="sal-order-heading">',
                    '<div class="sal-order-title">',
                        '<span class="sal-kicker">Plan ', escapeHtml(header.planNo), ' · Version ', escapeHtml(header.versionNo), '</span>',
                        '<h2>', escapeHtml(header.description || 'Untitled stock and logistics plan'), '</h2>',
                        '<div class="sal-order-sub">', escapeHtml(sourceHeadline(sources)), '</div>',
                    '</div>',
                    '<span class="sal-status" data-tone="', escapeHtml(statusKey(header.status)), '">', escapeHtml(header.status), '</span>',
                '</div>',
                '<div class="sal-facts">',
                    caps.canEdit ? priorityFact(header.priority) : fact('Priority (1 highest)', header.priority || 'Not set'),
                    fact('Marketer', header.marketerDescription || 'Not confirmed'),
                    fact('Required finish', dateLabel(header.requiredFinishDate)),
                    fact('Dispatch', dateLabel(header.dispatchDate)),
                    fact('Pallets', String((plan.pallets || []).length)),
                '</div>',
            '</section>',
            renderRouteCard(selectedSource, sources, caps),
            '<div class="sal-tabs" role="tablist">',
                tabButton('plan', 'Plan'),
                tabButton('source', 'Source'),
                tabButton('activity', 'Activity'),
            '</div>',
            '<section class="sal-tab-card">',
                localState.tab === 'source' ? renderSources(plan, caps) :
                    localState.tab === 'activity' ? renderActivity(plan) : renderPlan(plan, caps),
            '</section>'
        ].join('');
    }

    function fact(label, value) {
        return '<div class="sal-fact"><span>' + escapeHtml(label) + '</span><strong>' + escapeHtml(value) + '</strong></div>';
    }

    function priorityFact(current) {
        const options = [];
        for (let priority = 1; priority <= 10; priority += 1)
            options.push('<option value="' + priority + '"' + (Number(current) === priority ? ' selected' : '') + '>' + priority + '</option>');
        return [
            '<div class="sal-fact"><span>Priority · 1 highest</span>',
                '<div class="sal-priority-control">',
                    '<select id="sal-priority-select" aria-label="Plan priority">', options.join(''), '</select>',
                    '<button type="button" class="sal-link-button" data-action="save-priority" data-server-action>Save</button>',
                '</div>',
            '</div>'
        ].join('');
    }

    function tabButton(key, label) {
        return '<button type="button" class="sal-tab" data-action="tab" data-tab="' +
            escapeHtml(key) + '" aria-selected="' + String(localState.tab === key) + '">' + escapeHtml(label) + '</button>';
    }

    function sourceHeadline(sources) {
        if (!sources || !sources.length)
            return 'No demand added yet';
        const documents = [];
        sources.forEach(function (source) {
            const key = text(source.sourceType) + ' ' + text(source.documentNo);
            if (documents.indexOf(key) < 0)
                documents.push(key);
        });
        return documents.slice(0, 3).join(' · ') + (documents.length > 3 ? ' +' + (documents.length - 3) : '');
    }

    function renderRouteCard(source, sources, caps) {
        const canEdit = caps && caps.canEdit === true;
        if (!source) {
            return [
                '<section class="sal-route-card">',
                    '<div class="sal-route-copy"><strong>Fulfilment route</strong><small>Add demand before confirming the route and Packing Facility work.</small></div>',
                    '<button type="button" class="sal-button" data-action="add-demand" data-server-action>Add demand</button>',
                '</section>'
            ].join('');
        }

        const sourceOptions = sources.map(function (item) {
            return '<option value="' + escapeHtml(item.lineNo) + '"' +
                (Number(item.lineNo) === Number(source.lineNo) ? ' selected' : '') + '>' +
                escapeHtml(item.documentNo + ' · ' + item.itemNo) + '</option>';
        }).join('');

        return [
            '<section class="sal-route-card">',
                '<div class="sal-route-copy">',
                    '<strong>Fulfilment route · ', escapeHtml(source.documentNo), ' / ', escapeHtml(source.itemNo), '</strong>',
                    '<small>Route is confirmed per demand line. ', sources.length > 1 ? 'Choose the source line before changing it.' : '', '</small>',
                '</div>',
                '<div class="sal-route-controls">',
                    sources.length > 1 ? '<select id="sal-source-picker" aria-label="Source line">' + sourceOptions + '</select>' : '',
                    '<select id="sal-route-select" aria-label="Execution route"', canEdit ? '' : ' disabled', '>', routeOptions(source.executionRoute), '</select>',
                    '<select id="sal-work-select" aria-label="Facility work type"', canEdit ? '' : ' disabled', '>', workOptions(source.facilityWorkType), '</select>',
                    canEdit ? '<button type="button" class="sal-button is-primary" data-action="save-route" data-server-action>Confirm route</button>' : '<span class="sal-chip">Released version · read only</span>',
                '</div>',
            '</section>'
        ].join('');
    }

    function option(value, current) {
        return '<option value="' + escapeHtml(value) + '"' + (text(value) === text(current) ? ' selected' : '') + '>' + escapeHtml(value) + '</option>';
    }

    function routeOptions(current) {
        return [
            'Manjimup Pack',
            'Manjimup Existing Stock',
            'External DC Fulfilment',
            'Inter-DC Transfer',
            'No Facility Action'
        ].map(function (value) { return option(value, current); }).join('');
    }

    function workOptions(current) {
        return [
            'Pack New',
            'Match Existing',
            'Repack or Relabel',
            'None'
        ].map(function (value) { return option(value, current); }).join('');
    }

    function renderPlan(plan, caps) {
        const pallets = plan.pallets || [];
        const canEdit = caps && caps.canEdit === true;
        const actions = canEdit ? '<div class="sal-action-row">' +
            '<button type="button" class="sal-button" data-action="add-demand" data-server-action>Add demand</button>' +
            '<button type="button" class="sal-button" data-action="add-pallet" data-server-action>Add pallet group</button></div>' : '';
        return [
            '<div class="sal-panel-heading">',
                '<div><h3>Physical pallet plan</h3><p>Required versus planned allocation. Facility scan completion is not yet part of the Cloud model.</p></div>',
                actions,
            '</div>',
            renderSizes(plan.sources || []),
            '<div class="sal-plan-table">',
                pallets.length ? pallets.map(function (pallet) { return renderPallet(pallet, canEdit); }).join('') :
                    '<div class="sal-queue-footer">No physical pallets have been planned yet.</div>',
            '</div>'
        ].join('');
    }

    function renderSizes(sources) {
        const grouped = {};
        sources.forEach(function (source) {
            const key = [source.itemNo, source.variantCode, source.uom].join('|');
            if (!grouped[key])
                grouped[key] = {
                    itemNo: source.itemNo,
                    variantCode: source.variantCode,
                    uom: source.uom,
                    required: 0,
                    planned: 0
                };
            grouped[key].required += Number(source.requiredQuantity || 0);
            grouped[key].planned += Number(source.plannedQuantity || 0);
        });
        const items = Object.keys(grouped).map(function (key) { return grouped[key]; });
        if (!items.length)
            return '';
        return '<div class="sal-size-strip">' + items.map(function (item) {
            const label = item.itemNo + (item.variantCode ? ' · ' + item.variantCode : '');
            return [
                '<div class="sal-size-card">',
                    '<strong>', escapeHtml(label), '</strong>',
                    '<span>', escapeHtml(number(item.planned)), ' / ', escapeHtml(number(item.required)), ' ', escapeHtml(item.uom || 'units'), ' planned</span>',
                    '<div class="sal-meter"><span style="width:', String(percent(item.planned, item.required)), '%"></span></div>',
                '</div>'
            ].join('');
        }).join('') + '</div>';
    }

    function renderPallet(pallet, canEdit) {
        const components = pallet.components || [];
        const actions = canEdit ? '<div class="sal-action-row">' +
            '<button type="button" class="sal-link-button" data-action="add-component" data-pallet-no="' + escapeHtml(pallet.palletNo) + '" data-server-action>Add component</button>' +
            '<button type="button" class="sal-link-button" data-action="delete-pallet" data-pallet-no="' + escapeHtml(pallet.palletNo) + '" data-server-action>Remove</button></div>' : '';
        const productSummary = components.length ?
            components.map(function (component) { return component.itemNo; }).filter(function (value, index, array) {
                return array.indexOf(value) === index;
            }).join(' + ') : 'No components';
        return [
            '<article class="sal-plan-row">',
                '<div class="sal-row-head">',
                    cell('Pallet', pallet.palletNo),
                    cell('Type', pallet.palletType),
                    cell('Product / sizes', productSummary),
                    cell('Target', number(pallet.targetQuantity)),
                    cell('Planned', number(pallet.plannedQuantity)),
                    actions,
                '</div>',
                components.length ? '<div class="sal-components">' + components.map(function (component) {
                    return [
                        '<div class="sal-component">',
                            '<strong>', escapeHtml(component.itemNo), component.variantCode ? ' · ' + escapeHtml(component.variantCode) : '', '</strong>',
                            '<span>', escapeHtml(number(component.quantity)), ' ', escapeHtml(component.uom || 'units'), '</span>',
                            canEdit ? '<button type="button" class="sal-link-button" data-action="delete-component" data-pallet-no="' + escapeHtml(pallet.palletNo) +
                                '" data-line-no="' + escapeHtml(component.lineNo) + '" data-server-action>Remove</button>' : '',
                        '</div>'
                    ].join('');
                }).join('') + '</div>' : '',
            '</article>'
        ].join('');
    }

    function cell(label, value) {
        return '<div class="sal-cell"><span>' + escapeHtml(label) + '</span><strong>' + escapeHtml(value) + '</strong></div>';
    }

    function renderSources(plan, caps) {
        const sources = plan.sources || [];
        const canEdit = caps && caps.canEdit === true;
        const actions = canEdit ? '<div class="sal-action-row">' +
            '<button type="button" class="sal-button" data-action="add-demand" data-server-action>Add demand</button>' +
            '<button type="button" class="sal-button" data-action="refresh-demand" data-server-action>Refresh demand</button></div>' : '';
        return [
            '<div class="sal-panel-heading">',
                '<div><h3>Demand sources</h3><p>Released Business Central demand copied into this exact plan version.</p></div>',
                actions,
            '</div>',
            '<div class="sal-source-list">',
                sources.length ? sources.map(function (source) {
                    return [
                        '<article class="sal-source-row">',
                            '<strong>', escapeHtml(source.sourceType), '</strong>',
                            '<span>', escapeHtml(source.documentNo), '<br><small>Line ', escapeHtml(source.documentLineNo), '</small></span>',
                            '<span><strong>', escapeHtml(source.itemNo), '</strong><br><small>', escapeHtml(source.itemDescription), '</small></span>',
                            '<span><strong>', escapeHtml(number(source.plannedQuantity)), ' / ', escapeHtml(number(source.requiredQuantity)), '</strong><br><small>planned / plan quantity<br>BC outstanding snapshot ', escapeHtml(number(source.remainingQuantity)), '</small></span>',
                            '<span>', escapeHtml(source.executionRoute), '</span>',
                            '<span>', source.routingConfirmed ? 'Confirmed' : 'Review route', '</span>',
                            '<button type="button" class="sal-link-button" data-action="open-source" data-source-line="', escapeHtml(source.lineNo), '">Open source</button>',
                        '</article>'
                    ].join('');
                }).join('') : '<div class="sal-queue-footer">No demand has been added.</div>',
            '</div>'
        ].join('');
    }

    function renderActivity(plan) {
        const events = plan.events || [];
        return [
            '<div class="sal-panel-heading"><div><h3>Plan activity</h3><p>Append-only lifecycle history for this version.</p></div></div>',
            '<div class="sal-activity-list">',
                events.length ? events.map(function (event) {
                    return [
                        '<article class="sal-event-row">',
                            '<strong>', escapeHtml(event.eventType), '</strong>',
                            '<p>', escapeHtml(event.description), '</p>',
                            '<small>', escapeHtml(dateTimeLabel(event.eventAt)), ' · ', escapeHtml(event.userId), '</small>',
                        '</article>'
                    ].join('');
                }).join('') : '<div class="sal-queue-footer">No activity has been recorded yet.</div>',
            '</div>'
        ].join('');
    }

    function renderSidebar() {
        const data = localState.data;
        const plan = data.plan;
        const caps = data.capabilities || {};
        if (!plan || !plan.header) {
            elements.sidebar.innerHTML = [
                '<section class="sal-panel"><h3>Plan readiness</h3><p class="sal-order-sub">Select or create a plan to begin.</p></section>',
                '<section class="sal-panel sal-integration"><h3>Facility connection</h3><p>Publishing and facility feedback are intentionally disabled until the Cloud-to-facility integration is implemented.</p></section>'
            ].join('');
            return;
        }

        const header = plan.header;
        const readiness = plan.readiness || {};
        elements.sidebar.innerHTML = [
            '<section class="sal-panel">',
                '<div class="sal-panel-heading"><h3>Plan readiness</h3><span class="sal-status" data-tone="', readiness.readyToRelease ? 'released' : 'draft', '">', readiness.readyToRelease ? 'Ready' : 'Needs review', '</span></div>',
                '<div class="sal-checks">',
                    check('Demand added', readiness.hasDemand, readiness.hasDemand ? 'Valid' : 'Add source lines'),
                    check('Marketer confirmed', readiness.marketerConfirmed, readiness.marketerConfirmed ? 'Valid' : 'Review in details'),
                    check('Routes confirmed', readiness.routesConfirmed, readiness.routesConfirmed ? 'Valid' : 'Confirm each source'),
                    check('Physical pallet plan', readiness.hasPallets, readiness.hasPallets ? 'Set' : 'Add pallets'),
                    check('Required quantities', readiness.quantitiesBalanced, readiness.quantitiesBalanced ? 'Balanced' : 'Allocation differs'),
                '</div>',
            '</section>',
            '<section class="sal-panel sal-advisory">',
                '<h3>Planner suggestion</h3>',
                '<p>', escapeHtml(header.suggestion || 'Review the plan and validate it before release.'), '</p>',
            '</section>',
            '<section class="sal-panel">',
                '<div class="sal-panel-heading"><div><h3>Release plan</h3><p>Validate this Cloud plan version. This does not yet send an instruction to the Packing Facility.</p></div></div>',
                '<div class="sal-action-stack">',
                    header.status === 'Draft' ? '<button type="button" class="sal-button" data-action="validate" data-server-action' + (caps.canValidate ? '' : ' disabled') + '>Validate plan</button>' : '',
                    header.status === 'Draft' ? '<button type="button" class="sal-button is-primary" data-action="release" data-server-action' + (caps.canRelease ? '' : ' disabled') + '>Release plan</button>' : '',
                    header.status === 'Released' ? '<button type="button" class="sal-button is-primary" data-action="create-version" data-server-action>Create new version</button>' : '',
                    header.status === 'Draft' ? '<button type="button" class="sal-button is-danger" data-action="cancel" data-server-action>Cancel draft</button>' : '',
                '</div>',
            '</section>',
            '<section class="sal-panel sal-integration">',
                '<h3>Facility feedback</h3>',
                '<p><strong>Cloud status:</strong> ', escapeHtml(header.status), '<br><strong>Packing Facility:</strong> Integration not enabled<br><strong>Finish short:</strong> Not implemented</p>',
            '</section>'
        ].join('');
    }

    function check(label, ok, detail) {
        return [
            '<div class="sal-check', ok ? ' is-ok' : '', '">',
                '<span class="sal-check-mark">', ok ? '✓' : '!', '</span>',
                '<span>', escapeHtml(label), '</span>',
                '<small>', escapeHtml(detail), '</small>',
            '</div>'
        ].join('');
    }

    function renderFlow() {
        const plan = localState.data.plan;
        const steps = Array.prototype.slice.call(elements.host.querySelectorAll('.sal-step'));
        steps.forEach(function (step) {
            step.classList.remove('is-done', 'is-active');
        });
        if (!plan || !plan.header) {
            setStep('demand', 'is-active');
            return;
        }
        const readiness = plan.readiness || {};
        if (!readiness.hasDemand) {
            setStep('demand', 'is-active');
            return;
        }
        setStep('demand', 'is-done');
        if (!readiness.routesConfirmed) {
            setStep('route', 'is-active');
            return;
        }
        setStep('route', 'is-done');
        if (!readiness.hasPallets || !readiness.quantitiesBalanced) {
            setStep('pallet', 'is-active');
            return;
        }
        setStep('pallet', 'is-done');
        if (plan.header.status === 'Draft') {
            setStep('validate', plan.header.validatedAt ? 'is-done' : 'is-active');
            if (plan.header.validatedAt)
                setStep('release', 'is-active');
            return;
        }
        setStep('validate', 'is-done');
        if (plan.header.status === 'Released')
            setStep('release', 'is-done');
    }

    function setStep(name, className) {
        const step = elements.host.querySelector('[data-step="' + name + '"]');
        if (step)
            step.classList.add(className);
    }

    function handleInput(event) {
        if (event.target === elements.search) {
            localState.query = event.target.value || '';
            renderQueue();
            return;
        }
        if (event.target && event.target.id === 'sal-dialog-target-quantity')
            event.target.dataset.changed = 'true';
        if (event.target && event.target.id === 'sal-dialog-description')
            event.target.dataset.changed = 'true';
    }

    function handleChange(event) {
        if (event.target && event.target.id === 'sal-source-picker') {
            localState.activeSourceLine = Number(event.target.value || 0);
            renderWorkspace();
            return;
        }
        if (event.target && event.target.id === 'sal-dialog-pallet-type') {
            const target = elements.dialog.querySelector('#sal-dialog-target-quantity');
            const palletCount = elements.dialog.querySelector('#sal-dialog-pallet-count');
            const description = elements.dialog.querySelector('#sal-dialog-description');
            const isStandard = event.target.value === 'Standard';
            if (target && !target.dataset.changed)
                target.value = isStandard ? '160' : '';
            if (palletCount) {
                palletCount.disabled = !isStandard;
                if (!isStandard)
                    palletCount.value = '1';
            }
            if (description && !description.dataset.changed)
                description.value = isStandard ? 'Standard pallet' : event.target.value + ' pallet';
        }
    }

    function handleKeyDown(event) {
        if (!elements.dialog || elements.dialog.hidden)
            return;
        if (event.key === 'Escape') {
            closeDialog();
            return;
        }
        if (event.key !== 'Tab')
            return;
        const focusable = Array.prototype.slice.call(elements.dialog.querySelectorAll(
            'button:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'));
        if (!focusable.length)
            return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
            event.preventDefault();
            first.focus();
        }
    }

    function handleClick(event) {
        if (event.target === elements.dialog) {
            closeDialog();
            return;
        }
        const target = event.target.closest('[data-action]');
        if (!target)
            return;
        const action = target.dataset.action;

        if (action === 'fullscreen') {
            toggleFullscreen();
            return;
        }
        if (action === 'density') {
            toggleDensity();
            return;
        }
        if (action === 'close-dialog') {
            closeDialog();
            return;
        }
        if (action === 'submit-pallet') {
            submitPallet();
            return;
        }
        if (action === 'submit-component') {
            submitComponent();
            return;
        }
        if (action === 'refresh') {
            invoke('RefreshRequested', [], false);
            return;
        }
        if (action === 'open-native') {
            openNative('OpenNativeRequested', []);
            return;
        }
        if (action === 'open-plans') {
            openNative('OpenPlansRequested', []);
            return;
        }
        if (action === 'select-plan') {
            invoke('PlanSelected', [text(target.dataset.planNo), Number(target.dataset.versionNo)], false);
            return;
        }
        if (action === 'select-demand-candidate') {
            if (target.disabled || target.dataset.eligible !== 'true')
                return;
            invoke('DemandCandidateSelected', [text(target.dataset.sourceType), text(target.dataset.documentNo)], true);
            return;
        }
        if (action === 'tab') {
            localState.tab = target.dataset.tab || 'plan';
            renderWorkspace();
            return;
        }
        if (action === 'add-demand') {
            openNative('AddDemandRequested', [], true);
            return;
        }
        if (action === 'refresh-demand') {
            invoke('RefreshDemandRequested', [], true);
            return;
        }
        if (action === 'save-route') {
            const route = elements.host.querySelector('#sal-route-select');
            const work = elements.host.querySelector('#sal-work-select');
            invoke('SaveRoutingRequested', [
                Number(localState.activeSourceLine),
                route ? route.value : '',
                work ? work.value : ''
            ], true);
            return;
        }
        if (action === 'save-priority') {
            const priority = elements.host.querySelector('#sal-priority-select');
            invoke('SavePriorityRequested', [priority ? Number(priority.value) : 10], true);
            return;
        }
        if (action === 'add-pallet') {
            addPallet();
            return;
        }
        if (action === 'delete-pallet') {
            if (globalThis.confirm('Remove pallet ' + target.dataset.palletNo + ' and its components from this draft?'))
                invoke('DeletePalletRequested', [Number(target.dataset.palletNo)], true);
            return;
        }
        if (action === 'add-component') {
            addComponent(Number(target.dataset.palletNo));
            return;
        }
        if (action === 'delete-component') {
            if (globalThis.confirm('Remove this component from the draft pallet?'))
                invoke('DeleteComponentRequested', [Number(target.dataset.palletNo), Number(target.dataset.lineNo)], true);
            return;
        }
        if (action === 'open-source') {
            openNative('OpenSourceRequested', [Number(target.dataset.sourceLine)]);
            return;
        }
        if (action === 'validate') {
            invoke('ValidateRequested', [], true);
            return;
        }
        if (action === 'release') {
            if (globalThis.confirm('Validate and release this exact SAL plan version? This does not yet publish to the Packing Facility.'))
                invoke('ReleaseRequested', [], true);
            return;
        }
        if (action === 'create-version') {
            invoke('CreateVersionRequested', [], true);
            return;
        }
        if (action === 'cancel') {
            if (globalThis.confirm('Cancel this draft plan version?'))
                invoke('CancelDraftRequested', [], true);
            return;
        }
        if (target.dataset.marketer) {
            localState.marketer = target.dataset.marketer;
            elements.filters.querySelectorAll('[data-marketer]').forEach(function (button) {
                button.setAttribute('aria-pressed', String(button === target));
            });
            renderQueue();
        }
    }

    function addPallet() {
        openDialog([
            '<div class="sal-dialog" role="dialog" aria-modal="true" aria-labelledby="sal-dialog-title">',
                '<div class="sal-dialog-head"><div><span class="sal-eyebrow">Physical pallet plan</span><h2 id="sal-dialog-title">Add pallet group</h2></div>',
                '<button class="sal-dialog-close" type="button" data-action="close-dialog" aria-label="Close">×</button></div>',
                '<p class="sal-dialog-intro">Create one or more physical pallets. Standard groups stay compact; Custom and Mixed pallets remain visible by sequence.</p>',
                '<div class="sal-dialog-grid">',
                    '<label>Pallet type<select id="sal-dialog-pallet-type"><option value="Standard">Standard</option><option value="Custom">Custom</option><option value="Mixed">Mixed</option></select></label>',
                    '<label>Physical pallets<input id="sal-dialog-pallet-count" type="number" min="1" max="50" step="1" value="1"></label>',
                    '<label>Target trays / units per pallet<input id="sal-dialog-target-quantity" type="number" min="0.01" step="0.01" value="160"></label>',
                    '<label class="is-wide">Description<input id="sal-dialog-description" type="text" maxlength="100" value="Standard pallet"></label>',
                '</div>',
                '<div class="sal-dialog-error" id="sal-dialog-error" role="alert"></div>',
                '<div class="sal-dialog-actions"><button class="sal-button" type="button" data-action="close-dialog">Cancel</button>',
                '<button class="sal-button is-primary" type="button" data-action="submit-pallet">Add pallet group</button></div>',
            '</div>'
        ].join(''), '#sal-dialog-pallet-type');
    }

    function addComponent(palletNo) {
        const plan = localState.data.plan;
        const sources = plan && plan.sources ? plan.sources : [];
        if (!sources.length) {
            showToast('Add demand before adding a pallet component.', true);
            return;
        }
        const options = sources.map(function (source) {
            return '<option value="' + escapeHtml(source.lineNo) + '">' + escapeHtml(source.documentNo) + ' · ' +
                escapeHtml(source.itemNo) + ' · ' + escapeHtml(source.description || 'Item line') + '</option>';
        }).join('');
        openDialog([
            '<div class="sal-dialog" role="dialog" aria-modal="true" aria-labelledby="sal-dialog-title">',
                '<div class="sal-dialog-head"><div><span class="sal-eyebrow">Pallet ', escapeHtml(palletNo), '</span><h2 id="sal-dialog-title">Add product / size</h2></div>',
                '<button class="sal-dialog-close" type="button" data-action="close-dialog" aria-label="Close">×</button></div>',
                '<p class="sal-dialog-intro">Choose an order line and the exact quantity carried by this physical pallet.</p>',
                '<div class="sal-dialog-grid is-component">',
                    '<label class="is-wide">Product / size<select id="sal-dialog-source-line">', options, '</select></label>',
                    '<label>Tray / unit quantity<input id="sal-dialog-component-quantity" type="number" min="0.01" step="0.01" value="160"></label>',
                '</div>',
                '<input id="sal-dialog-pallet-no" type="hidden" value="', escapeHtml(palletNo), '">',
                '<div class="sal-dialog-error" id="sal-dialog-error" role="alert"></div>',
                '<div class="sal-dialog-actions"><button class="sal-button" type="button" data-action="close-dialog">Cancel</button>',
                '<button class="sal-button is-primary" type="button" data-action="submit-component">Add to pallet</button></div>',
            '</div>'
        ].join(''), '#sal-dialog-source-line');
    }

    function openDialog(content, focusSelector) {
        if (!elements.dialog)
            return;
        localState.dialogReturnFocus = document.activeElement;
        elements.dialog.innerHTML = content;
        elements.dialog.hidden = false;
        Array.prototype.forEach.call(elements.root.children, function (child) {
            if (child !== elements.dialog && child !== elements.toast)
                child.inert = true;
        });
        const focusTarget = elements.dialog.querySelector(focusSelector);
        if (focusTarget)
            focusTarget.focus();
    }

    function closeDialog() {
        if (!elements.dialog)
            return;
        elements.dialog.hidden = true;
        elements.dialog.innerHTML = '';
        Array.prototype.forEach.call(elements.root.children, function (child) {
            child.inert = false;
        });
        if (localState.dialogReturnFocus && typeof localState.dialogReturnFocus.focus === 'function')
            localState.dialogReturnFocus.focus();
        localState.dialogReturnFocus = null;
    }

    function dialogValue(selector) {
        const field = elements.dialog && elements.dialog.querySelector(selector);
        return field ? field.value : '';
    }

    function showDialogError(message) {
        const field = elements.dialog && elements.dialog.querySelector('#sal-dialog-error');
        if (field)
            field.textContent = message;
    }

    function submitPallet() {
        const palletType = dialogValue('#sal-dialog-pallet-type');
        const palletCount = Number(dialogValue('#sal-dialog-pallet-count'));
        const targetQuantity = Number(dialogValue('#sal-dialog-target-quantity'));
        const description = dialogValue('#sal-dialog-description').trim();
        if (!['Standard', 'Custom', 'Mixed'].includes(palletType)) {
            showDialogError('Choose Standard, Custom or Mixed.');
            return;
        }
        if (!Number.isSafeInteger(palletCount) || palletCount < 1 || palletCount > 50) {
            showDialogError('Physical pallets must be a whole number from 1 to 50.');
            return;
        }
        if (palletType !== 'Standard' && palletCount !== 1) {
            showDialogError('Custom and Mixed pallets must be added one physical pallet at a time.');
            return;
        }
        if (!Number.isFinite(targetQuantity) || targetQuantity <= 0) {
            showDialogError('Target trays / units must be greater than zero.');
            return;
        }
        closeDialog();
        invoke('AddPalletRequested', [palletType, palletCount, targetQuantity, description || palletType + ' pallet'], true);
    }

    function submitComponent() {
        const palletNo = Number(dialogValue('#sal-dialog-pallet-no'));
        const sourceLineNo = Number(dialogValue('#sal-dialog-source-line'));
        const quantity = Number(dialogValue('#sal-dialog-component-quantity'));
        if (!Number.isSafeInteger(palletNo) || palletNo <= 0 || !Number.isSafeInteger(sourceLineNo) || sourceLineNo <= 0) {
            showDialogError('Choose a valid pallet and product / size.');
            return;
        }
        if (!Number.isFinite(quantity) || quantity <= 0) {
            showDialogError('Tray / unit quantity must be greater than zero.');
            return;
        }
        closeDialog();
        invoke('AddComponentRequested', [palletNo, sourceLineNo, quantity], true);
    }

    globalThis.SetState = applyState;
    globalThis.SALPlannerWorkspace = {
        start: function () {
            buildShell();
            renderAll();
            invoke('ControlReady', [], false);
        }
    };
}());
