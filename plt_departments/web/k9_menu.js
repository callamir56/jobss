(function() {
    const k9Menu = document.getElementById('k9-menu-container');
    const k9Tabs = document.querySelectorAll('#k9-menu-container .tab');
    const k9Views = {
        commands: document.getElementById('k9-commands-view'),
        actions: document.getElementById('k9-actions-view')
    };

    window.openK9Menu = function() {
        if (k9Menu) {
            k9Menu.style.setProperty('display', 'flex', 'important');
            k9Menu.classList.add('visible');
        }
    };

    window.closeK9Menu = function() {
        if (k9Menu) {
            k9Menu.classList.remove('visible');
            k9Menu.style.setProperty('display', 'none', 'important');
            fetch(`https://${GetParentResourceName()}/closeK9Menu`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        }
    };

    window.k9Action = function(action) {
        fetch(`https://${GetParentResourceName()}/k9Action`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action })
        });
        // We don't necessarily close the menu on every action
    };

    // ---------------- K9 ID input (attack / track by player id) ----------------
    window.openK9IdInput = function() {
        const container = document.getElementById('k9-id-input-container');
        const titleEl = document.getElementById('k9-id-title');
        const labelEl = document.getElementById('k9-id-label');
        const input = document.getElementById('k9-id-input');
        if (titleEl && window.T) titleEl.innerText = window.T('k9_command_title');
        if (labelEl && window.T) labelEl.innerText = window.T('k9_player_id_label');
        if (input) input.value = '';
        if (container) {
            container.classList.add('visible');
            if (input) setTimeout(() => input.focus(), 100);
        }
    };

    window.closeK9IdInput = function() {
        const container = document.getElementById('k9-id-input-container');
        if (container) container.classList.remove('visible');
        fetch(`https://${GetParentResourceName()}/k9IdInputClose`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    };

    window.submitK9Id = function(mode) {
        const input = document.getElementById('k9-id-input');
        const id = input ? parseInt(input.value, 10) : NaN;
        const container = document.getElementById('k9-id-input-container');
        if (container) container.classList.remove('visible');
        if (!id || isNaN(id) || id <= 0) return;
        fetch(`https://${GetParentResourceName()}/k9IdInputSubmit`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id, mode: mode || 'attack' })
        });
    };

    k9Tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const cat = tab.dataset.cat;
            
            // Update tabs
            k9Tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            // Update views
            Object.keys(k9Views).forEach(viewKey => {
                if (viewKey === cat) {
                    k9Views[viewKey].classList.remove('hidden');
                } else {
                    k9Views[viewKey].classList.add('hidden');
                }
            });
        });
    });

    window.addEventListener('message', function(event) {
        if (event.data.action === 'openK9Menu') {
            window.openK9Menu();
        } else if (event.data.action === 'closeK9Menu') {
            const container = document.getElementById('k9-menu-container');
            if (container) {
                container.classList.remove('visible');
                container.style.setProperty('display', 'none', 'important');
            }
        } else if (event.data.action === 'openK9IdInput') {
            window.openK9IdInput();
        } else if (event.data.action === 'closeK9IdInput') {
            const container = document.getElementById('k9-id-input-container');
            if (container) container.classList.remove('visible');
        }
    });

    // Handle Escape key
    window.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            const k9IdInput = document.getElementById('k9-id-input-container');
            if (k9IdInput && k9IdInput.classList.contains('visible')) {
                window.closeK9IdInput();
                return;
            }
            if (k9Menu && k9Menu.classList.contains('visible')) {
                window.closeK9Menu();
            }
        }
    });
})();

