import { $, $$ } from "./utils.js";

const suggestions = [
    { label: "Wireless Headphones", category: "Electronics", slug: "wireless-headphones" },
    { label: "Classic Backpack", category: "Bags", slug: "classic-backpack" },
    { label: "Running Shoes", category: "Sports & Outdoors", slug: "running-shoes" },
    { label: "Smart Watch", category: "Electronics", slug: "smart-watch" },
    { label: "Skincare Set", category: "Beauty & Health", slug: "skincare-set" },
    { label: "Mechanical Keyboard", category: "Electronics", slug: "mechanical-keyboard" },
];

export function initGuestHeader() {
    const toggle = $("[data-guest-category-toggle]");
    const menu = $("[data-guest-category-menu]");

    toggle?.addEventListener("click", (event) => {
        event.stopPropagation();
        menu?.classList.toggle("is-open");
        toggle.setAttribute("aria-expanded", menu?.classList.contains("is-open") ? "true" : "false");
    });

    document.addEventListener("click", (event) => {
        if (menu && !menu.contains(event.target) && event.target !== toggle) {
            menu.classList.remove("is-open");
            toggle?.setAttribute("aria-expanded", "false");
        }
    });

    const mobileToggle = $("[data-guest-mobile-toggle]");
    const mobileNav = $("[data-guest-mobile-nav]");

    mobileToggle?.addEventListener("click", () => {
        mobileNav?.classList.toggle("is-open");
        mobileToggle.setAttribute("aria-expanded", mobileNav?.classList.contains("is-open") ? "true" : "false");
    });

    const search = $("[data-guest-search]");
    const suggestionBox = $("[data-guest-search-suggestions]");

    if (!search || !suggestionBox) return;

    const render = () => {
        const query = search.value.trim().toLowerCase();

        if (!query) {
            suggestionBox.innerHTML = "";
            suggestionBox.classList.remove("is-open");
            return;
        }

        const matches = suggestions
            .filter((item) =>
                `${item.label} ${item.category}`.toLowerCase().includes(query)
            )
            .slice(0, 5);

        if (!matches.length) {
            suggestionBox.innerHTML = `<div style="padding:13px;color:#6F706F;font-size:13px">No matching suggestions.</div>`;
            suggestionBox.classList.add("is-open");
            return;
        }

        suggestionBox.innerHTML = matches.map((item) => `
            <a class="g-search-suggestion" href="/products/${encodeURIComponent(item.slug)}">
                <span class="g-search-suggestion-icon">⌕</span>
                <span>
                    <strong>${item.label}</strong>
                    <small>${item.category}</small>
                </span>
            </a>
        `).join("");

        suggestionBox.classList.add("is-open");
    };

    search.addEventListener("input", render);
    search.addEventListener("focus", render);

    document.addEventListener("click", (event) => {
        if (!suggestionBox.contains(event.target) && event.target !== search) {
            suggestionBox.classList.remove("is-open");
        }
    });
}
