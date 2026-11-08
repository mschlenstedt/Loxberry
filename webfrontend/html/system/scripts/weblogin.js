// Progressive enhancement only: login, redirects and logout work without JS.
"use strict";
const toggle = document.getElementById("toggle-password");
if (toggle) {
    const password = document.getElementById("password");
    toggle.hidden = false;
    toggle.addEventListener("click", () => {
        const show = password.type === "password";
        password.type = show ? "text" : "password";
        toggle.setAttribute("aria-pressed", String(show));
        toggle.textContent = show ? toggle.dataset.hide : toggle.dataset.show;
    });
}
