<div align="center">
  <img src="icon_clipcomp.png" width="128" height="128" alt="ClipComp 아이콘" />
  <h1>ClipComp</h1>
  <p><strong>복사하는 순간, 이미지가 작아집니다.</strong></p>

  ![macOS](https://img.shields.io/badge/macOS-Mojave%2B-black?style=flat-square&logo=apple)
  ![Shell](https://img.shields.io/badge/Shell-Bash-orange?style=flat-square)
  ![License](https://img.shields.io/badge/License-MIT-orange?style=flat-square)
</div>

---

## 이런 분께 딱 맞습니다

- 스크린샷을 자주 찍고 Slack, Notion, 이메일에 붙여넣는 분
- 이미지 붙여넣기 전에 매번 압축 툴을 열기 귀찮은 분
- 팀 협업 도구의 파일 용량 제한에 걸려본 분

ClipComp는 클립보드에 PNG 이미지가 복사되는 순간 자동으로 압축합니다.  
별도 앱 실행 없이, 백그라운드에서 조용히 작동합니다.

---

## 미리보기

> PNG 이미지를 클립보드에 복사하면 약 1초 후 알림이 표시됩니다.

```
┌─────────────────────────────────────┐
│  ClipComp                      [아이콘] │
│  84% 압축 완료 (401KB → 64KB)         │
└─────────────────────────────────────┘
```

압축된 이미지는 클립보드에 자동으로 교체되어 있습니다.  
그대로 붙여넣기(⌘V)하면 됩니다.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| 자동 감지 | 클립보드 변경을 1초마다 감지 |
| PNG 전용 처리 | PNG 이미지일 때만 작동, 텍스트 복사는 무시 |
| 자동 압축 | pngquant로 품질 80-95% 유지하며 평균 65% 용량 감소 |
| 알림 피드백 | 압축 전후 용량 비교를 macOS 알림으로 표시 |
| 클립보드 교체 | 압축된 이미지를 클립보드에 자동으로 덮어씀 |
| 백그라운드 상시 실행 | 로그인 시 자동 시작, 종료 시 자동 재시작 |

---

## 작동 원리

[📄 워크플로우 문서 보기](workflow.html)

```
클립보드 복사
     ↓
PNG 타입 감지 (clipboard info)
     ↓
osascript로 이미지 추출
     ↓
pngquant 압축 (품질 80-95)
     ↓
클립보드 교체
     ↓
알림 표시 (압축률 + 용량 비교)
```

---

## 설치

### 요구사항

- macOS Mojave (10.14) 이상
- [Homebrew](https://brew.sh)

### 한 번에 설치하기

1. 이 저장소를 다운로드합니다
2. `install.command` 파일을 더블클릭합니다
3. 터미널에서 설치가 진행됩니다 (약 2-3분)

```bash
# install.command 가 자동으로 아래 작업을 수행합니다:
brew install pngquant terminal-notifier
# ClipComp.app 생성 (알림 발신자)
# ClipComp-notifier.app 생성 (전용 알림 앱)
# launchd 등록 (로그인 시 자동 시작)
```

### 수동 설치

```bash
# 1. 의존성 설치
brew install pngquant terminal-notifier

# 2. 저장소 클론
git clone https://github.com/duneshique/clipcomp.git ~/clipcomp

# 3. 실행 권한
chmod +x ~/clipcomp/install.command

# 4. 설치 실행
~/clipcomp/install.command
```

---

## 파일 구조

```
~/clipcomp/
├── clipboard-compress.sh          # 메인 압축 스크립트
├── install.command                # 설치 스크립트 (더블클릭)
├── ClipComp-notifier.app/         # 전용 알림 앱 (아이콘 적용)
├── icon_clipcomp.png              # 앱 아이콘
├── clipcomp.log                   # 실행 로그
└── clipcomp-error.log             # 에러 로그

~/Applications/
└── ClipComp.app/                  # 알림 발신자 앱

~/Library/LaunchAgents/
└── com.clipcomp.plist             # launchd 등록 파일 (자동 시작)
```

---

## 기술 스펙

| 항목 | 내용 |
|------|------|
| 언어 | Bash + AppleScript |
| 클립보드 감지 | `osascript -e 'clipboard info'` |
| PNG 타입 확인 | clipboard info에서 `PNGf` 타입 존재 여부 |
| 이미지 추출 | AppleScript `«class PNGf»` |
| 압축 엔진 | pngquant 256색 팔레트, 품질 80-95 |
| 알림 | terminal-notifier (전용 앱 번들, 썸네일 포함) |
| 자동 실행 | launchd (`~/Library/LaunchAgents/`) |
| 폴링 주기 | 1초 |
| 지원 아키텍처 | Apple Silicon (M1/M2/M3/M4), Intel |
| 지원 macOS | Mojave (10.14) 이상 |

---

## 효과

> 테스트 환경: Mac mini M4, Retina 스크린샷 기준

| 파일 유형 | 압축 전 | 압축 후 | 감소율 |
|-----------|---------|---------|--------|
| 스크린샷 (전체화면) | 4.2 MB | 1.1 MB | 74% |
| 스크린샷 (부분캡처) | 401 KB | 64 KB | 84% |
| UI 이미지 | 320 KB | 103 KB | 68% |
| 사진 PNG | 2.1 MB | 890 KB | 58% |

평균 압축률: **약 65-75%**  
압축 소요 시간: **0.5 ~ 1초** (체감 거의 없음)

---

## 중지 / 제거

```bash
# 일시 중지
launchctl unload ~/Library/LaunchAgents/com.clipcomp.plist

# 재시작
launchctl load ~/Library/LaunchAgents/com.clipcomp.plist

# 완전 제거
launchctl unload ~/Library/LaunchAgents/com.clipcomp.plist
rm -rf ~/clipcomp
rm -rf ~/Applications/ClipComp.app
rm ~/Library/LaunchAgents/com.clipcomp.plist
```

---

## 로그 확인

```bash
# 실시간 로그
tail -f ~/clipcomp/clipcomp.log

# 에러 로그
cat ~/clipcomp/clipcomp-error.log
```

---

## 주의사항

- PNG 이외의 이미지(JPEG, WebP 등)는 압축하지 않습니다
- 이미 압축된 이미지는 효과가 적을 수 있습니다
- macOS 알림 권한이 필요합니다 (설치 시 자동 요청)

---

<div align="center">
  <sub>Made with ☕ for daily workflow</sub>
</div>
