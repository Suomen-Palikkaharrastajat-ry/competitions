import './main.css'
import { Elm } from './Main.elm'

// Restore auth token from localStorage
const restoredToken = localStorage.getItem('competition-auth-token') || null;

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: restoredToken
});

// Persist auth token when Elm sends it
app.ports.storeToken.subscribe(function (token) {
  if (token) {
    localStorage.setItem('competition-auth-token', token);
  } else {
    localStorage.removeItem('competition-auth-token');
  }
});
