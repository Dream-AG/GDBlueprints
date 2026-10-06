"use strict";
const themeToggle = document.querySelector("#theme-toggle");
const updateThemeLabel = () => {
  const dark = document.documentElement.dataset.theme === "dark";
  themeToggle?.setAttribute("aria-pressed", String(dark));
  if (themeToggle) themeToggle.textContent = dark ? "Light mode" : "Dark mode";
};
themeToggle?.addEventListener("click", () => {
  const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = next;
  try { localStorage.setItem("gdblueprints-theme", next); } catch (_) { /* Private/local-file storage may be disabled. */ }
  updateThemeLabel();
});
updateThemeLabel();
const search = document.querySelector("#node-search");
const cards = [...document.querySelectorAll("article.node")];
if (search) {
  const filter = () => {
    const terms = search.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    let count = 0;
    cards.forEach(card => {
      card.hidden = !terms.every(term => card.textContent.toLowerCase().includes(term));
      if (!card.hidden) count++;
    });
    document.querySelector("#result-count").textContent = `${count} of ${cards.length} nodes`;
  };
  search.addEventListener("input", filter);
  window.addEventListener("hashchange", () => { search.value = ""; filter(); document.getElementById(decodeURIComponent(location.hash.slice(1)))?.scrollIntoView(); });
  filter();
}
