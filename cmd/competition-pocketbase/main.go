package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/plugins/jsvm"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/osutils"
)

func main() {
	app := pocketbase.New()
	migrationsDir := os.Getenv("PB_MIGRATIONS_DIR")
	hooksDir := os.Getenv("PB_HOOKS_DIR")

	jsvm.MustRegister(app, jsvm.Config{
		HooksWatch:    true,
		HooksDir:      hooksDir,
		MigrationsDir: migrationsDir,
	})
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate:  osutils.IsProbablyGoRun(),
		Dir:          migrationsDir,
		TemplateLang: "js",
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
