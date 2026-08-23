#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# create.sh — gtalk-create-miniapp scaffolder
# Compatible with: macOS (bash 3.2+), Linux, Git Bash on Windows
#
# Usage:
#   bash create.sh                  # interactive mode
#   bash create.sh <app-name>       # non-interactive (skips all prompts)
#
# Windows users: use create.ps1 instead (PowerShell)
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

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Template constants ────────────────────────────────────────────────────────
TEMPLATE_ZIP_URL="https://s3-sgn10.fptcloud.com/gtalk-public/miniapp/gtalk-create-miniapp-template.zip"
TEMPLATE_MODULE="gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp"
TEMPLATE_MODULE_PREFIX="gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps"
TEMPLATE_REPO_NAME="gtalk-create-miniapp"
TEMPLATE_PKG="gtalk_miniapp"
TEMPLATE_ID="gtalk-create-miniapp"
TEMPLATE_DB="gtalk_miniapp_note_db"
TEMPLATE_FE_NAME="gtalk-note-web"
TEMPLATE_CONFIG_STRUCT="NoteAppConfig"
TEMPLATE_CONFIG_DB_FIELD="NoteDB"
TEMPLATE_CONFIG_DB_KEY="noteDB"

# ── Helpers ───────────────────────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${CYAN}${BOLD}🚀 gtalk-create-miniapp scaffolder${RESET}"
  echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
  echo ""
}

print_step() { echo -e "${BOLD}$1${RESET}"; }
print_ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
print_error(){ echo -e "${RED}❌ $1${RESET}"; }

# Portable lowercase (works on bash 3.2 / macOS)
to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Remove all spaces
strip_spaces() {
  echo "$1" | tr -d ' '
}

# Convert first letter to uppercase (portable, no bash 4 required)
to_pascal_case() {
  echo "$1" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
}

# Portable in-place sed (GNU sed and macOS BSD sed)
# LC_ALL=C is required on macOS to avoid "illegal byte sequence" errors
# when processing files that contain UTF-8 characters (e.g. comments with emoji)
sed_inplace() {
  local pattern="$1"
  local file="$2"
  if LC_ALL=C sed --version 2>/dev/null | grep -q GNU; then
    LC_ALL=C sed -i "$pattern" "$file"
  else
    LC_ALL=C sed -i '' "$pattern" "$file"
  fi
}

# Replace all occurrences of $1 with $2 in file $3
replace_in_file() {
  local from="$1"
  local to="$2"
  local file="$3"
  local escaped_from
  escaped_from=$(printf '%s\n' "$from" | LC_ALL=C sed 's/[[\.*^$()+?{|]/\\&/g; s/\//\\\//g')
  local escaped_to
  escaped_to=$(printf '%s\n' "$to" | LC_ALL=C sed 's/[[\.*^$()+?{|]/\\&/g; s/\//\\\//g; s/&/\\&/g')
  sed_inplace "s/${escaped_from}/${escaped_to}/g" "$file"
}

