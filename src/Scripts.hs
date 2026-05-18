{-# LANGUAGE OverloadedStrings #-}

module Scripts (js) where

import Data.Text (Text)
import qualified Data.Text as T

{- | Vanilla JS lightbox for gallery entry images.
Images with a data-lightbox attribute open in a full-screen overlay.
Respects prefers-reduced-motion for the overlay transition.
-}
js :: Text
js =
    T.unlines
        [ "(function () {"
        , "  var overlay = document.getElementById('lightbox');"
        , "  var img = overlay.querySelector('img');"
        , ""
        , "  function open(src) {"
        , "    img.src = src;"
        , "    overlay.classList.add('active');"
        , "    overlay.focus();"
        , "  }"
        , ""
        , "  function close() {"
        , "    overlay.classList.remove('active');"
        , "    img.src = '';"
        , "  }"
        , ""
        , "  document.addEventListener('click', function (e) {"
        , "    var t = e.target;"
        , "    if (t.tagName === 'IMG' && t.dataset && t.dataset.lightbox) {"
        , "      e.preventDefault();"
        , "      open(t.dataset.lightbox);"
        , "    }"
        , "  });"
        , ""
        , "  overlay.addEventListener('click', close);"
        , ""
        , "  document.addEventListener('keydown', function (e) {"
        , "    if (e.key === 'Escape' && overlay.classList.contains('active')) {"
        , "      close();"
        , "    }"
        , "  });"
        , ""
        , "  overlay.addEventListener('keydown', function (e) {"
        , "    if (e.key === 'Tab') { e.preventDefault(); }"
        , "  });"
        , "}());"
        ]
