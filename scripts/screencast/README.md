# Kilpailualustan kuvaruututallenteet (Screencasts)

Tämä hakemisto sisältää [robotframework-screencast](https://github.com/datakurre/robotframework-screencast) -tarinoita, joilla tuotetaan automaattisesti ohjevideoita, esittelyitä ja laadunvarmistustallenteita kilpailualustan eri ominaisuuksista.

Tallenteet ajavat Playwright-selainta paikallista `devenv`-ympäristöä (`http://127.0.0.1:8080`) vasten usean eri roolihenkilön (järjestäjä Olli, jäsen Aino, vieras Ville, galleriakävijä) näkökulmasta.

---

## Saatavilla olevat tarinat

### 1. `kilpailun-jarjestaminen.robot` (Pääohjevideo järjestäjille)
Kattava kilpailun elinkaari: Olli perustaa kilpailun sovelluksen omassa Ylläpito-osiossa (`/#/admin`, ADR-0004) ja asettaa sille aikarajat ja säännöt. Aino (Keycloak-jäsen) ja Ville (OTP-vieras) osallistuvat, Olli siirtää kilpailun arviointiin, arvostelee ja hyväksyy/hylkää työt, Aino näkee tuloksensa ja valmis kilpailu julkaistaan staattiseen galleriaan.

### 2. `auth-flow.robot` (Kirjautumistavat ja tunnistautuminen)
Keskittyy kahteen kirjautumismalliin (ADR-0003):
- Jäsenkirjautuminen Keycloak SSO -tunnuksella.
- Vieras-/avoin kirjautuminen sähköpostiin tulevalla 6-numeroisella OTP-koodilla (Mailpit) ja näyttönimen valinta.
- Tunnusristiriitojen hallinta (Keycloak-sähköpostilla ei voi pyytää OTP-koodia).

### 3. `entry-submission.robot` (Kilpailutyön jättäminen, esikatselu ja muokkaus)
Keskittyy osallistujan työnkulkuun:
- Teoksen nimen ja kuvauksen syöttö.
- Kuvien valinta, suurikokoiset esikatseluruudut ja poistopainikkeet.
- Selaimessa tapahtuva automaattinen WebP-pakkaus ja kuvalaskurin validointi.
- Työn tallennus luonnoksena ja jatkaminen myöhemmin.
- Lähetys ja lähetetyn työn muokkaaminen määräaikaan asti.

### 4. `review-workflow.robot` (Arvostelijan työkalut ja pisteytys)
Keskittyy arviointiprosessiin:
- Arvostelijan näkymä ja suodatus ("Ei vielä arvosteltu" vs "Kaikki").
- Neljä pisteytyskriteeriä (Teema-vastaavuus, Omaperäisyys, Rakennustekniikka, Esitys (kuvat); 1–5 tähteä).
- Luonnosarvostelu vs julkaistu arvostelu.
- Töiden hyväksyminen tai hylkääminen.

### 5. `voting-flow.robot` (Yleisöäänestys ja tulosseuranta, ADR-0007)
Keskittyy ranked voting -äänestykseen:
- Äänestysvaiheen näyttäminen etusivulla "Äänestys käynnissä" -osiossa.
- Suosikkien valinta sijoille 1.–5. (8-5-3-2-1 pistettä) ja lipukkeen järjestäminen nuolinäppäimillä.
- Äänen tallentaminen ja muuttaminen äänestysajan puitteissa.
- Reaaliaikainen äänestystulosten ja annettujen äänien seuranta järjestäjän Ylläpito-näkymässä (`/#/admin/osallistumiset/<id>`).

### 6. `gallery-experience.robot` (Staattinen galleria ja saavutettavuus)
Keskittyy julkiseen tulossivustoon:
- Palkintopallin esitys (kulta, hopea, pronssi) ja keskiarvopisteet sekä mahdollinen yleisöäänestyksen tulos.
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