# Replace in all text files under a directory
replace_in_dir() {
  local from="$1"
  local to="$2"
  local dir="$3"
  find "$dir" \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/web/dist/*' \
    -not -path '*/fe/build/*' \
    -not -name '*.png' \
    -not -name '*.jpg' \
    -not -name '*.ico' \
    -not -name '*.woff' \
    -not -name '*.woff2' \
    -not -name '*.ttf' \
    -not -name '*.eot' \
    -not -name '*.DS_Store' \
    -type f \
    -exec grep -lF "$from" {} \; 2>/dev/null | while read -r file; do
      replace_in_file "$from" "$to" "$file"
    done
}

# ── Validation ────────────────────────────────────────────────────────────────
validate_app_name() {
  local name="$1"
  # Single word: lowercase letters and digits only, starts with letter, 2–31 chars
  case "$name" in
    [a-z][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]) ;;
    [a-z][a-z0-9]*) ;;
    *) return 1 ;;
  esac
  # Must be at least 2 chars
  if [ ${#name} -lt 2 ]; then
    return 1
  fi
  # Must be at most 31 chars
  if [ ${#name} -gt 31 ]; then
    return 1
  fi
  # Check only lowercase letters and digits
  case "$name" in
    *[^a-z0-9]*) return 1 ;;
  esac
  # Reserved IDs
  case "$name" in
    auth|api|admin|static|assets|health|app|apps) return 1 ;;
  esac
  return 0
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  print_banner

  # ── Step 1: Collect inputs ──────────────────────────────────────────────────
  print_step "📝 Project setup"
  echo ""

  # App name (single word)
  if [ -n "${1:-}" ]; then
    # Non-interactive: app name provided as argument
    APP_NAME=$(strip_spaces "$(to_lower "$1")")
    if [ -z "$APP_NAME" ]; then
      print_error "App name cannot be empty."
      exit 1
    fi
    if ! validate_app_name "$APP_NAME"; then
      print_error "Invalid name '$APP_NAME'. Use a single lowercase word (letters and digits only, starts with a letter, 2–31 chars). Cannot be: auth, api, admin, static, assets, health, app, apps."
      exit 1
    fi
  else
    # Interactive: prompt user
    while true; do
      printf "  App name (single word, e.g. donation): "
      read -r APP_NAME_RAW
      APP_NAME=$(strip_spaces "$(to_lower "$APP_NAME_RAW")")
      if [ -z "$APP_NAME" ]; then
        print_error "App name cannot be empty."
        continue
      fi
      if validate_app_name "$APP_NAME"; then
        break
      else
        print_error "Invalid name. Use a single lowercase word (letters and digits only, starts with a letter, 2–31 chars). Cannot be: auth, api, admin, static, assets, health, app, apps."
      fi
    done
  fi

  # Derived names
  REPO_NAME="miniapp-${APP_NAME}-service"
  GO_PKG="miniapp-${APP_NAME}-service"
  MINIAPP_ID="${APP_NAME}"
  DB_NAME="gtalk_miniapp_${APP_NAME}_db"
  OWNER="${APP_NAME}_team"
  TARGET_DIR="./${REPO_NAME}"

  echo ""
  echo -e "  ${CYAN}Derived names:${RESET}"
  echo "    Repo name   : ${REPO_NAME}"
  echo "    Miniapp ID  : ${MINIAPP_ID}"
  echo "    URL path    : /apps/${MINIAPP_ID}/"
  echo "    Go module   : ${TEMPLATE_MODULE_PREFIX}/${REPO_NAME}"
  echo "    DB name     : ${DB_NAME}"
  echo "    Owner       : ${OWNER}"
  echo "    Directory   : ${TARGET_DIR}"
  echo ""

  # Confirm (only in interactive mode)
  if [ -z "${1:-}" ]; then
    printf "  Create project? [Y/n]: "
    read -r CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    case "$CONFIRM" in
      [Yy]*) ;;
      *) echo "Aborted."; exit 0 ;;
    esac
  fi

  echo ""

  # ── Step 2: Get template ────────────────────────────────────────────────────
  print_step "📦 Downloading template..."

  if [ -d "$TARGET_DIR" ]; then
    print_error "Directory '${TARGET_DIR}' already exists. Please choose a different name or remove it first."
    exit 1
  fi

  # Download template zip from S3 (no VPN required)
  if ! command -v curl >/dev/null 2>&1; then
    print_error "curl is not installed. Please install curl first."
    exit 1
  fi

  TMP_ZIP="/tmp/gtalk-template-$$.zip"
  TMP_DIR="/tmp/gtalk-template-$$"

  echo "  Downloading from S3..."
  if ! curl -fsSL "$TEMPLATE_ZIP_URL" -o "$TMP_ZIP"; then
    rm -f "$TMP_ZIP"
    print_error "Failed to download template. Check your internet connection."
    exit 1
  fi

  # Unzip to a temp directory first
  mkdir -p "$TMP_DIR"
  if ! unzip -q "$TMP_ZIP" -d "$TMP_DIR"; then
    rm -f "$TMP_ZIP"
    rm -rf "$TMP_DIR"
    print_error "Failed to unzip template."
    exit 1
  fi
  rm -f "$TMP_ZIP"

  # The zip may extract into a single subdirectory (and possibly a __MACOSX folder).
  # Find the actual content directory (skip __MACOSX) and flatten it.
  CONTENT_DIR=""
  for item in "$TMP_DIR"/*/; do
    # Skip __MACOSX (macOS zip artifact)
    case "$item" in
      */__MACOSX/) continue ;;
    esac
    if [ -d "$item" ]; then
      CONTENT_DIR="$item"
      break
    fi
  done

  if [ -n "$CONTENT_DIR" ]; then
    # Single content subdirectory — move it directly to TARGET_DIR
    mv "$CONTENT_DIR" "$TARGET_DIR"
  else
    # Files extracted directly into TMP_DIR
    mv "$TMP_DIR" "$TARGET_DIR"
  fi
  rm -rf "$TMP_DIR"

  # Clean up scaffolder artifacts from the template
  rm -f "${TARGET_DIR}/create.sh"
  rm -f "${TARGET_DIR}/create.ps1"
  rm -rf "${TARGET_DIR}/docs"
  rm -rf "${TARGET_DIR}/create_miniapp_docs"
  rm -rf "${TARGET_DIR}/templates"
  rm -rf "${TARGET_DIR}/.git"
  rm -rf "${TARGET_DIR}/web/dist" "${TARGET_DIR}/fe/build" "${TARGET_DIR}/bin"

  print_ok "Template ready at ${TARGET_DIR}"
  echo ""

  # ── Step 3: Substitutions ───────────────────────────────────────────────────
  print_step "🔧 Customizing project..."

  # 3a. Go module path
  echo "  Updating Go module path..."
  replace_in_dir "${TEMPLATE_MODULE}" "${TEMPLATE_MODULE_PREFIX}/${REPO_NAME}" "$TARGET_DIR"

  # 3b. Go package name
  echo "  Updating Go package name..."
  replace_in_dir "package ${TEMPLATE_PKG}" "package ${GO_PKG}" "$TARGET_DIR"
  replace_in_dir "\"${TEMPLATE_PKG}\"" "\"${GO_PKG}\"" "$TARGET_DIR"

  # 3c. Miniapp ID
  echo "  Updating miniapp ID..."
  replace_in_dir "${TEMPLATE_ID}" "${MINIAPP_ID}" "$TARGET_DIR"

  # 3d. Repo name references
  echo "  Updating repo name references..."
  replace_in_dir "${TEMPLATE_REPO_NAME}" "${REPO_NAME}" "$TARGET_DIR"

  # 3e. DB name
  echo "  Updating DB name..."
  replace_in_dir "${TEMPLATE_DB}" "${DB_NAME}" "$TARGET_DIR"

  # 3f. FE package name
  echo "  Updating FE package name..."
  replace_in_dir "${TEMPLATE_FE_NAME}" "${APP_NAME}-web" "$TARGET_DIR"

  # 3g. Config struct and DB field/key substitutions
  echo "  Updating config struct and DB references..."
  PASCAL_NAME=$(to_pascal_case "$APP_NAME")
  replace_in_dir "${TEMPLATE_CONFIG_STRUCT}" "${PASCAL_NAME}AppConfig" "$TARGET_DIR"
  replace_in_dir "${TEMPLATE_CONFIG_DB_FIELD}" "${PASCAL_NAME}DB" "$TARGET_DIR"
  replace_in_dir "${TEMPLATE_CONFIG_DB_KEY}" "${APP_NAME}DB" "$TARGET_DIR"

  # 3h. Update miniapp.json
  echo "  Updating miniapp.json..."
  cat > "${TARGET_DIR}/miniapp.json" <<EOF
{
  "id": "${MINIAPP_ID}",
  "name": "${PASCAL_NAME}",
  "owner": "${OWNER}"
}
EOF

  print_ok "Substitutions complete"
  echo ""

  # ── Step 4: Git init ────────────────────────────────────────────────────────
  print_step "🗂  Initializing git repository..."
  cd "$TARGET_DIR"
  git init -q
  git add .
  git commit -q -m "chore: init from gtalk-create-miniapp template"
  cd - > /dev/null
  print_ok "Git repository initialized"
  echo ""

  # ── Step 5: Done! ───────────────────────────────────────────────────────────
  echo -e "${GREEN}${BOLD}──────────────────────────────────────────────────────${RESET}"
  echo -e "${GREEN}${BOLD}🎉 Project '${REPO_NAME}' created at ${TARGET_DIR}${RESET}"
  echo -e "${GREEN}${BOLD}   URL: https://gtalk-miniapp.ghn.vn/apps/${MINIAPP_ID}/${RESET}"
  echo -e "${GREEN}${BOLD}──────────────────────────────────────────────────────${RESET}"
  echo ""
  echo -e "${BOLD}Next steps:${RESET}"
  echo ""
  echo "  1. 🔑 Request VPN (if you haven't already):"
  echo "     https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73"
  echo "     Contact: tailp@ghn.vn  (takes 1–2 business days)"
  echo ""
  echo "  2. 🦊 Request GitLab account + repo (requires VPN):"
  echo "     Contact: tiendk@ghn.vn"
  echo "     Repo name: ${REPO_NAME}"
  echo ""
  echo "  3. 🗄️  Request DB access (if your miniapp needs a database):"
  echo "     Contact your team lead for Postgres credentials + VPN ACL"
  echo "     Then update: ${TARGET_DIR}/conf/application-dev.yaml"
  echo ""
  echo "  4. 💻 Run locally (after DB is configured):"
  echo "     cd ${TARGET_DIR}"
  echo "     make run          # builds FE + starts server at http://localhost:8082"
  echo ""
  echo "  5. 📤 Push to GitLab (requires VPN + GitLab account):"
  echo "     git -C ${TARGET_DIR} remote add origin http://gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/${REPO_NAME}.git"
  echo "     git -C ${TARGET_DIR} push -u origin main"
  echo ""
  echo "  6. 🚢 Tag release to trigger CI/CD:"
  echo "     git -C ${TARGET_DIR} tag v0.1.0 && git -C ${TARGET_DIR} push origin v0.1.0"
  echo ""
  echo -e "${CYAN}📖 Full guide: docs/GETTING_STARTED.md${RESET}"
  echo ""
}

main "$@"
