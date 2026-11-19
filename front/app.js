import { API_URL } from "./config.js";
import { api } from "./api.js";

const $ = (selector, root = document) => root.querySelector(selector);

$("#docs-link").href = API_URL;

const dateFormat = new Intl.DateTimeFormat("fr-FR", { dateStyle: "long" });
const formatDate = (iso) => dateFormat.format(new Date(iso));

// Construit un élément sans jamais passer par innerHTML : les données de
// l'API (titres, noms) sont insérées comme du texte.
function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key === "class") node.className = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value);
  }
  node.append(...children);
  return node;
}

function button(label, onClick, className = "") {
  return el(
    "button",
    { type: "button", class: className, onclick: onClick },
    label,
  );
}

function toast(message, isError = false) {
  const node = el("p", { class: isError ? "toast error" : "toast" }, message);
  $("#toasts").append(node);
  setTimeout(() => node.remove(), 5000);
}

// Exécute une action déclenchée par un bouton et affiche l'erreur de l'API.
async function run(action) {
  try {
    await action();
  } catch (error) {
    toast(error.message, true);
  }
}

function showFormError(dialog, error) {
  const target = $(".form-error", dialog);
  target.textContent = error ? error.message : "";
  target.hidden = !error;
}

for (const cancel of document.querySelectorAll("[data-cancel]")) {
  cancel.addEventListener("click", () => cancel.closest("dialog").close());
}

// Branche un formulaire de boîte de dialogue sur un appel à l'API.
// L'erreur renvoyée par l'API reste affichée dans la boîte, qui ne se ferme
// qu'en cas de succès.
function bindSubmit(dialog, form, handler) {
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showFormError(dialog, null);
    try {
      await handler(new FormData(form));
      dialog.close();
      await refresh();
    } catch (error) {
      showFormError(dialog, error);
    }
  });
}

// --- Onglets ---------------------------------------------------------------

const tabs = ["games", "members", "overdue"];

function currentTab() {
  const name = location.hash.slice(1);
  return tabs.includes(name) ? name : "games";
}

async function refresh() {
  const tab = currentTab();
  for (const name of tabs) {
    $(`#${name}`).hidden = name !== tab;
    $(`[data-tab="${name}"]`).toggleAttribute("aria-current", name === tab);
  }
  await run(() =>
    tab === "games"
      ? loadGames()
      : tab === "members"
        ? loadMembers()
        : loadOverdue(),
  );

  await updateOverdueCount();
}

window.addEventListener("hashchange", refresh);

// --- Jeux ------------------------------------------------------------------

const gameFilters = $("#game-filters")

const positiveIntValue = (value) => {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 ? number : undefined;
};

function addGameFilters() {
  const inputs = gameFilters.elements;
  return {
    q: inputs.q.value.trim(),
    players: positiveIntValue(inputs.players.value),
    maxDuration: positiveIntValue(inputs.maxDuration.value),
  };
}

const emptyMessages = {
  library: $("#games-empty").textContent,            
  search: "Aucun jeu ne correspond à votre recherche.",
};

async function loadGames() {
  const filters = addGameFilters();
  const games = await api.listGames(filters);
  const searching = Object.values(filters).some((value) => value != null && value !== "");

  $("#games-empty").textContent = searching ? emptyMessages.search : emptyMessages.library;
  $("#games-empty").hidden = games.length > 0;
  $("#games-list").replaceChildren(...games.map(gameCard));
}

gameFilters.addEventListener("submit", (event) => {
  event.preventDefault();
  run(loadGames);
});

$("#reset-filters").addEventListener("click", () => {
  gameFilters.reset();
  run(loadGames);
});

function gameCard(game) {
  const players =
    game.minPlayers === game.maxPlayers
      ? `${game.minPlayers}`
      : `${game.minPlayers} à ${game.maxPlayers}`;
  const status = game.isAvailable
    ? el("span", { class: "badge ok" }, "Disponible")
    : el("span", { class: "badge busy" }, "Emprunté");

  const actions = el("div", { class: "actions" });
  if (game.isAvailable) {
    actions.append(
      button("Emprunter", () => openBorrowDialog(game), "primary"),
    );
  } else {
        actions.append(
      button("Rendre", () => returnGame(game), "primary"),
    );
  }

  actions.append(button("Modifier", () => openGameDialog(game), "primary"));

  actions.append(button("Supprimer", () => openDeleteDialog({
     dialogLabel: `le jeu « ${game.title} »`,
     call: () => api.deleteGame(game.id),
     toastLabel: "Le jeu a bien été supprimé·e.",
  }), 
    "danger"));

  return el(
    "li",
    { class: "card" },
    el("div", { class: "card-head" }, el("h3", {}, game.title), status),
    el(
      "p",
      { class: "meta" },
      `${players} joueur·ses · ${game.durationMinutes} min`,
    ),
    actions,
  );
}

