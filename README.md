# RetroPod Classic (SwiftUI)

iPod 클릭 휠 스타일 iOS 미디어 플레이어. iOS 16+ / Xcode 15+ 기준, **iPhone 17(402×874pt) 전체 화면** 기준으로 본체가 화면을 가득 채웁니다.

## 프로젝트 만들기
1. Xcode → File → New → Project → **iOS App** (Interface: SwiftUI, Language: Swift), 이름 `RetroPod`
2. 자동 생성된 `RetroPodApp.swift`, `ContentView.swift`, `Assets.xcassets`를 지우고 이 폴더의 `.swift` 파일과 `Assets.xcassets` 전체를 프로젝트에 추가
3. Target → General → Deployment Info: **iPhone**, 방향은 **Portrait만** 체크
4. Target → Info(또는 Info.plist)에 키 추가
   - `UIFileSharingEnabled` = YES, `LSSupportsOpeningDocumentsInPlace` = YES (파일 앱에서 RetroPod 폴더에 음원/MV를 넣을 수 있음)
   - `NSLocalNetworkUsageDescription` = "Wi-Fi로 음악 파일을 전송받기 위해 로컬 네트워크를 사용합니다" (Wi-Fi Transfer용, 처음 켤 때 iOS가 권한을 물어봄)
5. Target → Signing & Capabilities → **Background Modes → Audio, AirPlay, and Picture in Picture**
6. (선택) Project → Info → Localizations → **+ Korean** : 파일 선택창, 알림창 등 시스템 문구도 한국어로 표시
7. 실행 (AltStore/SideStore/TrollStore는 빌드한 .ipa를 설치)

## 앱 아이콘 넣기
- `Assets.xcassets/AppIcon.appiconset/` 폴더에 **1024×1024 PNG(투명 배경 없음)** 를 `AppIcon.png` 이름으로 넣으면 됩니다. (Xcode에서 AppIcon 슬롯에 끌어다 놓아도 동일)
- 다크/틴트 아이콘(iOS 18)은 Xcode에서 AppIcon을 열어 해당 슬롯에 따로 넣으면 됩니다.
- Target → General → App Icons Source 가 `AppIcon`인지 확인

## 구현된 기능
- 클릭 휠: 원형 드래그 → 스크롤/볼륨, 햅틱 + 클릭음. 버튼은 이모지 대신 SF Symbols 아이콘(◀◀ ▶▶ ▶‖), MENU만 글자
- iPod 모델 UI 10종 (설정 → iPod Model), 하우징 색상, 디스플레이 테마(흑백/백라이트/컬러)
- **한글 지원**: 설정 → Language에서 한국어/English 전환(기기 언어가 한국어면 기본 한국어). 한글 MP3 태그(CP949)와 `.lrc` 파일(EUC-KR/CP949) 인코딩 깨짐 자동 복구
- 로컬 음원(MP3/FLAC/AAC/WAV…) 가져오기, ID3 메타데이터(제목/아티스트/앨범/커버) 추출
- Now Playing: 앨범 커버, 화면 탭으로 가사 전환 (같은 이름 `.lrc` → 내장 가사 → LRCLIB 순서), 길게 누르면 플레이리스트에 추가
- 플레이리스트: 만들기/이름 변경/삭제, 곡 추가·제거, 전체 재생/셔플. 파일명 기준으로 저장되어 앱을 다시 켜도 유지
- **Wi-Fi Transfer** (설정 → Wi-Fi Transfer): 켜면 `http://<아이폰 IP>:8080` 주소가 표시됨. 같은 Wi-Fi의 PC/폰 브라우저에서 열어 음악·MV·.lrc 파일을 끌어다 놓으면 저장 후 라이브러리에 자동 반영 (외부 라이브러리 없이 Network 프레임워크로 구현, 대용량 파일도 스트리밍 저장)
- Cover Flow, 오프라인 MV 재생 (휠=볼륨, ◀◀▶▶=10초 이동, 센터=재생/정지)

## 아직 비어 있는 부분
- **YouTube 연동**: `StreamResolver.swift`는 자리만 있음 (공식/허용된 출처만 연결 권장)
- 캐시 용량 관리

> 이 코드는 Xcode가 없는 환경에서 작성해 직접 빌드해 보지 못했습니다. 컴파일 오류가 나면 메시지를 알려주세요.
