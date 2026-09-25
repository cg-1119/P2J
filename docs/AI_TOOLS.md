# AI와 CLI에서 P2J 사용하기

P2J를 실행한 뒤 저장소 루트의 `Tools/p2j`를 사용합니다. Python 3이 필요하며 외부 패키지는 없습니다.

```sh
Tools/p2j list
Tools/p2j stats --json '{"days":30}'
Tools/p2j add --json '{"title":"포트폴리오 정리","rule":"period","startDate":"2026-09-25","endDate":"2026-09-30","subtasks":["소개 작성","화면 정리"]}'
```

개발 빌드는 `xcodebuild`의 `-derivedDataPath`로 지정한 폴더 아래 `Build/Products/Debug/P2J.app`에 있습니다. 해당 경로를 `--app`에 전달하면 이전 앱이 URL을 받는 일을 피할 수 있습니다. 앱을 새 버전으로 재실행해야 API가 연결됩니다.

[스킬과 전체 요청 규격](../Skills/p2j-control/SKILL.md)을 참고하세요. `Skills/p2j-control` 폴더를 Codex의 skills 디렉터리에 복사하면 `$p2j-control`로 사용할 수 있습니다. 설치된 스킬은 동봉된 스크립트를 사용하므로 저장소 위치에 의존하지 않습니다. 새 스킬은 다음 세션에서 검색될 수 있습니다.

도구는 `p2j://automation` URL로 요청하고 앱이 원래 TaskStore를 통해 저장·위젯 갱신을 처리합니다. 앱만 원본 데이터를 수정하므로 동시에 앱을 조작해도 파일 덮어쓰기 경쟁을 피합니다. 앱은 사용자 전용 `automation-token`을 생성하고, 인증된 요청만 처리합니다. 토큰이나 실제 할 일 데이터는 Git에 포함하지 않습니다. 응답은 같은 저장 폴더의 `automation/<요청 UUID>.json`에 남습니다.

요청은 UUID로 중복 실행을 방지하며 `complete`·`subtask`는 명시적인 상태 설정입니다. 시간 초과는 실패 확정이 아니므로 같은 UUID로 재조회합니다. 수정 요청은 제목 UUID를 목록에서 확인한 뒤 보냅니다. `timing`은 해당 기록 전체를 교체하므로 생략 필드의 의미에 주의하세요.
