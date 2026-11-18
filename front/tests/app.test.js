import { assertEqual, assertIncludes, assertTrue, test, waitFor } from "./runner.js";
import { mountApp } from "./helpers.js";

const catan = { id: "g1", title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90, isAvailable: true };
const dixit = { id: "g2", title: "Dixit", minPlayers: 3, maxPlayers: 6, durationMinutes: 30, isAvailable: false };
const camille = { id: "m1", name: "Camille", email: "camille@example.com" };

const cardOf = (app, title) => app.$$("#games-list .card").find((card) => card.querySelector("h3").textContent === title);

const rowOf = (app, name) => app.$$("#member-list .row").find((row) => row.querySelector("strong").textContent === name);

// --- Jeux

test("games list shows one card per game with its availability", async () => {
  const app = await mountApp({ "GET /games": [catan, dixit] });
  await waitFor(() => app.$$("#games-list .card").length === 2, "deux cartes de jeu");
  assertIncludes(cardOf(app, "Catan").textContent, "Disponible");
  assertIncludes(cardOf(app, "Dixit").textContent, "Emprunté");
  assertIncludes(cardOf(app, "Catan").textContent, "3 à 4 joueur·ses · 90 min");
});

test("only an available game offers Borrow", async () => {
  const app = await mountApp({ "GET /games": [catan, dixit] });
  await waitFor(() => app.$$("#games-list .card").length === 2);
  const labels = (title) => [...cardOf(app, title).querySelectorAll("button")].map((button) => button.textContent);
  assertTrue(labels("Catan").includes("Emprunter"), "Catan devrait proposer Emprunter");
  assertTrue(!labels("Dixit").includes("Emprunter"), "Dixit est emprunté, il ne doit pas proposer Emprunter");
});

test("with no game, a message invites to add one", async () => {
  const app = await mountApp({ "GET /games": [] });
  await waitFor(() => !app.$("#games-empty").hidden);
  assertIncludes(app.$("#games-empty").textContent, "ne contient aucun jeu");
  assertIncludes(app.$("#games-empty").textContent, "Ajouter un jeu");
});

test("adding a game posts the form then reloads the list", async () => {
  const app = await mountApp({ "GET /games": [catan], "POST /games": [201, { ...catan, id: "g3", title: "Dixit" }] });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Ajouter un jeu");
  const form = app.$("#game-form");
  form.elements.title.value = "  Dixit ";
  form.elements.minPlayers.value = "3";
  form.elements.maxPlayers.value = "6";
  form.elements.durationMinutes.value = "30";
  form.requestSubmit();
  await waitFor(() => app.calls.some((call) => call.method === "POST" && call.path === "/games"), "l'appel POST /games");
  assertEqual(app.calls.find((call) => call.method === "POST").body, {
    title: "Dixit",
    minPlayers: 3,
    maxPlayers: 6,
    durationMinutes: 30,
  });
  await waitFor(() => !app.$("#game-dialog").open, "la boîte se ferme");
});

test("feat-01 : updating a game puts the form then reloads the list", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "PUT /games/g1": [
      200,
      { ...catan, title: "Uno", maxPlayers: 10, durationMinutes: 60 },
    ],
  });

  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click(`Modifier`, cardOf(app, "Catan"));
  const form = app.$("#game-form");
  assertEqual(app.$("#game-dialog-title").textContent, "Modifier « Catan »");
  assertEqual(form.elements.title.value, "Catan");
  assertEqual(form.elements.minPlayers.value, "3");
  assertEqual(form.elements.maxPlayers.value, "4");
  assertEqual(form.elements.durationMinutes.value, "90");

  form.elements.title.value = "  Uno ";
  form.elements.maxPlayers.value = "10";
  form.elements.durationMinutes.value = "60";
  form.requestSubmit();

  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "PUT" && call.path === `/games/${catan.id}`,
      ),
    "l'appel PUT /games/:gameID",
  );
  assertEqual(app.calls.find((call) => call.method === "PUT").body, {
    title: "Uno",
    minPlayers: 3,
    maxPlayers: 10,
    durationMinutes: 60,
  });
  await waitFor(() => !app.$("#game-dialog").open, "la boîte se ferme");
});

