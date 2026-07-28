<p align="center">
  <a href="https://app.darkrio326.top/autoledger/">
    <img src="icon.png" width="128" height="128" alt="AutoLedger 아이콘" />
  </a>
</p>

<h1 align="center">AutoLedger</h1>

<p align="center">
  <strong>전 세계 Apple 사용자를 위한 로컬 우선 개인 지출 장부 + 자동 가져오기 + 호텔 폴리오 보관</strong><br/>
  AutoLedger는 Auto+ 제품군의 개인정보 보호 중심, 로컬 우선 개인 지출 장부입니다. 스크린샷, 영수증, 음성, 클립보드, 단축어, 호텔 폴리오 PDF를 검토 가능한 기록으로 정리합니다. 기본 장부 기능은 계속 무료로 제공되며, Pro는 이메일 폴리오, 일괄 후보 처리, 전용 폴리오 수신함 등 시간을 절약하는 자동화 기능을 제공합니다.
</p>

<p align="center">
  <a href="README.en.md">English</a> ·
  <a href="README.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a>
</p>

## 다운로드 및 TestFlight

- **App Store 정식 버전**: [AutoLedger 다운로드](https://apps.apple.com/app/id6761892533)
- **TestFlight 베타**: [AutoLedger Beta 참여](https://testflight.apple.com/join/T3Wu6ngk). 테스트 인원과 사용 가능한 빌드는 Apple TestFlight 페이지의 표시를 기준으로 합니다.

## 라이선스 및 상업적 이용

AutoLedger는 학습, 개인 연구, 보안 검토, 기여를 위해 소스가 공개된 비상업용 라이선스로 제공됩니다. 사전 서면 허가 없이 상업적 이용, 화이트 라벨 배포, SaaS 또는 호스팅 재배포, 수정된 App의 App Store, Google Play, Steam, Microsoft Store, WeChat Mini Program 등 공개 마켓 등록은 허용되지 않습니다.

Pro / IAP / 구독 제한을 제거하거나 우회 또는 변조한 뒤 배포할 수 없습니다. AutoLedger 이름, 아이콘, 스크린샷, 웹사이트 자료, App Store 자료, 결제 화면 artwork, README 이미지는 소스 코드 라이선스에 포함되지 않습니다. 자세한 내용은 [LICENSE](LICENSE)와 [브랜드 자산 안내](docs/operations/brand-assets-notice.md)를 참고하세요.

## AutoLedger를 사용하는 이유

AutoLedger는 수동 입력을 전제로 한 또 하나의 예산 관리 App이 아니며 은행 계좌에 연결하지 않습니다. 스크린샷, 영수증, 구독, 다중 통화 지출, 호텔 폴리오 같은 흩어진 자료를 정리해 반복 입력을 줄이는 데 집중합니다.

분석 결과는 저장 전에 검토하고 수정할 수 있습니다. 개인정보 보호를 중요하게 생각하는 Apple 사용자, 여행자, 반복 작업을 자동화하려는 사용자에게 적합합니다.

Auto+ 원칙, 대상 시장, App Store 방향, 현지화 점검 항목과 코드 구조 위험은 [글로벌 제품 전략](docs/product/GLOBAL_PRODUCT_STRATEGY.md)을 참고하세요.

## 주요 기능

### 빠른 기록

- 스크린샷 및 촬영한 영수증 OCR로 금액, 가맹점, 날짜를 추출합니다.
- 클립보드와 Share Extension으로 다른 App의 결제 화면이나 텍스트를 가져옵니다.
- 음성 장부, Siri / 단축어, App Intent 입력을 지원합니다.
- iPhone 동작 버튼, 제어 센터 Widget, Apple Watch에서 빠르게 기록할 수 있습니다.

### 자동 정리

- 규칙 엔진과 기기 내 LLM으로 일반적인 결제 스크린샷, 영수증, 청구서 텍스트를 분석합니다.
- 분류 학습과 사용자 정의 카테고리 / 출처로 사용자의 수정을 다음 기록에 반영합니다.
- 구독 인식과 알림으로 반복 결제를 관리합니다.
- 월간 보고서에서 카테고리 통계, 지출 추이, 가맹점 순위를 확인합니다.
- 여러 장부, 로컬 장부, 장부 관리, 현재 장부 / 전체 장부 보기, 기본 기록 장부를 지원합니다.
- JSON 내보내기 / 가져오기와 iCloud 동기화 / 백업으로 이전과 복구를 지원합니다.

### 호텔 폴리오 워크플로

- 호텔 폴리오 PDF를 수동으로 가져오고 PDFKit으로 텍스트를 추출한 뒤 검토합니다.
- Pro 사용자는 명시적으로 실행한 로컬 이메일 검색에서 PDF 후보를 선택해 가져올 수 있습니다.
- 전달된 호텔 폴리오 이메일을 위한 Pro 전용 폴리오 수신함을 제공합니다.
- 후보는 저장 전에 검토하며 공식 장부에 자동으로 기록하지 않습니다.
- 호텔, 브랜드 / 그룹, 체크인 / 체크아웃, 숙박일, 비용 항목과 연결 거래를 숙박 기록으로 보관합니다.

## Free / Pro 경계

Free는 일상 장부에 필요한 기능을 계속 제공합니다. AutoLedger는 기존 핵심 기능을 Pro 뒤로 옮기지 않으며, Pro 만료 후에도 사용자의 장부 기록을 잠그지 않습니다.

Free에는 수동 기록, 단일 스크린샷 / 사진 가져오기, 음성 / 텍스트 입력, 호텔 폴리오 PDF 수동 가져오기, 호텔 기록 보기, 기본 구독 관리, 기본 월간 보고서, Widget / Share Extension, JSON 가져오기 / 내보내기, 백업, 기존 기록의 보기 / 수정 / 삭제가 포함됩니다.

Pro의 핵심 메시지는 장부 접근 권한이나 개발자 후원이 아니라 “자동화 기능 잠금 해제”입니다. 현재 Pro에는 로컬 이메일 폴리오 검색, 전용 클라우드 폴리오 수신함, 일괄 후보 가져오기, 고급 중복 제거, 고급 검색, 구독 이상 알림, 월말 내보내기 패키지, 스마트 정리 제안, 고급 규칙 자동 적용, 사용자가 명시적으로 켠 경우 비식별 집계 특성을 이용하는 첫 번째 클라우드 가맹점 별칭 제안이 포함됩니다. 이후에는 통합 검토 대기열, 월말 체크리스트, 규칙 센터, Saved Views, 구독 절약 대시보드, 고급 공유 템플릿과 더 안정적인 기기 간 자동화 동기화를 계속 발전시킵니다.

## 로컬 우선과 클라우드 자동화

AutoLedger는 로컬 우선 App이며 핵심 장부 기능에 계정이 필요하지 않습니다. 클라우드 폴리오 수신함은 선택형 자동화 기능입니다. 사용자가 AutoLedger 전용 주소로 전달한 이메일 첨부 파일만 처리하고, 필요한 동안 원본 PDF를 단기 보관해 검토 가능한 후보를 만듭니다.

App은 저장 전에 사용자의 확인을 요구합니다. 클라우드 자동화는 공식 장부에 거래를 조용히 자동 기록하지 않습니다.

## 호텔 폴리오 가져오기

AutoLedger는 호텔 폴리오를 단일 OCR 금액이 아니라 검토 가능한 숙박 기록으로 정리합니다.

지원하는 가져오기 경로:

- **수동 PDF 가져오기**: 호텔 화면에서 폴리오 PDF를 선택합니다. App이 PDFKit으로 텍스트를 추출하고 호텔 폴리오 인식 및 검토 흐름을 엽니다.
- **AutoLedger로 PDF 공유**: 파일, Mail 또는 다른 App에서 호텔 폴리오 PDF를 AutoLedger로 공유해 대기 중인 호텔 검토 흐름으로 이동합니다.
- **로컬 이메일 검색**: Pro 자동화 경로에서 사용자가 App 안에서 IMAP 이메일을 명시적으로 연결합니다. 인증 코드는 로컬 Keychain에만 저장됩니다. App은 PDF 첨부 파일이 있는 후보 이메일을 보여 주고 사용자가 가져올 파일을 선택합니다.
- **전용 수신함 후보**: Pro 자동화 경로에서 `folio+<token>@getautoledger.app` 주소를 발급받아 호텔 폴리오를 직접 전달하거나 자신의 이메일 전달 규칙을 설정할 수 있습니다. Worker는 단기 PDF 후보만 저장하며, App은 PDF를 내려받은 뒤 로컬에서 텍스트 추출, 인식, 검토를 수행합니다.

인식 대상에는 호텔 이름, 브랜드 / 그룹, 도시 / 국가, 체크인 / 체크아웃 날짜, 숙박일, 객실 유형, 객실 번호, 예약 번호, 통화, 객실료, 세금, 서비스 요금, 식음료, 기타 비용, 총액, 결제 수단, 원본 파일과 인식 신뢰도가 포함됩니다. 확인 후 `HotelStayRecord`를 만들고 기본적으로 호텔 숙박 카테고리의 일반 지출 거래를 연결합니다.

개인정보 보호 경계:

- Worker는 사용자 이메일 계정에 로그인하지 않으며 QQ / IMAP / Gmail / Outlook 인증 코드를 저장하지 않습니다.
- 로컬 이메일 검색은 사용자가 직접 실행할 때만 동작하며, 결과는 확인 전까지 대기 상태로 유지됩니다.
- 전용 클라우드 수신함은 AutoLedger 주소로 전달된 이메일만 처리하며 사용자의 개인 이메일 계정을 검색하지 않습니다.
- 클라우드 PDF 후보는 단기 보관됩니다. App이 PDF를 내려받아 변환한 뒤에는 가능한 경우 클라우드 사본을 삭제합니다.
- 사용자 확인 전에는 공식 장부에 기록하지 않습니다. 호텔 기록과 연결 거래는 App에서 확인, 수정, 삭제할 수 있습니다.

## 개인정보 보호

AutoLedger는 로컬 우선 개인 장부로 설계되었습니다.

- 기본적으로 계정이 필요하지 않습니다.
- 거래 분석은 가능한 경우 기기에서 수행합니다.
- 사용자는 저장 전에 분석 결과를 검토해야 합니다.
- 사용자가 직접 생성한 디버그 또는 피드백 내보내기에는 개인 거래 정보가 포함될 수 있습니다.
- 공개 Issue나 PR에 실제 영수증, 결제 스크린샷, 청구서 또는 개인 금융 정보를 올리지 마세요.

App은 선택형 로컬 모델과 StoreKit 기능을 포함합니다. 스토어 메타데이터, 서명 자격 증명과 프로덕션 계정 설정은 이 저장소의 공개 구성과 다를 수 있습니다.

## 스크린샷 미리보기

App Store 스크린샷 파이프라인은 [tools/appstore-screenshots/README.md](tools/appstore-screenshots/README.md)를 참고하세요.

로컬 미리보기를 새로 만들려면 `bash tools/appstore-screenshots/scripts/export.sh`를 실행한 뒤 생성된 `tools/appstore-screenshots/output/preview.html`을 여세요.

## 현지화 및 인식 언어 팩

AutoLedger는 App UI 현지화와 영수증 / 청구서 인식 언어 팩을 별도 계층으로 관리합니다.

- **App UI 언어**: 주요 사용자 경로는 `zh-Hans` 간체 중국어, `zh-Hant` 번체 중국어, `en` 영어, `ja` 일본어, `ko` 한국어를 지원합니다. Main App, Watch, Widget, Control Widget, Share Extension의 키 집합은 `scripts/check_localization_coverage.py`로 검사합니다.
- **App Store 스크린샷 언어**: 스크린샷 파이프라인은 iPhone, iPad, Mac, Apple Watch, Apple TV, visionOS용 `zh-Hans` / `zh-Hant` / `en` / `ja` / `ko` 문구를 관리합니다.
- **인식 언어 팩**: `AutoLedgerCore`에는 `zh-Hans`, `zh-Hant`, `en`, `ja`, `ko` 팩이 내장되어 영수증 키워드, 금액과 날짜 형식, 계층형 금액 라벨, 가맹점 라벨, 가맹점 제외어, 카테고리 키워드, OCR 언어 힌트를 제공합니다.
- **한국어 지원**: 한국어 App UI와 `ko` 인식 팩은 ASC `1.6.0`에서 정식 출시되었습니다. `₩` / `원` / `KRW`, 합계, 세금, 가맹점, 카테고리, `ko-KR + en-US` OCR 힌트를 지원합니다. 실제 한국 영수증과 결제 알림, 카드 전표, 호텔 폴리오, 지역별 표현과 모국어 검토는 출시 후 품질 개선으로 계속 보강합니다.
- **출시 기준과 확장 순서**: [현재 출시 매트릭스](versions/v1.7.0-i18n-release-matrix.md)는 스토어, UI, 인식 팩, 현실적인 샘플, 지역 영수증, 사람 검토 상태를 관리합니다. [버전 간 언어 로드맵](docs/product/I18N_ROADMAP.md)은 각 공개 기능 버전에 새 언어 또는 지역 그룹을 배정합니다.
- **영어 기본 언어**: ASC `1.6.0`부터 엔지니어링 fallback과 App Store Primary Language는 영어를 기준으로 합니다. Xcode `developmentRegion = en`과 ASC `English (U.S.) / en-US`는 별도 증거로 확인합니다.
- **다음 품질 그룹**: `v1.8.0`은 Early Execution 단계에서 미국, 영국, 캐나다, 호주, 싱가포르 영어 시장을 검증하며 UI 언어를 추가하지 않습니다. 다음 단계에서는 일본어 품질을 높이고 독일어와 프랑스어를 추가하며, 스페인어와 브라질 포르투갈어는 이후 후보로 유지합니다.
- **확장 원칙**: 이후 언어 팩은 순수 데이터, 버전 관리, 검토 가능, fallback 가능 구조를 유지합니다. 사용자 수정 공유는 opt-in, 비식별, 철회 가능해야 하며 검토 후에만 reviewed pack에 포함될 수 있습니다. 현재 저장소는 원격 언어 팩 hot update나 자동 업로드를 구현하지 않습니다.

## 기술 스택

| 계층 | 기술 |
|---|---|
| UI | SwiftUI, iOS 17+ deployment target, Xcode 27 / iOS 27 SDK adaptive layout |
| OCR | Apple Vision (`VNRecognizeTextRequest`) |
| 분석 | 규칙 엔진 + LLM (`SmartReceiptParser`) |
| LLM | Apple Foundation Models / Gemma-2 2B (MediaPipe LLM Inference) |
| 모델 배포 | Cloudflare R2 CDN + SHA-256 (CryptoKit) |
| 저장소 | SQLite (로컬) |
| 구조 | MVVM + 생성자 기반 의존성 주입 |
| 의존성 관리 | CocoaPods (MediaPipe), SPM (`AutoLedgerCore`) |
| 단축어 | AppIntents / `ForegroundContinuableIntent` |
| 공유 | Share Extension |
| Watch | watchOS 10+, WatchConnectivity |
| Widget | WidgetKit (홈 화면 및 제어 센터) |
| CI | Xcode Cloud |

## 빌드

환경 요구 사항:

- Xcode 27 beta
- Swift 6 / SwiftUI
- CocoaPods
- Main App은 iOS 17 이상
- Watch App은 watchOS 10 이상

```bash
# CocoaPods 의존성 설치
cd AutoLedger
pod install

# 반드시 workspace로 빌드
xcodebuild -workspace AutoLedger.xcworkspace \
  -scheme AutoLedger \
  -destination 'generic/platform=iOS' \
  build

# 저장소 루트에서 회귀 테스트
cd ..
bash scripts/run_offline_regression.sh
bash scripts/run_golden_regression.sh
```

다중 target 서명을 위해 iOS App, Apple Watch App, Share Extension, Widget Extension에 각각 자신의 Bundle ID를 설정하고 App Groups와 iCloud Containers도 자신의 계정에 맞게 구성해야 합니다.

## 프로젝트 구조

```text
AutoLedgerRio/
├── AutoLedger/                    # Xcode 프로젝트
│   ├── AutoLedger/                # Main iOS / iPadOS / Mac Catalyst App
│   ├── AutoLedgerCore/            # Foundation 전용 로컬 Swift Package
│   ├── AutoLedgerWatch Watch App/ # Apple Watch App
│   ├── AutoLedgerWidgets/         # iOS Widget Extension
│   ├── ControlWidgetExtension/    # 제어 센터 Widget Extension
│   ├── ShareExtension/            # Share Extension
│   ├── AutoLedgerTV/              # tvOS 읽기 전용 대시보드
│   └── AutoLedgerVision/          # visionOS 쇼케이스
├── docs/                          # 제품, 설계, 운영 문서
├── process/                       # 반복 작업 흐름과 로그
├── scripts/                       # 로컬 회귀 및 smoke
├── tests/                         # Golden 회귀 fixture
├── tools/appstore-screenshots/    # App Store 스크린샷 파이프라인
├── tools/worker/                  # Worker / 원격 기능
└── versions/                      # 버전 계획과 출시 기준
```

## 저장소 상태

이 저장소는 공개 소스 배포를 위해 정리되어 있습니다. App Store 버전은 이 저장소의 공개 구성과 다른 서명, entitlement, Xcode Cloud, StoreKit, 스토어 메타데이터 설정을 사용할 수 있습니다.

`main` 브랜치는 실제 AutoLedger 개발 및 출시 브랜치로 유지됩니다. 공개용 정리를 이유로 Xcode workspace, scheme, target, Bundle Identifier, entitlement 또는 Xcode Cloud 스크립트 이름을 변경해서는 안 됩니다.

## 로드맵

현재 출시 단계와 gate는 [PROJECT_STATUS.md](PROJECT_STATUS.md), 제품 방향은 [docs/ROADMAP.md](docs/ROADMAP.md), 버전별 언어 그룹과 진입 기준은 [docs/product/I18N_ROADMAP.md](docs/product/I18N_ROADMAP.md)를 기준으로 합니다. 아래 내용은 공개용 요약입니다.

현재 주요 상태:

- `v1.6.0`과 `v1.6.1`은 완료되었으며 ASC / App Store `1.5.0` 출시 라인에 포함됩니다.
- App Store `1.4.0`은 출시되었고 내부 `v1.5.1`이 해당 라인의 최종 마무리 버전입니다.
- `v1.6.2`는 SDK 적응 2단계, 호텔 이메일 가져오기, Deep link / Widget / App Intents, 데이터 신뢰성, 일본어 출시 자료 검토를 완료했습니다.
- `v1.6.3`은 호텔 C1 전용 폴리오 수신함의 첫 App/Core 골격, 검토 설명, 회귀 baseline을 완료했습니다.
- `v1.6.4`는 ASC / App Store `1.5.0` 마무리 baseline으로 완료되었으며 Free / Pro 경계, Pro 구독 기반, 클라우드 폴리오 수신함과 관련 출시 기준을 확정했습니다.
- `v1.7.0 / ASC 1.6.0`은 정식 출시되었습니다. 실시간 OCR, 한국어 UI와 `ko` 인식, i18n 출시 매트릭스, `common-api`, App Store Server Notifications, ASC metadata-as-code, Pro 자동화, 첫 번째 hash-only 클라우드 가맹점 별칭 제안, 공유 카드, 호텔 여행 기록, 개인정보 보호형 분석을 포함합니다.
- `v1.8.0 / ASC 1.7.0`은 Early Execution 단계에서 Review & Close, 이해하기 쉬운 동기화 상태, 월말 마감, 영어 5개 시장 품질을 진행합니다.

| 내부 버전 | App Store | 상태 | 주요 내용 |
|---|---|---|---|
| v1.5.0 | 1.4.0 | 1.4.0 출시에 포함 | iPad 작업 공간, 일괄 가져오기 / 인식, 데이터 정리, 기본 다중 기기 동기화, Watch complication, Mac Catalyst |
| v1.5.1 | 1.4.0 | 출시됨 | 낮은 배포 대상, Core 분석 리팩터링, 편집 저장 안정성, iCloud 동기화 성능, 현재 플랫폼 스크린샷 |
| v1.6.0 | 1.5.0 | 완료 | 구독 관리, 학습 cache, tvOS / visionOS, 전체 플랫폼 build / TestFlight / ASC / schema / 스크린샷 마무리 |
| v1.6.1 | 1.5.0 | 완료 | 호텔 폴리오 보관, 기본 다중 장부, 일본어 현지화, App Icon 재작업, iOS 27 적응형 레이아웃 1단계 |
| v1.6.2 | 1.5.0 기본 유지 | 완료 | SDK 적응 2단계, 호텔 이메일 초안 대기열, Deep link, Widget / App Intents, 데이터 신뢰성, 일본어 출시 자료 |
| v1.6.3 | 1.5.0 기본 유지 | 완료 | 호텔 C1 전용 폴리오 수신함 App/Core 골격, 클라우드 후보 모델, deep link, PDFKit 로컬 변환, 회귀 baseline |
| v1.6.4 | 1.5.0 기본 유지 | 완료 | Personal Pro 기반, Free / Pro 경계, 전용 수신함 Worker, D1/R2/Queue, 클라우드 후보 API, 출시 마무리 |
| v1.7.0 | 1.6.0 | 출시됨 | 실시간 OCR, 5개 언어 UI / 인식, `common-api`, 서버 구독, ASC metadata-as-code, Pro 검색 / 구독 이상 / 월말 ZIP / 고급 규칙 / 스마트 정리, hash-only 클라우드 별칭, 공유 카드와 출시 분석 |
| v1.8.0 | 1.7.0 | Early Execution | 영속 대기 항목, 이해 가능한 동기화 상태, 월말 마감, 영어 5개 시장의 형식 / 스토어 / 개인정보 보호 / 실제 기기 검증 |

## 라이선스

소스 코드는 source-available 비상업용 라이선스로 제공됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요. 학습, 연구, 기여에는 사용할 수 있지만 승인 없는 상업적 이용, 화이트 라벨 배포, 공개 마켓 재배포, 호스팅 서비스 또는 Pro / IAP / 구독 제한을 우회한 배포는 허용되지 않습니다.

AutoLedger 이름, App 아이콘, App Store 스크린샷, 마케팅 자료와 브랜드 자산은 소스 코드 라이선스에 포함되지 않으며 관련 권리는 저작권자에게 있습니다.
