import { $ } from "../utils.js";

export function initGuestLogin() {
    const form = $("[data-guest-login-form]");
    if (!form) return;

    const toggle = $("[data-login-password-toggle]", form);
    const password = $("#guestLoginPassword", form);

    toggle?.addEventListener("click", () => {
        if (!password) return;

        const hidden = password.type === "password";
        password.type = hidden ? "text" : "password";
        toggle.textContent = hidden ? "Hide" : "Show";
        toggle.setAttribute("aria-label", hidden ? "Hide password" : "Show password");
    });
}