test("feat-01 : deleting a game opens a confirmation box and makes it disappear from game list", async () => {
  let deleted = false;
  const app = await mountApp({
    "GET /games": () => (deleted ? [dixit] : [dixit, catan]),
    "DELETE /games/g1": () => {
      deleted = true;
      return [204];
    },
  });

  await waitFor(() => app.$$("#games-list .card").length === 2);

  app.click(`Supprimer`, cardOf(app, "Catan"));
    await waitFor(() => app.$("#delete-dialog").open, "la boîte de suppression");
  assertEqual(
    app.$("#delete-dialog-title").textContent,
    "Voulez-vous vraiment supprimer le jeu « Catan » ?",
  );
  const form = app.$("#delete-form");
  form.requestSubmit();

  await waitFor(
    () =>
      app.calls.some(
        (call) =>
          call.method === "DELETE" && call.path === `/games/${catan.id}`,
      ),
    "l'appel DELETE /games/:gameID",
  );
  await waitFor(() => app.$$("#games-list .card").length === 1);
  assertTrue(cardOf(app, "Catan") === undefined, "Catan a disparu");
  await waitFor(
    () => app.$("#toasts").textContent.includes("supprimé"),
    "le message de confirmation",
  );
});

test("a validation error is shown in French and the dialog stays open", async () => {
  const app = await mountApp({
    "GET /games": [],
    "POST /games": [400, { error: true, reason: "title is empty, durationMinutes is less than minimum of 1" }],
  });
  await waitFor(() => !app.$("#games-empty").hidden, "la page est chargée");
  app.click("Ajouter un jeu");
  app.$("#game-form").requestSubmit();
  await waitFor(() => !app.$("#game-dialog .form-error").hidden, "le message d'erreur");
  assertEqual(app.$("#game-dialog .form-error").textContent, "Le titre est obligatoire. La durée doit être d'au moins 1.");
  assertTrue(app.$("#game-dialog").open, "la boîte devrait rester ouverte");
});

// --- Emprunts

test("borrowing a game sends the game and the chosen member", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "GET /members": [camille],
    "POST /loans": [201, { id: "l1", gameID: "g1", memberID: "m1", borrowedAt: new Date().toISOString(), dueAt: new Date().toISOString() }],
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Emprunter", cardOf(app, "Catan"));
  await waitFor(() => app.$("#borrow-dialog").open, "la boîte d'emprunt");
  app.$("#borrow-form").requestSubmit();
  await waitFor(() => app.calls.some((call) => call.method === "POST" && call.path === "/loans"), "l'appel POST /loans");
  assertEqual(app.calls.find((call) => call.path === "/loans").body, { gameID: "g1", memberID: "m1" });
  await waitFor(() => app.$("#toasts").textContent.includes("emprunté"), "le message de confirmation");
});

test("borrowing without any member explains that one must be added first", async () => {
  const app = await mountApp({ "GET /games": [catan], "GET /members": [] });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Emprunter", cardOf(app, "Catan"));
  await waitFor(() => app.$("#toasts").textContent.includes("Ajoutez d'abord"), "le message d'aide");
  assertTrue(!app.$("#borrow-dialog").open, "la boîte d'emprunt ne doit pas s'ouvrir");
});

// --- Adhérent·es

test("members tab lists the members", async () => {
  const app = await mountApp({ "GET /members": [camille] }, { hash: "#members" });
  await waitFor(() => app.$$("#members-list .row").length === 1);
  assertIncludes(app.$("#members-list .row").textContent, "Camille");
  assertIncludes(app.$("#members-list .row").textContent, "camille@example.com");
});

test("with no member, a message invites to add one", async () => {
  const app = await mountApp({ "GET /members": [] }, { hash: "#members" });
  await waitFor(() => !app.$("#members-empty").hidden);
  assertIncludes(app.$("#members-empty").textContent, "Ajouter un·e adhérent·e");
});

test("adding a member posts the form", async () => {
  const app = await mountApp({ "GET /members": [], "POST /members": [201, camille] }, { hash: "#members" });
  await waitFor(() => !app.$("#members-empty").hidden);
  app.click("Ajouter un·e adhérent·e");
  const form = app.$("#member-form");
  form.elements.name.value = " Camille ";
  form.elements.email.value = "camille@example.com";
  form.requestSubmit();
  await waitFor(() => app.calls.some((call) => call.method === "POST" && call.path === "/members"), "l'appel POST /members");
  assertEqual(app.calls.find((call) => call.method === "POST").body, { name: "Camille", email: "camille@example.com" });
});

