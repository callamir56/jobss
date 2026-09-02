// Officer Menu Logic

window.currentRadioCodes = [];
window.allAnimations = {};
window.fakePlayers = [];
window.playerName = "Officer";
window.rankLabel = "Officer";
window.myCitizenId = null;
window.officerMenuTabs = {
    interaction: true,
    radio: true,
    frequency: true,
    objects: true,
    vehicles: true,
    poses: true
};

window.currentFrequency = null;
window.syncedRadioChannels = {}; // Stores real data from server
window.fakePlayerFreqs = {}; // Local state for fake player overrides { [cid]: freqId }

// --- Custom Drag System ---
window.isDragging = false;
window.dragGhost = null;
window.draggedCid = null;
window.draggedFromFreq = null;
window.dragOffsetX = 0;
window.dragOffsetY = 0;
window.freqRects = [];

function normalizeOfficerTabs(tabs) {
    const defaults = {
        interaction: true,
        radio: true,
        frequency: true,
        objects: true,
        vehicles: true,
        poses: true
    };

    if (!tabs || typeof tabs !== 'object') return defaults;
    return {
        interaction: tabs.interaction !== false,
        radio: tabs.radio !== false,
        frequency: tabs.frequency !== false,
        objects: tabs.objects !== false,
        vehicles: tabs.vehicles !== false,
        poses: tabs.poses !== false
    };
}

function applyOfficerTabVisibility() {
    document.querySelectorAll('.officer-menu-tabs .tab').forEach((tab) => {
        const category = tab.getAttribute('data-cat');
        const isEnabled = window.officerMenuTabs[category] !== false;
        tab.style.display = isEnabled ? '' : 'none';
        if (!isEnabled) tab.classList.remove('active');
    });
}

function openFirstEnabledOfficerTab() {
    const tabs = Array.from(document.querySelectorAll('.officer-menu-tabs .tab'));
    const firstEnabled = tabs.find((tab) => {
        const category = tab.getAttribute('data-cat');
        return window.officerMenuTabs[category] !== false;
    });

    if (firstEnabled) {
        firstEnabled.click();
    }
}

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'openOfficerMenu') {
        const container = document.getElementById('officer-menu-container');
        if (container) {
            container.classList.add('visible');
            container.style.setProperty('display', 'flex', 'important');
            
            if (data.radioCodes) window.currentRadioCodes = data.radioCodes;
            if (data.animations) window.allAnimations = data.animations;
            window.fakePlayers = data.fakePlayers || [];
            if (data.playerName) window.playerName = data.playerName;
            if (data.rankLabel) window.rankLabel = data.rankLabel;
            if (data.myCitizenId) window.myCitizenId = data.myCitizenId;
            window.officerMenuTabs = normalizeOfficerTabs(data.tabs);
            applyOfficerTabVisibility();

            // Reset to first enabled tab
            openFirstEnabledOfficerTab();
        }
    } else if (data.action === 'closeOfficerMenu') {
        const container = document.getElementById('officer-menu-container');
        if (container) {
            container.classList.remove('visible');
            container.style.setProperty('display', 'none', 'important');
        }
    } else if (data.action === 'syncRadioChannels') {
        window.syncedRadioChannels = data.channels || {};
        const activeTab = document.querySelector('.officer-menu-tabs .tab.active');
        if (activeTab && activeTab.getAttribute('data-cat') === 'frequency') {
            window.renderFrequencyList();
        }
    }
});

