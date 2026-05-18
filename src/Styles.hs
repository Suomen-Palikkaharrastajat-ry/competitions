{-# LANGUAGE OverloadedStrings #-}

module Styles (css) where

import Data.Text (Text)
import qualified Data.Text as T

{- | Embedded CSS for the public gallery.
Uses brand tokens: #05131D (black), #FAC80A (yellow), #C91A09 (red).
-}
css :: Text
css =
    T.unlines
        [ -- Custom properties
          ":root {"
        , "  --brand-black: #05131D;"
        , "  --brand-yellow: #FAC80A;"
        , "  --brand-red: #C91A09;"
        , "  --radius: 8px;"
        , "  --white: #fff;"
        , "  --text-muted: #6B7280;"
        , "  --text-subtle: #9CA3AF;"
        , "  --border-default: #E5E7EB;"
        , "  --duration-fast: 150ms;"
        , "  --duration-base: 300ms;"
        , "}"
        , -- Reset & base
          "*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }"
        , "body { font-family: 'Outfit', system-ui, sans-serif; line-height: 1.6;"
        , "       color: var(--brand-black); background: var(--white); }"
        , "img { max-width: 100%; height: auto; display: block; }"
        , "a { color: var(--brand-black); }"
        , -- Layout
          ".site-header { background: var(--brand-black); color: var(--white); padding: 1rem 0; }"
        , ".header-inner { max-width: 64rem; margin: 0 auto; padding: 0 1rem; }"
        , ".site-header h1 { font-weight: 900; font-size: 1.75rem; color: var(--brand-yellow); }"
        , "main { max-width: 64rem; margin: 0 auto; padding: 2rem 1rem; }"
        , ".site-footer { max-width: 64rem; margin: 0 auto; padding: 2rem 1rem;"
        , "               color: var(--text-muted); font-size: 0.875rem; border-top: 1px solid var(--border-default); }"
        , -- Competition section
          ".competition-section { margin-bottom: 4rem; }"
        , ".competition-title { font-size: 1.5rem; font-weight: 700;"
        , "                     margin-bottom: 0.5rem; border-bottom: 3px solid var(--brand-yellow);"
        , "                     padding-bottom: 0.5rem; }"
        , ".competition-desc { color: var(--text-muted); margin-bottom: 1.5rem; }"
        , -- Podium
          ".podium { background: #f9fafb; border-radius: var(--radius);"
        , "          padding: 1.5rem; margin-bottom: 2rem; }"
        , ".podium-title { font-size: 1.125rem; font-weight: 700;"
        , "                margin-bottom: 1rem; color: var(--brand-black); }"
        , ".podium-list { list-style: none; display: flex; gap: 1rem; flex-wrap: wrap; }"
        , ".podium-item { display: flex; flex-direction: column; align-items: center;"
        , "               flex: 1; min-width: 10rem; gap: 0.5rem; }"
        , ".podium-rank { font-size: 2rem; font-weight: 900; color: var(--brand-yellow); }"
        , ".rank-1 .podium-rank { font-size: 2.5rem; }"
        , ".podium-img { width: 100%; max-height: 12rem; object-fit: cover;"
        , "              border-radius: var(--radius); cursor: pointer; }"
        , ".podium-info { display: flex; flex-direction: column; align-items: center; gap: 0.25rem; }"
        , ".podium-entry-title { font-weight: 600; text-align: center; }"
        , ".podium-score { font-size: 0.875rem; color: var(--text-muted); }"
        , ".podium-submitter { font-size: 0.875rem; color: var(--text-subtle); }"
        , -- Entry grid
          ".entry-grid { display: grid;"
        , "              grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr));"
        , "              gap: 1.5rem; }"
        , ".entry-card { border: 1px solid var(--border-default); border-radius: var(--radius);"
        , "              overflow: hidden; display: flex; flex-direction: column; }"
        , ".entry-img-wrap { height: 12rem; overflow: hidden; }"
        , ".entry-img { width: 100%; height: 100%; object-fit: cover; cursor: pointer;"
        , "             transition: transform var(--duration-base, 300ms) cubic-bezier(0.4, 0, 0.2, 1); }"
        , "@media (prefers-reduced-motion: reduce) { .entry-img { transition: none; } }"
        , ".entry-img:hover { transform: scale(1.04); }"
        , ".entry-body { padding: 1rem; display: flex; flex-direction: column; gap: 0.375rem; }"
        , ".entry-title { font-size: 1rem; font-weight: 600; }"
        , ".entry-desc { font-size: 0.875rem; color: var(--text-muted); }"
        , ".entry-submitter { font-size: 0.8125rem; color: var(--text-subtle); }"
        , ".entry-score { font-size: 0.8125rem; color: var(--text-muted); }"
        , -- Lightbox
          "#lightbox { display: none; position: fixed; inset: 0;"
        , "            background: rgba(5,19,29,0.92); z-index: 9999;"
        , "            align-items: center; justify-content: center; cursor: pointer; }"
        , "#lightbox.active { display: flex; }"
        , "#lightbox img { max-width: 90vw; max-height: 90vh; object-fit: contain;"
        , "                border-radius: var(--radius); box-shadow: 0 8px 32px rgba(0,0,0,0.5); }"
        , -- Accessibility
          ".sr-only { position: absolute; width: 1px; height: 1px; padding: 0;"
        , "           margin: -1px; overflow: hidden; clip: rect(0,0,0,0);"
        , "           white-space: nowrap; border: 0; }"
        , ".skip-link { position: absolute; width: 1px; height: 1px; padding: 0;"
        , "             margin: -1px; overflow: hidden; clip: rect(0,0,0,0);"
        , "             white-space: nowrap; border: 0; text-decoration: none; }"
        , ".skip-link:focus { position: fixed; top: 0.75rem; left: 50%;"
        , "                   transform: translateX(-50%); width: auto; height: auto;"
        , "                   padding: 0.5rem 1rem; margin: 0; overflow: visible;"
        , "                   clip: auto; white-space: normal;"
        , "                   background: var(--brand-black); color: var(--white);"
        , "                   border-radius: 4px; z-index: 10000; font-weight: 600; }"
        , -- Responsive
          "@media (max-width: 40rem) {"
        , "  .podium-list { flex-direction: column; }"
        , "  .entry-grid { grid-template-columns: 1fr; }"
        , "}"
        ]
