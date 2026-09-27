# Codex·Claude Code에서 P2J 사용하기

[← README](../README.md)

P2J를 사용하는 **같은 Mac에서 실행되는 Codex 또는 Claude Code**가 대상입니다. 최신 P2J 앱을 한 번 실행하고 Python 3을 준비하세요. 스킬을 웹 채팅에 첨부하는 것만으로 로컬 앱에 연결되지는 않습니다.

## 설치

P2J 저장소 안에서 작업하면 프로젝트 스킬이 이미 들어 있습니다.

| 도구 | 프로젝트 경로 | 직접 호출 |
| --- | --- | --- |
| Codex | `.agents/skills/p2j-control` | `$p2j-control` |
| Claude Code | `.claude/skills/p2j-control` | `/p2j-control` |

두 경로는 같은 `Skills/p2j-control` 폴더를 가리킵니다. 실행 스크립트와 참조 문서를 함께 관리하므로 도구별로 동작이 달라지지 않습니다. Codex 전용 UI 정보는 `agents/openai.yaml`에 있습니다.

다른 프로젝트에서도 쓰려면 저장소 루트에서 개인 스킬로 설치합니다.

```sh
python3 Tools/install-skill both
# 한 도구만 설치: both 대신 codex 또는 claude
```

기본 설치 위치는 Codex `~/.agents/skills/p2j-control`, Claude Code `~/.claude/skills/p2j-control`입니다. 기존 `~/.codex/skills/p2j-control` 설치가 있으면 Codex는 그 위치를 사용해 중복 설치를 피합니다. 이미 설치돼 있다면 `--replace`로 업데이트하세요. 기존 폴더는 스킬 검색 경로 밖의 `p2j-skill-backups`로 백업합니다.

```sh
python3 Tools/install-skill both --replace
```

설치 후 새 세션에서 스킬을 확인하세요. 개인 설치본은 필요한 파일을 모두 포함하므로 저장소를 옮겨도 사용할 수 있습니다. 권한은 각 도구의 기존 승인 설정을 따르며 설치 스크립트가 변경하지 않습니다.

설치 경로와 호출 방식은 [Codex 공식 스킬 문서](https://learn.chatgpt.com/docs/build-skills), [Claude Code 공식 스킬 문서](https://code.claude.com/docs/en/skills)를 기준으로 작성했습니다. 이 스킬의 로컬 앱 연결은 클라우드·원격 세션을 지원하지 않습니다.

## 이렇게 요청하세요

Codex:

```text
$p2j-control 오늘 할 일과 우선순위를 보여줘.
$p2j-control 매일 할 일로 영어 공부 20분을 보통 우선순위로 등록해줘.
```

Claude Code:

```text
/p2j-control 이번 주에 끝낼 포트폴리오 정리를 기간 작업으로 등록해줘.
/p2j-control 영어 공부를 시작했어. 시작을 기록해줘.
```

두 도구 모두 같은 등록·수정·완료·통계 기능을 제공합니다. 이름이 같은 작업은 날짜와 내용으로 구분합니다. 상대 날짜는 Mac의 오전 6시 작업일 기준이며, 날짜 범위가 모호하면 확인한 뒤 등록합니다. 상세 기록 모드에서는 먼저 시작해야 완료할 수 있습니다.

## 연결 확인

저장소 루트에서:

```sh
Tools/p2j doctor
Tools/p2j list
Tools/p2j stats --json '{"days":7}'
```

`doctor`는 토큰 값이나 할 일을 출력하지 않고 준비 상태만 확인합니다. 실제 앱 응답은 `list`로 확인합니다. 성공 응답의 `ok`는 `true`, 실패는 `false`이며 `error`에 설명이 있습니다.

개발 빌드가 여러 개이거나 번들 ID를 바꿨다면 앱과 응답 폴더를 지정하세요. `--app`은 `.app` 경로, `--response-dir`는 **해당 앱이 사용하는** `Application Support/TODOFirst/automation` 폴더입니다. 샌드박스 앱은 앱 컨테이너 아래에 있습니다. 다른 앱의 토큰을 복사하지 마세요.

```sh
Tools/p2j list --app /absolute/path/P2J.app \
  --response-dir /absolute/path/TODOFirst/automation
```

같은 값을 반복해서 쓰면 `P2J_APP`, `P2J_RESPONSE_DIR` 환경변수로 지정할 수 있습니다. 토큰은 환경변수에 넣지 않습니다. 설치된 스킬에서는 `python3 <설치한 스킬 폴더>/scripts/p2j`로 동일한 명령을 실행합니다.

## 직접 명령 실행

오늘 작업은 `startDate`를 생략하면 앱이 현재 작업일을 선택합니다. 먼저 `--dry-run`으로 요청만 확인할 수 있습니다.

```sh
Tools/p2j add --dry-run --json '{"title":"영어 공부 20분","rule":"daily","priority":1}'
Tools/p2j add --json '{"title":"영어 공부 20분","rule":"daily","priority":1}'
```

제목에 따옴표나 셸 기호가 있으면 stdin으로 안전하게 전달하세요.

```sh
Tools/p2j add --json - <<'JSON'
{"title":"포트폴리오의 ‘소개’ 문장 다듬기","rule":"once","priority":0}
JSON
```

명령별 필드, 날짜·시각 형식과 응답은 [요청 규격](../Skills/p2j-control/references/commands.md)을 참고하세요. `update`로 기존 하위 항목의 제목 편집이나 삭제는 지원하지 않습니다. 도구에 없는 작업을 저장 파일 직접 편집으로 우회하지 않습니다.

## 기록과 재시도

- 앱이 요청을 받아 원래 TaskStore로 저장하고 UI·위젯을 갱신합니다. CLI는 `tasks.json`을 직접 수정하지 않습니다.
- 요청은 사용자 전용 토큰과 UUID를 사용합니다. 토큰과 실제 할 일은 저장소에 포함하지 않습니다.
- **시간 초과는 실패 확정이 아닙니다.** 출력된 UUID를 `--request-id`로 재사용해 같은 명령·같은 필드를 한 번 더 보내세요. 새 UUID로 등록을 반복하면 중복 작업이 생길 수 있습니다.
- `complete`·`subtask`는 원하는 완료 상태를 지정합니다. `timing`은 기록 전체를 교체하므로 보존할 시작·종료 시각도 함께 보내야 합니다.
- 상세 모드의 완료 조건을 맞추려고 시작 시각을 임의로 만들지 않습니다. 시작·종료가 모두 있어야 시간 합계·평균에 포함되며, 시간은 휴식을 포함합니다.

CLI와 앱 사이는 로컬 통신입니다. 다만 AI에게 조회 결과를 전달하면 할 일 내용이 해당 AI 서비스의 대화 처리 대상이 됩니다. 민감한 내용을 다룰 때는 사용하는 Codex·Claude의 데이터 처리 설정을 확인하세요.

## 검증

```sh
swift test
python3 -m unittest discover -s Tests/ToolTests -v
```

Swift 테스트는 일정과 자동화의 실제 모델 처리를, Python 테스트는 CLI의 안전한 입력·오류 출력·같은 UUID 재조회·설치 독립성을 검사합니다. 도구 테스트는 임시 폴더와 가상 데이터만 사용합니다.
