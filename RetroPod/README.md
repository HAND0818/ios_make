# RetroPod Classic (SwiftUI)

iPod 클릭 휠 스타일 iOS 미디어 플레이어. iOS 16+ / Xcode 15+ 기준.

## 프로젝트 만들기
1. Xcode → File → New → Project → **iOS App** (Interface: SwiftUI, Language: Swift), 이름 `RetroPod`
2. 자동 생성된 `RetroPodApp.swift`, `ContentView.swift`를 지우고 이 폴더의 `.swift` 파일 전부를 프로젝트에 추가
3. Target → Info(또는 Info.plist)에 키 추가
   - `UIFileSharingEnabled` = YES, `LSSupportsOpeningDocumentsInPlace` = YES (파일 앱에서 RetroPod 폴더에 음원/MV를 넣을 수 있음)
4. Target → Signing & Capabilities → **Background Modes → Audio, AirPlay, and Picture in Picture** (화면이 꺼져도 재생)
5. 실행 (AltStore/SideStore/TrollStore는 빌드한 .ipa를 설치)

## 구현된 기능
- 클릭 휠: 원형 드래그 → 스크롤/볼륨, 햅틱(`UIImpactFeedbackGenerator`) + 클릭음, 센터/MENU/⏮⏭⏯ 버튼
- iPod 모델 UI 10종 (설정 → iPod Model), 하우징 색상, 디스플레이 테마(모노/백라이트/컬러)
- 로컬 음원(MP3/FLAC/AAC/WAV…) 가져오기, ID3 메타데이터(제목/아티스트/앨범/커버) 추출
- Now Playing: 앨범 커버, 화면 탭으로 가사 전환 (같은 이름 `.lrc` → 내장 가사 → LRCLIB 순서)
- 플레이리스트: 만들기/이름 변경/삭제, 곡 추가·제거(Add/Remove Songs), Now Playing 화면을 길게 눌러 현재 곡 담기, 전체 재생/셔플. 파일명 기준으로 저장되어 앱을 다시 켜도 유지
- Cover Flow, 오프라인 MV 재생 (휠=볼륨, ⏮⏭=10초 이동, 센터=재생/정지)

## 아직 비어 있는 부분
- **Wi-Fi Transfer**: Swift Package로 GCDWebServer를 추가하고 업로드 파일을 `PlayerStore.docs`에 저장 → `refreshLibrary()` 호출
- **YouTube/YouTube Music**: `StreamResolver.swift`의 프로토콜 구현 (현재는 자리만 있음). 다운로드는 `OfflineCache.save`로 Documents에 저장하면 자동 인식
- 캐시 용량 관리

> 이 코드는 Xcode가 없는 환경에서 작성해 직접 빌드해 보지 못했습니다. 컴파일 오류가 나면 메시지를 알려주세요.
