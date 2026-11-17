# CourtMate Windows 개발 · 통합 테스트 · 로컬 빌드 실행 가이드

대상: `React 19 + Vite + Python FastAPI + SQLAlchemy/pyodbc + Microsoft SQL Server` 전환본. Windows 11 x64와 PowerShell 5.1/7을 기준으로 작성했습니다. 기존 React UI·대진·통계 기능은 변경하지 않습니다.

> **보안 경고:** 현재 앱에는 로그인 및 역할별 API 권한 검사가 없습니다. 아래는 **개발 PC / 폐쇄형 테스트 환경**을 위한 설정입니다. 인터넷 또는 일반 사내망에 인증 없이 공개하지 마세요. 운영 투입 전 로그인, 인가, HTTPS, DB 계정 권한 최소화, 백업·복원, 로그 점검이 선행되어야 합니다.

## 0. 설치 결과의 최종 구조

| 실행 요소 | 개발 단계 | 로컬 빌드 실행 |
| --- | --- | --- |
| React 화면 | Vite `http://127.0.0.1:5173` | FastAPI `http://127.0.0.1:8000/` |
| Python REST API | `http://127.0.0.1:8000/api/*` | 같은 주소의 `/api/*` |
| API 문서 | `http://127.0.0.1:8000/api/docs` | 동일 |
| SQL Server | `CourtMate` DB, 로컬 또는 별도 SQL Server | 동일 |
| 실행 프로세스 수 | React + Python (2개) + DB | Python (1개) + DB |

개발 시 React는 `vite.config.ts` 설정에 따라 `/api` 요청을 포트 8000으로 프록시합니다. 로컬 빌드 모드에서는 Python이 `dist/`를 직접 제공하므로 별도 웹 서버/프록시가 필요 없습니다.

## 1. 프로그램 설치

1. **Python 3.12 x64** 권장 (3.13도 지원): https://www.python.org/downloads/windows/ . `py -3.12 --version`으로 확인합니다. 설치 방식에 따라 `py` 대신 `python` 명령을 사용합니다.
2. **Node.js LTS x64**: https://nodejs.org/ko/download . 이 프로젝트의 Vite 8은 최근 Node 버전이 필요합니다. 설치 후 `node -v`, `npm.cmd -v`로 확인합니다. Node 24 LTS 이상을 권장합니다.
3. **SQL Server 2019/2022**: 기존 인스턴스를 사용할 수 있습니다. 로컬 신규 설치 시 SQL Server 2022 Express: https://www.microsoft.com/ko-kr/download/details.aspx?id=104781 . 인스턴스 이름을 기록하세요(예: `SQLEXPRESS`).
4. **SQL Server Management Studio (SSMS)**: https://learn.microsoft.com/ko-kr/ssms/install/install . SSMS는 DB 관리 도구이며 SQL Server 엔진과 별도로 설치됩니다.
5. **ODBC Driver 18 for SQL Server x64**: https://learn.microsoft.com/ko-kr/sql/connect/odbc/download-odbc-driver-for-sql-server . *Python API를 실행하는 PC*에 설치합니다.
6. **VS Code**(선택): https://code.visualstudio.com/download , Python/Pylance, ESLint 등 확장 설치.

### 설치 버전 확인

새 PowerShell에서 다음 명령을 실행합니다.

```powershell
py -3.14 --version
node -v
npm.cmd -v
Get-OdbcDriver | Where-Object { $_.Name -like '*ODBC Driver 18*' }
Get-Service | Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' }
```

`py -3.12`가 없다면 `py -3 --version` 또는 `python --version`을 확인합니다. `npm.ps1`이 스크립트 실행 정책에 걸린다면 `npm.cmd`를 사용합니다.

## 2. 프로젝트 ZIP 압축 해제

파일 이름이 `courtmate-react-fastapi-mssql-windows.zip`이라고 가정합니다.

