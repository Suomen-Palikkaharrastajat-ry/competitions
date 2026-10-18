*** Settings ***
Documentation     Keywords in the competitions app's vocabulary, built on the
...               screencast engine and CompetitionsLibrary.py. Local devenv
...               stack only (`devenv up`, http://127.0.0.1:8080).
Library           screencast.Screencast    take_dir=${TAKE_DIR}    record=${RECORD}
Library           ${CURDIR}/CompetitionsLibrary.py

*** Variables ***
# The app is the production build served by `Serve App` (no dev-server
# overlays on camera); PocketBase, its Admin UI and Mailpit stay behind Caddy.
${APP}            http://127.0.0.1:5174
${ADMIN}          http://127.0.0.1:8080/_/
${IMAGES}         ${CURDIR}/../images
${OTP_EMAIL}      ville.virtanen@example.test
&{DISPLAY_NAMES}
...               keycloak-participant@example.test=Aino Palikka
...               keycloak-reviewer@example.test=Olli Järjestäjä
...               janedoe@example.com=Iida Ilomäki

*** Keywords ***
# ── Setup ────────────────────────────────────────────────────────────────

Reset Demo Data
    [Documentation]    Empty competitions, entries and reviews; forget the
    ...    OTP participant; give the fixture accounts the story's names.
    Reset Competition Data    ${OTP_EMAIL}    ${DISPLAY_NAMES}

Serve App
    [Documentation]    Build the app for production and serve it on ${APP}.
    Build App
    ${origin}=    Serve App Build
    Should Be Equal    ${origin}    ${APP}

# ── Admin UI (organiser) ──────────────────────────────────────────────────

Open Admin Collection
    [Arguments]    ${collection}
    ${session}=    Admin Session
    Use Session    ${session}
    Go To    ${ADMIN}#/collections?collection=${collection}
    Wait Until Visible    role=button[name="New record"i]

Choose Status
    [Arguments]    ${status}
    Human Click    role=button[name="status *"]
    Human Click    role=button[name="${status}"s]

Fill Competition Form
    [Arguments]    ${title}    ${slug}    ${theme}    ${description}    ${rules}
    ...    ${start}    ${end}    ${judging_end}    ${cover}
    Human Type    role=textbox[name="title *"]    ${title}
    Human Type    role=textbox[name="slug *"]    ${slug}
    Paste Text    role=textbox[name="description"]    ${description}
    Human Type    role=textbox[name="theme"]    ${theme}
    Paste Text    role=textbox[name="rules"]    ${rules}
    Human Click    role=textbox[name="start_date (UTC) *"]
    Fill Field    role=textbox[name="start_date (UTC) *"]    ${start}
    Human Click    role=textbox[name="end_date (UTC) *"]
    Fill Field    role=textbox[name="end_date (UTC) *"]    ${end}
    Human Click    role=textbox[name="judging_end_date (UTC)"]
    Fill Field    role=textbox[name="judging_end_date (UTC)"]    ${judging_end}
    Upload Images    input[type=file]    ${cover}

Set Entry Limits
    [Arguments]    ${max_entries}    ${min_images}    ${max_images}
    Human Click    role=spinbutton[name="max_entries_per_user"]
    Fill Field    role=spinbutton[name="max_entries_per_user"]    ${max_entries}
    Human Click    role=spinbutton[name="min_images_per_entry"]
    Fill Field    role=spinbutton[name="min_images_per_entry"]    ${min_images}
    Human Click    role=spinbutton[name="max_images_per_entry"]
    Fill Field    role=spinbutton[name="max_images_per_entry"]    ${max_images}

Change Competition Status
    [Arguments]    ${title}    ${status}
    Open Admin Collection    competitions
    Human Click    role=cell[name="${title}"s]
    Wait Until Visible    role=button[name="status *"]
    Choose Status    ${status}
    Human Click    role=button[name="Save changes"]
    Wait Until Visible    role=cell[name="${status}"s]

# ── Competitions app ─────────────────────────────────────────────────────

Sign In As Member
    [Documentation]    Keycloak sign-in: the click is on camera, the popup
    ...    is completed off camera.
    [Arguments]    ${username}    ${password}
    Go To    ${APP}/
    Sign In With Keycloak    ${username}    ${password}
    Wait Until Visible    role=button[name="Kirjaudu ulos"]

Open App As
    [Documentation]    Continue a session saved earlier with `Save State`.
    [Arguments]    ${state_key}    ${path}=/
    ${session}=    Load State    ${state_key}
    Use Session    ${session}    ${APP}
    Go To    ${APP}${path}
    Wait Until Visible    role=button[name="Kirjaudu ulos"]

Request Login Code
    [Arguments]    ${email}
    Go To    ${APP}/
    Human Type    label=Sähköpostiosoite    ${email}
    Human Click    role=button[name="Lähetä kirjautumiskoodi"]
    Wait Until Visible    label=Kirjautumiskoodi

Enter Login Code
    [Arguments]    ${code}
    Fill Field    label=Kirjautumiskoodi    ${EMPTY}
    Human Type    label=Kirjautumiskoodi    ${code}
    Human Click    role=button[name="Kirjaudu"s]

Start Entry
    [Arguments]    ${competition}
    Wait Until Visible    text=${competition}
    Human Click    role=button[name="Osallistu →"]
    Wait Until Visible    role=textbox[name="Nimi *"]

Fill Entry
    [Arguments]    ${title}    ${description}    @{images}
    Human Type    role=textbox[name="Nimi *"]    ${title}
    Paste Text    role=textbox[name="Kuvaus"]    ${description}
    IF    ${images}
        Human Move    role=button[name^="Kuvat *"]
        Upload Images    input[type=file]    @{images}
    END

Submit Entry
    [Documentation]    "Lähetä arvosteltavaksi" and confirm in the dialog.
    Human Click    role=button[name="Lähetä arvosteltavaksi"]
    Wait Until Visible    role=dialog[name="Lähetetäänkö arvioitavaksi?"]
    Human Click    role=dialog >> role=button[name="Lähetä"s]
    Wait Until Visible    role=heading[name="Osallistuminen lähetetty!"]

Choose Display Name
    [Arguments]    ${name}
    Wait Until Visible    label=Näyttönimi
    Human Type    label=Näyttönimi    ${name}
    Human Click    role=button[name="Tallenna"s]
    Wait Until Visible    role=button[name="Kirjaudu ulos"]

Open My Entries
    Human Click    role=link[name="Omat osallistumiset"]
    Wait Until Visible    role=heading[name="Omat osallistumiset"]

Score Entry
    [Documentation]    Four criteria from 1 to 5 stars, then a comment.
    [Arguments]    ${theme}    ${originality}    ${technique}    ${presentation}    ${comment}
    Human Click    role=dialog >> role=button[name="Arvo ${theme} viidestä"] >> nth=0
    Human Click    role=dialog >> role=button[name="Arvo ${originality} viidestä"] >> nth=1
    Human Click    role=dialog >> role=button[name="Arvo ${technique} viidestä"] >> nth=2
    Human Click    role=dialog >> role=button[name="Arvo ${presentation} viidestä"] >> nth=3
    Paste Text    role=dialog >> role=textbox[name="Kommentti"]    ${comment}

Review Entry
    [Arguments]    ${entry}    ${theme}    ${originality}    ${technique}    ${presentation}    ${comment}
    Human Click    css=div.p-4:has(p:text-is("${entry}")) >> role=button[name="Arvioi"]
    Wait Until Visible    role=dialog[name="Arvostele: ${entry}"]
    Score Entry    ${theme}    ${originality}    ${technique}    ${presentation}    ${comment}

# ── In-App Admin (ADR-0004) ────────────────────────────────────────────────

Open In-App Admin
    Human Click    role=link[name="Ylläpito"]
    Wait Until Visible    role=heading[name="Ylläpito"]

Fill In-App Competition Form
    [Arguments]    ${title}    ${slug}    ${theme}    ${description}
    ...    ${start}    ${end}    ${judging_end}    ${min_img}    ${max_img}    ${max_entries}=${EMPTY}
    Human Click    role=button[name="+ Uusi kilpailu"]
    Wait Until Visible    role=heading[name="Uusi kilpailu"]
    Human Type    label=Nimi    ${title}
    Human Type    label=Tunniste (osoitteeseen)    ${slug}
    Human Type    label=Teema    ${theme}
    Human Type    label=Kuvaus    ${description}
    Fill Field    label=Alkaa    ${start}
    Fill Field    label=Osallistumisen päättyy    ${end}
    Fill Field    label=Arvostelun päättyy    ${judging_end}
    IF    "${max_entries}" != ""
        Fill Field    label=Osallistumisia per osallistuja (tyhjä = oletus)    ${max_entries}
    END
    Fill Field    label=Kuvia vähintään    ${min_img}
    Fill Field    label=Kuvia enintään    ${max_img}

Enable Ranked Voting On Form
    [Arguments]    ${start}    ${end}    ${required}=${False}
    Human Click    label=Yleisöäänestys käytössä
    Fill Field    label=Äänestys alkaa    ${start}
    Fill Field    label=Äänestys suljetaan (päivän alussa)    ${end}
    IF    ${required}
        Human Click    label=Osallistujien on äänestettävä
    END

Save In-App Competition
    Human Click    role=button[name="Tallenna"s]
    Wait Until Visible    role=heading[name="Ylläpito"]

Open Competition Edit In App Admin
    [Arguments]    ${title}
    Open In-App Admin
    Human Click    css=li:has(h2:text-is("${title}")) >> role=button[name="Muokkaa"]
    Wait Until Visible    role=heading[name="Muokkaa kilpailua"]

Transition In-App Status
    [Arguments]    ${target_status}
    Human Click    role=button[name="Siirrä tilaan: ${target_status}"]
    Wait Until Visible    text=Tila: ${target_status}

Open In-App Admin Entries
    [Arguments]    ${title}
    Open In-App Admin
    Human Click    css=li:has(h2:text-is("${title}")) >> role=button[name="Osallistumiset"]
    Wait Until Visible    role=heading[name="Osallistumiset"]
    Wait Until Visible    css=ul.grid, #vote-result, p:has-text("Ei osallistumisia.")

# ── Voting UI (ADR-0007) ───────────────────────────────────────────────────

Open Vote Page
    [Arguments]    ${competition_title}
    Go To    ${APP}/
    Wait Until Visible    text=Äänestys käynnissä
    Human Click    css=li:has-text("${competition_title}") >> role=button[name="Äänestä"]
    Wait Until Visible    role=heading[name^="Äänestys:"]

Choose Entry To Vote
    [Arguments]    ${entry_title}
    Human Click    role=button[name="Valitse: ${entry_title}"]

Save Vote Ballot
    Human Click    role=button[name="Tallenna ääni"]
    Wait Until Visible    text=Äänesi on tallennettu.

