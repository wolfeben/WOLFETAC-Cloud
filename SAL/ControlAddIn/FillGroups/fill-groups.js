(function () {
    'use strict';

    const state = {
        data: { groups: [], items: [], marketers: [] },
        selectedCode: '',
        draft: null,
        query: '',
        type: 'all',
        size: 'all',
        selectedOnly: false,
        pending: false
    };
    let host;

    function navAvailable() {
        return globalThis.Microsoft && Microsoft.Dynamics && Microsoft.Dynamics.NAV &&
            typeof Microsoft.Dynamics.NAV.InvokeExtensibilityMethod === 'function';
    }

    function invoke(name, args) {
        if (!navAvailable()) {
            toast('This workspace is not connected to Business Central.', true);
            return;
        }
        state.pending = true;
        render();
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(name, args || [], false);
        globalThis.setTimeout(function () {
            if (state.pending) {
                state.pending = false;
                render();
            }
        }, 12000);
    }

    function esc(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function normalize(value) {
        return String(value || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
    }

    function itemFacts(item) {
        const haystack = (item.itemNo + ' ' + item.description + ' ' + item.searchDescription + ' ' + item.itemCategoryCode).toUpperCase();
        const compact = normalize(haystack);
        const types = [];
        if (/PR\b/.test(haystack) || /PR$/.test(normalize(item.itemNo)) || haystack.indexOf('PREMIUM') >= 0)
            types.push('premium');
        if (/CL\b/.test(haystack) || /CL$/.test(normalize(item.itemNo)) || haystack.indexOf('CLASS 1') >= 0 || haystack.indexOf('CLASS1') >= 0)
            types.push('class1');
        if (compact.indexOf('EXPORT') >= 0 || normalize(item.itemNo).indexOf('EX') >= 0)
            types.push('export');
        if (compact.indexOf('BULK') >= 0 || normalize(item.itemNo).indexOf('BLK') >= 0)
            types.push('bulk');
        if (!types.length)
            types.push('other');
        const sizeMatch = normalize(item.itemNo).match(/(?:16|18|20|23|25|28|30)/);
        return { types: types, size: sizeMatch ? sizeMatch[0] : '' };
    }

    function blankDraft(preset) {
        const marketers = state.data.marketers || [];
        const draft = {
            isNew: true,
            code: '',
            description: '',
            marketerCustomerNo: marketers.length ? marketers[0].customerNo : '',
            allowMixedPallets: false,
            defaultPalletQuantity: 160,
            members: {}
        };
        const items = state.data.items || [];
        if (preset === 'premium') {
            draft.code = uniqueCode('SUPERMKT-PREM');
            draft.description = 'Supermarket Premium Fill';
            state.type = 'premium';
            items.forEach(function (item) {
                if (itemFacts(item).types.indexOf('premium') >= 0)
                    draft.members[item.itemNo] = memberDraft(item, 0, 0);
            });
        } else if (preset === 'class1') {
            draft.code = uniqueCode('CLASS1-MIX');
            draft.description = 'Class 1 Size Mix';
            draft.allowMixedPallets = true;
            state.type = 'class1';
            items.forEach(function (item) {
                if (itemFacts(item).types.indexOf('class1') >= 0)
                    draft.members[item.itemNo] = memberDraft(item, 0, 0);
            });
        } else if (preset === 'export2830') {
            draft.code = uniqueCode('EXPORT-28-30');
            draft.description = 'Export 28 / 30 Fill';
            state.type = 'export';
            items.forEach(function (item) {
                const facts = itemFacts(item);
                if (facts.types.indexOf('export') >= 0 && (facts.size === '28' || facts.size === '30'))
                    draft.members[item.itemNo] = memberDraft(item, 0, 0);
            });
        } else {
            state.type = 'all';
        }
        state.size = 'all';
        state.query = '';
        state.selectedOnly = false;
        return draft;
    }

    function uniqueCode(base) {
        const existing = (state.data.groups || []).map(function (group) { return String(group.code || '').toUpperCase(); });
        if (existing.indexOf(base) < 0)
            return base;
        for (let sequence = 2; sequence < 100; sequence += 1) {
            const suffix = '-' + sequence;
            const candidate = base.slice(0, 20 - suffix.length) + suffix;
            if (existing.indexOf(candidate) < 0)
                return candidate;
        }
        return '';
    }

    function memberDraft(item, maximumQuantity, maximumPallets) {
        return {
            itemNo: item.itemNo,
            maximumQuantity: Number(maximumQuantity || 0),
            maximumPallets: Number(maximumPallets || 0)
        };
    }

    function selectGroup(code) {
        const group = (state.data.groups || []).find(function (candidate) { return candidate.code === code; });
        if (!group)
            return;
        state.selectedCode = code;
        state.query = '';
        state.type = 'all';
        state.size = 'all';
        state.selectedOnly = false;
        const draft = {
            isNew: false,
            code: group.code,
            description: group.description,
            marketerCustomerNo: group.marketerCustomerNo,
            allowMixedPallets: Boolean(group.allowMixedPallets),
            defaultPalletQuantity: Number(group.defaultPalletQuantity || 160),
            members: {}
        };
        (group.members || []).forEach(function (member) {
            draft.members[member.itemNo] = {
                itemNo: member.itemNo,
                maximumQuantity: Number(member.maximumQuantity || 0),
                maximumPallets: Number(member.maximumPallets || 0)
            };
        });
        state.draft = draft;
        render();
    }

    function render() {
        if (!host)
            return;
        const groups = state.data.groups || [];
        if (!state.draft) {
            if (groups.length)
                return selectGroup(groups[0].code);
            state.draft = blankDraft('premium');
        }
        host.innerHTML = [
            '<main class="fg-app">',
                '<header class="fg-header"><div><span class="fg-eyebrow">THE AVOCADOS COLLECTIVE · SAL</span><h1>Fill Group Layouts</h1>',
                    '<p>Build reusable product and size rules for flexible orders.</p></div>',
                    '<div class="fg-header-actions"><span>', esc(state.data.company || 'Business Central'), '</span>',
                    '<button data-action="refresh"', state.pending ? ' disabled' : '', '>Refresh</button></div></header>',
                '<section class="fg-presets"><div><strong>Start from a layout</strong><small>Presets select matching BC items; review sizes before saving.</small></div>',
                    '<button data-action="new-template" data-preset="premium">Premium supermarket</button>',
                    '<button data-action="new-template" data-preset="class1">Class 1 mix</button>',
                    '<button data-action="new-template" data-preset="export2830">Export 28 / 30</button>',
                    '<button data-action="new-template" data-preset="blank">Blank layout</button></section>',
                '<div class="fg-layout">',
                    '<aside class="fg-sidebar"><div class="fg-sidebar-title"><strong>Saved layouts</strong><span>', groups.length, '</span></div>',
                        '<div class="fg-group-list">', groups.length ? groups.map(groupCard).join('') : '<p class="fg-empty">No layouts saved yet.</p>', '</div></aside>',
                    '<section class="fg-editor">', renderEditor(), '</section>',
                '</div>',
                '<div id="fg-toast" class="fg-toast" hidden></div>',
            '</main>'
        ].join('');
        bindDynamicValues();
    }

    function groupCard(group) {
        const selected = state.selectedCode === group.code;
        return [
            '<button class="fg-group-card', selected ? ' is-selected' : '', group.active ? '' : ' is-inactive', '" data-action="select-group" data-code="', esc(group.code), '">',
                '<span><strong>', esc(group.description || group.code), '</strong><small>', esc(group.code), ' · ', esc(group.marketerDescription || 'No marketer'), '</small></span>',
                '<b>', (group.members || []).length, '</b>',
            '</button>'
        ].join('');
    }

    function renderEditor() {
        const draft = state.draft;
        const marketers = state.data.marketers || [];
        const selectedCount = Object.keys(draft.members || {}).length;
        return [
            '<div class="fg-editor-head"><div><span class="fg-eyebrow">', draft.isNew ? 'NEW LAYOUT' : 'SAVED LAYOUT', '</span>',
                '<h2>', esc(draft.description || 'Name this fill group'), '</h2></div>',
                '<div class="fg-editor-actions">', !draft.isNew ? '<button class="fg-secondary" data-action="toggle-active">' + (currentGroupActive() ? 'Make inactive' : 'Reactivate') + '</button>' : '',
                '<button class="fg-primary" data-action="save-template"', state.pending ? ' disabled' : '', '>Save layout</button></div></div>',
            '<div class="fg-fields">',
                '<label>Layout code<input id="fg-code" maxlength="20" value="', esc(draft.code), '"', draft.isNew ? '' : ' disabled', '></label>',
                '<label class="is-wide">Layout name<input id="fg-name" maxlength="100" value="', esc(draft.description), '" placeholder="e.g. Woolworths premium fill"></label>',
                '<label>Marketer<select id="fg-marketer">', marketers.map(function (marketer) {
                    return '<option value="' + esc(marketer.customerNo) + '"' + (marketer.customerNo === draft.marketerCustomerNo ? ' selected' : '') + '>' + esc(marketer.name) + '</option>';
                }).join(''), '</select></label>',
                '<label>Default trays / pallet<input id="fg-pallet-qty" type="number" min="1" step="1" value="', esc(draft.defaultPalletQuantity), '"></label>',
                '<label class="fg-check"><input id="fg-mixed" type="checkbox"', draft.allowMixedPallets ? ' checked' : '', '>Allow mixed products or sizes on one pallet</label>',
            '</div>',
            '<div class="fg-picker-head"><div><h3>Eligible products and sizes</h3><p>Filter the item catalogue, then tick exactly what this layout may use.</p></div>',
                '<span class="fg-selected-count">', selectedCount, ' selected</span></div>',
            '<div class="fg-filters">',
                '<label>Find product<input id="fg-query" value="', esc(state.query), '" placeholder="Item, description or category"></label>',
                '<label>Product type<select id="fg-type">', typeOptions(), '</select></label>',
                '<label>Size<select id="fg-size">', sizeOptions(), '</select></label>',
                '<label class="fg-check"><input id="fg-selected-only" type="checkbox"', state.selectedOnly ? ' checked' : '', '>Selected only</label>',
            '</div>',
            '<div class="fg-item-grid">', renderItems(), '</div>',
            '<footer class="fg-footer"><span><strong>', selectedCount, '</strong> eligible SKUs saved in this layout.</span>',
                '<button class="fg-primary" data-action="save-template"', state.pending ? ' disabled' : '', '>Save layout</button></footer>'
        ].join('');
    }

    function typeOptions() {
        return [['all','All types'],['premium','Premium'],['class1','Class 1'],['export','Export'],['bulk','Bulk'],['other','Other']]
            .map(function (item) { return '<option value="' + item[0] + '"' + (state.type === item[0] ? ' selected' : '') + '>' + item[1] + '</option>'; }).join('');
    }

    function sizeOptions() {
        return ['all','16','18','20','23','25','28','30'].map(function (size) {
            return '<option value="' + size + '"' + (state.size === size ? ' selected' : '') + '>' + (size === 'all' ? 'All sizes' : 'Size ' + size) + '</option>';
        }).join('');
    }

    function filteredItems() {
        const query = normalize(state.query);
        return (state.data.items || []).filter(function (item) {
            const facts = itemFacts(item);
            const selected = Boolean(state.draft.members[item.itemNo]);
            if (state.selectedOnly && !selected)
                return false;
            if (state.type !== 'all' && facts.types.indexOf(state.type) < 0)
                return false;
            if (state.size !== 'all' && facts.size !== state.size)
                return false;
            if (query && normalize(item.itemNo + item.description + item.searchDescription + item.itemCategoryCode).indexOf(query) < 0)
                return false;
            return true;
        }).slice(0, 300);
    }

    function renderItems() {
        const items = filteredItems();
        if (!items.length)
            return '<p class="fg-empty">No BC items match these filters.</p>';
        return items.map(function (item) {
            const facts = itemFacts(item);
            const member = state.draft.members[item.itemNo];
            return [
                '<article class="fg-item', member ? ' is-selected' : '', '" data-item="', esc(item.itemNo), '">',
                    '<label class="fg-item-title"><input class="fg-item-select" type="checkbox"', member ? ' checked' : '', '><span><strong>', esc(item.itemNo), '</strong><small>', esc(item.description), '</small></span></label>',
                    '<div class="fg-tags">', facts.types.map(function (type) { return '<span>' + esc(type === 'class1' ? 'Class 1' : type) + '</span>'; }).join(''), facts.size ? '<span>Size ' + esc(facts.size) + '</span>' : '', '<span>', esc(item.uom || 'units'), '</span></div>',
                    '<div class="fg-item-limits">',
                        '<label>Max qty<input class="fg-max-qty" type="number" min="0" step="1" value="', esc(member ? member.maximumQuantity : 0), '"', member ? '' : ' disabled', '></label>',
                        '<label>Max pallets<input class="fg-max-pallets" type="number" min="0" step="1" value="', esc(member ? member.maximumPallets : 0), '"', member ? '' : ' disabled', '></label>',
                    '</div>',
                '</article>'
            ].join('');
        }).join('');
    }

    function bindDynamicValues() {
        const query = host.querySelector('#fg-query');
        if (query)
            query.focus({ preventScroll: true });
    }

    function currentGroupActive() {
        const group = (state.data.groups || []).find(function (item) { return item.code === state.selectedCode; });
        return !group || group.active;
    }

    function captureHeaderFields() {
        state.draft.code = (host.querySelector('#fg-code') || {}).value || state.draft.code;
        state.draft.description = (host.querySelector('#fg-name') || {}).value || '';
        state.draft.marketerCustomerNo = (host.querySelector('#fg-marketer') || {}).value || '';
        state.draft.defaultPalletQuantity = Number((host.querySelector('#fg-pallet-qty') || {}).value || 0);
        state.draft.allowMixedPallets = Boolean((host.querySelector('#fg-mixed') || {}).checked);
    }

    function saveTemplate() {
        captureHeaderFields();
        const members = Object.keys(state.draft.members).map(function (itemNo) {
            return state.draft.members[itemNo];
        });
        if (!state.draft.code || !state.draft.description || !state.draft.marketerCustomerNo) {
            toast('Enter a code, name and marketer before saving.', true);
            return;
        }
        if (!members.length) {
            toast('Select at least one eligible product or size.', true);
            return;
        }
        invoke('SaveTemplateRequested', [state.draft.code, state.draft.description, state.draft.marketerCustomerNo,
            state.draft.allowMixedPallets, state.draft.defaultPalletQuantity, JSON.stringify(members)]);
    }

    function handleClick(event) {
        const target = event.target.closest('[data-action]');
        if (!target || state.pending)
            return;
        const action = target.dataset.action;
        if (action === 'refresh')
            invoke('RefreshRequested', []);
        else if (action === 'select-group')
            selectGroup(target.dataset.code);
        else if (action === 'new-template') {
            state.selectedCode = '';
            state.draft = blankDraft(target.dataset.preset || 'blank');
            render();
        } else if (action === 'save-template')
            saveTemplate();
        else if (action === 'toggle-active')
            invoke('SetTemplateActiveRequested', [state.selectedCode, !currentGroupActive()]);
    }

    function handleChange(event) {
        const itemCard = event.target.closest('.fg-item');
        if (event.target.classList.contains('fg-item-select') && itemCard) {
            captureHeaderFields();
            const itemNo = itemCard.dataset.item;
            const item = (state.data.items || []).find(function (candidate) { return candidate.itemNo === itemNo; });
            if (event.target.checked)
                state.draft.members[itemNo] = memberDraft(item, 0, 0);
            else
                delete state.draft.members[itemNo];
            render();
            return;
        }
        if ((event.target.classList.contains('fg-max-qty') || event.target.classList.contains('fg-max-pallets')) && itemCard) {
            const member = state.draft.members[itemCard.dataset.item];
            if (member) {
                if (event.target.classList.contains('fg-max-qty'))
                    member.maximumQuantity = Number(event.target.value || 0);
                else
                    member.maximumPallets = Number(event.target.value || 0);
            }
            return;
        }
        if (event.target.id === 'fg-type' || event.target.id === 'fg-size' || event.target.id === 'fg-selected-only') {
            captureHeaderFields();
            state.type = (host.querySelector('#fg-type') || {}).value || 'all';
            state.size = (host.querySelector('#fg-size') || {}).value || 'all';
            state.selectedOnly = Boolean((host.querySelector('#fg-selected-only') || {}).checked);
            render();
        }
    }

    function handleInput(event) {
        if (event.target.id === 'fg-query') {
            captureHeaderFields();
            state.query = event.target.value || '';
            render();
        }
    }

    function toast(message, isError) {
        const element = host && host.querySelector('#fg-toast');
        if (!element)
            return;
        element.hidden = false;
        element.textContent = message;
        element.classList.toggle('is-error', Boolean(isError));
        globalThis.setTimeout(function () { element.hidden = true; }, 4500);
    }

    function setState(json, statusMessage, isError) {
        let parsed;
        try {
            parsed = JSON.parse(json || '{}');
        } catch (_error) {
            toast('Business Central returned invalid fill group data.', true);
            return;
        }
        state.data = parsed;
        state.pending = false;
        const previousCode = state.draft && state.draft.code;
        state.draft = null;
        state.selectedCode = '';
        if (previousCode && (parsed.groups || []).some(function (group) { return group.code === previousCode; }))
            selectGroup(previousCode);
        else
            render();
        if (statusMessage)
            toast(statusMessage, isError);
    }

    function start() {
        host = document.getElementById('controlAddIn') || document.body;
        host.addEventListener('click', handleClick);
        host.addEventListener('change', handleChange);
        host.addEventListener('input', handleInput);
        render();
        if (navAvailable())
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlReady', [], false);
    }

    globalThis.SALFillGroupWorkspace = { start: start, setState: setState };
    globalThis.SetState = setState;
}());