test("an email already in use is shown in French", async () => {
  const app = await mountApp(
    { "GET /members": [], "POST /members": [409, { error: true, reason: "A member with this email already exists" }] },
    { hash: "#members" },
  );
  await waitFor(() => !app.$("#members-empty").hidden);
  app.click("Ajouter un·e adhérent·e");
  app.$("#member-form").requestSubmit();
  await waitFor(() => !app.$("#member-dialog .form-error").hidden, "le message d'erreur");
  assertIncludes(app.$("#member-dialog .form-error").textContent, "utilise déjà cette adresse e-mail");
});

test("feat-02 : updating a member puts the form then reloads the list", async () => {
  const app = await mountApp({
    "GET /members": [camille],
    "PUT /members/m1": [
      200,
      { ...camille, name: "Camila" },
    ]},
    { hash: "#members" }
);

  await waitFor(() => app.$$("#members-list .row").length === 1);
  app.click(`Modifier`, rowOf(app, "Camille"));
  const form = app.$("#member-form");
  assertEqual(app.$("#member-dialog-title").textContent, "Modifier l'adhérent·e « Camille »");
  assertEqual(form.elements.name.value, "Camille");
  assertEqual(form.elements.email.value, "camille@example.com");

  form.elements.name.value = "  Camila ";
  form.requestSubmit();

  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "PUT" && call.path === `/members/${camille.id}`,
      ),
    "l'appel PUT /members/:memberID",
  );
  assertEqual(app.calls.find((call) => call.method === "PUT").body, {
    name: "Camila",
    email: "camille@example.com",
  });
  await waitFor(() => !app.$("#member-dialog").open, "la boîte se ferme");
});

test("feat-02 : deleting a member opens a confirmation box and makes it disappear from member list", async () => {
  let deleted = false;
  const app = await mountApp({
    "GET /members": () => (deleted ? [] : [camille]),
    "DELETE /members/m1": () => {
      deleted = true;
      return [204];
    }},
    { hash: "#members" }
  );

  await waitFor(() => app.$$("#members-list .row").length === 1);

  app.click(`Supprimer`, rowOf(app, "Camille"));
    await waitFor(() => app.$("#delete-dialog").open, "la boîte de suppression");
  assertEqual(
    app.$("#delete-dialog-title").textContent,
    "Voulez-vous vraiment supprimer l'adhérent·e « Camille » ?",
  );
  const form = app.$("#delete-form");
  form.requestSubmit();

  await waitFor(
    () =>
      app.calls.some(
        (call) =>
          call.method === "DELETE" && call.path === `/members/${camille.id}`,
      ),
    "l'appel DELETE /members/:memberID",
  );
  await waitFor(() => app.$$("#members-list .row").length === 0);
  assertTrue(rowOf(app, "Camille") === undefined, "Camille a disparu");
  await waitFor(
    () => app.$("#toasts").textContent.includes("supprimé"),
    "le message de confirmation",
  );
});

test("feat-03 : returning a game changes game availability with a confirmation message and borrow is possible again", async () => {
  let returned = false;
  const activeLoan = {
    id: "l1",
    gameID: "g2",
    memberID: "m1",
    borrowedAt: new Date().toISOString(),
    dueAt: new Date().toISOString(),
  };

  const app = await mountApp({
    "GET /games": () => [returned ? { ...dixit, isAvailable: true } : dixit],
    "GET /members": [camille],
    "GET /members/m1/loans": [activeLoan],
    "POST /loans/l1/return": () => {
      returned = true;
      return [200, { ...activeLoan, returnedAt: new Date().toISOString() }];
    },
  });

  await waitFor(() => app.$$("#games-list .card").length === 1);
  assertIncludes(cardOf(app, "Dixit").textContent, "Emprunté");

  app.click(`Rendre`, cardOf(app, "Dixit"));

  await waitFor(
    () =>
      app.calls.some(
        (call) =>
          call.method === "POST" &&
          call.path === `/loans/${activeLoan.id}/return`,
      ),
    "l'appel POST /loans/:loanID/return",
  );

  await waitFor(
    () => cardOf(app, "Dixit")?.textContent.includes("Disponible"),
    "le jeu redevient disponible",
  );
  await waitFor(
    () => app.$("#toasts").textContent.includes("rendu"),
    "le message de confirmation",
  );

  const buttons = [...cardOf(app, "Dixit").querySelectorAll("button")].map(
    (button) => button.textContent,
  );
  assertTrue(buttons.includes("Emprunter"), "Emprunter est de nouveau proposé");
  assertTrue(!buttons.includes("Rendre"), "Rendre n'est plus proposé");
});

