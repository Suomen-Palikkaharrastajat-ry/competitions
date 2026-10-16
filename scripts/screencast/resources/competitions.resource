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
    Wait Until Visible    role=button[name="New Record"]

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
