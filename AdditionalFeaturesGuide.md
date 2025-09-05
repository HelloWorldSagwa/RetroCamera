# Additional Features Guide for RetroCamera

## Apple에서 제공하는 추가 가능한 기능들

### 1. 📸 **Manual Camera Controls (수동 카메라 제어)**
AVFoundation Framework (iOS 8+)에서 제공

#### Manual Focus (수동 초점)
- `lensPosition` 속성 (0.0 ~ 1.0)
- 0 = 매크로 (가장 가까운 초점)
- 1 = 무한대 (가장 먼 초점)
- 빈티지 카메라의 수동 초점 링 재현 가능

#### Manual Exposure/ISO (수동 노출/ISO)
- ISO 값 직접 제어 (100 ~ 6400+)
- 노출 시간 제어 (Duration)
- 필름 감도 시뮬레이션에 완벽
- 각 필름 타입별 ISO 특성 구현 가능

#### Manual White Balance (수동 화이트 밸런스)
- 색온도 조절 (2000K ~ 10000K)
- Tungsten, Daylight, Fluorescent 프리셋
- 필름별 고유 색감 재현

### 2. 🌀 **Distortion Effects (왜곡 효과)**
Core Image Filters로 빈티지 렌즈 효과 구현

#### CIGlassDistortion
- 유리 렌즈 왜곡 효과
- 오래된 렌즈의 광학적 왜곡 재현

#### CIHoleDistortion
- 구멍/소용돌이 왜곡
- 홀가 카메라 효과

#### CIPinchDistortion
- 핀치 효과 (압축/확장)
- 피쉬아이 렌즈 효과 구현 가능

#### CITorusLensDistortion
- 토러스 렌즈 왜곡
- 독특한 빈티지 렌즈 효과

#### CIVortexDistortion
- 소용돌이 왜곡
- 실험적인 아트 필터

### 3. 🔮 **Blur & Bokeh Effects (블러 & 보케 효과)**

#### CIBokehBlur (iOS 11+)
- 실제 렌즈 보케 효과
- `inputRingSize`: 보케 링 크기 조절
- 빈티지 렌즈의 독특한 보케 재현

#### CIMotionBlur
- 모션 블러 효과
- 카메라 움직임 시뮬레이션
- 각도와 거리 파라미터

#### CIZoomBlur
- 줌 블러 효과
- 카메라 줌 인/아웃 효과
- 다이나믹한 사진 효과

#### CIDiscBlur
- 디스크 모양 블러
- 부드러운 아웃포커스 효과

### 4. 🎨 **Additional Photo Effects**

#### CIPhotoEffectMono
- 저대비 흑백 필름 효과
- 클래식 흑백 사진

#### CIPhotoEffectTonal
- 톤 매핑 효과
- 풍부한 계조 표현

#### CIPhotoEffectNoir
- 고대비 흑백 효과
- 필름 누아르 스타일

#### CISepiaTone
- 세피아 톤 효과
- 강도 조절 가능 (0.0 ~ 1.0)
- 오래된 사진 효과

### 5. 🎯 **Advanced Capture Features**

#### Bracketed Capture
- 한 번에 여러 노출 설정으로 촬영
- HDR 효과 구현 가능
- 필름 브라케팅 시뮬레이션

#### Zero Shutter Lag (iOS 18)
- 셔터 지연 제거
- 즉각적인 촬영 반응

#### Deferred Photo Processing (iOS 18)
- 지연 사진 처리
- 빠른 연속 촬영 가능

### 6. 🌈 **Color & Tone Adjustments**

#### CIColorControls
- 밝기, 대비, 채도 조절
- 이미 구현됨, 더 세밀한 조절 가능

#### CIHighlightShadowAdjust
- 하이라이트/섀도우 개별 조절
- 필름의 다이나믹 레인지 재현

#### CITemperatureAndTint
- 색온도와 틴트 조절
- 이미 구현됨, UI 추가 가능

#### CIVibrance
- 자연스러운 채도 증가
- 피부톤 보호

### 7. 🎭 **Composite & Blend Effects**

#### CISourceAtopCompositing
- 이미지 위에 텍스처 오버레이
- 스크래치, 먼지 효과

#### CIMultiplyBlendMode
- 곱하기 블렌드
- 필름 번 효과

#### CIColorDodgeBlendMode
- 컬러 닷지 블렌드
- 강렬한 빛 효과

### 8. 📱 **User Experience Features**

#### Haptic Feedback
- 셔터 버튼 햅틱 피드백
- 다이얼 조작 촉각 반응

#### Live Photo Support
- 라이브 포토 캡처
- 필터 적용된 라이브 포토

#### Portrait Mode Integration
- 인물 모드와 필터 결합
- 배경 블러 + 필름 효과

## 구현 우선순위 추천

### 🥇 **높은 우선순위** (사용자 경험 크게 향상)
1. **Manual Focus** - 수동 초점 슬라이더
2. **CIBokehBlur** - 보케 효과 조절
3. **Manual ISO** - ISO 감도 직접 제어
4. **CISepiaTone** - 세피아 톤 강도 조절

### 🥈 **중간 우선순위** (차별화 요소)
1. **Lens Distortion** - 렌즈 왜곡 효과 선택
2. **White Balance Presets** - 화이트 밸런스 프리셋
3. **Motion/Zoom Blur** - 특수 블러 효과
4. **Highlight/Shadow Adjust** - 톤 조절

### 🥉 **낮은 우선순위** (고급 기능)
1. **Bracketed Capture** - 브라케팅 촬영
2. **Texture Overlays** - 스크래치/먼지 텍스처
3. **Live Photo with Filters** - 필터 라이브 포토
4. **Custom Blend Modes** - 커스텀 블렌드

## 기술적 고려사항

### 성능
- 실시간 프리뷰는 60 FPS 유지
- 필터 체인 최적화 필요
- GPU 활용 극대화

### 메모리
- 필터 수 증가시 메모리 관리 중요
- 텍스처 캐싱 전략 필요

### 호환성
- iOS 버전별 기능 체크
- 디바이스별 성능 차이 고려

### UI/UX
- 직관적인 컨트롤 배치
- 프리셋과 수동 조절 균형
- 실시간 피드백 제공