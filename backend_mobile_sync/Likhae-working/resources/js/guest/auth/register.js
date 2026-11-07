import { $ } from "../utils.js";

export function initGuestRegister() {
    const page = $("[data-guest-register-page]");
    if (!page) return;

    page.querySelectorAll("[data-register-password-toggle]").forEach((button) => {
        button.addEventListener("click", () => {
            const target = document.getElementById(button.dataset.registerPasswordToggle);
            if (!target) return;

            const hidden = target.type === "password";
            target.type = hidden ? "text" : "password";
            button.textContent = hidden ? "Hide" : "Show";
        });
    });
}
