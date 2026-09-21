# 개발 가이드

[← README](../README.md)

## 환경

macOS 14 이상과 Swift 6을 지원하는 Xcode 16 이상을 사용합니다. 현재 빌드 검증 환경은 Xcode 26.5입니다. 외부 라이브러리나 프로젝트 생성 도구 설치는 필요하지 않습니다.

`TODOFirst.xcodeproj`를 열고 `TODOFirst` 스킴 및 `My Mac`을 선택합니다. 앱을 빌드하면 의존성으로 연결된 `TODOFirstWidgets` 확장도 함께 빌드되어 앱에 포함됩니다.

## 개발 서명

저장소 루트에서 개인 설정 예시를 복사합니다.

```sh
cp Configuration/Local.xcconfig.example Configuration/Local.xcconfig
```

`Local.xcconfig`의 `DEVELOPMENT_TEAM`을 본인의 Apple Developer Team ID로 변경합니다. 필요하면 `BUNDLE_ID_PREFIX`도 본인이 사용할 고유 식별자로 변경합니다. 실제 Team ID 확인과 계정 연결은 Xcode의 **Settings → Accounts**에서 진행합니다.

`Local.xcconfig`는 Git에서 제외됩니다. 인증서, 프로비저닝 프로파일, 인증 정보는 저장소에 추가하지 않습니다.

두 타깃 모두 App Sandbox가 활성화되어 있습니다. App Groups 권한과 공유 저장소는 추후 데이터 공유 기능에서 추가할 예정입니다.

## 빌드 검증

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

서명을 생략한 컴파일·패키징 검증입니다. 위젯의 실제 등록, 앱 배포 서명, 공증을 대신하지 않습니다.

현재는 프로젝트 뼈대만 구성되어 있어 자동화된 동작 테스트는 없습니다. 할 일 모델과 저장 로직을 구현할 때 관련 테스트를 추가합니다.

## 위젯 확인

1. 개발 서명을 설정하고 앱을 실행합니다.
2. macOS의 **위젯 편집**을 엽니다.
3. **TODO First**를 찾아 소형 또는 중형 위젯을 추가합니다.
4. 준비 화면이 표시되는지 확인합니다.

실제 등록과 표시는 아직 검증되지 않았습니다. 위젯이 목록에 나타나지 않으면 먼저 앱·위젯의 서명 설정과 설치 상태를 확인합니다. 현재 위젯에는 실제 할 일 데이터가 연결되지 않았습니다.

## 커밋 기준

프로젝트 구성, 로컬 저장, 할 일 편집, 우선순위, 메뉴 막대, 위젯 등 변경 목적별로 커밋합니다. 해당 변경의 빌드·테스트·문서 확인을 마친 뒤 커밋하고, 아직 구현되지 않은 기능을 완료로 표시하지 않습니다.

## 배포 전 작업

- 기능별 동작과 날짜 전환·데이터 보존 검증
- 앱 아이콘과 배포 메타데이터 준비
- App Groups 및 앱·위젯 서명 확인
- Developer ID 서명, 공증과 배포 패키지 준비
- 실제 설치 환경에서 앱 실행·위젯 등록 확인
- 라이선스, 릴리스 노트, 설치 안내 작성

현재 설치용 파일과 정식 릴리스는 제공하지 않습니다.
