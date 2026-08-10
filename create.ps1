# ─────────────────────────────────────────────────────────────────────────────
# create.ps1 — gtalk-create-miniapp scaffolder (Windows PowerShell)
# Compatible with: Windows PowerShell 5.1+, PowerShell 7+
#
# Usage:
#   .\create.ps1
#
# macOS/Linux users: use create.sh instead (bash)
#
# Naming convention:
#   App name    : single word, lowercase (e.g. "donation")
#   Repo name   : miniapp-<appname>-service  (e.g. "miniapp-donation-service")
#   Miniapp ID  : <appname>                  (e.g. "donation")
#   URL path    : /apps/<appname>/           (e.g. /apps/donation/)
#   Go module   : gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/miniapp-<appname>-service
#   Go package  : miniapp-<appname>-service
#   DB name     : gtalk_miniapp_<appname>_db (e.g. "gtalk_miniapp_donation_db")
#   Owner       : <appname>_team             (e.g. "donation_team")
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

# ── Template constants ────────────────────────────────────────────────────────
$TEMPLATE_ZIP_URL            = "https://s3-sgn10.fptcloud.com/gtalk-public/miniapp/gtalk-create-miniapp-template.zip"
$TEMPLATE_MODULE             = "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp"
$TEMPLATE_MODULE_PREFIX      = "gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps"
$TEMPLATE_REPO_NAME          = "gtalk-create-miniapp"
$TEMPLATE_PKG                = "gtalk_miniapp"
$TEMPLATE_ID                 = "gtalk-create-miniapp"
$TEMPLATE_DB                 = "gtalk_miniapp_note_db"
$TEMPLATE_FE_NAME            = "gtalk-note-web"
$TEMPLATE_CONFIG_STRUCT      = "NoteAppConfig"
$TEMPLATE_CONFIG_DB_FIELD    = "NoteDB"
$TEMPLATE_CONFIG_DB_KEY      = "noteDB"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Banner {
    Write-Host ""
    Write-Host "🚀 gtalk-create-miniapp scaffolder" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($msg)  { Write-Host $msg -ForegroundColor White }
function Write-Ok($msg)    { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "❌ $msg" -ForegroundColor Red }

function ToPascalCase($name) {
    if ($name.Length -eq 0) { return $name }
    return $name.Substring(0,1).ToUpper() + $name.Substring(1)
}

# Replace text in a single file (UTF-8 safe)
function Replace-InFile($from, $to, $filePath) {
    try {
        $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
        if ($content.Contains($from)) {
            $newContent = $content.Replace($from, $to)
            [System.IO.File]::WriteAllText($filePath, $newContent, [System.Text.Encoding]::UTF8)
        }
    } catch {
        # Skip binary or unreadable files
    }
}

# Replace text in all text files under a directory
function Replace-InDir($from, $to, $dir) {
    $skipDirs  = @('.git', 'node_modules', 'web\dist', 'fe\build', 'bin')
    $skipExts  = @('.png', '.jpg', '.ico', '.woff', '.woff2', '.ttf', '.eot', '.exe', '.dll', '.zip')

    Get-ChildItem -Path $dir -Recurse -File | ForEach-Object {
        $file = $_
        # Skip excluded directories
        foreach ($skip in $skipDirs) {
            if ($file.FullName -like "*\$skip\*") { return }
        }
        # Skip binary extensions
        if ($skipExts -contains $file.Extension.ToLower()) { return }

        Replace-InFile $from $to $file.FullName
    }
}

# ── Validation ────────────────────────────────────────────────────────────────
function Validate-AppName($name) {
    if ($name.Length -lt 2 -or $name.Length -gt 31) { return $false }
    if ($name -notmatch '^[a-z][a-z0-9]+$') { return $false }
    $reserved = @('auth','api','admin','static','assets','health','app','apps')
    if ($reserved -contains $name) { return $false }
    return $true
}

# ── Main ──────────────────────────────────────────────────────────────────────
Write-Banner

# ── Step 1: Collect inputs ────────────────────────────────────────────────────
Write-Step "📝 Project setup"
Write-Host ""

# App name
$APP_NAME = ""
while ($true) {
    $input = Read-Host "  App name (single word, e.g. donation)"
    $APP_NAME = $input.Trim().ToLower() -replace '\s',''
    if ($APP_NAME -eq "") {
        Write-Err "App name cannot be empty."
        continue
    }
    if (Validate-AppName $APP_NAME) { break }
    Write-Err "Invalid name. Use a single lowercase word (letters and digits only, starts with a letter, 2-31 chars). Cannot be: auth, api, admin, static, assets, health, app, apps."
}

# Derived names
$REPO_NAME    = "miniapp-${APP_NAME}-service"
$GO_PKG       = "miniapp-${APP_NAME}-service"
$MINIAPP_ID   = $APP_NAME
$DB_NAME      = "gtalk_miniapp_${APP_NAME}_db"
$OWNER        = "${APP_NAME}_team"
$TARGET_DIR   = ".\$REPO_NAME"

Write-Host ""
Write-Host "  Derived names:" -ForegroundColor Cyan
Write-Host "    Repo name   : $REPO_NAME"
Write-Host "    Miniapp ID  : $MINIAPP_ID"
Write-Host "    URL path    : /apps/$MINIAPP_ID/"
Write-Host "    Go module   : $TEMPLATE_MODULE_PREFIX/$REPO_NAME"
Write-Host "    DB name     : $DB_NAME"
Write-Host "    Owner       : $OWNER"
Write-Host "    Directory   : $TARGET_DIR"
Write-Host ""

$confirm = Read-Host "  Create project? [Y/n]"
if ($confirm -ne "" -and $confirm -notmatch '^[Yy]') {
    Write-Host "Aborted."
    exit 0
}

Write-Host ""

# ── Step 2: Get template ──────────────────────────────────────────────────────
Write-Step "📦 Downloading template..."

if (Test-Path $TARGET_DIR) {
    Write-Err "Directory '$TARGET_DIR' already exists. Please choose a different name or remove it first."
    exit 1
}

# Download template zip from S3 (no VPN required)
$TMP_ZIP = "$env:TEMP\gtalk-template-$([System.Guid]::NewGuid().ToString('N')).zip"
$TMP_DIR = "$env:TEMP\gtalk-template-$([System.Guid]::NewGuid().ToString('N'))"

Write-Host "  Downloading from S3..."
try {
    Invoke-WebRequest -Uri $TEMPLATE_ZIP_URL -OutFile $TMP_ZIP -UseBasicParsing
} catch {
    Write-Err "Failed to download template. Check your internet connection. Error: $_"
    exit 1
}

# Unzip to a temp directory first
New-Item -ItemType Directory -Path $TMP_DIR -Force | Out-Null
try {
    Expand-Archive -Path $TMP_ZIP -DestinationPath $TMP_DIR -Force
} catch {
    Remove-Item $TMP_ZIP -Force -ErrorAction SilentlyContinue
    Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Err "Failed to unzip template. Error: $_"
    exit 1
}
Remove-Item $TMP_ZIP -Force -ErrorAction SilentlyContinue

# The zip may extract into a single subdirectory — detect and flatten
$extractedItems = Get-ChildItem -Path $TMP_DIR
if ($extractedItems.Count -eq 1 -and $extractedItems[0].PSIsContainer) {
    Move-Item -Path $extractedItems[0].FullName -Destination $TARGET_DIR
    Remove-Item $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Move-Item -Path $TMP_DIR -Destination $TARGET_DIR
}

# Clean up scaffolder artifacts from the template
Remove-Item -Path "$TARGET_DIR\create.sh"            -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\create.ps1"           -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\docs"                 -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\create_miniapp_docs"  -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\templates"            -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\.git"                 -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\web\dist"             -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\fe\build"             -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$TARGET_DIR\bin"                  -Recurse -Force -ErrorAction SilentlyContinue

Write-Ok "Template ready at $TARGET_DIR"
Write-Host ""

# ── Step 3: Substitutions ─────────────────────────────────────────────────────
Write-Step "🔧 Customizing project..."

# 3a. Go module path
Write-Host "  Updating Go module path..."
Replace-InDir $TEMPLATE_MODULE "$TEMPLATE_MODULE_PREFIX/$REPO_NAME" $TARGET_DIR

# 3b. Go package name
Write-Host "  Updating Go package name..."
Replace-InDir "package $TEMPLATE_PKG" "package $GO_PKG" $TARGET_DIR
Replace-InDir "`"$TEMPLATE_PKG`"" "`"$GO_PKG`"" $TARGET_DIR

# 3c. Miniapp ID
Write-Host "  Updating miniapp ID..."
Replace-InDir $TEMPLATE_ID $MINIAPP_ID $TARGET_DIR

# 3d. Repo name references
Write-Host "  Updating repo name references..."
Replace-InDir $TEMPLATE_REPO_NAME $REPO_NAME $TARGET_DIR

# 3e. DB name
Write-Host "  Updating DB name..."
Replace-InDir $TEMPLATE_DB $DB_NAME $TARGET_DIR

# 3f. FE package name
Write-Host "  Updating FE package name..."
Replace-InDir $TEMPLATE_FE_NAME "$APP_NAME-web" $TARGET_DIR

# 3g. Config struct and DB field/key substitutions
Write-Host "  Updating config struct and DB references..."
$PASCAL_NAME = ToPascalCase $APP_NAME
Replace-InDir $TEMPLATE_CONFIG_STRUCT "${PASCAL_NAME}AppConfig" $TARGET_DIR
Replace-InDir $TEMPLATE_CONFIG_DB_FIELD "${PASCAL_NAME}DB" $TARGET_DIR
Replace-InDir $TEMPLATE_CONFIG_DB_KEY "${APP_NAME}DB" $TARGET_DIR

# 3h. Update miniapp.json
Write-Host "  Updating miniapp.json..."
$miniappJson = @"
{
  "id": "$MINIAPP_ID",
  "name": "$PASCAL_NAME",
  "owner": "$OWNER"
}
"@
[System.IO.File]::WriteAllText("$TARGET_DIR\miniapp.json", $miniappJson, [System.Text.Encoding]::UTF8)

Write-Ok "Substitutions complete"
Write-Host ""

# ── Step 4: Git init ──────────────────────────────────────────────────────────
Write-Step "🗂  Initializing git repository..."
Push-Location $TARGET_DIR
git init -q
git add .
git commit -q -m "chore: init from gtalk-create-miniapp template"
Pop-Location
Write-Ok "Git repository initialized"
Write-Host ""

# ── Step 5: Done! ─────────────────────────────────────────────────────────────
Write-Host "──────────────────────────────────────────────────────" -ForegroundColor Green
Write-Host "🎉 Project '$REPO_NAME' created at $TARGET_DIR" -ForegroundColor Green
Write-Host "   URL: https://gtalk-miniapp.ghn.vn/apps/$MINIAPP_ID/" -ForegroundColor Green
Write-Host "──────────────────────────────────────────────────────" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "  1. 🔑 Request VPN (if you haven't already):"
Write-Host "     https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73"
Write-Host "     Contact: tailp@ghn.vn  (takes 1-2 business days)"
Write-Host ""
Write-Host "  2. 🦊 Request GitLab account + repo (requires VPN):"
Write-Host "     Contact: tiendk@ghn.vn"
Write-Host "     Repo name: $REPO_NAME"
Write-Host ""
Write-Host "  3. 🗄️  Request DB access (if your miniapp needs a database):"
Write-Host "     Contact your team lead for Postgres credentials + VPN ACL"
Write-Host "     Then update: $TARGET_DIR\conf\application-dev.yaml"
Write-Host ""
Write-Host "  4. 💻 Run locally (after DB is configured):"
Write-Host "     cd $TARGET_DIR"
Write-Host "     make run          # builds FE + starts server at http://localhost:8082"
Write-Host ""
Write-Host "  5. 📤 Push to GitLab (requires VPN + GitLab account):"
Write-Host "     cd $TARGET_DIR"
Write-Host "     git remote add origin http://gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/$REPO_NAME.git"
Write-Host "     git push -u origin main"
Write-Host ""
Write-Host "  6. 🚢 Tag release to trigger CI/CD:"
Write-Host "     git tag v0.1.0; git push origin v0.1.0"
Write-Host ""
Write-Host "📖 Full guide: docs\GETTING_STARTED.md" -ForegroundColor Cyan
Write-Host ""
