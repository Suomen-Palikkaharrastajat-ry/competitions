*** Settings ***
Documentation     Palikkakilpailun järjestäminen alusta loppuun: järjestäjä Olli
...               perustaa kilpailun, jäsen Aino ja ei-jäsen Ville osallistuvat,
...               Olli arvioi työt ja julkaisee gallerian. Ohjevideo
...               järjestäjille. Ajetaan paikallista devenv-ympäristöä vasten
...               (`devenv up`); nollaa kilpailut, osallistumiset ja arviot.
Resource          resources/competitions.resource
Suite Setup       Restore The Story State

*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${COMPETITION}    Majakka 2026
${AINO_ENTRY}     Myrskyluodon majakka
${VILLE_ENTRY}    Satamamajakka
${IIDA_ENTRY}     Majakan luonnos

*** Tasks ***
Valmistele Tallenne
    # Unrecorded: the same starting point for every take.
    Reset Demo Data
    Clear State
    Serve App
    ${builder}=    Prepare Gallery Builder
    Save State    gallery_builder    ${builder}

Aloita Seuranta
    # The observer is the Admin UI's entries list: it shows entries arrive
    # and change state while the participants and the organiser work.
    ${state}=    Admin Storage State
    Start Observer    ylläpito    ${ADMIN}#/collections?collection=entries    storage_state=${state}

Olli Perustaa Kilpailun
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 1 / 7
    ...    title=Kilpailun perustaminen
    ...    subtitle=Järjestäjä luo kilpailun PocketBasen ylläpitonäkymässä
    Open Admin Collection    competitions
    Caption    Kilpailut ovat ylläpitonäkymän competitions-kokoelmassa.
    Human Click    role=button[name="New Record"]
    Wait Until Visible    role=textbox[name="title *"]
    Fill Competition Form    ${COMPETITION}    majakka-2026    Majakka
    ...    Rakenna majakka – pieni tai suuri, merellä tai maalla.
    ...    Yksi osallistuminen per rakentaja. 1–3 kuvaa, joista ensimmäinen on pääkuva.
    ...    2026-10-01T09:00    2026-11-30T21:59    2026-12-15T21:59
    ...    ${IMAGES}/kansi.png
    Caption    Ajat ovat UTC-aikaa: 21.59 UTC on 23.59 Suomen aikaa.
    Set Entry Limits    1    1    3
    Caption    Rajat: yksi osallistuminen per henkilö ja 1–3 kuvaa per osallistuminen.
    Choose Status    open
    Caption    Tila "open" näyttää kilpailun osallistujille. "draft" pitää sen piilossa.
    Human Click    role=button[name="Create"s]
    Wait Until Visible    role=cell[name="${COMPETITION}"s]
    Take Screenshot    ${SHOTS_DIR}/01-kilpailu-luotu.png
    [Teardown]    End Actor Turn

Iida Osallistuu Taustalla
    # Unrecorded: a third entry, so the review has something to reject.
    Create Submitted Entry    ${COMPETITION}    janedoe@example.com    ${IIDA_ENTRY}
    ...    Pelkkä luonnos, kuvat puuttuvat vielä.    ${IMAGES}/iida-1.png

Aino Osallistuu
    [Setup]    Start Actor Turn    aino    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 2 / 7
    ...    title=Jäsen osallistuu
    ...    subtitle=Aino kirjautuu jäsentunnuksella, tallentaa luonnoksen ja lähettää työnsä
    Sign In As Member    keycloak-participant@example.test    participant
    Caption    Jäsenet kirjautuvat yhdistyksen jäsentunnuksella (Keycloak).
    ${session}=    App Session
    Save State    aino_session    ${session}
    Start Entry    ${COMPETITION}
    Fill Entry    ${AINO_ENTRY}
    ...    Punavalkoinen majakka kalliosaarella. Valo pyörii pienellä moottorilla.
    ...    ${IMAGES}/aino-1.png    ${IMAGES}/aino-2.png    ${IMAGES}/aino-3.png
    Save Draft
    Caption    Luonnosta voi muokata, kunnes sen lähettää arvioitavaksi.
    Human Click    role=button[name="Lähetä arvosteltavaksi"]
    Wait Until Visible    role=heading[name="Osallistuminen lähetetty!"]
    Caption    Lähettämisen jälkeen työtä ei voi enää muokata.
    Open My Entries
    Wait Until Visible    text=${AINO_ENTRY}
    Refresh Admin List
    Take Screenshot    ${SHOTS_DIR}/02-aino-lahetetty.png
    [Teardown]    End Actor Turn

Ville Osallistuu Sähköpostilla
    [Setup]    Start Actor Turn    ville    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 3 / 7
    ...    title=Kuka tahansa voi osallistua
    ...    subtitle=Ville kirjautuu sähköpostiin tulevalla koodilla
    Request Login Code    ${OTP_EMAIL}
    Caption    Ilman jäsentunnusta kirjaudutaan kertakäyttöisellä koodilla.
    Enter Login Code    000000
    Wait Until Visible    text=Väärä koodi
    Caption    Väärä tai vanhentunut koodi ei kelpaa.
    ${code}=    Latest Login Code    ${OTP_EMAIL}
    Enter Login Code    ${code}
    Wait Until Visible    role=button[name="Kirjaudu ulos"]
    Start Entry    ${COMPETITION}
    Fill Entry    ${VILLE_ENTRY}    Majakka laiturin päässä, mukana kalastajan vene.
    Save Draft
    Human Click    role=button[name="Lähetä arvosteltavaksi"]
    Wait Until Visible    text=Lisää vähintään yksi kuva
    Caption    Kilpailun kuvarajat tarkistetaan ennen lähettämistä.
    Human Move    role=button[name^="Kuvat *"]
    Upload Images    input[type=file]    ${IMAGES}/ville-1.png    ${IMAGES}/ville-2.png
    Save Draft
    Human Click    role=button[name="Lähetä arvosteltavaksi"]
    Wait Until Visible    role=heading[name="Osallistuminen lähetetty!"]
    Refresh Admin List
    Take Screenshot    ${SHOTS_DIR}/03-ville-lahetetty.png
    [Teardown]    End Actor Turn

