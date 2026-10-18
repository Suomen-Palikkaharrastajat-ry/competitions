# Kilpailun järjestäjän ja arvostelijan opas
*Competition Organizer & Reviewer Guide* — Suomen Palikkaharrastajat ry

Tämä opas neuvoo Suomen Palikkaharrastajat ry:n kilpailualustan ylläpitäjiä ja arvostelijoita kilpailujen luomisessa, hallinnoinnissa, osallistumistöiden arvioinnissa sekä julkisen tulosgallerian tuottamisessa.

---

## 1. Järjestelmän yleiskuva

Kilpailualusta koostuu kolmesta pääkomponentista:
1. **PocketBase (taustajärjestelmä ja REST API):** Tallentaa kilpailut, osallistumiset (`entries`), arvostelut (`reviews`) ja käyttäjäprofiilit (`profiles`). Tarjoaa ylläpitäjille visuaalisen hallintapaneelin (`/_/`).
2. **Elm SPA (osallistuja- ja arvostelijaliittymä):** Selainsovellus osallistujille töiden jättämiseen ja arvostelijoille töiden arviointiin (`/#/arvostelu`).
3. **Haskell-galleriatyökalu:** Generoi hyväksytyistä töistä ja julkaistuista arvosteluista staattisen, saavutettavan HTML-gallerian (`dist/galleria/index.html`).

![Etusivu ja kirjautumisvalinnat](images/00-homepage.png)

---

## 2. Kirjautuminen ja käyttöoikeudet

Alustalla on käytössä **kahden kerroksen käyttäjämalli** (ADR-0003):
- **Kirjautumistilit:** `users` (yhdistyksen jäsenet Keycloak SSO -tunnuksella; sama jäsentili kuin tapahtumakalenterissa) ja `local_users` (kertakirjautumiskoodi eli OTP sähköpostiin).
- **Profiili (`profiles`):** Jokaisella käyttäjällä on profiili, joka yhdistää osallistumiset ja arvostelut.

### Arvostelijan oikeuksien myöntäminen
1. Avaa PocketBase-hallintapaneeli osoitteessa `http://127.0.0.1:8080/_/` (paikallisesti) tai tuotantopalvelimella.
2. Siirry kokoelmaan **`profiles`**.
3. Etsi henkilön profiili ja aseta rasti kenttään **`is_reviewer = true`**.
4. Tallenna. Käyttäjä näkee nyt Elm-sovelluksessa yläpalkissa linkin **Arvostelu** (`/#/arvostelu`).

![PocketBase-hallintapaneeli](images/06-pocketbase-admin.png)

---

## 3. Kilpailun luominen ja elinkaari

Kilpailut luodaan PocketBasen **`competitions`**-kokoelmassa.

### Pakolliset ja tärkeät kentät
- **`title`**: Kilpailun nimi (esim. *Linnakilpailu 2026*).
- **`slug`**: URL-ystävällinen tunniste (esim. `linnakilpailu-2026`). Uniikki.
- **`description`**: Kilpailun kuvaus ja teema.
- **`rules`**: Säännöt ja osallistumisohjeet.
- **`status`**: Kilpailun tila (ks. elinkaari alla).
- **`start_date`** & **`end_date`**: Alkamis- ja päättymisaika **ISO-8601 UTC** -muodossa (`YYYY-MM-DDTHH:MM:SS.000Z`).
- **`min_images_per_entry`**: Vähimmäiskuvamäärä työtä kohden (esim. `1`).
- **`max_images_per_entry`**: Enimmäiskuvamäärä työtä kohden (esim. `5`).
- **`cover_image`**: Kilpailun kansikuva (näytetään listauksessa).

### Kilpailun tilat (`status`)
1. **`draft` (Luonnos):** Kilpailu näkyy vain arvostelijoille ja ylläpitäjille. Käytetään tietojen esisyöttöön ja esikatseluun.
2. **`open` (Käynnissä):** Kilpailu on julkinen ja osallistujat voivat lähettää töitä ennen `end_date`-aikaa.
3. **`closed` (Päättynyt):** Töiden jättöaika on päättynyt. Osallistujat eivät voi enää muokata tai jättää töitä. Arvostelijat pisteyttävät työt.
4. **`archived` (Arkistoitu):** Tulokset on julkaistu ja kilpailu on pysyvästi arkistoitu.

---

## 4. Arvostelijan työkalut ja työnkulku

Kun käyttäjällä on `is_reviewer = true`, sovelluksen navigaatioon ilmestyy **Arvostelu**-osio (`/#/arvostelu`).

![Arvostelijan näkymä](images/02-reviewer-dashboard.png)

### Arvostelujonon käsittely
1. Siirry osoitteeseen `/#/arvostelu`.
2. Voit suodattaa töitä kahdella välilehdellä:
   - **Kaikki:** Näyttää kaikki kilpailun työt.
   - **Ei vielä arvosteltu:** Näyttää työt, joita et ole vielä arvostellut.