window.closeAlprSpeedModal = function() {
    document.getElementById('alpr-speed-modal').classList.add('hidden');
    document.getElementById('alpr-speed-modal').style.display = 'none';
    
    fetch(`https://${GetParentResourceName()}/closeOfficerMenu`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
};

function sendAlprSpeedSetting(speed) {
    fetch(`https://${GetParentResourceName()}/officerAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'alpr_set_speed', speed: speed })
    });
}

window.getCurrentAlprSpeedLimit = function() {
    const sources = [
        document.getElementById('alpr-settings-speed-input'),
        document.getElementById('alpr-lock-speed'),
        document.getElementById('alpr-speed-input-field')
    ];

    for (const el of sources) {
        if (!el) continue;
        const value = parseInt(el.value, 10);
        if (!isNaN(value) && value > 0) {
            return value;
        }
    }

    const limitDisplay = document.getElementById('alpr-limit-display');
    if (limitDisplay) {
        const value = parseInt(limitDisplay.innerText, 10);
        if (!isNaN(value) && value > 0) {
            return value;
        }
    }

    return 80;
};

window.syncAlprSettingsSpeedInput = function() {
    const speedInput = document.getElementById('alpr-settings-speed-input');
    if (!speedInput) return;
    speedInput.value = window.getCurrentAlprSpeedLimit();
};

window.applyAlprSettingsSpeed = function() {
    const speedInput = document.getElementById('alpr-settings-speed-input');
    if (!speedInput) return false;

    const speed = parseInt(speedInput.value, 10);
    if (isNaN(speed) || speed <= 0) return false;

    speedInput.value = speed;
    sendAlprSpeedSetting(speed);
    return true;
};

window.confirmAlprSpeed = function() {
    const speed = document.getElementById('alpr-speed-input-field').value;
    if (speed && speed > 0) {
        sendAlprSpeedSetting(speed);
        window.closeAlprSpeedModal();
    }
};

window.closeOfficerMenu = function() {
    const container = document.getElementById('officer-menu-container');
    if (container) {
        container.classList.remove('visible');
        container.style.setProperty('display', 'none', 'important');
        fetch(`https://${GetParentResourceName()}/closeOfficerMenu`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }
};

window.officerAction = function(action) {
    if (action === 'open_alpr') {
        const hexView = document.getElementById('hexagon-view');
        const alprView = document.getElementById('alpr-settings-view');
        if (hexView && alprView) {
            hexView.classList.add('hidden');
            alprView.classList.remove('hidden');
            window.syncAlprSettingsSpeedInput();
            
            const titleEl = document.getElementById('officer-menu-title');
            if (titleEl) titleEl.innerText = window.T('alpr_settings');
        }
        return;
    }
    if (action === 'back_to_vehicles') {
        window.updateHexGrid('vehicles');
        return;
    }
    if (action === 'alpr_set_speed' || action === 'alpr_apply_speed') {
        if (window.applyAlprSettingsSpeed()) {
            return;
        }

        const container = document.getElementById('officer-menu-container');
        if (container) {
            container.classList.remove('visible');
            container.style.setProperty('display', 'none', 'important');
        }
        
        document.getElementById('alpr-speed-modal').classList.remove('hidden');
        document.getElementById('alpr-speed-modal').style.display = 'flex';
        document.getElementById('alpr-speed-input-field').focus();
        return;
    }

    fetch(`https://${GetParentResourceName()}/officerAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: action })
    });
};

// Handle Tab Switching
document.querySelectorAll('.officer-menu-tabs .tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.officer-menu-tabs .tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        
        const category = tab.getAttribute('data-cat');
        if (window.officerMenuTabs[category] === false) return;
        const titleEl = document.getElementById('officer-menu-title');
        if (titleEl) titleEl.innerText = window.T('tab_' + category);

        const hexView = document.getElementById('hexagon-view');
        const radioView = document.getElementById('radio-view');
        const freqView = document.getElementById('frequency-view');
        const posesView = document.getElementById('poses-view');
        const alprSettingsView = document.getElementById('alpr-settings-view');
        
        if (hexView) hexView.classList.add('hidden');
        if (radioView) radioView.classList.add('hidden');
        if (freqView) freqView.classList.add('hidden');
        if (posesView) posesView.classList.add('hidden');
        if (alprSettingsView) alprSettingsView.classList.add('hidden');

        if (category === 'radio') {
            radioView.classList.remove('hidden');
            window.renderRadioGrid();
        } else if (category === 'frequency') {
            freqView.classList.remove('hidden');
            window.renderFrequencyList();
        } else if (category === 'poses') {
            posesView.classList.remove('hidden');
            window.renderOfficerPosesGrid();
        } else {
            hexView.classList.remove('hidden');
            window.updateHexGrid(category);
        }
    });
});

window.joinFrequency = function(id) {
    if (window.currentFrequency === id) {
        window.currentFrequency = null;
        fetch(`https://${GetParentResourceName()}/leaveFrequency`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ frequency: id })
        });
    } else {
        window.currentFrequency = id;
        fetch(`https://${GetParentResourceName()}/joinFrequency`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ frequency: id })
        });
    }
    window.renderFrequencyList();
};

