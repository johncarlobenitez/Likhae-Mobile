import { $, $$, showGuestToast } from "./utils.js";

export function initGuestProductDetail() {
    const page = $("[data-guest-product-detail]");
    if (!page) return;

    const mainImage = $("[data-guest-main-image]", page);

    $$("[data-guest-thumbnail]", page).forEach((thumb) => {
        thumb.addEventListener("click", () => {
            $$("[data-guest-thumbnail]", page).forEach((item) => item.classList.remove("is-active"));
            thumb.classList.add("is-active");

            if (mainImage) {
                mainImage.src = thumb.dataset.image;
                mainImage.alt = thumb.dataset.alt || mainImage.alt;
            }
        });
    });

    $$("[data-option-group]", page).forEach((group) => {
        $$("[data-option]", group).forEach((option) => {
            option.addEventListener("click", () => {
                if (option.disabled) return;

                $$("[data-option]", group).forEach((item) => item.classList.remove("is-selected"));
                option.classList.add("is-selected");
            });
        });
    });

    const quantity = $("[data-product-quantity]", page);
    const stock = Number(page.dataset.stock || 1);

    $("[data-quantity-minus]", page)?.addEventListener("click", () => {
        quantity.value = Math.max(1, Number(quantity.value || 1) - 1);
    });

    $("[data-quantity-plus]", page)?.addEventListener("click", () => {
        quantity.value = Math.min(stock, Number(quantity.value || 1) + 1);
    });

    $("[data-guest-add-cart]", page)?.addEventListener("click", () => {
        showGuestToast("Please sign in to add products to your cart.");
    });

    $("[data-guest-buy-now]", page)?.addEventListener("click", () => {
        window.location.href = "/login";
    });

    $("[data-guest-wishlist]", page)?.addEventListener("click", () => {
        showGuestToast("Sign in to save products to your wishlist.");
    });

    $("[data-guest-chat]", page)?.addEventListener("click", () => {
        showGuestToast("Sign in first to message this seller.");
    });

    $$("[data-product-tab]", page).forEach((button) => {
        button.addEventListener("click", () => {
            $$("[data-product-tab]", page).forEach((item) => item.classList.remove("is-active"));
            $$("[data-product-panel]", page).forEach((item) => item.classList.remove("is-active"));

            button.classList.add("is-active");
            $(`[data-product-panel="${button.dataset.productTab}"]`, page)?.classList.add("is-active");
        });
    });
}
