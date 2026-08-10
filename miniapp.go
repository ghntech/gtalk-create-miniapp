package gtalk_miniapp

import (
	"embed"
	"encoding/json"
	"io/fs"
	"net/http"
	"strings"

	controller "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp/internal/app/controller"
	meCtrl "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp/internal/app/controller/me"
	noteCtrl "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp/internal/app/controller/note"
	"gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp/internal/app/infra/config"
	"gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp/internal/app/infra/repository"
	miniapp "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-miniapp-sdk"

	noteService "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp/internal/app/core/service/note"

	"github.com/gin-gonic/gin"

	"gitlab.ghn.vn/golang/gobase-library/pkg/ghn/base/database/dbmysql"
	database "gitlab.ghn.vn/golang/gobase-library/pkg/ghn/base/database/pg"
	"gitlab.ghn.vn/golang/gobase-library/pkg/ghn/base/engine/generator"
	"gitlab.ghn.vn/golang/gobase-library/pkg/ghn/base/logger"
	"go.uber.org/zap"
)

// staticFiles holds the compiled Vite SPA output.
// Build the frontend first: cd fe && pnpm run build
// The dist output must be copied to web/dist/ (relative to this repo's root).
//
//go:embed web/dist
var staticFiles embed.FS

// App is the miniapp entry point for gtalk-miniapp-service.
var App = miniapp.Miniapp{
	ID:          "gtalk-create-miniapp",
	Router:      setupRouter,
	StaticFiles: staticFiles,
	BindConfig: func() any {
		return &config.ServiceConfig{}
	},
	OnStart: func(cfg any) {
		c := cfg.(*config.ServiceConfig)
		initInfra(c)
	},
}

// appServices holds the initialized services for the hosted mode.
var appServices []controller.ServiceRegister

// appFEConfig holds the FEConfig for injection into index.html.
// Set during OnStart from the miniapp's config.
var appFEConfig *config.FEConfig

// appUploadOrigins holds the configured S3/object-store origins added to the CSP
// connect-src so the direct-to-S3 upload PUT isn't blocked. Set during OnStart.
var appUploadOrigins []string

// appImageOrigins holds the configured image CDN origins added to the CSP img-src
// so rendered images aren't blocked. Set during OnStart.
var appImageOrigins []string

func initInfra(conf *config.ServiceConfig) {
	// Store FEConfig and CSP origins for use in setupRouter / serveIndexHTML.
	appFEConfig = &conf.FEConfig
	appUploadOrigins = conf.UploadOrigins
	appImageOrigins = conf.ImageOrigins
	if err := generator.NewSnowFlake(); err != nil {
		logger.L().Panic("[gtalk-create-miniapp] create snowflake failed", zap.Error(err))
	}

	db, err := database.NewPostgresSQLDatabase(conf.NoteDB)
	if err != nil {
		logger.L().Panic("[gtalk-create-miniapp] newDatabase failed", zap.Error(err))
	}

	noteRepo := repository.NewNoteRepository(db)
	noteSvc := noteService.NewNoteService(noteRepo)

	// In hosted mode, auth is handled by the host's identity middleware.
	// We use a no-op auth middleware here — the host has already validated the user.
	authMiddleware := &noopAuthMiddleware{}

	appServices = []controller.ServiceRegister{
		meCtrl.NewMeController(authMiddleware),
		noteCtrl.NewNoteController(noteSvc, authMiddleware),
	}
}

// setupRouter is called by the host to mount all routes.
func setupRouter(r *gin.RouterGroup) {
	// Baseline security headers on every response (API + SPA shell + assets).
	apiURL := ""
	if appFEConfig != nil {
		apiURL = appFEConfig.ApiUrl
	}
	r.Use(controller.SecurityHeaders(apiURL, appUploadOrigins, appImageOrigins))

	// Mount API routes
	if appServices != nil {
		controller.SetupRoutes(appServices)(r)
	}

	// Serve static FE files from web/dist/
	distFS, err := fs.Sub(staticFiles, "web/dist")
	if err != nil {
		logger.L().Panic("[gtalk-create-miniapp] failed to sub static files", zap.Error(err))
	}

	r.GET("/assets/*filepath", func(c *gin.Context) {
		filePath := c.Param("filepath")
		data, err := fs.ReadFile(distFS, "assets"+filePath)
		if err != nil {
			c.Status(http.StatusNotFound)
			return
		}
		contentType := "application/octet-stream"
		switch {
		case strings.HasSuffix(filePath, ".css"):
			contentType = "text/css; charset=utf-8"
		case strings.HasSuffix(filePath, ".js"):
			contentType = "application/javascript; charset=utf-8"
		case strings.HasSuffix(filePath, ".svg"):
			contentType = "image/svg+xml"
		case strings.HasSuffix(filePath, ".png"):
			contentType = "image/png"
		case strings.HasSuffix(filePath, ".woff2"):
			contentType = "font/woff2"
		case strings.HasSuffix(filePath, ".woff"):
			contentType = "font/woff"
		}
		c.Data(http.StatusOK, contentType, data)
	})

	r.GET("/favicon.png", func(c *gin.Context) {
		data, err := fs.ReadFile(distFS, "favicon.png")
		if err != nil {
			c.Status(http.StatusNotFound)
			return
		}
		c.Data(http.StatusOK, "image/png", data)
	})

	r.GET("/", func(c *gin.Context) {
		serveIndexHTML(c, distFS)
	})
}

// serveIndexHTML reads index.html, injects window.appEnvConfig, and writes it to the response.
func serveIndexHTML(c *gin.Context, distFS fs.FS) {
	indexBytes, err := fs.ReadFile(distFS, "index.html")
	if err != nil {
		c.Status(http.StatusInternalServerError)
		return
	}

	// Use the package-level FEConfig stored during OnStart.
	// Each miniapp has its own package-level var, so multiple miniapps don't conflict.
	var feConfigData any
	if appFEConfig != nil {
		feConfigData = appFEConfig
	}

	if feConfigData == nil {
		c.Data(http.StatusOK, "text/html; charset=utf-8", indexBytes)
		return
	}

	configJSON, err := json.Marshal(feConfigData)
	if err != nil {
		c.Data(http.StatusOK, "text/html; charset=utf-8", indexBytes)
		return
	}

	script := `<script>window.appEnvConfig=` + string(configJSON) + `;</script>`
	html := strings.Replace(string(indexBytes), `</head>`, script+`</head>`, 1)
	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))
}

// noopAuthMiddleware is used in hosted mode where the host handles authentication.
type noopAuthMiddleware struct{}

func (n *noopAuthMiddleware) Intercept(ctx *gin.Context) {
	ctx.Next()
}

// Ensure dbmysql is used (imported for config struct compatibility)
var _ = dbmysql.DatasourceX{}