window.toggleFreqItem = function(id) {
    const item = document.getElementById(`freq-${id}`);
    if (item) item.classList.toggle('expanded');
};

window.renderFrequencyList = function() {
    const listContent = document.getElementById('frequency-list-content');
    if (!listContent) return;

    const localChannels = JSON.parse(JSON.stringify(window.syncedRadioChannels));
    if (window.fakePlayers && window.fakePlayers.length > 0) {
        window.fakePlayers.forEach((fake, idx) => {
            if (fake.isOnline) {
                let freq = window.fakePlayerFreqs[fake.cid];
                if (freq === undefined) freq = (idx % 3) + 1;
                
                const freqStr = freq.toString();
                if (!localChannels[freqStr]) localChannels[freqStr] = [];
                if (!localChannels[freqStr].find(m => m.cid === fake.cid)) {
                    localChannels[freqStr].push({
                        cid: fake.cid,
                        name: fake.name,
                        rank: fake.jobGradeLabel,
                        isFake: true
                    });
                }
            }
        });
    }

    let totalConnected = 0;
    Object.values(localChannels).forEach(members => { totalConnected += members.length; });

    const categories = [
        { titleKey: 'patrol_units', frequencies: [{ id: 1, labelKey: 'freq_lspd_comisar_1' }, { id: 2, labelKey: 'freq_lspd_comisar_2' }, { id: 3, labelKey: 'freq_lspd_comisar_3' }] },
        { titleKey: 'special_operations', frequencies: [{ id: 4, labelKey: 'freq_swat_tactical' }, { id: 5, labelKey: 'freq_air_support' }, { id: 6, labelKey: 'freq_k9_unit' }] },
        { titleKey: 'admin_channels', frequencies: [{ id: 7, labelKey: 'freq_command_staff' }, { id: 8, labelKey: 'freq_training_channel' }] }
    ];

    const html = categories.map((cat, index) => `
        <div class="freq-category-group">
            <div class="freq-category-header">
                <div class="freq-category-title">${window.T(cat.titleKey)}</div>
                ${index === 0 ? `<span>${window.T('connected')}: <span class="highlight-blue">${totalConnected}/10</span></span>` : ''}
            </div>
            ${cat.frequencies.map(f => {
                const members = localChannels[f.id.toString()] || [];
                const isMeInThis = window.currentFrequency === f.id;
                return `
                <div class="frequency-list" data-freq-id="${f.id}">
                    <div class="freq-item ${members.length > 0 ? 'expanded' : ''} ${isMeInThis ? 'active-freq' : ''}" id="freq-${f.id}">
                        <div class="freq-header" onclick="window.joinFrequency(${f.id})">
                            <span>${window.T(f.labelKey)}</span>
                            <i class="fas fa-chevron-down" onclick="event.stopPropagation(); window.toggleFreqItem(${f.id})"></i>
                        </div>
                        <div class="freq-content">
                            ${members.map(m => `
                                <div class="freq-member-row ${m.cid === window.myCitizenId ? 'is-me' : ''}" 
                                     data-cid="${m.cid}" data-from-freq="${f.id}"
                                     onmousedown="window.startPlayerDrag(event, '${m.cid}', ${f.id})">
                                    <span class="member-rank-tag">${m.rank}</span>
                                    <span class="member-name">${m.name}</span>
                                    <button class="join-freq-btn ${m.cid === window.myCitizenId ? 'leave' : ''}" onclick="window.joinFrequency(${f.id})">
                                        <div style="width: 8px; height: 8px; background: white; border-radius: 1px;"></div>
                                    </button>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                </div>`;
            }).join('')}
        </div>
    `).join('');
    listContent.innerHTML = html;
};

window.startPlayerDrag = function(event, cid, fromFreq) {
    if (event.button !== 0 || event.target.closest('.join-freq-btn')) return;
    event.preventDefault();
    event.stopPropagation();
    
    window.isDragging = true;
    window.draggedCid = cid;
    window.draggedFromFreq = fromFreq;
    
    const target = event.currentTarget;
    const rect = target.getBoundingClientRect();
    window.dragOffsetX = event.clientX - rect.left;
    window.dragOffsetY = event.clientY - rect.top;
    
    window.freqRects = Array.from(document.querySelectorAll('.frequency-list')).map(el => ({
        el: el,
        id: parseInt(el.getAttribute('data-freq-id')),
        rect: el.getBoundingClientRect()
    }));
    
    window.dragGhost = target.cloneNode(true);
    window.dragGhost.classList.add('custom-drag-ghost');
    window.dragGhost.style.width = target.offsetWidth + 'px';
    window.dragGhost.style.pointerEvents = 'none';
    document.body.appendChild(window.dragGhost);
    
    updateGhostPosition(event);
    target.classList.add('dragging-source');
};

function updateGhostPosition(e) {
    if (!window.dragGhost) return;
    window.dragGhost.style.transform = `translate(${e.clientX - window.dragOffsetX}px, ${e.clientY - window.dragOffsetY}px)`;
}

window.handleGlobalMove = function(e) {
    if (!window.isDragging) return;
    updateGhostPosition(e);
    requestAnimationFrame(() => {
        let found = null;
        for (const item of window.freqRects) {
            const r = item.rect;
            if (e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom) {
                found = item;
                break;
            }
        }
        window.freqRects.forEach(item => item.el.classList.toggle('drag-over', item === found));
    });
};

window.handleGlobalUp = function(e) {
    if (!window.isDragging) return;
    let targetFreq = null;
    for (const item of window.freqRects) {
        const r = item.rect;
        if (e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom) {
            targetFreq = item.id;
            break;
        }
    }
    
    if (targetFreq && targetFreq !== window.draggedFromFreq) {
        const isFake = window.fakePlayers.some(p => p.cid === window.draggedCid);
        if (isFake) {
            window.fakePlayerFreqs[window.draggedCid] = targetFreq;
            window.renderFrequencyList();
        } else {
            const fromFreqStr = window.draggedFromFreq.toString();
            const toFreqStr = targetFreq.toString();
            if (window.syncedRadioChannels[fromFreqStr]) {
                const playerIdx = window.syncedRadioChannels[fromFreqStr].findIndex(m => m.cid === window.draggedCid);
                if (playerIdx > -1) {
                    const playerData = window.syncedRadioChannels[fromFreqStr].splice(playerIdx, 1)[0];
                    if (!window.syncedRadioChannels[toFreqStr]) window.syncedRadioChannels[toFreqStr] = [];
                    window.syncedRadioChannels[toFreqStr].push(playerData);
                }
            }
            window.renderFrequencyList();
            fetch(`https://${GetParentResourceName()}/movePlayerFrequency`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ cid: window.draggedCid, toFrequency: targetFreq })
            });
        }
    }
    
    window.isDragging = false;
    if (window.dragGhost) window.dragGhost.remove();
    window.dragGhost = null;
    window.draggedCid = null;
    window.draggedFromFreq = null;
    document.querySelectorAll('.dragging-source').forEach(el => el.classList.remove('dragging-source'));
    document.querySelectorAll('.frequency-list').forEach(el => el.classList.remove('drag-over'));
};

