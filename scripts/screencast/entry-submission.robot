*** Settings ***
Documentation     Kilpailutyön jättäminen ja kuvien käsittely (Entry Submission Flow):
...               1. Osallistumislomakkeen avaaminen ja tietojen täyttäminen.
...               2. Selaimessa tapahtuva automaattinen WebP-kuvamuunnos ja kuvarajojen tarkistus.
...               3. Työn tallentaminen luonnoksena ja jatkaminen myöhemmin.
...               4. Lopullinen lähetys arvioitavaksi ja tilan seuranta omalla sivulla.
Resource          resources/competitions.resource
Suite Setup       Restore The Story State

*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${COMPETITION}    Majakka 2026
${ENTRY_TITLE}    Myrskyluodon majakka

*** Tasks ***
Valmistele Ymparisto
    Reset Demo Data
    Clear State
    Serve App

Perusta Kilpailu Taustalla
    # Create competition with 1-3 images limit
    Open Admin Collection    competitions
    Human Click    role=button[name="New Record"]
    Wait Until Visible    role=textbox[name="title *"]
    Fill Competition Form    ${COMPETITION}    majakka-2026    Majakka
    ...    Rakenna majakka – pieni tai suuri, merellä tai maalla.
    ...    Yksi osallistuminen per rakentaja. 1–3 kuvaa, joista ensimmäinen on pääkuva.
    ...    2026-10-01T09:00    2026-11-30T21:59    2026-12-15T21:59
    ...    ${IMAGES}/kansi.png
    Set Entry Limits    1    1    3
    Choose Status    open
    Human Click    role=button[name="Create"s]
    Wait Until Visible    role=cell[name="${COMPETITION}"s]

Tayta Lomake Ja Tallenna Luonnos
    [Setup]    Start Actor Turn    aino    anonymous=${True}
    ...    eyebrow=Osallistuminen · 1 / 2
    ...    title=Lomakkeen täyttö ja luonnos
    ...    subtitle=Tietojen syöttö, kuvien WebP-optimointi ja luonnoksen tallennus
    Sign In As Member    keycloak-participant@example.test    participant
    ${session}=    App Session
    Save State    aino_session    ${session}
    Start Entry    ${COMPETITION}
    Fill Entry    ${ENTRY_TITLE}
    ...    Punavalkoinen majakka kalliosaarella. Valo pyörii pienellä moottorilla.
    ...    ${IMAGES}/aino-1.png
    Caption    Kuvat pakataan ja muunnetaan selaimessa moderniin WebP-muotoon.
    Save Draft
    Wait Until Visible    text=Luonnos tallennettu.
    Caption    Luonnostilaan tallennettu työ säilyy muokattavana.
    Take Screenshot    ${SHOTS_DIR}/01-luonnos-tallennettu.png
    [Teardown]    End Actor Turn

Lisaa Kuvat Ja Laheta
    [Setup]    Start Actor Turn    aino    anonymous=${True}
    ...    eyebrow=Osallistuminen · 2 / 2
    ...    title=Kuvien lisäys ja lähetys
    ...    subtitle=Täydennetään kuvat ja vahvistetaan lähetys arviointiin
    Open App As    aino_session    /#/omat
    Wait Until Visible    text=${ENTRY_TITLE}
    Caption    Avataan tallennettu luonnos uudelleen muokattavaksi.
    Human Click    role=button[name="Muokkaa"]
    Wait Until Visible    role=textbox[name="Nimi *"]
    Upload Images    input[type=file]    ${IMAGES}/aino-2.png    ${IMAGES}/aino-3.png
    Caption    Lisätään kaksi lisäkuvaa. Kuvalaskuri päivittyy automaattisesti.
    Submit Entry
    Caption    Vahvistusikkuna varmistaa, ettei keskeneräistä työtä lähetetä vahingossa.
    Open My Entries
    Wait Until Visible    text=${ENTRY_TITLE}
    Caption    Omat osallistumiset -sivulla näkyy työn tilana "Lähetetty".
    Take Screenshot    ${SHOTS_DIR}/02-tyo-lahetetty.png
    [Teardown]    End Actor Turn

*** Keywords ***
Restore The Story State
    No Operation
