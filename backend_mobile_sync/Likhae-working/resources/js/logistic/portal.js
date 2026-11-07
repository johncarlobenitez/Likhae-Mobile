/*
|--------------------------------------------------------------------------
| LOGISTICS JS
|--------------------------------------------------------------------------
*/


/*
|--------------------------------------------------------------------------
| Messages — openChat / sendMessage
|--------------------------------------------------------------------------
*/

window.openChat = function (id) {

    if (typeof window.likhaeConversations === 'undefined') return;

    window.likhaeActiveChat = id;

    const chat = window.likhaeConversations[id];

    const avatarIcons = {
        rider: `<svg viewBox="0 0 24 24" class="h-6 w-6 fill-none stroke-current stroke-[1.6]"><path d="M5 17H3a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v3"></path><rect x="9" y="11" width="14" height="10" rx="2"></rect><circle cx="12" cy="21" r="1"></circle><circle cx="20" cy="21" r="1"></circle></svg>`,
        seller: `<svg viewBox="0 0 24 24" class="h-6 w-6 fill-none stroke-current stroke-[1.6]"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>`,
        buyer:  `<svg viewBox="0 0 24 24" class="h-6 w-6 fill-none stroke-current stroke-[1.6]"><circle cx="12" cy="8" r="4"></circle><path d="M4 21c0-5 3-8 8-8s8 3 8 8"></path></svg>`,
    };

    document.getElementById('emptyChat')?.classList.add('hidden');
    document.getElementById('chatWindow')?.classList.remove('hidden');

    document.getElementById('chatName').innerHTML    = chat.name;
    document.getElementById('chatStatus').innerHTML  = chat.type + ' • ' + chat.status;
    document.getElementById('chatAvatar').innerHTML  = avatarIcons[chat.avatar] ?? '';

    const box = document.getElementById('messageBox');
    box.innerHTML = '';

    chat.messages.forEach(function (message) {

        const side   = message.type === 'sent' ? 'justify-end' : 'justify-start';
        const bubble = message.type === 'sent' ? 'bg-primary text-white' : 'bg-surface text-ink';

        box.innerHTML += `
            <div class="flex ${side}">
                <div class="max-w-md rounded-2xl p-5 ${bubble}">
                    <p class="text-sm">${message.text}</p>
                    <span class="block mt-2 text-xs opacity-70">${message.time}</span>
                </div>
            </div>
        `;

    });

    box.scrollTop = box.scrollHeight;

};


window.sendMessage = function () {

    const input = document.getElementById('messageInput');

    if (!input || input.value.trim() === '') return;

    window.likhaeConversations[window.likhaeActiveChat].messages.push({
        type: 'sent',
        text: input.value,
        time: 'Now',
    });

    input.value = '';

    window.openChat(window.likhaeActiveChat);

};


/*
|--------------------------------------------------------------------------
| Parcel Show — Copy Tracking ID
|--------------------------------------------------------------------------
*/

document.addEventListener('DOMContentLoaded', function () {

    const copyButton = document.getElementById('copyTrackingButton');

    copyButton?.addEventListener('click', async function () {

        const tracking = copyButton.dataset.tracking;

        if (!tracking) return;

        try {

            await navigator.clipboard.writeText(tracking);

            const original = copyButton.innerHTML;

            copyButton.innerHTML = '<span>Copied!</span><span>✓</span>';

            setTimeout(function () {
                copyButton.innerHTML = original;
            }, 1500);

        } catch {

            window.prompt('Copy tracking number:', tracking);

        }

    });

});
