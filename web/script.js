/* ===================================================
   ndrp_tasks — NUI Script
   Handles messages from Lua client + sends callbacks
   =================================================== */

const taskMenu = document.getElementById('task-menu');
const taskList = document.getElementById('task-list');
const closeBtn = document.getElementById('close-btn');

// ---- Icon color palette for task cards ----
const iconColors = [
    { bg: 'rgba(59, 130, 246, 0.12)', color: '#3B82F6' },
    { bg: 'rgba(168, 85, 247, 0.12)', color: '#A855F7' },
    { bg: 'rgba(245, 158, 11, 0.12)', color: '#F59E0B' },
    { bg: 'rgba(34, 197, 94, 0.12)', color: '#22C55E' },
    { bg: 'rgba(239, 68, 68, 0.12)', color: '#EF4444' },
    { bg: 'rgba(6, 182, 212, 0.12)', color: '#06B6D4' },
];

// ---- Show/Hide helpers using display property ----
function showMenu() {
    taskMenu.style.display = 'flex';
}

function hideMenu() {
    taskMenu.style.display = 'none';
}

// ---- Listen for NUI messages from Lua ----
window.addEventListener('message', function (event) {
    var data = event.data;

    if (data.action === 'showTaskMenu') {
        renderTasks(data.tasks || []);
        showMenu();
    }

    if (data.action === 'hideTaskMenu') {
        hideMenu();
    }
});

// ---- Render task cards dynamically ----
function renderTasks(tasks) {
    taskList.innerHTML = '';

    for (var i = 0; i < tasks.length; i++) {
        var task = tasks[i];
        var colorSet = iconColors[i % iconColors.length];
        var reward = task.reward || 0;

        var card = document.createElement('div');
        card.className = 'task-card';
        card.setAttribute('data-task-id', task.id);

        var iconWrap = document.createElement('div');
        iconWrap.className = 'task-icon-wrap';
        iconWrap.style.background = colorSet.bg;

        var icon = document.createElement('i');
        icon.className = task.icon || 'fas fa-box';
        icon.style.color = colorSet.color;
        iconWrap.appendChild(icon);

        var info = document.createElement('div');
        info.className = 'task-info';

        var name = document.createElement('div');
        name.className = 'task-name';
        name.textContent = task.name || 'Uppdrag';

        var desc = document.createElement('div');
        desc.className = 'task-desc';
        desc.textContent = task.description || '';

        info.appendChild(name);
        info.appendChild(desc);

        var rewardEl = document.createElement('div');
        rewardEl.className = 'task-reward';
        rewardEl.textContent = reward + ' kr';

        card.appendChild(iconWrap);
        card.appendChild(info);
        card.appendChild(rewardEl);

        card.addEventListener('click', (function (taskId) {
            return function () {
                selectTask(taskId);
            };
        })(task.id));

        taskList.appendChild(card);
    }
}

// ---- Send task selection back to Lua ----
function selectTask(taskId) {
    hideMenu();
    fetch('https://' + GetParentResourceName() + '/taskSelected', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ taskId: taskId }),
    });
}

// ---- Close menu via button or ESC ----
function closeMenuAction() {
    hideMenu();
    fetch('https://' + GetParentResourceName() + '/closeMenu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
}

closeBtn.addEventListener('click', closeMenuAction);

document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
        closeMenuAction();
    }
});
