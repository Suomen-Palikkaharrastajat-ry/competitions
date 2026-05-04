import './main.css'
import { Elm } from './Main.elm'
import PocketBase from 'pocketbase'

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
  },
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
    const record = authData.record || {};
    app.ports.keycloakLoginSucceeded.send({
      token: authData.token,
      record: {
        id: record.id || '',
        collectionName: record.collectionName || 'keycloak_users',
        profile_id: record.profile_id || '',
        email: record.email || '',
        display_name: record.display_name || '',
        is_reviewer: !!record.is_reviewer,
      },
    });
  } catch (err) {
    app.ports.keycloakLoginFailed.send('Keycloak-kirjautuminen epäonnistui');
  }
});