const gameDialog = $("#game-dialog");
const gameForm = $("#game-form");
let updatedGameID = null;

function openGameDialog(game = null) {
  gameForm.reset();
  showFormError(gameDialog, null);

  if (game !== null) {
    $("#game-dialog-title").textContent = `Modifier « ${game.title} »`;

    updatedGameID = game.id;

    gameForm.elements.title.value = game.title;
    gameForm.elements.minPlayers.value = game.minPlayers;
    gameForm.elements.maxPlayers.value = game.maxPlayers;
    gameForm.elements.durationMinutes.value = game.durationMinutes;

  } else {
    
    $("#game-dialog-title").textContent = `Ajouter un jeu`;
    updatedGameID = null;

  }

  gameDialog.showModal();
}

$("#add-game").addEventListener("click", () => 
  openGameDialog()
);

bindSubmit(gameDialog, gameForm, async (data) => {
  const game = {
    title: data.get("title").trim(),
    minPlayers: Number(data.get("minPlayers")),
    maxPlayers: Number(data.get("maxPlayers")),
    durationMinutes: Number(data.get("durationMinutes")),
  };

  if (updatedGameID) {

    await api.updateGame(updatedGameID, game);
    toast(`Le jeu « ${game.title} » a bien été modifié·e.`);

  } else {

    await api.createGame(game);
    toast(`Le jeu « ${game.title} » a bien été créé·e.`);

  }

});

// --- Emprunts --------------------------------------------------------------

async function loadOverdue() {
  const [loans, games, members] = await Promise.all([
    api.listOverdueLoans(),
    api.listGames(),
    api.listMembers(),
  ]);

  const gameTitles = new Map(games.map((game) => [game.id, game.title]));

  const memberNames = new Map(
    members.map((member) => [member.id, member.name]),
  );

  $("#overdue-empty").hidden = loans.length > 0;
  $("#overdue-list").replaceChildren(
    ...loans.map((loan) =>
      overdueRow(
        loan,
        gameTitles.get(loan.gameID),
        memberNames.get(loan.memberID),
      ),
    ),
  );
}
async function updateOverdueCount() {
  try {
    const loans = await api.listOverdueLoans();
    $("#overdue-count").textContent = loans.length;
    $("#overdue-count").hidden = loans.length === 0;
  } catch {
    $("#overdue-count").hidden = true;
  }
}

function daysLate(loan) {
  return Math.max(1, Math.floor((Date.now() - new Date(loan.dueAt)) / (24 * 3600 * 1000)));
}

function overdueRow(loan, gameTitle, memberName) {
  const days = daysLate(loan);
  return el(
    "li",
    { class: "row late" },
    el(
      "div",
      { class: "row-main" },
      el("p", {}, el("strong", {}, gameTitle), ` · ${memberName}`),
      el("p", { class: "meta" }, `À rendre le ${formatDate(loan.dueAt)}`),
    ),
    el(
      "span",
      { class: "badge late" },
      `En retard de ${days} jour${days > 1 ? "s" : ""}`,
    ),
  );
}

const borrowDialog = $("#borrow-dialog");
const borrowForm = $("#borrow-form");
let borrowedGame = null;

async function openBorrowDialog(game) {
  await run(async () => {
    const members = await api.listMembers();
    if (members.length === 0) {
      toast("Ajoutez d'abord un·e adhérent·e pour pouvoir emprunter.", true);
      return;
    }
    borrowedGame = game;
    $("#borrow-dialog-title").textContent = `Emprunter « ${game.title} »`;
    $("select", borrowForm).replaceChildren(
      ...members.map((member) =>
        el("option", { value: member.id }, `${member.name} (${member.email})`),
      ),
    );
    showFormError(borrowDialog, null);
    borrowDialog.showModal();
  });
}

async function returnGame (game) {
  await run(async () => {
    const members = await api.listMembers();

    const membersLoans = await Promise.all(members.map((member) => api.listMemberLoans(member.id)));

    const gameLoan = membersLoans.flat().find((loan) => loan.gameID === game.id && !loan.returnedAt);

    //Peut arriver si l'affichage n'est pas à jour
    if (!gameLoan){
      toast(`Aucun emprunt en cours n'a été trouvé pour le jeu « ${game.title} ».`, true);

      await refresh();
      return;
    }
    
    await api.returnLoan(gameLoan.id);

    toast(`Le jeu « ${game.title} » a bien été rendu.`);

    await refresh();
  })
}