```powershell
New-Item -ItemType Directory C:\Projects -Force | Out-Null
Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\courtmate-react-fastapi-mssql-windows.zip" -DestinationPath C:\Projects
Set-Location C:\Projects\courtmate-react-fastapi-mssql
Get-ChildItem
```

이미 폴더가 있으면 기존 소스·`.env`·DB를 백업하고 새로운 별도 디렉터리에 압축을 풀어 비교하세요. `Expand-Archive -Force`로 무분별하게 덮어쓰지 않습니다. 이후 모든 명령은 위 프로젝트 루트에서 실행하는 것으로 가정합니다.

## 3. SSMS: SQL Server DB 초기화 (최초 1회)

1. SSMS 접속 창에서 서버 이름은 환경에 따라 `.\SQLEXPRESS`, `localhost\SQLEXPRESS`, `localhost`, `(local)` 중 하나입니다. 로컬 개발은 Windows 인증 사용을 권장합니다.
2. 새 쿼리 창에서 데이터베이스를 `master`로 선택하고 `database/00_create_database.sql`을 실행합니다. `CourtMate` DB가 생성됩니다(이미 있으면 생성 생략).
3. **쿼리 창 상단의 데이터베이스 선택을 `CourtMate`로 변경**하고 `database/01_schema.sql` 실행. `members`, `sessions`, `matches`, `match_score_history` 4개 테이블이 생성됩니다.
4. 같은 `CourtMate` DB에서 `database/02_verify.sql` 실행. 테이블 4개와 초기 행 수 0을 확인합니다.
5. PostgreSQL의 실제 운영 데이터가 있다면 **빈 DB 상태에서** `tools/import-legacy-json.py`를 통해 별도로 이관합니다. 소스 ZIP에는 운영 데이터가 없습니다.

### DB 연결 방식 A: Windows 통합 인증 — 로컬 개발에 권장

SQL Server 접속에 사용하는 Windows 계정에 `CourtMate` DB 접근 권한이 있어야 합니다. SSMS에서 같은 Windows 계정으로 접속·DB 조회가 된다면 가장 간단합니다. 다른 계정으로 실행할 경우 DB 사용자 권한을 추가해야 합니다.

`backend/.env`에 다음 **한 줄**을 추가/활성화합니다. `Server`를 실제 인스턴스 명으로 바꾸세요.

```dotenv
MSSQL_ODBC_CONNECTION_STRING=Driver={ODBC Driver 18 for SQL Server};Server=.\SQLEXPRESS;Database=CourtMate;Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;
```

`TrustServerCertificate=yes`는 **로컬 개발 인스턴스가 자체 서명 인증서를 사용하는 경우에만** 사용합니다. 운영 환경은 `TrustServerCertificate=no`와 신뢰 가능한 서버 인증서를 사용해야 합니다. 기존 예제의 `MSSQL_USER`/`MSSQL_PASSWORD`는 이 연결 문자열이 존재하면 무시됩니다.

### DB 연결 방식 B: SQL Server 계정 인증

명명된 인스턴스가 아니라 SQL Server가 `127.0.0.1:1433` TCP에서 서비스 중인 경우 `backend/.env` 값을 아래와 같이 설정합니다.

```dotenv
MSSQL_HOST=127.0.0.1
MSSQL_PORT=1433
MSSQL_DATABASE=CourtMate
MSSQL_USER=courtmate_app
MSSQL_PASSWORD=your-own-strong-password
MSSQL_DRIVER=ODBC Driver 18 for SQL Server
MSSQL_ENCRYPT=yes
MSSQL_TRUST_SERVER_CERTIFICATE=yes
```

