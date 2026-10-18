*** Settings ***
Documentation     Julkisen tulosgallerian esittely (Static Gallery Experience):
...               1. Staattisen tulossivuston generointi hyväksytyistä töistä.
...               2. Palkintopallin (kulta, hopea, pronssi) ja tulosten selaus.
...               3. Saavutettava Lightbox-kuvakatselin ja näppäimistöohjaus.
Resource          resources/competitions.resource
Suite Setup       Restore The Story State

*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${COMPETITION}    Majakka 2026
${GOLD_ENTRY}     Myrskyluodon majakka
${SILVER_ENTRY}   Satamamajakka

*** Tasks ***
Valmistele Galleria
    Reset Demo Data
    Clear State
    Serve App
    Start Observer    galleria    ${APP}/
    ${builder}=    Prepare Gallery Builder
    Save State    gallery_builder    ${builder}
    # Create finished competition
    Open Admin Collection    competitions
    Human Click    role=button[name="New record"i]
    Wait Until Visible    role=textbox[name="title *"]
    Fill Competition Form    ${COMPETITION}    majakka-2026    Majakka
    ...    Rakenna majakka – pieni tai suuri, merellä tai maalla.
    ...    Yksi osallistuminen per rakentaja. 1–3 kuvaa, joista ensimmäinen on pääkuva.
    ...    2026-10-01T09:00    2026-11-30T21:59    2026-12-15T21:59
    ...    ${IMAGES}/kansi.png
    Set Entry Limits    1    1    3
    Choose Status    finished
    Human Click    role=button[name="Create"s]
    Wait Until Visible    role=cell[name="${COMPETITION}"s]
    # Create two submitted and approved entries
    Create Submitted Entry    ${COMPETITION}    keycloak-participant@example.test    ${GOLD_ENTRY}
    ...    Punavalkoinen majakka kalliosaarella. Valo pyörii pienellä moottorilla.
    ...    ${IMAGES}/aino-1.png    ${IMAGES}/aino-2.png
    Create Submitted Entry    ${COMPETITION}    janedoe@example.com    ${SILVER_ENTRY}
    ...    Klassinen satamamajakka ja laiturialue.
    ...    ${IMAGES}/ville-1.png
    # Approve and review entries
    Approve Entry    ${GOLD_ENTRY}
    Approve Entry    ${SILVER_ENTRY}
    Create Published Review    ${GOLD_ENTRY}    keycloak-reviewer@example.test    5    5    5    5    Mestarillinen toteutus!
    Create Published Review    ${SILVER_ENTRY}    keycloak-reviewer@example.test    4    4    4    4    Hieno tunnelma ja yksityiskohdat.
    Build Gallery    ${builder}
    ${url}=    Serve Gallery
    Save State    gallery_url    ${url}

Selaa Tuloksia Ja Galleriaa
    [Setup]    Start Actor Turn    vierailija    anonymous=${True}
    ...    eyebrow=Galleria · 1 / 1
    ...    title=Julkinen tulosgalleria
    ...    subtitle=Sijoitukset, keskiarvopisteet ja esteetön kuvaselain
    ${url}=    Load State    gallery_url
    Go To    ${url}
    Wait Until Visible    text=${COMPETITION}
    Caption    Staattinen galleria latautuu salamannopeasti ilman tietokantakuormaa.
    Human Move    css=.podium-list
    Caption    Kolme parasta teosta korostetaan näyttävästi palkintopallilla.
    Human Click    css=img.podium-img[alt^="${GOLD_ENTRY}"]
    Wait Until Visible    role=dialog
    Caption    Kuvaa klikkaamalla avautuu täysikokoinen esteetön Lightbox-kuvakatselin.
    Press Key    body    Escape
    Caption    Lightbox sulkeutuu kätevästi Esc-näppäimellä.
    Take Screenshot    ${SHOTS_DIR}/01-galleria-nakyma.png
    [Teardown]    End Actor Turn

Lopuksi
    Hold    2
    End Observer

*** Keywords ***
Restore The Story State
    No Operation
