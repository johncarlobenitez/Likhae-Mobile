import { initGuestHeader } from "./header.js";
import { initGuestProducts } from "./products.js";
import { initGuestProductDetail } from "./product-detail.js";
import { initGuestLogin } from "./auth/login.js";
import { initGuestRegister } from "./auth/register.js";

document.addEventListener("DOMContentLoaded", () => {
    initGuestHeader();
    initGuestProducts();
    initGuestProductDetail();
    initGuestLogin();
    initGuestRegister();
});