- `MSSQL_ODBC_CONNECTION_STRING` 설정을 **주석 처리하거나 삭제**해야 위의 개별 값들이 적용됩니다.
- `courtmate_app` 로그인과 `CourtMate` DB 사용자는 SSMS에서 별도로 생성해야 합니다. 개발용 계정에도 필요한 `db_datareader`, `db_datawriter` 권한만 부여하고 `db_owner`는 피합니다.
- `SQLEXPRESS`는 이름 있는 인스턴스이며 **반드시 포트 1433을 사용하는 것은 아닙니다**. 이 경우 통합 인증 예제처럼 `Server=.\SQLEXPRESS`를 지정하거나 실제 TCP 포트를 확인해서 사용합니다.
- SQL Server Configuration Manager에서 TCP/IP 활성화 또는 포트 변경 시 해당 SQL Server 서비스를 다시 시작해야 할 수 있습니다. 로컬 공유 메모리 연결만 사용한다면 TCP 개방은 불필요합니다. 방화벽 1433 포트를 무조건 열지 마세요.

SQL 인증용 계정을 신규 발급해야 한다면, 관리자 권한이 있는 SSMS에서 아래 SQL의 임시 비밀번호를 **반드시 강력한 값으로 변경한 뒤** 실행할 수 있습니다. 동일 로그인/DB 사용자가 이미 있으면 생성문은 중복 오류가 발생하므로 생략하세요.

```sql
USE master;
GO
CREATE LOGIN [courtmate_app]
WITH PASSWORD = N'REPLACE_WITH_A_LONG_UNIQUE_PASSWORD', CHECK_POLICY = ON;
GO
USE [CourtMate];
GO
CREATE USER [courtmate_app] FOR LOGIN [courtmate_app];
GO
ALTER ROLE db_datareader ADD MEMBER [courtmate_app];
ALTER ROLE db_datawriter ADD MEMBER [courtmate_app];
GO
```

SQL Server 인증이 허용되지 않은 인스턴스라면 Windows 통합 인증을 우선 사용하세요. SQL Server 혼합 인증 모드로 변경하는 것은 관리자의 보안 정책 검토 후 별도로 진행해야 합니다. 위 계정에는 DB 생성·수정(DDL) 권한을 부여하지 않습니다.

### SSL/TLS 인증서 오류 주의

ODBC 18은 기본적으로 암호화를 사용하며 서버 인증서를 검증합니다. 로컬 개발용 자체 서명 인증서라면 인증서 신뢰 오류가 생길 수 있습니다. 폐쇄형 로컬 개발에 한해서 `Encrypt=yes;TrustServerCertificate=yes`를 임시 사용하고, 운영에서는 인증서를 올바르게 구성하세요. `Encrypt=no`로 끄는 방식을 권장하지 않습니다.

## 4. 개발환경 설치 자동화

프로젝트 루트 PowerShell에서 실행합니다.

```powershell
.\windows\00_diagnostics.ps1
.\windows\01_setup_dev.ps1
```

`01_setup_dev.ps1`은 **기존 `.env` 파일을 덮어쓰지 않고**, 없는 경우에만 `backend/.env.example`과 루트 `.env.example`을 복사합니다. Python 가상환경(`backend/.venv`)을 만들고 FastAPI·SQLAlchemy·pyodbc·pytest를 설치하며, React 패키지를 `npm.cmd ci`로 설치합니다.

```powershell
# Python만 준비할 때
.\windows\01_setup_dev.ps1 -SkipNode
# npm 패키지만 설치할 때
.\windows\01_setup_dev.ps1 -SkipPython
```

PowerShell의 `.ps1` 실행이 정책에 의해 제한되면 조직 보안 정책을 우선 확인하세요. 허용되는 개인 개발 PC에서는 현재 PowerShell 프로세스에만 `Set-ExecutionPolicy -Scope Process RemoteSigned`를 적용할 수 있습니다. 스크립트를 쓰지 않아도 아래 수동 명령으로 동일한 작업을 할 수 있습니다.

```powershell
cd C:\Projects\courtmate-react-fastapi-mssql\backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
Copy-Item .env.example .env  # 아직 없다면
cd ..
Copy-Item .env.example .env  # 아직 없다면
npm.cmd ci
```

가상환경 활성화 `Activate.ps1`은 필수가 아닙니다. 스크립트는 `.venv\Scripts\python.exe`를 직접 호출합니다.

## 5. SQL Server 단독 연결 검사