Olli Sulkee Osallistumisen
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 4 / 7
    ...    title=Osallistuminen päättyy
    ...    subtitle=Kilpailu siirretään arviointivaiheeseen
    Change Competition Status    ${COMPETITION}    judging
    Caption    Arviointivaiheessa kilpailu ei enää näy avoimena eikä uusia töitä voi lähettää.
    [Teardown]    End Actor Turn

Olli Arvioi Työt
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 5 / 7
    ...    title=Arviointi
    ...    subtitle=Arvioija pisteyttää, hyväksyy ja hylkää osallistumiset
    Sign In As Member    keycloak-reviewer@example.test    reviewer
    Caption    Arvioijilla on oma Arvosteltavat-sivunsa. Arvioijaoikeus annetaan ylläpidossa.
    Human Click    role=link[name="Arvosteltavat"]
    Human Click    role=button[name="Ei vielä arvosteltu"]
    Review Entry    ${AINO_ENTRY}    5    4    4    5    Upea valaistus ja siisti kallio!
    Caption    Neljä arviointikriteeriä, kukin 1–5 tähteä: yhteensä enintään 20 pistettä.
    Human Click    role=dialog >> role=button[name="Tallenna"s]
    Caption    "Tallenna" pitää arvion vain arvioijan nähtävänä.
    Human Click    role=dialog >> role=button[name="Tallenna ja julkaise"]
    Caption    "Tallenna ja julkaise" näyttää pisteet ja kommentin osallistujalle.
    Human Click    role=button[name="Sulje arvostelulomake"]
    Caption    Arvioitu työ poistuu "Ei vielä arvosteltu" -näkymästä.
    Human Click    role=button[name="Kaikki"s]
    Human Click    role=button[name="Hyväksy osallistuminen: ${AINO_ENTRY}"]
    Review Entry    ${VILLE_ENTRY}    4    5    3    4    Hauska tarina veneen kanssa.
    Human Click    role=dialog >> role=button[name="Tallenna ja julkaise"]
    Human Click    role=button[name="Sulje arvostelulomake"]
    Human Click    role=button[name="Hyväksy osallistuminen: ${VILLE_ENTRY}"]
    Human Click    role=button[name="Hylkää osallistuminen: ${IIDA_ENTRY}"]
    Caption    Vain hyväksytyt työt päätyvät julkiseen galleriaan.
    Refresh Admin List
    Take Screenshot    ${SHOTS_DIR}/05-arvioitu.png
    [Teardown]    End Actor Turn

Aino Näkee Tuloksen
    [Setup]    Start Actor Turn    aino    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 6 / 7
    ...    title=Palaute osallistujalle
    ...    subtitle=Aino näkee julkaistut pisteet ja kommentin
    Open App As    aino_session    /#/omat
    Wait Until Visible    text=${AINO_ENTRY}
    Human Move    text=${AINO_ENTRY}
    Caption    Osallistuja näkee työnsä tilan ja julkaistut arviot omalla sivullaan.
    Take Screenshot    ${SHOTS_DIR}/06-aino-tulos.png
    [Teardown]    End Actor Turn

Olli Julkaisee Gallerian
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Palikkakilpailun järjestäminen · 7 / 7
    ...    title=Tulokset ja galleria
    ...    subtitle=Kilpailu merkitään valmiiksi ja galleria julkaistaan
    Change Competition Status    ${COMPETITION}    finished
    Caption    Valmiin kilpailun hyväksytyt työt ja pisteet päätyvät julkiseen galleriaan.
    [Teardown]    End Actor Turn

Galleria Päivittyy
    # Unrecorded: in production the scheduled workflow runs this pipeline.
    ${builder}=    Load State    gallery_builder
    Build Gallery    ${builder}
    ${url}=    Serve Gallery
    Save State    gallery_url    ${url}

Galleria
    [Setup]    Start Actor Turn    vierailija    anonymous=${True}
    ...    title=Julkinen galleria
    ...    subtitle=Palkintopalli, keskiarvot ja kuvat kaikkien nähtäville
    ${url}=    Load State    gallery_url
    Go To    ${url}
    Wait Until Visible    text=${COMPETITION}
    Caption    Galleria on staattinen sivu, jonka ajastettu julkaisu päivittää.
    Human Move    css=.podium-list
    Human Click    css=img.podium-img[alt^="${AINO_ENTRY}"]
    Caption    Kuvaa klikkaamalla se avautuu suurena.
    Press Key    body    Escape
    Take Screenshot    ${SHOTS_DIR}/07-galleria.png
    [Teardown]    End Actor Turn

Lopuksi
    Refresh Admin List
    Chapter    Palikkakilpailu    Kiitos!
    ...    Kilpailut: kilpailut.palikkaharrastajat.fi · Ylläpito: /_/
    Hold    3
    End Observer

*** Keywords ***
Restore The Story State
    No Operation