![Arvostelulistaus](images/05-reviewer-list.png)

### Arviointikriteerit ja pisteytys
Jokainen osallistumistyö arvioidaan neljällä kriteerillä asteikolla **1–5**:
1. **Idea ja luovuus (1–5)**
2. **Rakennustekniikka (1–5)**
3. **Esillepano ja kuvaus (1–5)**
4. **Kokonaisvaikutelma (1–5)**

Lisäksi arvostelija antaa sanallista palautetta:
- **Kommentit:** Vapaamuotoinen palaute rakentajalle.

### Arvostelun tilat ja tallennus
- **Tallenna luonnos (Save Draft):** Arvostelu tallentuu PocketBaseen `published = false` -tilassa. Vain arvostelija itse näkee omat luonnoksensa.
- **Julkaise arvostelu (Publish):** Arvostelu asetetaan tilaan `published = true`. Julkaistut arvostelut lasketaan mukaan kilpailun virallisiin pisteisiin ja tulevat rakentajan nähtäville.

### Työn hyväksyminen tai hylkääminen
Arvostelijat tarkistavat, että työ täyttää säännöt:
- **Hyväksy (`approved`):** Työ etenee tuloslaskentaan ja julkiseen galleriaan.
- **Hylkää (`rejected`):** Jos työ rikkoo sääntöjä tai kuvarajoja, se merkitään hylätyksi perustelujen kera.

### Yleisöäänestys

Arvostelun rinnalla kilpailussa voi olla yleisöäänestys (ADR-0007). Ne eivät korvaa toisiaan: kummastakin tulee oma tuloksensa.

- **Käyttöönotto:** Valitse kilpailun lomakkeella *Yleisöäänestys käytössä* ja anna äänestyksen alku- ja loppupäivä. Äänestys alkaa alkupäivän alussa ja päättyy loppupäivän alussa (klo 00.00 UTC). Jos äänestys päättyy 14.7. klo 23.59, anna loppupäiväksi 15.7.
- **Kuka äänestää:** Kuka tahansa kirjautunut käyttäjä. Äänestäjä valitsee enintään viisi kilpailun hyväksyttyä työtä paremmuusjärjestyksessä. Ääntä voi muuttaa äänestyksen loppuun asti.
- **Pisteet:** 1. sija 8, 2. sija 5, 3. sija 3, 4. sija 2 ja 5. sija 1 piste. Tasapisteissä ratkaisee 1. sijojen määrä, sitten 2. sijojen ja niin edelleen.
- **Pakollinen äänestys:** Valitse *Osallistujien on äänestettävä*, jos äänestämättä jättäneen osallistujan työ ei saa sijoitusta äänestyksessä.
- **Sarjat:** Pro- ja Casual-sarjat ovat kumpikin oma kilpailunsa, joissa äänestetään erikseen.
- **Ääntenlasku:** Osallistumisten ylläpitosivulla näkyy äänten määrä, tulos ja ne työt, jotka jäävät tuloksen ulkopuolelle. Yksittäisiä ääniä näkevät vain äänestäjä itse ja arvostelijat.
- **Galleria:** Tulos näkyy galleriassa, kun galleria generoidaan äänestyksen päätyttyä ja `POCKETBASE_API_KEY` on asetettu (äänet luetaan ylläpitäjän avaimella). Äänestäjille näytetään viimeinen äänestyspäivä eli loppupäivää edeltävä päivä.
- **Hyväksy työt ennen äänestystä:** Äänestää voi vain hyväksyttyjä töitä.

---

## 5. Tulosten julkaisu ja staattinen galleria

Kun arvostelu on valmistunut ja kilpailu on päättynyt, julkaistaan staattinen galleria.

### Gallerian konfiguraatio (`competition.toml`)
Tiedosto `competition.toml` määrittää gallerian asetukset:
```toml
title = "Palikkaharrastajat — Kilpailugalleria"
base_url = "https://kilpailut.palikkaharrastajat.fi"
output_dir = "dist/galleria"
locale = "fi"
timezone = "Europe/Helsinki"
min_reviews = 1
```

### Gallerian generointi
Aja paikallisessa kehitysympäristössä tai CI/CD-putkessa:
```bash
devenv shell --no-eval-cache -- make gallery-run
```
Komento hakee hyväksytyt työt ja julkaistut arvostelut PocketBasesta, laskee keskiarvopisteet, sijoittaa voittajat (kulta, hopea, pronssi) ja tuottaa valmiin gallerian hakemistoon `dist/galleria/index.html`.

![Julkinen tulosgalleria](images/08-static-gallery.png)

---

## 6. Sähköpostit ja Mailpit paikallisessa kehityksessä

Paikallisessa ympäristössä sähköpostiliikennettä (kuten OTP-kirjautumiskoodeja) valvotaan Mailpitin kautta:
- **Käyttöliittymä:** `http://127.0.0.1:8080/mailpit/`
- **SMTP-portti:** `1025`

![Mailpit-sähköpostilaatikko](images/07-mailpit.png)