`backend/.env`를 설정한 후, 프로젝트 루트에서:

```powershell
.\windows\08_check_mssql_direct.ps1
```

기대 결과(예시):

```text
[PASS] SQL Server database: CourtMate
```

실패 시 React를 실행하지 말고 ODBC Driver, SQL Server 서비스, 인스턴스 이름, 인증서, 사용자 DB 권한을 우선 점검합니다.

## 6. 개발용 실행 (터미널 2개)

**PowerShell A — FastAPI:**

```powershell
cd C:\Projects\courtmate-react-fastapi-mssql
.\windows\02_start_backend_dev.ps1
```

- FastAPI URL: `http://127.0.0.1:8000/api/health`
- Swagger API 문서: `http://127.0.0.1:8000/api/docs`
- 개발 모드 `--reload`: Python 파일 변경 시 자동 재시작
- 기대 health 응답: `{"ok":true,"database":"connected"}`

**PowerShell B — React:**

```powershell
cd C:\Projects\courtmate-react-fastapi-mssql
.\windows\03_start_frontend_dev.ps1
```

- React UI: `http://127.0.0.1:5173`
- Vite는 루트 `.env`의 `VITE_API_PROXY_TARGET`(기본 `http://127.0.0.1:8000`)으로 `/api` 요청을 전달합니다.
- `VITE_API_BASE_URL`은 로컬 개발/동일 호스트 빌드에서는 **설정하지 않습니다**.
- 종료 시 각 터미널에서 `Ctrl+C`를 누릅니다.

## 7. 로컬 자동 테스트

개발 서버가 없어도 실행 가능한 테스트입니다. 프로젝트 루트의 별도 터미널에서 실행합니다.

```powershell
.\windows\04_run_tests.ps1
```

자동 수행 내용:

1. `backend/.venv/Scripts/python.exe -m pytest -q` — SQLite 테스트 DB에서 FastAPI 13개 테스트 실행
2. `npm.cmd run typecheck` — TypeScript 전체 타입 검사
3. `npm.cmd run build` — React 배포용 `dist/` 생성

기존 검증에서는 **FastAPI 테스트 13개가 통과**했지만 **실제 Windows MSSQL과 전체 npm 빌드는 이전 실행 환경에서 검증하지 못했습니다**. Windows에서 위 명령이 실제로 통과해야 개발 설치가 완료된 것입니다.

API 서버를 켜 둔 상태에서 DB 연결과 조회 API까지 확인하려면:

```powershell
.\windows\04_run_tests.ps1 -CheckLiveApi
# 또는 읽기 전용 API 검사만
.\windows\06_check_api_readonly.ps1
```

## 8. 실제 MSSQL을 사용하는 통합 테스트

**반드시 비어 있거나 폐기 가능한 테스트 데이터베이스를 연결한 후** 아래 순서로 실행하세요. 기존 운영 DB에 테스트 데이터가 삽입되지 않도록 주의하세요.

### 단계 1 — 읽기 전용 API 검사

```powershell
.\windows\06_check_api_readonly.ps1
```

`/api/health`, `/api/members`, `/api/sessions`, `/api/matches`를 조회합니다. 데이터는 수정하지 않습니다.

### 단계 2 — 실제 DB INSERT/UPDATE/DELETE 시험

```powershell
.\windows\07_live_crud_test.ps1 -AllowWrite
```

이 스크립트는 `CMTEST-...` 이름으로 **회원 4명 생성 → 복식 모임 1개 → 경기 1개 → 6:4 점수 입력 → 점수 변경 이력 확인 → 생성한 모임·회원 삭제 시도**를 합니다. 오류가 나도 `finally`에서 정리를 시도하지만 네트워크·DB 오류 때문에 일부 레코드가 남을 수 있으니 결과를 점검하세요. **운영 DB에서는 절대 실행하지 마세요.**

### 단계 3 — React UI 수동 테스트