bindSubmit(borrowDialog, borrowForm, async (data) => {
  const loan = await api.borrow(borrowedGame.id, data.get("memberID"));
  toast(
    `« ${borrowedGame.title} » emprunté, à rendre avant le ${formatDate(loan.dueAt)}.`,
  );
});

// --- Adhérent·es -----------------------------------------------------------

async function loadMembers() {
  const members = await api.listMembers();
  $("#members-empty").hidden = members.length > 0;
  $("#members-list").replaceChildren(...members.map(memberRow));
}

function memberRow(member) {
  const actions = el("div", { class: "actions" });

  actions.append(button("Emprunts", () => openMemberLoansDialog(member), "primary"));

  actions.append(button("Modifier", () => openMemberDialog(member), "primary"));

  actions.append(button("Supprimer", () => openDeleteDialog({
     dialogLabel: `l'adhérent·e « ${member.name} »`,
     call: () => api.deleteMember(member.id),
     toastLabel: "L'adhérent·e a bien été supprimé·e.",
  }), 
    "danger"));

  return el(
    "li",
    { class: "row" },
    el(
      "div",
      { class: "row-main" },
      el("p", {}, el("strong", {}, member.name)),
      el("p", { class: "meta" }, member.email),
    ),
    actions,
  );
}

const memberDialog = $("#member-dialog");
const memberForm = $("#member-form");
let updatedMemberID = null;

function openMemberDialog(member = null) {
  memberForm.reset();
  showFormError(memberDialog, null);

  if (member !== null) {
    $("#member-dialog-title").textContent = `Modifier l'adhérent·e « ${member.name} »`;

    updatedMemberID = member.id;

    memberForm.elements.name.value = member.name;
    memberForm.elements.email.value = member.email;

  } else {
    
    $("#member-dialog-title").textContent = `Ajouter un·e adhérent·e`;
    updatedMemberID = null;

  }

  memberDialog.showModal();
}

$("#add-member").addEventListener("click", () => {
  openMemberDialog()
});

bindSubmit(memberDialog, memberForm, async (data) => {
  const member = {
    name: data.get("name").trim(),
    email: data.get("email").trim(),
  };

  if (updatedMemberID) {

    await api.updateMember(updatedMemberID, member);
    toast(`L'adhérent·e « ${member.name} » a bien été modifié·e.`);

  } else {

    await api.createMember(member);
    toast(`L'adhérent·e « ${member.name} » a bien été créé·e.`);

  }
});

// --- Emprunts d'un·e adhérent·e -----------------------------------------------------------

function loanStatus(loan) {

 return loan.returnedAt 
  ? el("span", { class: "badge ok" }, "Rendu")
  : (new Date(loan.dueAt) > new Date())
    ? el("span", { class: "badge busy" }, "En cours")
    : el("span", { class: "badge late" }, "En retard")

}

function loanRow(loan, gameTitle) {
  return el(
    "li",
    { class: new Date(loan.dueAt) > new Date() ? "row" : "row late" },
    el(
      "div",
      { class: "row-main" },
      el("p", {}, el("strong", {}, gameTitle)),
      el(
        "p",
        { class: "meta" },
        `Emprunté le ${formatDate(loan.borrowedAt)} · À rendre le ${formatDate(loan.dueAt)}`,
      ),
    ),
    loanStatus(loan),
  );
}

const memberLoansDialog = $("#member-loans-dialog");

async function openMemberLoansDialog(member) {
 await run(async () => {
    const [loans, games] = await Promise.all([api.listMemberLoans(member.id), api.listGames()]);
    const gameTitles = new Map(games.map((game) => [game.id, game.title]));

    $("#member-loans-dialog-title").textContent = `Emprunts de l'adhérent·e « ${member.name} »`;
    
    $("#member-loans-empty").hidden = loans.length > 0;
    $("#member-loans-list").replaceChildren(...loans.map((loan) => loanRow(loan, gameTitles.get(loan.gameID))));

    memberLoansDialog.showModal();
  });
}
// --- Suppression -----------------------------------------------------------
const deleteDialog = $("#delete-dialog");
const deleteForm = $("#delete-form");
let onDeletion = null

function openDeleteDialog({ dialogLabel, call, toastLabel }) {

  onDeletion = { call, toastLabel };
  showFormError(deleteDialog, null);

  $("#delete-dialog-title").textContent =
    `Voulez-vous vraiment supprimer ${dialogLabel} ?`;

  deleteDialog.showModal();

}

bindSubmit(deleteDialog, deleteForm, async () => {
  await onDeletion.call();
  toast(onDeletion.toastLabel);

});

refresh();