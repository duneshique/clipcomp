#!/bin/bash

# 터미널 색상
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${ORANGE}!${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "  ClipComp 설치를 시작합니다."
echo ""

# ── 1. 아키텍처 감지 ──────────────────────────────────────────
if [ "$(uname -m)" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi
log "아키텍처: $(uname -m) → Homebrew 경로: $BREW_PREFIX"

# ── 2. Homebrew 확인 ──────────────────────────────────────────
if ! command -v "$BREW_PREFIX/bin/brew" &>/dev/null; then
    warn "Homebrew가 없습니다. 설치를 시작합니다..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || fail "Homebrew 설치 실패"
fi
log "Homebrew 확인"

# ── 3. 의존성 설치 ────────────────────────────────────────────
log "pngquant, terminal-notifier 설치 중..."
"$BREW_PREFIX/bin/brew" install pngquant terminal-notifier --quiet 2>/dev/null
log "의존성 설치 완료"

# ── 4. 폴더 생성 ──────────────────────────────────────────────
mkdir -p "$HOME/clipcomp"
log "~/clipcomp 폴더 생성"

# ── 5. 아이콘 처리 ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_SRC="$SCRIPT_DIR/icon_clipcomp.png"
ICON_DST="$HOME/clipcomp/icon_clipcomp.png"
HAS_ICON=false

if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$ICON_DST"
    HAS_ICON=true
    log "아이콘 파일 복사"
fi

# ── 6. icns 변환 ──────────────────────────────────────────────
ICNS_PATH="$HOME/clipcomp/clipcomp.icns"
if [ "$HAS_ICON" = true ]; then
    ICONSET="/tmp/clipcomp_install.iconset"
    mkdir -p "$ICONSET"
    sips -z 1024 1024 "$ICON_DST" --out "$ICONSET/icon_512x512@2x.png" &>/dev/null
    sips -z 512  512  "$ICON_DST" --out "$ICONSET/icon_512x512.png"    &>/dev/null
    sips -z 512  512  "$ICON_DST" --out "$ICONSET/icon_256x256@2x.png" &>/dev/null
    sips -z 256  256  "$ICON_DST" --out "$ICONSET/icon_256x256.png"    &>/dev/null
    sips -z 128  128  "$ICON_DST" --out "$ICONSET/icon_128x128.png"    &>/dev/null
    sips -z 64   64   "$ICON_DST" --out "$ICONSET/icon_32x32@2x.png"   &>/dev/null
    sips -z 32   32   "$ICON_DST" --out "$ICONSET/icon_32x32.png"      &>/dev/null
    sips -z 16   16   "$ICON_DST" --out "$ICONSET/icon_16x16.png"      &>/dev/null
    iconutil -c icns "$ICONSET" -o "$ICNS_PATH" 2>/dev/null
    rm -rf "$ICONSET"
    log "아이콘 icns 변환 완료"
fi

# ── 7. ClipComp.app 생성 (알림 발신자용) ──────────────────────
APP_PATH="$HOME/Applications/ClipComp.app"
mkdir -p "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/MacOS"
osacompile -o "$APP_PATH" -e $'on run\nend run' &>/dev/null
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.clipcomp" \
    "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.clipcomp" \
    "$APP_PATH/Contents/Info.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleName ClipComp" \
    "$APP_PATH/Contents/Info.plist" 2>/dev/null
if [ -f "$ICNS_PATH" ]; then
    cp "$ICNS_PATH" "$APP_PATH/Contents/Resources/applet.icns"
fi
log "ClipComp.app 생성"

# ── 8. ClipComp 전용 notifier 생성 ────────────────────────────
TN_SRC=$(find "$BREW_PREFIX/Cellar/terminal-notifier" -name "terminal-notifier.app" -type d 2>/dev/null | head -1)
NOTIFIER_APP="$HOME/clipcomp/ClipComp-notifier.app"

if [ -n "$TN_SRC" ]; then
    rm -rf "$NOTIFIER_APP"
    cp -R "$TN_SRC" "$NOTIFIER_APP"
    if [ -f "$ICNS_PATH" ]; then
        cp "$ICNS_PATH" "$NOTIFIER_APP/Contents/Resources/Terminal.icns"
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.clipcomp.notifier" \
        "$NOTIFIER_APP/Contents/Info.plist" 2>/dev/null
    log "ClipComp-notifier.app 생성"
else
    fail "terminal-notifier.app을 찾을 수 없습니다."
fi

# ── 9. clipboard-compress.sh 생성 ─────────────────────────────
SCRIPT_PATH="$HOME/clipcomp/clipboard-compress.sh"
cat > "$SCRIPT_PATH" << SCRIPT
#!/bin/bash

TMP_IN="/tmp/clip_in.png"
TMP_OUT="/tmp/clip_out.png"
NOTIFIER="\$HOME/clipcomp/ClipComp-notifier.app/Contents/MacOS/terminal-notifier"
PNGQUANT="$BREW_PREFIX/bin/pngquant"
trap "rm -f \$TMP_IN \$TMP_OUT" EXIT

PREV_COUNT=""

while true; do
    CLIP_INFO=\$(osascript -e 'clipboard info' 2>/dev/null)
    CURRENT_COUNT=\$(echo "\$CLIP_INFO" | md5)

    if [ "\$CURRENT_COUNT" != "\$PREV_COUNT" ]; then
        PREV_COUNT="\$CURRENT_COUNT"

        if echo "\$CLIP_INFO" | grep -q "PNGf"; then
            rm -f "\$TMP_IN" "\$TMP_OUT"

            osascript << 'APPLESCRIPT' 2>/dev/null
try
    set png_data to the clipboard as «class PNGf»
    set f to open for access POSIX file "/tmp/clip_in.png" with write permission
    set eof of f to 0
    write png_data to f
    close access f
end try
APPLESCRIPT

            if [ -f "\$TMP_IN" ]; then
                BEFORE=\$(wc -c < "\$TMP_IN")
                "\$PNGQUANT" 256 --quality=80-95 --speed 1 "\$TMP_IN" -o "\$TMP_OUT" --force 2>/dev/null

                if [ -f "\$TMP_OUT" ]; then
                    AFTER=\$(wc -c < "\$TMP_OUT")
                    SAVED=\$(( (BEFORE - AFTER) * 100 / BEFORE ))
                    BEFORE_KB=\$(( BEFORE / 1024 ))
                    AFTER_KB=\$(( AFTER / 1024 ))
                    osascript -e "set the clipboard to (read (POSIX file \"\$TMP_OUT\") as «class PNGf»)"
                    PREV_COUNT=\$(osascript -e 'clipboard info' 2>/dev/null | md5)
                    "\$NOTIFIER" -title "ClipComp" \\
                        -message "\${SAVED}% 압축 완료 (\${BEFORE_KB}KB → \${AFTER_KB}KB)" \\
                        -contentImage "\$TMP_OUT" \\
                        -sender "com.clipcomp.notifier" \\
                        -sound default
                    echo "\$(date): \${SAVED}% 압축 완료 (\${BEFORE_KB}KB → \${AFTER_KB}KB)"
                else
                    "\$NOTIFIER" -title "ClipComp" -message "압축 실패 (pngquant 오류)" -sound default
                fi
            fi
        fi
    fi
    sleep 1
done
SCRIPT
chmod +x "$SCRIPT_PATH"
log "clipboard-compress.sh 생성"

# ── 10. launchd plist 생성 ────────────────────────────────────
# ~/Library/LaunchAgents/ 에 등록된 plist는 macOS 로그인 시 자동 실행됩니다.
# RunAtLoad: 로그인할 때마다 자동 시작
# KeepAlive: 스크립트가 비정상 종료되면 자동 재시작
PLIST_PATH="$HOME/Library/LaunchAgents/com.clipcomp.plist"
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clipcomp</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/clipcomp/clipboard-compress.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/clipcomp/clipcomp.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/clipcomp/clipcomp-error.log</string>
</dict>
</plist>
PLIST
log "launchd plist 생성"

# ── 11. Launch Services 등록 및 launchd 시작 ──────────────────
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREGISTER" -f "$APP_PATH" 2>/dev/null
"$LSREGISTER" -f "$NOTIFIER_APP" 2>/dev/null

launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"
log "ClipComp 시작 완료"

echo ""
echo "  설치 완료! PNG 이미지를 복사하면 자동으로 압축됩니다."
echo ""