| 테스트 ID | 사용자 행동 | 기대 결과 |
|---|---|---|
| UI-01 | 홈 접속 | 데이터 로딩 성공, 빈 DB라면 빈 현황 표시 |
| UI-02 | 회원 4명 등록 | 회원 목록/검색에 표시 |
| UI-03 | 회원 정보 변경 | 저장 후 화면과 MSSQL 데이터 일치 |
| UI-04 | 복식 4명 / 1코트 / 1라운드 생성 | 경기 1개 생성 |
| UI-05 | 같은 라운드 선수 중복 대진 저장 시도 | HTTP 400 거부 |
| UI-06 | 같은 코트 중복 저장 시도 | HTTP 400 거부 |
| UI-07 | 점수 6:4 입력 | 승패와 점수 저장 |
| UI-08 | 점수 5:5로 변경 | 무승부, 이력 2건 |
| UI-09 | 점수 0:0 입력 | 미진행으로 통계에서 제외 |
| UI-10 | 승률·승수·득실차 동일 회원 | 공동 순위 표시 |
| UI-11 | 라운드 삭제 | 삭제 및 이후 라운드 번호 정리 |
| UI-12 | 경기/모임 삭제 | 참조 레코드 정리 및 화면 갱신 |

### 단계 4 — MSSQL 데이터 검사

SSMS에서 `CourtMate` DB를 선택하고 다음 SQL을 실행합니다.

```sql
SELECT TOP (20) id, [name], gender, active, joined_at
FROM dbo.members ORDER BY id DESC;

SELECT TOP (20) id, title, play_date, [format], courts
FROM dbo.sessions ORDER BY id DESC;

SELECT TOP (20) id, session_id, [round], court, score_a, score_b, score_version
FROM dbo.matches ORDER BY id DESC;

SELECT TOP (20) match_id, old_score_a, old_score_b,
                new_score_a, new_score_b, old_version, new_version, changed_at
FROM dbo.match_score_history ORDER BY id DESC;
```

주의: 현재 구현에서는 모임/경기를 삭제하면 종속된 `match_score_history`도 함께 삭제됩니다. 중요한 감사 이력을 영구 보존해야 한다면 별도 보존 정책을 먼저 구현하세요.

## 9. 로컬 빌드 실행 — React와 Python을 포트 하나로 실행

이 가이드의 Windows 지원본에는 `SERVE_FRONTEND_DIST=1` 옵션을 추가했습니다. 기존 화면 파일을 수정하지 않고 `dist/`의 정적 파일을 FastAPI가 직접 제공합니다.

1. 실행 중인 개발 서버 두 개를 종료합니다(`Ctrl+C`).
2. **루트 `.env`에 `VITE_API_BASE_URL` 값이 설정되어 있지 않은지 확인**합니다. 이 모드에서는 `/api` 상대 경로가 필요합니다.
3. 빌드 및 API 실행:

```powershell
cd C:\Projects\courtmate-react-fastapi-mssql
.\windows\05_start_built_app_local.ps1 -Rebuild
```

4. 브라우저에서 `http://127.0.0.1:8000/`을 엽니다. 같은 포트의 `http://127.0.0.1:8000/api/health`도 동작해야 합니다.
5. `-Rebuild`를 생략하면 기존 `dist/index.html`이 있을 때 빌드를 생략합니다. 수정한 React 코드를 반영하려면 `-Rebuild`를 사용하세요.

**중요:** 이 구성은 로컬 빌드 검증용입니다. `--host 127.0.0.1`로 실행하여 외부 접근을 막습니다. 실제 조직 운영 서버에는 서비스 관리자/HTTPS 역방향 프록시/로그 수집/DB 백업/접근 통제를 별도로 갖춰야 하며, 인증되지 않은 현재 버전을 공개해서는 안 됩니다.

## 10. 자주 발생하는 오류