window.addEventListener('mousemove', window.handleGlobalMove);
window.addEventListener('mouseup', window.handleGlobalUp);

window.renderRadioGrid = function() {
    const gridContent = document.getElementById('radio-grid-content');
    if (!gridContent) return;
    gridContent.innerHTML = '';
    
    const dispatchBtn = document.createElement('div');
    dispatchBtn.className = 'radio-btn highlight';
    setTranslatedHTML(dispatchBtn, `<i class="fas fa-satellite-dish" style="font-size: 18px; margin-bottom: 4px; color: #fff;"></i><span style="color: #fff; font-weight: 700; font-size: 14px; text-align: center;">${window.T('toggle_dispatch')}</span>`);
    dispatchBtn.style.flexDirection = 'column';
    dispatchBtn.onclick = () => { fetch(`https://${GetParentResourceName()}/toggleDispatch`, { method: 'POST', body: JSON.stringify({}) }); };
    gridContent.appendChild(dispatchBtn);

    window.currentRadioCodes.forEach((item, index) => {
        const btn = document.createElement('div');
        btn.className = 'radio-btn';
        if (item.label === 'QRR' || index === window.currentRadioCodes.length - 1) btn.classList.add('highlight');
        btn.innerHTML = `<span>${item.label}</span>`;
        btn.onclick = () => window.officerAction(item.code);
        gridContent.appendChild(btn);
    });
};

