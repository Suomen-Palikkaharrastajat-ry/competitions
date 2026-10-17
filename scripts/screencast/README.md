# Kilpailualustan kuvaruututallenteet (Screencasts)

Tämä hakemisto sisältää [robotframework-screencast](https://github.com/datakurre/robotframework-screencast) -tarinoita, joilla tuotetaan automaattisesti ohjevideoita, esittelyitä ja laadunvarmistustallenteita kilpailualustan eri ominaisuuksista.

Tallenteet ajavat Playwright-selainta paikallista `devenv`-ympäristöä (`http://127.0.0.1:8080`) vasten usean eri roolihenkilön (järjestäjä Olli, jäsen Aino, vieras Ville, galleriakävijä) näkökulmasta.

---

## Saatavilla olevat tarinat

### 1. `kilpailun-jarjestaminen.robot` (Pääohjevideo järjestäjille)
Kattava kilpailun elinkaari: Olli perustaa kilpailun PocketBase-ylläpidossa, Aino (Keycloak-jäsen) ja Ville (OTP-vieras) osallistuvat, Olli sulkee osallistumisen, arvostelee ja hyväksyy/hylkää työt, Aino näkee tuloksensa ja valmis kilpailu julkaistaan staattiseen galleriaan.

### 2. `auth-flow.robot` (Kirjautumistavat ja tunnistautuminen)
Keskittyy kahteen kirjautumismalliin (ADR-0003):
- Jäsenkirjautuminen Keycloak SSO -tunnuksella.
- Vieras-/avoin kirjautuminen sähköpostiin tulevalla 6-numeroisella OTP-koodilla (Mailpit) ja näyttönimen valinta.
- Tunnusristiriitojen hallinta (Keycloak-sähköpostilla ei voi pyytää OTP-koodia).

### 3. `entry-submission.robot` (Kilpailutyön jättäminen ja kuvien optimointi)
Keskittyy osallistujan työnkulkuun:
- Teoksen nimen ja tarinan syöttö.
- Selaimessa tapahtuva automaattinen WebP-pakkaus ja kuvalaskurin validointi.
- Työn tallennus luonnoksena ja jatkaminen myöhemmin.
- Lopullinen lähetys ja vahvistusikkuna.

### 4. `review-workflow.robot` (Arvostelijan työkalut ja pisteytys)
Keskittyy arviointiprosessiin:
- Arvostelijan näkymä ja suodatus ("Ei vielä arvosteltu" vs "Kaikki").
- Neljä pisteytyskriteeriä (Idea ja luovuus, Rakennustekniikka, Esillepano ja kuvaus, Kokonaisvaikutelma; 1–5 tähteä).
- Luonnosarvostelu vs julkaistu arvostelu.
- Töiden hyväksyminen tai hylkääminen.

### 5. `gallery-experience.robot` (Staattinen galleria ja saavutettavuus)
Keskittyy julkiseen tulossivustoon:
- Palkintopallin esitys (kulta, hopea, pronssi) ja keskiarvopisteet.
- Saavutettava, täysikokoinen Lightbox-kuvakatselin.
- Näppäimistöohjaus (`Esc`, nuolinäppäimet).

---

## Ajaminen

> [!WARNING]
> Tarinoiden alussa suoritettava `Reset Demo Data` tyhjentää paikallisesta PocketBasesta kilpailut, osallistumiset ja arviot toistettavuuden varmistamiseksi. Aja vain paikallisessa kehitysympäristössä!

### Testiajo ilman videotallennusta (`--no-record`)
Nopea tapa tarkistaa, että kaikki vaiheet ja elementit toimivat oikein:
```sh
cd scripts/screencast
nix run github:datakurre/robotframework-screencast -- run auth-flow.robot --no-record
```

### Valmiin videon ja tekstitysten tuottaminen
```sh
cd scripts/screencast
TAKE=/tmp/auth-take
nix run github:datakurre/robotframework-screencast -- run auth-flow.robot --take $TAKE
nix run github:datakurre/robotframework-screencast -- compose $TAKE
nix run github:datakurre/robotframework-screencast -- verify $TAKE
cp $TAKE/output.webm $TAKE/output.vtt .
```

Ympäristöhuomiot:
- Tarinat kääntävät Elm-sovelluksesta tuotantoversion ja tarjoilevat sen osoitteessa `http://127.0.0.1:5174` (jotta videolle ei tule kehityspalvelimen ilmoituksia).
- PocketBase, sen ylläpito (`/_/`) ja Mailpit pyörivät osoitteessa `http://127.0.0.1:8080`.