| 현상 | 점검 사항 |
| --- | --- |
| `py` 또는 `python`을 찾을 수 없음 | Python 설치/PATH/App Execution Aliases, Python launcher 확인 |
| `npm.ps1 cannot be loaded` | PowerShell에서는 `npm.cmd`로 실행 |
| `npm ci` 실패 | 네트워크/사내 프록시/Node LTS 버전 확인; `package-lock.json`은 보존 |
| `IM002 Data source name not found` | ODBC Driver 18 x64 설치 및 `MSSQL_DRIVER` 정확성 확인 |
| `08001` 또는 서버를 찾지 못함 | SQL Server 서비스, `SQLEXPRESS` 이름, TCP 설정/포트 확인 |
| `Login failed for user` / `18456` | SQL 인증 방식 및 해당 DB 사용자 권한 확인 |
| `certificate chain was issued by ... not trusted` | 로컬 자체 서명 인증서라면 개발용 한정 `TrustServerCertificate=yes`, 운영은 올바른 TLS 인증서 구성 |
| API `/api/health` 500 | DB 연결 오류/계정/방화벽/ODBC 로그 확인; 우선 `08_check_mssql_direct.ps1` 실행 |
| API는 되지만 화면 요청이 500/502 | FastAPI가 실행 중인지, Vite 프록시 포트가 8000인지 확인 |
| `/api/members` 테이블 오류 | `01_schema.sql`이 **CourtMate DB**에 실행됐는지 확인 |
| `5173` 또는 `8000` 이미 사용 중 | 기존 프로세스 종료 또는 해당 포트 설정 변경 |
| 빌드 페이지는 뜨는데 API 오류 | 루트 `.env`의 `VITE_API_BASE_URL` 제거, `-Rebuild` 재빌드 |
| 점수 저장 HTTP `409` | 다른 사용자의 수정으로 버전 충돌 가능; 페이지 새로고침 후 재입력 |
| 인스턴스는 보이지만 원격 TCP 접속 실패 | SQL Server Configuration Manager에서 해당 인스턴스의 TCP/IP 및 포트 확인, 방화벽 최소 개방 |

## 11. 권장 개발 체크리스트

- [ ] Python / Node / SQL Server / ODBC 설치 완료
- [ ] 압축 파일 정상 해제, `README.md` 확인
- [ ] SSMS에서 `CourtMate` DB 및 테이블 4개 생성
- [ ] `backend/.env`는 Git에서 제외, 접속 정보 설정
- [ ] `08_check_mssql_direct.ps1` 통과
- [ ] `02_start_backend_dev.ps1` 실행 및 health 200
- [ ] `03_start_frontend_dev.ps1` 실행 및 React 화면 확인
- [ ] `04_run_tests.ps1` 통과
- [ ] `06_check_api_readonly.ps1` 통과
- [ ] **개발 DB에서만** `07_live_crud_test.ps1 -AllowWrite` 통과
- [ ] React UI 업무 흐름 수동 테스트 통과
- [ ] `05_start_built_app_local.ps1 -Rebuild`로 로컬 빌드 실행 검증
- [ ] 추가 사용자에게 배포 전 인증·인가·HTTPS·백업 정책 확정

## 12. 기존 프로젝트 범위 및 검증 한계

- React 화면, `src/pairing.ts`, `src/stats.ts`는 유지합니다.
- 기존 Hono/PostgreSQL 코드는 `legacy/`에 보관합니다.
- 새 Windows `.ps1` 스크립트는 작성·검토했지만, 이 결과물 작성 환경에는 **Windows/SQL Server/PowerShell**이 없어 Windows 자체 실행을 검증할 수는 없었습니다.
- 기존 Python API 테스트 **13개 통과**(SQLite) 및 FastAPI가 임시 `dist/index.html`을 제공하는 기능 테스트는 실행하여 확인했습니다. 실제 MSSQL 통합 시험, PowerShell 스크립트 실행, Vite 전체 npm 빌드는 사용자 Windows 환경에서 수행해야 합니다.
- `SERVE_FRONTEND_DIST=1`은 로컬 빌드 실행 기능이며, Windows 서비스 등록·IIS HTTPS 배포는 아직 구현하지 않았습니다.
