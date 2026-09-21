# TODO First

**오늘 할 일, 중요한 것부터.**

오늘 해야 할 일과 우선순위를 앱, 메뉴 막대, 위젯에서 빠르게 확인하는 macOS 앱입니다.

## 현재 상태

프로젝트 초기 구성 단계입니다. 앱 창, 메뉴 막대 팝오버, 소형·중형 위젯의 기본 화면을 구성했습니다. 화면에는 개발 중임을 표시하며, 실제 할 일 관리와 데이터 공유는 아직 구현하지 않았습니다.

## 개발 환경

- macOS 14.0 이상
- Xcode 16 이상 / Swift 6 (로컬 검증 환경: Xcode 26.5)
- 외부 패키지와 프로젝트 생성 도구 설치 없이 Xcode 프로젝트를 직접 열 수 있습니다.

## 실행

1. `TODOFirst.xcodeproj`를 Xcode에서 엽니다.
2. `TODOFirst` 스킴과 `My Mac`을 선택합니다.
3. 개발 서명이 필요하면 `Configuration/Local.xcconfig.example`을 같은 폴더의 `Local.xcconfig`로 복사하고 `DEVELOPMENT_TEAM`을 자신의 Team ID로 변경합니다. 필요하면 `BUNDLE_ID_PREFIX`도 고유 값으로 변경합니다. 로컬 설정은 Git에서 제외됩니다.
4. Run(⌘R)으로 실행합니다. 앱 창과 메뉴 막대의 체크리스트 아이콘이 표시됩니다.

위젯은 앱에 확장으로 포함됩니다. 서명된 앱을 실행한 뒤 macOS의 **위젯 편집**에서 `TODO First`를 찾아 추가합니다. 위젯의 실제 등록과 표시는 개발 서명 및 macOS 환경에서 별도로 확인해야 합니다. 현재 위젯은 준비 화면만 표시합니다.

### 서명 없이 빌드 검증

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

이 명령은 앱과 포함된 위젯의 컴파일·패키징을 확인합니다. 배포용 서명이나 위젯 등록 검증은 수행하지 않습니다.

## 프로젝트 구조

```text
TODOFirst.xcodeproj/      공유 스킴과 앱·위젯 타깃
TODOFirst/
  App/                   SwiftUI 앱 진입점
  Features/Today/        오늘의 할 일 화면
  Features/MenuBar/      메뉴 막대 빠른 보기
TODOFirstWidgets/        WidgetKit 확장
Shared/                  앱·위젯 공통 코드
Configuration/           공통 빌드 설정 및 개인 서명 예시
```

앱은 SwiftUI와 MenuBarExtra, 위젯은 WidgetKit을 사용합니다. 위젯 타깃은 앱 타깃에 의존성 및 임베드 단계로 연결되어 함께 빌드됩니다. 두 타깃 모두 App Sandbox를 사용합니다. App Groups 권한과 공유 저장소는 데이터 공유 기능을 구현할 때 추가합니다.

## 다음 기능 및 커밋 단위

- [x] macOS 앱·메뉴 막대·위젯 프로젝트 초기 구성
- [ ] 할 일 모델과 로컬 저장
- [ ] 오늘의 할 일 추가·수정·삭제
- [ ] 우선순위 설정 및 정렬
- [ ] 완료 체크와 오늘의 진행 현황
- [ ] 메뉴 막대에서 실제 목록 확인 및 완료 처리
- [ ] App Groups 기반 앱·위젯 데이터 공유
- [ ] 위젯에 중요한 할 일과 완료 현황 표시

프로젝트 구성과 각 기능을 별도 커밋으로 관리합니다. 현재는 실행 뼈대만 있으므로 빌드로 검증하며, 데이터 로직 추가 시 동작 테스트를 함께 구성합니다.
