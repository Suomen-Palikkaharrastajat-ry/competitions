*** Settings ***
Documentation     Kirjautumistapojen esittely (Dual Authentication Flow):
...               1. Yhdistyksen jäsenen kirjautuminen Keycloak SSO -tunnuksella.
...               2. Vieraan / avoimen osallistujan kirjautuminen sähköpostiin
...                  lähetettävällä kertakoodilla (OTP) sekä näyttönimen asetus.
...               3. Tunnusten ristiriitatilanne: Keycloak-käyttäjä ei voi
...                  pyytää OTP-koodia, vaan hänet ohjataan jäsenkirjautumiseen.
Resource          resources/competitions.resource
Suite Setup       Restore The Story State

*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${KEYCLOAK_USER}  keycloak-participant@example.test
${KEYCLOAK_PASS}  participant
${GUEST_EMAIL}    ${OTP_EMAIL}

*** Tasks ***
Valmistele Ymparisto
    Reset Demo Data
    Clear State
    Serve App

Jasen Kirjautuu Keycloakilla
    [Setup]    Start Actor Turn    aino    anonymous=${True}
    ...    eyebrow=Kirjautuminen · 1 / 3
    ...    title=Jäsenkirjautuminen (Keycloak SSO)
    ...    subtitle=Yhdistyksen jäsen kirjautuu keskitetyllä jäsentunnuksella
    Go To    ${APP}/
    Caption    Etusivulla valitaan kirjautumistapa. Yhdistyksen jäsenet käyttävät jäsentunnusta.
    Sign In As Member    ${KEYCLOAK_USER}    ${KEYCLOAK_PASS}
    Wait Until Visible    role=button[name="Kirjaudu ulos"]
    Caption    Jäsen tunnistetaan automaattisesti ja nimimerkki on heti käytettävissä.
    Take Screenshot    ${SHOTS_DIR}/01-jasen-kirjautunut.png
    Human Click    role=button[name="Kirjaudu ulos"]
    Wait Until Visible    role=button[name="Kirjaudu Keycloakilla"]
    [Teardown]    End Actor Turn

Vieras Kirjautuu Sahkopostikoodilla
    [Setup]    Start Actor Turn    ville    anonymous=${True}
    ...    eyebrow=Kirjautuminen · 2 / 3
    ...    title=Kertakirjautuminen sähköpostilla (OTP)
    ...    subtitle=Osallistuja kirjautuu ilman salasanaa 6-numeroisella sähköpostikoodilla
    Go To    ${APP}/
    Caption    Avoimiin kilpailuihin osallistuvat voivat kirjautua sähköpostiosoitteella.
    Request Login Code    ${GUEST_EMAIL}
    Caption    Sähköpostiin lähetetään kertakäyttöinen 6-numeroinen vahvistuskoodi.
    Enter Login Code    111222
    Wait Until Visible    text=Väärä koodi
    Caption    Virheellinen koodi ilmoitetaan selkeästi punaisella virheilmoituksella.
    ${code}=    Latest Login Code    ${GUEST_EMAIL}
    Enter Login Code    ${code}
    Caption    Ensimmäisellä kirjautumiskerralla kysytään julkinen näyttönimi.
    Choose Display Name    Ville Virtanen
    Wait Until Visible    role=button[name="Kirjaudu ulos"]
    Take Screenshot    ${SHOTS_DIR}/02-vieras-kirjautunut.png
    Human Click    role=button[name="Kirjaudu ulos"]
    Wait Until Visible    role=button[name="Kirjaudu Keycloakilla"]
    [Teardown]    End Actor Turn

Tunnusten Ristiriitatilanne
    [Setup]    Start Actor Turn    yllapito    anonymous=${True}
    ...    eyebrow=Kirjautuminen · 3 / 3
    ...    title=Keycloak-tunnuksen ensisijaisuus
    ...    subtitle=Jos sähköposti kuuluu Keycloak-jäsenelle, OTP-koodia ei lähetetä
    Go To    ${APP}/
    Human Type    label=Sähköpostiosoite    ${KEYCLOAK_USER}
    Human Click    role=button[name="Lähetä kirjautumiskoodi"]
    Wait Until Visible    text=Kirjaudu tällä osoitteella Keycloakin kautta
    Caption    Turvallisuussääntö: Jäsentilin omistajaa estetään kirjautumasta ulkopuolisena OTP-koodilla.
    Take Screenshot    ${SHOTS_DIR}/03-keycloak-conflict.png
    [Teardown]    End Actor Turn

*** Keywords ***
Restore The Story State
    No Operation
