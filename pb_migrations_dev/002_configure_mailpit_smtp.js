// @ts-nocheck
// DEV ONLY — configure PocketBase to send email via local mailpit (127.0.0.1:1025)
migrate(
  (app) => {
    const settings = app.settings();
    settings.smtp.enabled = true;
    settings.smtp.host = "127.0.0.1";
    settings.smtp.port = 1025;
    settings.smtp.username = "";
    settings.smtp.password = "";
    settings.smtp.tls = false;
    settings.meta.senderName = "Palikkakilpailu";
    settings.meta.senderAddress = "noreply@palikkaharrastajat.fi";
    app.save(settings);
  },
  (app) => {
    const settings = app.settings();
    settings.smtp.enabled = false;
    app.save(settings);
  }
);
