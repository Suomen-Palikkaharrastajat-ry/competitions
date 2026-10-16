import './main.css'
import { Elm } from './src/Main.elm'
import PocketBase from 'pocketbase'
import siteConfig from 'virtual:site-config'
import { requestedLang } from './packages/site-config/browser.mjs'
import { keycloakAuthToElmAuthResponse } from './src/authInterop.mjs'

// Restore auth from localStorage (null if not present or invalid JSON)
let restoredAuth = null;
try {
  const stored = localStorage.getItem('pb_auth');
  if (stored) {
    restoredAuth = JSON.parse(stored);
  }
} catch (_) {
  restoredAuth = null;
}

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: {
    pbUrl: import.meta.env.VITE_POCKETBASE_URL || 'http://127.0.0.1:8080',
    restoredAuth: restoredAuth,
    siteConfig,
    requestedLang: requestedLang(siteConfig),
    hash: location.hash,
  },
});

// Hash navigation: the layout's links change the hash, Elm follows it and
// keeps it in step with the page.
window.addEventListener('hashchange', function () {
  app.ports.hashChanged.send(location.hash);
});

app.ports.setHash.subscribe(function (hash) {
  if (location.hash !== hash) {
    location.hash = hash;
  }
});

app.ports.replaceHash.subscribe(function (hash) {
  if (location.hash !== hash) {
    history.replaceState(null, '', hash);
  }
});

app.ports.reportError.subscribe(function (problem) {
  console.error(problem);
});

// Persist auth when Elm sends it
app.ports.storeAuth.subscribe(function (auth) {
  localStorage.setItem('pb_auth', JSON.stringify(auth));
});

// Clear auth on logout
app.ports.clearAuth.subscribe(function () {
  localStorage.removeItem('pb_auth');
});

app.ports.startKeycloakLogin.subscribe(async function (pbUrl) {
  try {
    const pb = new PocketBase(pbUrl);
    const authData = await pb.collection('keycloak_users').authWithOAuth2({
      provider: import.meta.env.VITE_KEYCLOAK_PROVIDER_NAME || 'oidc',
    });
    app.ports.keycloakLoginSucceeded.send(keycloakAuthToElmAuthResponse(authData));
  } catch (err) {
    console.error(err);
    // Elm shows its own, translated message; the raw error is for diagnostics.
    app.ports.keycloakLoginFailed.send(String((err && err.message) || err));
  }
});
