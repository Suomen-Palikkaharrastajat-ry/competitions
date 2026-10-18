*** Settings ***
Documentation     Yleisöäänestyksen esittely (Ranked Voting Flow, ADR-0007):
...               1. Äänestysajan käynnissäolo etusivulla.
...               2. Teosten valinta ja sijoittaminen paremmuusjärjestykseen 1.–5. (8-5-3-2-1 pistettä).
...               3. Lipukkeen järjestäminen ja tallentaminen.
...               4. Reaaliaikaisen äänestystuloksen tarkastelu järjestäjän ylläpidossa.
Resource          resources/competitions.resource
Suite Setup       Restore The Story State

*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${COMPETITION}    Kesäkisa 2026
${ENTRY_1}        Myrskyluodon majakka
${ENTRY_2}        Satamalaituri
${ENTRY_3}        Saaristolaisvene
${ENTRY_4}        Rantasauna

*** Tasks ***
Valmistele Ymparisto
    Reset Demo Data
    Clear State
    Serve App
    Start Observer    etusivu    ${APP}/

Perusta Kilpailu Ja Osallistumiset Taustalla
    # Create competition with voting enabled
    Open Admin Collection    competitions
    Human Click    role=button[name="New record"i]
    Wait Until Visible    role=textbox[name="title *"]
    Fill Competition Form    ${COMPETITION}    kesakisa-2026    Kesä
    ...    Rakenna kesäinen teos.
    ...    1–4 kuvaa.
    ...    2026-06-01T09:00    2026-07-01T21:59    2026-07-15T21:59
    ...    ${IMAGES}/kansi.png
    Set Entry Limits    1    1    4
    Choose Status    closed
    Human Click    role=button[name="Create"s]
    Wait Until Visible    role=cell[name="${COMPETITION}"s]
    Enable Competition Voting    ${COMPETITION}
    # Create approved entries
    Create Submitted Entry    ${COMPETITION}    keycloak-participant@example.test    ${ENTRY_1}
    ...    Punavalkoinen majakka kalliosaarella.    ${IMAGES}/aino-1.png
    Create Submitted Entry    ${COMPETITION}    janedoe@example.com    ${ENTRY_2}
    ...    Klassinen satamalaituri.    ${IMAGES}/ville-1.png
    Create Submitted Entry    ${COMPETITION}    keycloak-participant@example.test    ${ENTRY_3}
    ...    Perinteinen puuvene.    ${IMAGES}/aino-2.png
    Create Submitted Entry    ${COMPETITION}    janedoe@example.com    ${ENTRY_4}
    ...    Sauna ja uimalaituri.    ${IMAGES}/ville-2.png
    Approve Entry    ${ENTRY_1}
    Approve Entry    ${ENTRY_2}
    Approve Entry    ${ENTRY_3}
    Approve Entry    ${ENTRY_4}

Aino Aänestaa
    [Setup]    Start Actor Turn    aino    anonymous=${True}
    ...    eyebrow=Yleisöäänestys · 1 / 2
    ...    title=Suosikkien äänestäminen
    ...    subtitle=Aino valitsee omat suosikkinsa ja tallentaa äänestyslipukkeen
    Sign In As Member    keycloak-participant@example.test    participant
    Caption    Etusivulla näkyvät kilpailut, joissa yleisöäänestys on käynnissä.
    Open Vote Page    ${COMPETITION}
    Caption    Äänestäjä valitsee enintään viisi suosikkiaan sijoille 1.–5.
    Choose Entry To Vote    ${ENTRY_2}
    Choose Entry To Vote    ${ENTRY_1}
    Choose Entry To Vote    ${ENTRY_3}
    Caption    Sijat tuottavat 8, 5, 3, 2 ja 1 pistettä.
    Human Click    role=button[name^="Siirrä ylemmäs: ${ENTRY_1}"]
    Caption    Järjestystä voi muokata nuolipainikkeilla tai poistaa teoksen listalta.
    Save Vote Ballot
    Caption    Ääni tallennetaan. Sitä voi muuttaa vapaasti äänestysajan loppuun saakka.
    Take Screenshot    ${SHOTS_DIR}/01-aino-aanestanyt.png
    Human Click    role=button[name="Kirjaudu ulos"]
    [Teardown]    End Actor Turn

Olli Tarkastelee Tuloksia Yllapidossa
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Yleisöäänestys · 2 / 2
    ...    title=Äänestystilanteen seuranta
    ...    subtitle=Järjestäjä seuraa annettujen äänien määrää ja tulosta ylläpidossa
    Sign In As Member    keycloak-reviewer@example.test    reviewer
    Caption    Järjestäjät ja arvostelijat pääsevät Ylläpito-osioon.
    Open In-App Admin Entries    ${COMPETITION}
    Caption    Osallistumissivulla näkyvät annetut äänet, sijoitukset ja pisteet reaaliajassa.
    Human Move    text=Ääniä:
    Take Screenshot    ${SHOTS_DIR}/02-aanestystulokset-admin.png
    [Teardown]    End Actor Turn

Lopuksi
    Hold    2
    End Observer

*** Keywords ***
Restore The Story State
    No Operation
