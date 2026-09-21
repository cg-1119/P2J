<p align="center">
  <img src="docs/images/banner.svg" alt="TODO First — 오늘 할 일, 중요한 것부터." width="100%">
</p>

<p align="center">
  <strong>할 일을 적고, 우선순위를 정하고, 오늘의 중요한 일에 집중하세요.</strong><br>
  앱에서도, 메뉴 막대에서도, macOS 위젯에서도.
</p>

<p align="center">
  <a href="#미리보기">미리보기</a> ·
  <a href="#시작하기">시작하기</a> ·
  <a href="#로드맵">로드맵</a> ·
  <a href="https://github.com/cg-1119/todo-first/issues">피드백</a>
</p>

<p align="center">
  <code>macOS 14+</code> &nbsp; <code>Swift 6</code> &nbsp; <code>SwiftUI + WidgetKit</code> &nbsp; <code>개발 중</code>
</p>

> **아직 정식 출시 전입니다.** 현재는 앱·메뉴 막대·위젯의 기본 화면이 준비되어 있습니다. 할 일 관리와 데이터 공유는 개발 예정이며, 설치용 배포 파일은 아직 제공하지 않습니다.

## 오늘 무엇부터 할까요?

해야 할 일을 모두 적어도, 무엇부터 시작할지 막막할 때가 있습니다. **TODO First**는 오늘 할 일과 우선순위를 한곳에 모아 다음 행동을 쉽게 고를 수 있도록 만드는 macOS 앱입니다.

| 사용 공간 | 목표하는 경험 | 현재 상태 |
| :--- | :--- | :--- |
| **앱** | 오늘 할 일을 정리하고 중요한 순서대로 확인 | 기본 화면 구성 |
| **메뉴 막대** | 작업 중에도 목록을 빠르게 열고 완료 체크 | 팝오버 및 앱 열기·종료 구현 |
| **위젯** | 데스크톱에서 중요한 할 일과 진행 현황 확인 | 소형·중형 준비 화면 구성 |

## 미리보기

### 오늘의 화면

<p align="center">
  <img src="docs/images/app-preview.png" alt="TODO First 실제 실행 화면. 오늘, 중요한 것부터 제목과 개발 중인 초기 안내 화면." width="800">
</p>

<p align="center"><sub>2026-09-21 · macOS에서 실행한 초기 개발 버전의 실제 캡처</sub></p>

현재 화면은 할 일 기능을 연결하기 전의 상태입니다. 위 이미지는 완성 예상도나 목업이 아니며, 기능이 추가되면 실제 사용 화면으로 갱신합니다. 메뉴 막대와 위젯의 상세 스크린샷도 각각의 기능을 검증한 뒤 추가할 예정입니다.

## 시작하기

현재는 Xcode에서 소스를 빌드해 실행할 수 있습니다.

### 준비물

- **macOS 14.0 이상**
- **Xcode 16 이상**, Swift 6 지원 환경
- 위젯 등록과 실행 확인을 위한 개인 개발 서명 설정

로컬 빌드는 Xcode 26.5에서 확인했습니다. 외부 패키지나 프로젝트 생성 도구는 필요하지 않습니다.

### 소스에서 실행

```sh
git clone https://github.com/cg-1119/todo-first.git
cd todo-first
open TODOFirst.xcodeproj
```

1. Xcode에서 **TODOFirst** 스킴과 **My Mac**을 선택합니다.
2. 개발 서명을 설정합니다. 방법은 [개발 가이드](docs/DEVELOPMENT.md#개발-서명)를 참고하세요.
3. **⌘R**로 실행합니다. 앱 창과 메뉴 막대의 체크리스트 아이콘이 나타납니다.

서명된 앱을 실행한 뒤 macOS의 **위젯 편집**에서 **TODO First**를 찾아 추가할 수 있습니다. 위젯의 시스템 등록과 실제 표시는 별도 검증이 필요하며, 현재 위젯에는 준비 화면이 표시됩니다.

<details>
<summary><strong>서명 없이 빌드만 확인하려면</strong></summary>

```sh
xcodebuild \
  -project TODOFirst.xcodeproj \
  -scheme TODOFirst \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

앱과 포함된 위젯의 컴파일·패키징을 확인하는 명령입니다. 배포용 서명이나 위젯 등록은 검증하지 않습니다.

</details>

## 로드맵

첫 버전은 **오늘의 목록을 만들고, 중요한 일부터 끝내는 흐름**에 집중합니다.

- [x] macOS 앱·메뉴 막대·위젯 프로젝트 구성
- [ ] 할 일 모델과 로컬 저장
- [ ] 오늘의 할 일 추가·수정·삭제
- [ ] 우선순위 설정 및 정렬
- [ ] 완료 체크와 오늘의 진행 현황
- [ ] 메뉴 막대에서 실제 목록 확인 및 완료 처리
- [ ] 앱·위젯 간 데이터 공유
- [ ] 위젯에 중요한 할 일과 완료 현황 표시
- [ ] 사용 화면 및 설치 안내 갱신
- [ ] 배포용 서명·공증 및 첫 릴리스

## 프로젝트 안쪽

**SwiftUI**로 앱을, **MenuBarExtra**로 빠른 보기를, **WidgetKit**으로 위젯을 구성합니다. 앱과 위젯의 데이터 공유는 **App Groups** 기반으로 구현할 예정입니다.

```text
TODOFirst/
├── App/                  앱 진입점
└── Features/
    ├── Today/            오늘의 할 일 화면
    └── MenuBar/          메뉴 막대 빠른 보기
TODOFirstWidgets/         WidgetKit 확장
Shared/                   앱·위젯 공통 코드
Configuration/            공통 빌드 설정과 개인 서명 예시
docs/                     개발 안내와 실제 화면 이미지
TODOFirst.xcodeproj/       Xcode 프로젝트와 공유 스킴
```

프로젝트 구성과 각 기능은 독립된 커밋으로 관리합니다. 실행·서명·검증 방법은 [개발 가이드](docs/DEVELOPMENT.md), 이미지 갱신 기준은 [스크린샷 안내](docs/SCREENSHOTS.md)에 정리되어 있습니다.

## 함께 다듬기

불편한 점이나 아이디어는 [Issues](https://github.com/cg-1119/todo-first/issues)에 남겨주세요. 버그 제보에는 macOS 버전, 재현 단계, 기대한 동작을 함께 적어주시면 도움이 됩니다.

라이선스는 아직 정하지 않았습니다. 배포 전에 이용 및 재배포 조건을 명시할 예정입니다.

---

<p align="center"><strong>TODO First</strong><br><sub>오늘 할 일, 중요한 것부터.</sub></p>
