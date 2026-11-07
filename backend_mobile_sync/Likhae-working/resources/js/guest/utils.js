export const $ = (selector, context = document) => context.querySelector(selector);
export const $$ = (selector, context = document) => [...context.querySelectorAll(selector)];

export function showGuestToast(message) {
    let wrap = $("#guestToastWrap");

    if (!wrap) {
        wrap = document.createElement("div");
        wrap.id = "guestToastWrap";
        wrap.className = "g-toast-wrap";
        document.body.appendChild(wrap);
    }

    const toast = document.createElement("div");
    toast.className = "g-toast";
    toast.textContent = message;
    wrap.appendChild(toast);

    setTimeout(() => toast.remove(), 2800);
}
