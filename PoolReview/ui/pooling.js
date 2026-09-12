(function () {
    'use strict';

    var root = null;
    var state = null;
    var busy = false;
    var started = false;
    var localMessage = '';
    var localError = false;
    var requestSerial = 0;
    var stateSerial = 0;
    var localSearch = '';
    var issueFocus = -1;
    var detailView = 'findings';
    var fullscreenPending = false;
    var fullscreenNotice = '';
    var allowedActions = ['scope', 'select', 'check', 'batch', 'reload', 'source', 'groupSource', 'standard', 'payments', 'paymentSource', 'report', 'paymentExport'];
    var buckets = [
        { value: -1, key: 'all', title: 'All pool groups', hint: 'In this season / week', tone: 'all' },
        { value: 0, key: 'unchecked', title: 'Not checked', hint: 'Run a check to begin', tone: 'unchecked' },
        { value: 1, key: 'mismatches', title: 'Mismatches', hint: 'Differences detected', tone: 'mismatch' },
        { value: 2, key: 'review', title: 'Needs review', hint: 'Take a closer look', tone: 'review' },
        { value: 3, key: 'unable', title: 'Unable to check', hint: 'Results are incomplete', tone: 'unable' },
        { value: 4, key: 'clear', title: 'No findings', hint: 'Within these checks', tone: 'clear' }
    ];

    function nav() {
        return window.Microsoft && window.Microsoft.Dynamics && window.Microsoft.Dynamics.NAV;
    }

    function connected() {
        return !!(nav() && typeof nav().InvokeExtensibilityMethod === 'function');
    }

    function esc(value) {
        return String(value === undefined || value === null ? '' : value).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function text(value, fallback) {
        return typeof value === 'string' && value.trim() ? value : (fallback || '');
    }

    function num(value, decimals) {
        return typeof value === 'number' && Number.isFinite(value)
            ? value.toLocaleString(undefined, { minimumFractionDigits: decimals || 0, maximumFractionDigits: decimals || 0 })
            : '—';
    }

    function validId(value) {
        return typeof value === 'number' && Number.isSafeInteger(value) && value > 0;
    }

    function measured(group, property, decimals) {
        return group && group.scanComplete === true ? num(group[property], decimals) : '—';
    }

    function resource(path) {
        try {
            return nav() && typeof nav().GetImageResource === 'function' ? nav().GetImageResource(path) : path;
        } catch (_) {
            return path;
        }
    }

    function disabled(condition) {
        return busy || !connected() || condition ? ' disabled' : '';
    }

    function bucket(value) {
        return buckets.find(function (item) { return item.value === value; }) || buckets[1];
    }

    function severity(value) {
        if (value === 2) return { label: 'Mismatch', tone: 'mismatch' };
        if (value === 1) return { label: 'Needs review', tone: 'review' };
        return { label: 'Information', tone: 'information' };
    }

    function selectedGroup() {
        if (!state) return null;
        return state.groups.find(function (group) { return group.id === state.selectedId; }) || null;
    }

    function actionButton(action, label, className, attrs, unavailable) {
        return '<button type="button" class="pw-button ' + (className || '') + '" data-action="' + esc(action) + '"' +
            (attrs || '') + disabled(unavailable) + '>' + esc(label) + '</button>';
    }

    function scope() {
        return state ? state.scope : { season: '', week: '', type: -1, focus: -1 };
    }

    function logoHtml(className, file, alt) {
        return '<img class="' + className + '" src="' + esc(resource('ui/images/' + file)) + '" alt="' + esc(alt) + '">';
    }

    function isFullscreen() {
        return !!root && document.fullscreenElement === root;
    }

    function fullscreenButton() {
        return '<button id="pw-fullscreen" type="button" class="pw-fullscreen-button" data-fullscreen="true" aria-pressed="' + isFullscreen() + '"' + (fullscreenPending ? ' disabled' : '') + '>' + (isFullscreen() ? 'Exit full screen' : 'Full screen') + '</button>' +
            '<span class="pw-fullscreen-notice" role="status">' + esc(fullscreenNotice) + '</span>';
    }

    function syncFullscreen() {
        if (!root) return;
        var button = root.querySelector('#pw-fullscreen');
        if (button) {
            button.textContent = isFullscreen() ? 'Exit full screen' : 'Full screen';
            button.setAttribute('aria-pressed', String(isFullscreen()));
            button.disabled = fullscreenPending;
        }
        var notice = root.querySelector('.pw-fullscreen-notice');
        if (notice) notice.textContent = fullscreenNotice;
    }

    async function toggleFullscreen() {
        if (fullscreenPending) return;
        fullscreenPending = true;
        fullscreenNotice = '';
        syncFullscreen();
        try {
            if (isFullscreen()) await document.exitFullscreen();
            else {
                if (!root.requestFullscreen || !document.fullscreenEnabled) throw new Error('Fullscreen unavailable');
                await root.requestFullscreen();
            }
        } catch (_) {
            fullscreenNotice = 'Full screen is unavailable in this window. Use the browser’s full-screen command or expand the BC page.';
        } finally {
            fullscreenPending = false;
            syncFullscreen();
        }
    }

    document.addEventListener('fullscreenchange', syncFullscreen);

    function renderMasthead() {
        return '<header class="pw-masthead">' +
            '<div class="pw-brand">' + logoHtml('pw-wordmark', 'avocado-wordmark.png', 'The Avocados Collective') + '</div>' +
            '<div class="pw-heading"><div class="pw-eyebrow">The Avocados Collective</div>' +
            '<h1>Pooling overview</h1><p>See your pools. Understand the exceptions.</p></div>' +
            '<div class="pw-header-context">' + fullscreenButton() + '<span class="pw-readonly">Read-only workspace</span>' +
            '<span>' + esc(state ? text(state.company, 'Company unavailable') : 'Connecting to Business Central') + '</span></div>' +
            '</header>';
    }

    function renderCards() {
        return '<section class="pw-status-grid" aria-label="Filter pool groups by check result">' +
            buckets.map(function (item) {
                var active = scope().focus === item.value;
                var count = state && !(state.error && !state.groups.length && state.summary.all === 0) ? num(state.summary[item.key]) : '—';
                return '<button type="button" class="pw-status-card pw-tone-' + item.tone + (active ? ' is-active' : '') +
                    '" data-focus="' + item.value + '" aria-pressed="' + active + '"' + disabled(!state) + '>' +
                    '<span class="pw-card-top"><span class="pw-card-dot" aria-hidden="true"></span><span>' + esc(item.title) +
                    '</span></span><strong>' + count + '</strong><span class="pw-card-hint">' + esc(item.hint) + '</span></button>';
            }).join('') + '</section>';
    }

    function option(value, label, selected) {
        return '<option value="' + esc(value) + '"' + (selected ? ' selected' : '') + '>' + esc(label) + '</option>';
    }

    function renderFilters() {
        var current = scope();
        var seasons = state ? state.options.seasons : [];
        var weeks = state ? state.options.weeks : [];
        var seasonOptions = option('', 'All seasons', !current.season) + seasons.map(function (season) {
            return option(season, season, season === current.season);
        }).join('');
        var weekOptions = option('', 'All weeks', !current.week) + weeks.filter(function (week) {
            return !current.season || week.season === current.season;
        }).map(function (week) {
            return option(week.code, week.code, week.code === current.week);
        }).join('');
        return '<section class="pw-filter-panel" aria-label="Choose pooling scope">' +
            '<div class="pw-filter-fields"><label>Season<select id="pw-season" data-scope="season"' + disabled(!state) + '>' + seasonOptions +
            '</select></label><label>Pool week<select id="pw-week" data-scope="week"' + disabled(!state) + '>' + weekOptions +
            '</select></label><label>Pool type<select id="pw-type" data-scope="type"' + disabled(!state) + '>' +
            option(-1, 'All pool types', current.type === -1) +
            option(0, 'Internal', current.type === 0) + option(1, 'External', current.type === 1) +
            option(2, 'Contract pack', current.type === 2) + '</select></label></div>' +
            '<div class="pw-filter-actions">' +
            actionButton('reload', 'Reload groups', 'pw-button-secondary', ' title="Reload source group metadata and clear checks from this session"') +
            actionButton('batch', 'Check current list', 'pw-button-primary', ' title="Check up to 50 groups in the current filtered list"', !state || !state.total || !!localSearch.trim()) +
            '</div><p class="pw-filter-note">' + batchNote() + '</p></section>';
    }

    function batchNote() {
        return localSearch.trim() ? 'Clear the group search to check this list.' :
            'Status cards filter this list. Check up to 50 groups at a time. Reloading clears this session’s results.';
    }

    function renderMessage() {
        var message = localMessage || (state && text(state.message));
        var isError = localMessage ? localError : !!(state && state.error);
        if (!connected()) return '<div class="pw-notice pw-notice-error" role="alert"><strong>Not connected to Business Central.</strong> Open Pooling Overview inside BC to load and check actual pools.</div>';
        if (busy) return '<div class="pw-notice pw-notice-busy" role="status"><span class="pw-spinner" aria-hidden="true"></span><span>' +
            esc(localMessage || 'Loading your pooling workspace…') + '</span></div>';
        if (!message) return '';
        return '<div class="pw-notice' + (isError ? ' pw-notice-error' : '') + '" role="' + (isError ? 'alert' : 'status') + '">' + esc(message) + '</div>';
    }

    function renderGroupRows() {
        if (!state) return '<tr><td colspan="5" class="pw-empty"><strong>No pool data loaded</strong><span>' +
            (connected() ? 'Waiting for Business Central.' : 'Connect to BC to view your pool groups.') + '</span></td></tr>';
        var query = localSearch.toLocaleLowerCase().trim();
        var visibleGroups = state.groups.filter(function (group) {
            return !query || [group.code, group.season, group.week, group.typeCaption].join(' ').toLocaleLowerCase().indexOf(query) !== -1;
        });
        if (!visibleGroups.length && state.error && !state.groups.length) return '<tr><td colspan="5" class="pw-empty"><strong>Pool data is unavailable</strong><span>Review the connection or source error above, then reload groups.</span></td></tr>';
        if (!visibleGroups.length) return '<tr><td colspan="5" class="pw-empty"><strong>' +
            (query ? 'No matching groups in the shown list' : 'No groups match these filters') +
            '</strong><span>' + (query ? 'Try another search or clear the search text.' : 'Choose another status card, season or week.') + '</span></td></tr>';
        return visibleGroups.map(function (group) {
            var appearance = bucket(group.bucket);
            var findings = group.scanComplete === true ? num(group.mismatchCount) + ' / ' + num(group.warningCount) : '—';
            return '<tr class="' + (group.id === state.selectedId ? 'is-selected' : '') + '" data-group-row="' + esc(group.id) + '">' +
                '<td><button type="button" class="pw-group-link" data-action="select" data-group-id="' + esc(group.id) + '"' +
                (group.id === state.selectedId ? ' aria-current="true"' : '') + disabled(!validId(group.id)) + '>' +
                esc(text(group.code, 'Group ' + group.id)) + '</button><span class="pw-cell-sub">' +
                esc([group.week, group.typeCaption].filter(Boolean).join(' · ')) + '</span>' +
                '<span class="pw-business-status">' + esc(text(group.businessStatus, 'Business status unavailable')) + '</span></td>' +
                '<td><span class="pw-badge pw-tone-' + appearance.tone + '">' + esc(appearance.title === 'All pool groups' ? group.status : appearance.title) +
                '</span><span class="pw-cell-sub">' + esc(text(group.lastScanText, 'Not checked this session')) + '</span></td>' +
                '<td class="pw-number">' + measured(group, 'movementKg', 2) + '</td>' +
                '<td class="pw-number">' + measured(group, 'allKg', 2) + '</td>' +
                '<td class="pw-number pw-findings-count" title="Mismatches / needs review">' + findings + '</td></tr>';
        }).join('');
    }

    function renderGroupList() {
        var showing = state ? 'Showing ' + num(state.shown) + ' of ' + num(state.total) + ' groups' : 'No data loaded';
        return '<section class="pw-panel pw-groups-panel" aria-labelledby="pw-groups-title">' +
            '<div class="pw-panel-heading"><div><h2 id="pw-groups-title">Pool groups</h2><p>' + esc(showing) + '</p></div>' +
            '<span class="pw-section-tag">' + esc(bucket(scope().focus).title) + '</span></div>' +
            '<div class="pw-list-toolbar"><label class="pw-search-label" for="pw-search">Find in shown groups</label>' +
            '<input id="pw-search" type="search" placeholder="Group, week or pool type…" value="' + esc(localSearch) + '"' + disabled(!state) + '>' +
            '</div>' +
            (state && state.hasMore ? '<div class="pw-list-limit" role="status">Only the first ' + num(state.shown) +
                ' groups are shown. Narrow the season, week or status to see more. Status totals cover the full filtered scope.</div>' : '') +
            '<div class="pw-table-scroll" tabindex="0" role="region" aria-label="Pool groups table. Scroll to view additional rows and columns.">' +
            '<table class="pw-table"><thead><tr><th scope="col">Pool group</th><th scope="col">Check result</th>' +
            '<th scope="col" class="pw-number">Movement kg</th><th scope="col" class="pw-number">All ledger kg</th>' +
            '<th scope="col" class="pw-number">Mismatch / review</th></tr></thead><tbody id="pw-group-rows">' + renderGroupRows() + '</tbody></table></div>' +
            '<div class="pw-table-note">Kilograms are different ledger views. They are not a reconciliation of physical stock.</div></section>';
    }

    function metric(label, value, note, className) {
        return '<div class="pw-metric ' + (className || '') + '"><span>' + esc(label) + '</span><strong>' + esc(value) + '</strong>' +
            (note ? '<small>' + esc(note) + '</small>' : '') + '</div>';
    }

    function renderIssue(issue, index) {
        var appearance = severity(issue.severity);
        var metadata = [];
        if (issue.pool) metadata.push('Pool ' + issue.pool);
        if (issue.grower) metadata.push('Grower ' + issue.grower);
        if (issue.document) metadata.push('Document ' + issue.document);
        if (issue.line) metadata.push('Line ' + issue.line);
        if (issue.payment) metadata.push('Payment ' + issue.payment);
        var numericMeasure = ['raw signed kg', 'recorded amount', 'group ID', 'active PR matches'].indexOf(issue.measure) !== -1;
        var comparisonDecimals = issue.measure === 'group ID' || issue.measure === 'active PR matches' ? 0 : 2;
        var quantities = numericMeasure && typeof issue.expected === 'number' && typeof issue.actual === 'number' ?
            '<div class="pw-comparison"><span><small>Expected</small><strong>' + num(issue.expected, comparisonDecimals) + '</strong></span>' +
            '<span><small>Actual</small><strong>' + num(issue.actual, comparisonDecimals) + '</strong></span><span class="pw-comparison-unit">' + esc(issue.measure) + '</span></div>' : '';
        if (issue.rule === 'RECOVERY' && typeof issue.actual === 'number') {
            quantities = '<div class="pw-comparison"><span><small>Recorded amount</small><strong>' + num(issue.actual, 2) + '</strong></span></div>';
        }
        return '<details class="pw-issue pw-tone-' + appearance.tone + '" data-issue-key="' + esc(issue.id) + '"' + (index === 0 ? ' open' : '') + '>' +
            '<summary><span class="pw-badge pw-tone-' + appearance.tone + '">' + appearance.label + '</span>' +
            '<strong>' + esc(text(issue.summary, 'Review finding')) + '</strong><span class="pw-disclosure" aria-hidden="true"></span></summary>' +
            '<div class="pw-issue-body"><p class="pw-issue-details">' + esc(text(issue.details, 'No further explanation was supplied.')) + '</p>' +
            (metadata.length ? '<div class="pw-issue-meta">' + metadata.map(function (entry) { return '<span>' + esc(entry) + '</span>'; }).join('') + '</div>' : '') +
            quantities + '<div class="pw-evidence-actions">' +
            actionButton('source', 'View source', 'pw-button-small pw-button-secondary', ' data-issue-id="' + esc(issue.id) + '" data-related="false"', !issue.canSource) +
            actionButton('source', 'Related record', 'pw-button-small pw-button-secondary', ' data-issue-id="' + esc(issue.id) + '" data-related="true"', !issue.canRelated) +
            '</div><div class="pw-rule-reference">Check reference: ' + esc(text(issue.rule, 'Unavailable')) + '</div></div></details>';
    }

    function renderIssues(group) {
        var issues = state.issues.filter(function (issue) {
            return issue.groupId === group.id;
        });
        var visible = issues.filter(function (issue) { return issueFocus === -1 || issue.severity === issueFocus; });
        var filterItems = [{ value: -1, label: 'All' }, { value: 2, label: 'Mismatches' }, { value: 1, label: 'Review' }, { value: 0, label: 'Information' }];
        var filters = issues.length ? '<div class="pw-issue-filters" aria-label="Filter findings">' + filterItems.map(function (item) {
            var count = issues.filter(function (issue) { return item.value === -1 || issue.severity === item.value; }).length;
            return '<button type="button" class="' + (issueFocus === item.value ? 'is-active' : '') + '" data-issue-focus="' + item.value +
                '" aria-pressed="' + (issueFocus === item.value) + '"' + (busy ? ' disabled' : '') + '>' + item.label + ' <span>' + count + '</span></button>';
        }).join('') + '</div>' : '';
        var emptyTitle;
        var emptyDetail;
        if (issues.length && !visible.length) {
            emptyTitle = 'No findings in this category';
            emptyDetail = 'Choose another finding filter.';
        } else if (!group.lastScanText || group.bucket === 0) {
            emptyTitle = 'This group has not been checked';
            emptyDetail = 'Select Check this group to review the available source records.';
        } else if (!group.scanComplete) {
            emptyTitle = 'Check incomplete';
            emptyDetail = 'Review the check message and try again. Missing results do not mean this group is clear.';
        } else {
            emptyTitle = 'No findings within these checks';
            emptyDetail = 'This does not confirm a pool is ready to close or pay. See check coverage below.';
        }
        var more = state.issueHasMore ? '<p class="pw-list-limit">Showing ' + num(issues.length) + ' of ' + num(state.issueTotal) +
            ' findings. The displayed findings are incomplete.</p>' : '';
        return '<div class="pw-findings-heading"><h3>Findings &amp; evidence</h3><span>' + num(issues.length) + ' shown</span></div>' +
            filters + more + '<div class="pw-issue-list">' + (visible.length ? visible.map(renderIssue).join('') :
                '<div class="pw-empty pw-empty-compact"><strong>' + emptyTitle + '</strong><span>' + emptyDetail + '</span></div>') + '</div>';
    }

    function renderSelection() {
        var group = selectedGroup();
        if (!group) return '<section class="pw-panel pw-selection-panel"><div class="pw-panel-heading"><div><h2>Group details</h2>' +
            '<p>Select a pool group to investigate</p></div></div><div class="pw-empty"><strong>Your selected group will appear here</strong>' +
            '<span>See its checks, kilogram views and supporting records in one place.</span></div></section>';
        var appearance = bucket(group.bucket);
        return '<section class="pw-panel pw-selection-panel" aria-labelledby="pw-selected-title">' +
            '<div class="pw-panel-heading"><div><span class="pw-heading-kicker">Selected pool group</span><h2 id="pw-selected-title">' +
            esc(text(group.code, 'Group ' + group.id)) + '</h2><p>' +
            esc([group.season, group.week, group.typeCaption].filter(Boolean).join(' · ')) + '</p></div>' +
            '<span class="pw-section-tag">' + esc(text(group.businessStatus, 'Status unavailable')) + '</span></div>' +
            '<div class="pw-selection-body"><div class="pw-selection-actions"><span class="pw-badge pw-tone-' + appearance.tone + '">' +
            esc(appearance.title) + '</span>' + actionButton('check', 'Check this group', 'pw-button-primary', ' data-group-id="' + esc(group.id) + '"', !validId(group.id)) +
            '</div><p class="pw-scan-time">Last check: ' + esc(text(group.lastScanText, 'Not checked this session')) + '</p>' +
            (group.detail ? '<p class="pw-group-detail">' + esc(group.detail) + '</p>' : '') +
            '<div class="pw-kg-grid">' + metric('Movement kg', measured(group, 'movementKg', 2), 'TR / TRA / TRD movements') +
            metric('All ledger kg', measured(group, 'allKg', 2), 'Across transaction types') + '</div>' +
            '<div class="pw-small-metrics">' + metric('Pools', measured(group, 'poolCount')) +
            metric('Ledger entries', measured(group, 'ledgerCount')) + metric('Payments', measured(group, 'paymentCount')) +
            metric('Ledger net', measured(group, 'ledgerNet', 2)) + '</div>' +
            '<div class="pw-invoice-strip"><span>Candidate invoice lines <strong>' + measured(group, 'invoiceCandidates') + '</strong></span>' +
            '<span>Attributed invoice lines <strong>' + measured(group, 'attributedInvoices') + '</strong></span>' +
            '<span>Unresolved <strong>' + measured(group, 'unresolvedCount') + '</strong></span></div>' +
            '<div class="pw-group-source">' + actionButton('groupSource', 'View group record', 'pw-button-small pw-button-secondary',
                ' data-group-id="' + esc(group.id) + '"', !validId(group.id)) + '<span>Supporting records open read-only.</span></div>' +
            renderDetailTabs() + (detailView === 'payments' ? renderPayments(group) : renderIssues(group)) + '</div></section>';
    }

    function renderDetailTabs() {
        return '<div class="pw-detail-tabs" role="group" aria-label="Selected group view">' +
            ['findings', 'payments'].map(function (view) { return '<button type="button" data-detail-view="' + view + '" aria-pressed="' + (detailView === view) + '"' + (busy ? ' disabled' : '') + '>' + (view === 'payments' ? 'Pool payments' : 'Findings & evidence') + '</button>'; }).join('') + '</div>';
    }

    function renderReports() {
        return '<section class="pw-report-bar" aria-label="Reporting"><div><h2>Reports</h2><p>Download CSV for the current season, week, type and status. Uses existing check results.</p></div><div class="pw-report-actions">' +
            actionButton('report', 'Export overview', 'pw-button-secondary', ' data-report="overview"', !state || !state.total || !!localSearch.trim()) +
            actionButton('report', 'Export findings', 'pw-button-secondary', ' data-report="findings"', !state || !state.total || !!localSearch.trim()) +
            '</div></section>';
    }

    function paymentSnapshot(group) {
        var payments = state && state.payments;
        return payments && payments.groupId === group.id ? payments : null;
    }

    function renderPayments(group) {
        var payments = paymentSnapshot(group);
        var loaded = payments && payments.loaded;
        var controls = actionButton('payments', loaded ? 'Refresh payment history' : 'Load payment history', 'pw-button-secondary', ' data-group-id="' + esc(group.id) + '"') +
            actionButton('paymentExport', 'Export loaded payments', 'pw-button-secondary', '', !loaded);
        var body = '<p class="pw-payment-note">Payment runs and their recorded invoice references. Run completion does not confirm the grower has been paid.</p>';
        if (payments && payments.error) body += '<p class="pw-notice pw-notice-error" role="alert">' + esc(payments.error) + '</p>';
        if (!loaded) body += '<p class="pw-payment-empty">Load history to see this group’s payment runs. It can be viewed independently of the group checks.</p>';
        else {
            body += '<p class="pw-payment-note">Loaded ' + esc(payments.loadedAt) + ' · Showing ' + num(payments.rows.length) + ' of ' + num(payments.total) + ' payment headers.</p>';
            if (payments.hasMore) body += '<p class="pw-list-limit">Only the first 200 payment headers are loaded and exported. This is not the full payment history.</p>';
            if (!payments.rows.length) body += '<p class="pw-payment-empty">No payment headers were visible for this group when history was loaded.</p>';
            body += payments.rows.map(function (payment) {
                var tone = payment.reversed ? 'unable' : (payment.completedAt ? 'clear' : 'review');
                var detail = function (label, value) { return '<div><dt>' + esc(label) + '</dt><dd>' + esc(value || 'Not recorded') + '</dd></div>'; };
                return '<details class="pw-payment-run" data-issue-key="payment-' + esc(payment.id) + '"><summary><strong>Payment ' + num(payment.number) + ' · ' + esc(payment.type) + '</strong><span class="pw-badge pw-tone-' + tone + '">' + esc(payment.status) + '</span></summary>' +
                    '<div class="pw-payment-body"><dl>' + detail('Payment ID', String(payment.id)) + detail('Pool', payment.pool || 'Group-level / not recorded') +
                    detail('Provisional flag', payment.provisional ? 'Yes' : 'No') + detail('Closed at', payment.closedAt) + detail('Completed at', payment.completedAt) +
                    detail('Closed by', payment.closedBy) + detail('Completed by', payment.completedBy) + detail('Journal batch', payment.journalBatch) +
                    detail('Reversed by payment ID', payment.reversedBy ? String(payment.reversedBy) : '') + '</dl>' +
                    '<p class="pw-payment-note"><strong>Recorded purchase invoice references</strong><br>' + esc(payment.invoiceReferences || 'None recorded') + '</p>' +
                    actionButton('paymentSource', 'View payment header', 'pw-button-small pw-button-secondary', ' data-payment-id="' + esc(payment.id) + '"') + '</div></details>';
            }).join('');
        }
        return '<section class="pw-payment-section" aria-label="Pool payments"><h3>Pool payments</h3><div class="pw-payment-controls">' + controls + '</div>' + body + '</section>';
    }

    function renderCoverage() {
        return '<section class="pw-coverage"><div class="pw-coverage-label">Check coverage</div><p>' +
            esc(state ? text(state.coverage, 'Coverage information is unavailable. Do not treat these checks as a complete reconciliation.') :
                'Coverage will be supplied with the Business Central results.') +
            '</p><small>Results are a snapshot of the records read during each check. Refresh after source records change. Engine corrections are handled separately.</small></section>';
    }

    function renderFooter() {
        return '<footer class="pw-footer">' + logoHtml('pw-footer-mark', 'avocado-mark.png', '') +
            '<span class="pw-footer-item"><small>Company</small><strong>' + esc(state ? text(state.company, 'Unavailable') : 'Not connected') + '</strong></span>' +
            '<span class="pw-footer-item"><small>Environment</small><strong>' + esc(state ? text(state.environment, 'Unavailable') : 'Unavailable') + '</strong></span>' +
            '<span class="pw-footer-item pw-footer-last"><small>Latest check in scope</small><strong>' +
            esc(state ? text(state.summary.latestScanText, 'Not checked this session') : 'Not checked') + '</strong></span>' +
            '<span class="pw-footer-mode">POOLING · READ ONLY</span></footer>';
    }

    function rememberFocus() {
        var active = document.activeElement;
        if (!active || !root.contains(active)) return null;
        return {
            id: active.id,
            action: active.getAttribute('data-action'),
            group: active.getAttribute('data-group-id'),
            focus: active.getAttribute('data-focus'),
            issue: active.getAttribute('data-issue-id'),
            related: active.getAttribute('data-related'),
            payment: active.getAttribute('data-payment-id'),
            position: typeof active.selectionStart === 'number' ? active.selectionStart : null
        };
    }

    function restoreFocus(saved) {
        if (!saved) return;
        var element = saved.id ? document.getElementById(saved.id) : null;
        if (!element) {
            element = Array.from(root.querySelectorAll('button')).find(function (button) {
                return saved.focus !== null ? button.getAttribute('data-focus') === saved.focus :
                    saved.action && button.getAttribute('data-action') === saved.action &&
                    button.getAttribute('data-group-id') === saved.group &&
                    button.getAttribute('data-issue-id') === saved.issue &&
                    button.getAttribute('data-related') === saved.related && button.getAttribute('data-payment-id') === saved.payment;
            });
        }
        if (element && !element.disabled) {
            element.focus({ preventScroll: true });
            if (saved.position !== null && typeof element.setSelectionRange === 'function' && element.type !== 'number') {
                try { element.setSelectionRange(saved.position, saved.position); } catch (_) { /* Selects have no text caret. */ }
            }
        }
    }

    function render() {
        if (!root) return;
        var savedFocus = rememberFocus();
        var scroll = root.querySelector('.pw-table-scroll');
        var scrollTop = scroll ? scroll.scrollTop : 0;
        var scrollLeft = scroll ? scroll.scrollLeft : 0;
        var expandedIssues = {};
        root.querySelectorAll('details[data-issue-key]').forEach(function (details) {
            expandedIssues[details.getAttribute('data-issue-key')] = details.open;
        });
        root.innerHTML = '<div class="pw-shell" aria-busy="' + busy + '">' + renderMasthead() +
            '<main class="pw-main">' + renderCards() + renderFilters() + renderReports() + renderMessage() +
            '<div class="pw-workspace">' + renderGroupList() + renderSelection() + '</div>' + renderCoverage() +
            '</main>' + renderFooter() + '</div>';
        var newScroll = root.querySelector('.pw-table-scroll');
        if (newScroll) { newScroll.scrollTop = scrollTop; newScroll.scrollLeft = scrollLeft; }
        root.querySelectorAll('details[data-issue-key]').forEach(function (details) {
            var key = details.getAttribute('data-issue-key');
            if (Object.prototype.hasOwnProperty.call(expandedIssues, key)) details.open = expandedIssues[key];
        });
        restoreFocus(savedFocus);
    }

    function fail(message, discardState) {
        busy = false;
        localMessage = message;
        localError = true;
        if (discardState) state = null;
        render();
    }

    function invoke(event, args, message) {
        if (busy || !connected()) return;
        busy = true;
        localError = false;
        localMessage = message;
        var serial = ++requestSerial;
        var beforeState = stateSerial;
        render();
        try {
            nav().InvokeExtensibilityMethod(event, args, false, function () {
                // BC must supply SetState for every completed request. Allow the client callback queue to drain.
                window.setTimeout(function () {
                    if (serial === requestSerial && busy && stateSerial === beforeState) {
                        fail('Business Central finished the request without returning an updated view. Reload groups to try again.', false);
                    }
                }, 250);
            }, function () {
                if (serial === requestSerial) fail('The request could not be completed. Check the Business Central message, then try again.', false);
            });
        } catch (_) {
            fail('The Business Central connection is unavailable. Reopen this page or reload groups to try again.', false);
        }
    }

    function request(action, payload) {
        if (allowedActions.indexOf(action) === -1 || busy || !connected()) return;
        if ((action === 'batch' || action === 'report') && localSearch.trim()) return;
        if (!state && action !== 'reload') return;
        // BC dialogs and downloads live outside the add-in's fullscreen element.
        if (isFullscreen() && ['source', 'groupSource', 'paymentSource', 'report', 'paymentExport', 'standard'].includes(action)) {
            document.exitFullscreen().then(function () { request(action, payload); }).catch(function () {
                fullscreenNotice = 'Exit full screen before opening this record or download.';
                syncFullscreen();
            });
            return;
        }
        var messages = {
            scope: 'Updating the pool group view…',
            select: 'Loading group details…',
            check: 'Checking the selected pool group…',
            batch: 'Checking the current list — up to 50 groups…',
            reload: 'Reloading pool groups and clearing session results…',
            source: 'Opening the supporting record…',
            groupSource: 'Opening the pool group record…',
            standard: 'Opening the standard Business Central list…',
            payments: 'Reading this group’s payment history…',
            paymentSource: 'Opening the payment header…',
            report: 'Preparing the report download…',
            paymentExport: 'Preparing the loaded payment history download…'
        };
        invoke('ActionRequested', [action, JSON.stringify(payload || {})], messages[action]);
    }

    function changeScope(changes) {
        var current = scope();
        var payload = { season: current.season, week: current.week, type: current.type, focus: current.focus };
        Object.keys(changes).forEach(function (key) { payload[key] = changes[key]; });
        localSearch = '';
        issueFocus = -1;
        request('scope', payload);
    }

    function onClick(event) {
        var button = event.target.closest('button');
        if (!button || !root.contains(button) || button.disabled) return;
        if (button.hasAttribute('data-fullscreen')) { toggleFullscreen(); return; }
        if (busy) return;
        if (button.hasAttribute('data-detail-view')) {
            detailView = button.getAttribute('data-detail-view') === 'payments' ? 'payments' : 'findings';
            render();
            return;
        }
        if (button.hasAttribute('data-focus')) {
            changeScope({ focus: Number(button.getAttribute('data-focus')) });
            return;
        }
        if (button.hasAttribute('data-issue-focus')) {
            issueFocus = Number(button.getAttribute('data-issue-focus'));
            render();
            return;
        }
        var action = button.getAttribute('data-action');
        if (!action) return;
        var payload = {};
        if (action === 'select' || action === 'check' || action === 'groupSource' || action === 'payments') {
            payload.groupId = Number(button.getAttribute('data-group-id'));
            if (!validId(payload.groupId)) return;
            if (action === 'select') issueFocus = -1;
        }
        if (action === 'source') {
            payload.issueId = Number(button.getAttribute('data-issue-id'));
            payload.related = button.getAttribute('data-related') === 'true';
            if (!validId(payload.issueId)) return;
        }
        if (action === 'report') payload.kind = button.getAttribute('data-report');
        if (action === 'paymentSource') {
            payload.paymentId = Number(button.getAttribute('data-payment-id'));
            if (!validId(payload.paymentId)) return;
        }
        request(action, payload);
    }

    function onChange(event) {
        var field = event.target.getAttribute('data-scope');
        if (!field || busy || !state) return;
        var changes = {};
        changes[field] = field === 'type' ? Number(event.target.value) : event.target.value;
        if (field === 'season') changes.week = '';
        changeScope(changes);
    }

    function onInput(event) {
        if (event.target.id !== 'pw-search' || busy) return;
        localSearch = event.target.value;
        var body = root.querySelector('#pw-group-rows');
        if (body) body.innerHTML = renderGroupRows();
        var batchButton = root.querySelector('button[data-action="batch"]');
        if (batchButton) batchButton.disabled = busy || !connected() || !state || !state.total || !!localSearch.trim();
        var filterNote = root.querySelector('.pw-filter-note');
        if (filterNote) filterNote.textContent = batchNote();
        root.querySelectorAll('button[data-action="report"]').forEach(function (button) {
            button.disabled = busy || !connected() || !state || !state.total || !!localSearch.trim();
        });
    }

    function validateState(value) {
        if (!value || typeof value !== 'object' || Array.isArray(value) ||
            !Array.isArray(value.groups) || !Array.isArray(value.issues) ||
            !value.summary || !value.options || !value.scope ||
            !Array.isArray(value.options.seasons) || !Array.isArray(value.options.weeks)) return false;
        if (!Number.isSafeInteger(value.selectedId) || ![-1, 0, 1, 2].includes(value.scope.type) ||
            ![-1, 0, 1, 2, 3, 4].includes(value.scope.focus) ||
            typeof value.scope.season !== 'string' || typeof value.scope.week !== 'string') return false;
        if (!value.groups.every(function (group) {
            return group && validId(group.id) && [0, 1, 2, 3, 4].includes(group.bucket) && typeof group.scanComplete === 'boolean';
        })) return false;
        if (!value.issues.every(function (issue) {
            return issue && validId(issue.id) && validId(issue.groupId) && [0, 1, 2].includes(issue.severity);
        })) return false;
        if (!value.options.seasons.every(function (season) { return typeof season === 'string'; }) ||
            !value.options.weeks.every(function (week) { return week && typeof week.code === 'string' && typeof week.season === 'string'; })) return false;
        if (value.payments && Object.keys(value.payments).length) {
            var payments = value.payments;
            if (!validId(payments.groupId) || typeof payments.loaded !== 'boolean' || !Array.isArray(payments.rows) ||
                !Number.isSafeInteger(payments.total) || payments.total < 0 || payments.rows.length > 200 ||
                typeof payments.error !== 'string' || typeof payments.hasMore !== 'boolean' ||
                !payments.rows.every(function (row) { return row && validId(row.id) && row.groupId === payments.groupId && typeof row.reversed === 'boolean' && typeof row.provisional === 'boolean'; })) return false;
        }
        return buckets.every(function (item) {
            return Number.isSafeInteger(value.summary[item.key]) && value.summary[item.key] >= 0;
        });
    }

    window.SetState = function (stateJson) {
        var incoming;
        try {
            incoming = JSON.parse(stateJson);
            if (!validateState(incoming)) throw new Error('Invalid pooling state');
        } catch (_) {
            fail('The pooling data could not be read safely. Reload groups to try again. No results are being shown.', true);
            return;
        }
        var previousId = state && state.selectedId;
        state = incoming;
        stateSerial += 1;
        busy = false;
        localMessage = '';
        localError = false;
        if (previousId !== state.selectedId) issueFocus = -1;
        render();
    };

    window.PoolReviewWorkspace = {
        start: function () {
            var nextRoot = document.getElementById('controlAddIn') || document.getElementById('pool-branded-preview');
            if (!nextRoot || (started && root === nextRoot && root.querySelector('.pw-shell'))) return;
            if (root) {
                root.removeEventListener('click', onClick);
                root.removeEventListener('change', onChange);
                root.removeEventListener('input', onInput);
            }
            root = nextRoot;
            started = true;
            busy = false;
            requestSerial += 1;
            root.classList.add('pw-root');
            root.addEventListener('click', onClick);
            root.addEventListener('change', onChange);
            root.addEventListener('input', onInput);
            render();
            if (connected()) invoke('Ready', [], 'Loading your pooling workspace…');
        }
    };
}());
