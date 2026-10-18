*** Settings ***
Documentation     Arvostelijan työnkulku ja arviointityökalut (Reviewer Workflow):
...               1. Arvostelijan sisäänkirjautuminen ja arviointilistan avaus.
...               2. Suodatus: "Kaikki" vs "Ei vielä arvosteltu".
...               3. Työn avaaminen ja pisteytys 4 kriteerillä (1–5 tähteä).
...               4. Arvion tallennus luonnoksena ja julkaisu.
...               5. Työn hyväksyminen tai hylkääminen.
Resource          resources/competitions.resource
Suite Setup       Restore The Story State

*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${COMPETITION}    Majakka 2026
${VALID_ENTRY}    Myrskyluodon majakka
${REJECT_ENTRY}   Keskeneräinen majakka

*** Tasks ***
Valmistele Ymparisto
    Reset Demo Data
    Clear State
    Serve App
    Start Observer    arvostelu    ${APP}/#/arvostelu

Perusta Kilpailu Ja Osallistumiset
    # Create competition in judging state
    Open Admin Collection    competitions
    Human Click    role=button[name="New record"i]
    Wait Until Visible    role=textbox[name="title *"]
    Fill Competition Form    ${COMPETITION}    majakka-2026    Majakka
    ...    Rakenna majakka – pieni tai suuri, merellä tai maalla.
    ...    Yksi osallistuminen per rakentaja. 1–3 kuvaa, joista ensimmäinen on pääkuva.
    ...    2026-10-01T09:00    2026-11-30T21:59    2026-12-15T21:59
    ...    ${IMAGES}/kansi.png
    Set Entry Limits    1    1    3
    Choose Status    judging
    Human Click    role=button[name="Create"s]
    Wait Until Visible    role=cell[name="${COMPETITION}"s]
    # Create 2 submitted entries
    Create Submitted Entry    ${COMPETITION}    keycloak-participant@example.test    ${VALID_ENTRY}
    ...    Punavalkoinen majakka kalliosaarella. Valo pyörii pienellä moottorilla.
    ...    ${IMAGES}/aino-1.png    ${IMAGES}/aino-2.png
    Create Submitted Entry    ${COMPETITION}    janedoe@example.com    ${REJECT_ENTRY}
    ...    Vain pari palikkaa, työ jäi kesken.
    ...    ${IMAGES}/iida-1.png

Arvioi Ja Pisteyta Tyot
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Arviointi · 1 / 2
    ...    title=Töiden arviointi ja pisteytys
    ...    subtitle=Arvostelija pisteyttää teoksen 4 kriteerillä ja kirjoittaa palautteen
    Sign In As Member    keycloak-reviewer@example.test    reviewer
    Caption    Arvostelijalla on pääsy Arvosteltavat-osioon ylävalikosta.
    Human Click    role=link[name="Arvosteltavat"]
    Wait Until Visible    role=button[name="Ei vielä arvosteltu"]
    Caption    Suodatin näyttää vain työt, joita ei ole vielä pisteytetty.
    Human Click    role=button[name="Ei vielä arvosteltu"]
    Review Entry    ${VALID_ENTRY}    5    5    4    5    Upea valaistus ja näyttävä kalliosaari!
    Caption    Pisteytys koostuu neljästä kriteeristä (1–5) sekä sanallisesta palautteesta.
    Human Click    role=dialog >> role=button[name="Tallenna ja julkaise"]
    Caption    Julkaistu arvio näkyy osallistujalle ja lasketaan kokonaispisteisiin.
    Human Click    role=button[name="Sulje arvostelulomake"]
    Take Screenshot    ${SHOTS_DIR}/01-arvioitu.png
    [Teardown]    End Actor Turn

Hyvaksy Ja Hylkaa
    [Setup]    Start Actor Turn    olli    anonymous=${True}
    ...    eyebrow=Arviointi · 2 / 2
    ...    title=Töiden hyväksyminen ja hylkääminen
    ...    subtitle=Sääntöjen mukaisten töiden hyväksyntä ja virheellisten hylkäys
    Go To    ${APP}/#/arvostelu
    Human Click    role=button[name="Kaikki"s]
    Caption    Kaikki-näkymässä näkyvät kaikki osallistumiset ja niiden arviointitila.
    Human Click    role=button[name="Hyväksy osallistuminen: ${VALID_ENTRY}"]
    Caption    Hyväksytty työ pääsee mukaan tuloslaskentaan ja galleriaan.
    Human Click    role=button[name="Hylkää osallistuminen: ${REJECT_ENTRY}"]
    Caption    Sääntöjen vastainen tai puutteellinen työ merkitään hylätyksi.
    Take Screenshot    ${SHOTS_DIR}/02-hyvaksytty-ja-hylatty.png
    [Teardown]    End Actor Turn

Lopuksi
    Hold    2
    End Observer

*** Keywords ***
Restore The Story State
    No Operation