test("feat-04 : getting a member's loans opens a dialog with its loans list", async () => {
  const day = 24 * 3600 * 1000;
  const isoDaysFromNow = (days) =>
    new Date(Date.now() + days * day).toISOString();

  let loan1 = {
    id: "l1",
    gameID: "g1",
    memberID: "m1",
    borrowedAt: isoDaysFromNow(-30),
    dueAt: isoDaysFromNow(-30 + 14),
    returnedAt: isoDaysFromNow(-30 + 8),
  };

  let loan2 = {
    id: "l2",
    gameID: "g2",
    memberID: "m1",
    borrowedAt: isoDaysFromNow(-20),
    dueAt: isoDaysFromNow(-20 + 14),
  };

  let loan3 = {
    id: "l3",
    gameID: "g1",
    memberID: "m1",
    borrowedAt: isoDaysFromNow(-1),
    dueAt: isoDaysFromNow(-1 + 14),
  };

  const app = await mountApp(
    {
      "GET /members": [camille],
      "GET /games": [catan, dixit],
      "GET /members/m1/loans": [loan1, loan2, loan3],
    },
    { hash: "#members" },
  );

  await waitFor(() => app.$$("#members-list .row").length === 1);
  app.click(`Emprunts`, rowOf(app, "Camille"));

  await waitFor(
    () =>
      app.calls.some(
        (call) =>
          call.method === "GET" && call.path === `/members/${camille.id}/loans`,
      ),
    "l'appel GET /members/:memberID/loans",
  );

  await waitFor(
    () => app.$("#member-loans-dialog").open,
    "le dialogue des emprunts s'ouvre",
  );

  const list = app.$("#member-loans-list");
  const rows = app.$$("#member-loans-list .row");
  const rowStatus = (badge) => rows.find((row) => row.querySelector(badge));

  assertEqual(rows.length, 3);
  assertTrue(app.$("#member-loans-empty").hidden, "le message est caché lorsque la liste n'est pas vide");

  assertIncludes(list.textContent, "Catan");
  assertIncludes(list.textContent, "Dixit");

  assertIncludes(rowStatus(".busy").textContent, "Catan");
  assertIncludes(rowStatus(".busy").textContent, "En cours");

  assertIncludes(rowStatus(".late").textContent, "Dixit");
  assertIncludes(rowStatus(".late").textContent, "En retard");

  assertIncludes(rowStatus(".ok").textContent, "Catan");
  assertIncludes(rowStatus(".ok").textContent, "Rendu");
});

test("feat-04 : getting a member's loans opens a dialog with its empty loans list", async () => {
  const app = await mountApp(
    {
      "GET /members": [camille],
      "GET /games": [],
      "GET /members/m1/loans": [],
    },
    { hash: "#members" },
  );

  await waitFor(() => app.$$("#members-list .row").length === 1);
  app.click(`Emprunts`, rowOf(app, "Camille"));

  await waitFor(
    () =>
      app.calls.some(
        (call) =>
          call.method === "GET" && call.path === `/members/${camille.id}/loans`,
      ),
    "l'appel GET /members/:memberID/loans",
  );

  await waitFor(
    () => app.$("#member-loans-dialog").open,
    "le dialogue des emprunts s'ouvre",
  );

  const emptyMessage = app.$("#member-loans-empty");
  const rows = app.$$("#member-loans-list .row");

  assertEqual(rows.length, 0);
  assertTrue(!emptyMessage.hidden, "le message s'affiche lorsque la liste est vide");
});