window.renderOfficerPosesGrid = function() {
    const grid = document.getElementById('officer-poses-grid');
    if (!grid) return;
    grid.innerHTML = '';
    const stopBtn = document.createElement('div');
    stopBtn.className = 'pose-grid-item stop';
    setTranslatedHTML(stopBtn, `<i class="fas fa-stop"></i><span>${window.T('stop_all')}</span>`);
    stopBtn.onclick = () => window.officerAction('stop_poses');
    grid.appendChild(stopBtn);

    Object.keys(window.allAnimations).sort().forEach(id => {
        const pose = window.allAnimations[id];
        const btn = document.createElement('div');
        btn.className = 'pose-grid-item';
        btn.innerHTML = `<i class="fas fa-person"></i><span>${pose.label}</span>`;
        btn.onclick = () => window.officerAction('pose_' + id);
        grid.appendChild(btn);
    });
};

window.updateHexGrid = function(category) {
    const grid = document.querySelector('.hex-grid');
    if (!grid) return;
    const titleEl = document.getElementById('officer-menu-title');
    if (titleEl) titleEl.innerText = window.T('tab_' + category);

    const contents = {
        interaction: [{ icon: 'magnifying-glass', labelKey: 'hex_search', action: 'search_person' }, { icon: 'handcuffs', labelKey: 'hex_handcuff', action: 'cuff' }, { icon: 'person-walking-arrow-right', labelKey: 'hex_escort', action: 'escort' }, { icon: 'car-side', labelKey: 'hex_put_in_car', action: 'put_car' }, { icon: 'door-open', labelKey: 'hex_out_of_car', action: 'out_car' }, { icon: 'file-invoice-dollar', labelKey: 'hex_fine', action: 'fine' }, { icon: 'lock', labelKey: 'hex_jail', action: 'jail' }],
        vehicles: [{ icon: 'address-card', labelKey: 'hex_plate', action: 'check_plate' }, { icon: 'lock-open', labelKey: 'hex_unlock', action: 'unlock' }, { icon: 'toolbox', labelKey: 'hex_seize', action: 'seize' }, { icon: 'tower-broadcast', labelKey: 'hex_alpr_system', action: 'open_alpr' }],
        alpr: [{ icon: 'power-off', labelKey: 'hex_toggle', action: 'alpr_toggle' }, { icon: 'gauge-high', labelKey: 'hex_set_speed', action: 'alpr_set_speed' }, { icon: 'arrows-up-down-left-right', labelKey: 'hex_move_resize', action: 'alpr_move' }, { icon: 'arrow-left', labelKey: 'hex_back', action: 'back_to_vehicles' }],
        objects: [{ icon: 'cone', labelKey: 'hex_cone', action: 'spawn_cone' }, { icon: 'barrier', labelKey: 'hex_barrier', action: 'spawn_barrier' }, { icon: 'sign-hanging', labelKey: 'hex_spikes', action: 'spawn_spikes' }, { icon: 'lightbulb', labelKey: 'hex_light', action: 'spawn_light' }, { icon: 'trash', labelKey: 'hex_remove', action: 'remove_object' }, { icon: 'broom', labelKey: 'hex_clear_all', action: 'clear_objects' }]
    };

    const data = contents[category] || contents.interaction;
    const items = grid.querySelectorAll('.hex-item');
    items.forEach((item, index) => {
        const itemData = data[index];
        if (itemData) {
            item.style.display = 'block';
            item.onclick = () => window.officerAction(itemData.action);
            setTranslatedHTML(item.querySelector('.hex-inner'), `<i class="fas fa-${itemData.icon}"></i><span>${window.T(itemData.labelKey)}</span>`);
        } else {
            item.style.display = 'none';
        }
    });
};

window.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        const speedModal = document.getElementById('alpr-speed-modal');
        const officerMenu = document.getElementById('officer-menu-container');
        
        if (speedModal && !speedModal.classList.contains('hidden')) {
            window.closeAlprSpeedModal();
        } else if (officerMenu && officerMenu.style.display !== 'none') {
            window.closeOfficerMenu();
        }
    }
});

const alprSettingsSpeedInput = document.getElementById('alpr-settings-speed-input');
if (alprSettingsSpeedInput) {
    alprSettingsSpeedInput.addEventListener('keydown', function(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            window.officerAction('alpr_apply_speed');
        }
    });
}
