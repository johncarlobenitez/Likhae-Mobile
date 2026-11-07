import { $, $$ } from "./utils.js";

export function initGuestProducts() {
    const page = $("[data-guest-products-page]");
    if (!page) return;

    const cards = $$("[data-guest-product-card]", page);
    const categoryInputs = $$("[data-guest-category-filter]", page);
    const searchInput = $("[data-guest-product-filter-search]", page);
    const sort = $("[data-guest-sort]", page);

    const filter = () => {
        const search = (searchInput?.value || "").trim().toLowerCase();
        const category = categoryInputs.find((input) => input.checked)?.value || "";

        cards.forEach((card) => {
            const text = card.dataset.search || "";
            const cardCategory = card.dataset.category || "";

            const searchMatch = !search || text.includes(search);
            const categoryMatch = !category || category === cardCategory;

            card.hidden = !(searchMatch && categoryMatch);
        });
    };

    searchInput?.addEventListener("input", filter);
    categoryInputs.forEach((input) => input.addEventListener("change", filter));

    sort?.addEventListener("change", () => {
        const grid = $("[data-guest-product-grid]", page);
        if (!grid) return;

        const sorted = [...cards].sort((a, b) => {
            const priceA = Number(a.dataset.price || 0);
            const priceB = Number(b.dataset.price || 0);
            const soldA = Number(a.dataset.sold || 0);
            const soldB = Number(b.dataset.sold || 0);
            const ratingA = Number(a.dataset.rating || 0);
            const ratingB = Number(b.dataset.rating || 0);

            switch (sort.value) {
                case "price-low":
                    return priceA - priceB;
                case "price-high":
                    return priceB - priceA;
                case "best-selling":
                    return soldB - soldA;
                case "highest-rated":
                    return ratingB - ratingA;
                default:
                    return 0;
            }
        });

        sorted.forEach((card) => grid.appendChild(card));
    });

    const filterButton = $("[data-guest-filter-toggle]", page);
    const filterPanel = $("[data-guest-filter-panel]", page);

    filterButton?.addEventListener("click", () => {
        filterPanel?.classList.toggle("is-open");
    });
}
