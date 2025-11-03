---
title: Next.js 'use client' 'use server' 실행 환경이 아니라고?
date: 2025-10-26T19:48:00+09:00
description: use client와 use server는 실행 환경이 아닌 번들 경계선을 선언하는 디렉티브입니다. 이 둘의 정확한 역할과 server-only를 활용해 코드를 안전하게 보호하는 방법을 알아봅니다.
tags: ["Next.js", "use client", "use server", "번들 경계", "서버 컴포넌트", "클라이언트 컴포넌트", "RSC"]
weight: 8
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 8
---

'리액트 서버 컴포넌트(React Server Components, RSC)'의 공식 RFC 문서에는 이런 구절이 있는데요.

"근본적인 과제는, 리액트 앱이 클라이언트 중심이라 서버를 충분히 활용하지 못했다는 점이다."

리액트 코어 팀은 리액트가 가진 여러 문제들을 개별적으로 보지 않고, 근본적으로 '서버를 제대로 활용하지 못하는 것'이 진짜 문제라고 생각했거든요.

그래서 서버 활용과 기존의 클라이언트 중심 리액트를 통합하기 위해 설계된 아키텍처가 바로 리액트 서버 컴포넌트입니다.

'데이터 페칭' 파트에서 살펴봤듯이, 이제 데이터 페칭은 훨씬 더 간단하고 안전하게 컴포넌트 안에 캡슐화할 수 있게 되었는데요.

하지만 컴포넌트 설계 관점에서는 기존의 리액트 컴포넌트와 같은 '클라이언트 컴포넌트'와 새로운 '서버 컴포넌트'를 어떻게 잘 통합해서 사용할지가 중요한 과제로 남아있습니다.

지금부터 시작될 RSC 환경에서의 올바른 컴포넌트 설계 패턴에 대해 알아보겠습니다.

### 클라이언트와 서버의 번들 경계

결론부터 말씀드리면, `'use client'`와 `'use server'`는 코드가 실행되는 환경을 지정하는 게 아니거든요.

이 둘은 번들러에게 '번들 경계선'을 알려주는 아주 중요한 선언입니다.

그리고 서버에서만 사용해야 하는 모듈은, `server-only` 패키지를 사용해 안전하게 보호하는 것이 베스트 프랙티스입니다.

### 왜 이런 개념이 필요할까

RSC는 서버 처리와 클라이언트 처리, 두 단계로 계산이 이루어지는 아키텍처인데요.

이것은 곧 우리가 만드는 코드의 최종 결과물, 즉 번들 파일도 '서버 번들'과 '클라이언트 번들' 두 개로 나뉜다는 것을 의미합니다.

많은 분들이 `'use client'`나 `'use server'` 같은 지시어가 번들과 관련된 중요한 규칙이라는 점은 알고 계시는데요.

하지만 이 지시어들의 진짜 역할에 대해서는 '실행 환경을 지정하는 것'이라고 오해하는 경우가 정말 많습니다.

### 'use client'와 'use server'의 진짜 역할

이 둘은 실행 환경이 아니라 '번들 경계'를 선언하기 위한 것인데요.

정확한 역할은 다음과 같습니다.

**"use client"**: 서버에서 클라이언트로 넘어가는 경계선(Client Boundary)을 만들고, '클라이언트 컴포넌트'를 서버에 노출시키는 역할을 합니다.


**"use server"**: 클라이언트에서 서버로 넘어가는 경계선(Server Boundary)을 만들고, '서버 펑션'을 클라이언트에 노출시키는 역할을 합니다.

바로 이 두 지시어 덕분에, 서버 번들과 클라이언트 번들이 마치 하나의 프로그램처럼 완벽하게 동작할 수 있는 거거든요.

이 둘의 역할을 정확히 이해하는 것이 Next.js를 제대로 사용하는 첫걸음입니다.

### 흔한 오해들 바로잡기

**"서버 컴포넌트에는 'use server'를 붙여야 하나요?"**

아닙니다. `'use server'`는 서버 펑션을 위한 것이지, 서버 컴포넌트를 정의하는 키워드가 아닙니다.

**"그럼 서버 컴포넌트는 어떻게 정의하나요?"**

Next.js에서는 기본값이 서버 컴포넌트이기 때문에, 아무것도 지정하지 않으면 됩니다.

**"클라이언트 컴포넌트 안에서 서버 컴포넌트를 쓰고 싶어요."**

클라이언트 컴포넌트 안에서 서버 컴포넌트를 직접 `import` 할 수는 없는데요.

하지만 `children` props 등을 통해 서버 컴포넌트를 전달받아 렌더링하는 것은 가능합니다.

### 모듈 의존성과 번들 경계

사용자 정보 수정 페이지를 예로 들어보죠.

`page.tsx`가 아래와 같은 파일 의존성을 가지고 있다고 가정해 보겠습니다.

page.tsx

  ├── user-fetcher.ts

  └── user-profile-form.tsx

      └── submit-button.tsx

![Next.js 'use client' 'use server' 실행 환경이 아니라고? - RSC의 번들 경계 다이어그램 1](https://blogger.googleusercontent.com/img/a/AVvXsEhib1m9lCbvWaepl94ZeizLjfcIPJQwhSocvb4lYKUQ6GQt3Hkm3DDZg_neSyDbTMNF75Oa2p5xYyrIUAXrSdw9usbSLoMKMtCVpEGE34T7qvHiNMJESMo67IgCBmShRyELI6VkAZ5rHBkLLKVb_WFQNKWLtwIrXk4MNnoWB1_MXPgubdeahxwH2dxpcf4=s16000)

여기서 `user-profile-form.tsx` 파일 최상단에 `'use client'`를 선언하면, 이 파일은 클라이언트 번들에 포함되는데요.

중요한 점은, 이 파일이 `import`하고 있는 `submit-button.tsx` 역시 `'use client'` 선언이 없더라도 자동으로 클라이언트 번들에 함께 포함된다는 것입니다.

이제 여기에 폼 제출 시 호출될 서버 펑션이 담긴 `update-profile-action.ts` 파일을 추가하면 의존성은 아래와 같이 바뀌는데요.

![Next.js 'use client' 'use server' 실행 환경이 아니라고? - RSC의 번들 경계 다이어그램 2](https://blogger.googleusercontent.com/img/a/AVvXsEgdvvp10mIw8i_JZ8oULFJbgtsDtmpdMfxZeTNCF4hTxIio3fxIdYG2taTzlPJLA2yKjhIPCArz2QAg7hm3R0pO45-4QDpEtMEvxkj4F5cZdbCyYJKGLZfKtYzOe2KintMfrgfQBzPH7w0o3ertGyt5KRkck53pqQIISZKKkimEVZZEPo5_IrHwECF27oM=s16000)

`update-profile-action.ts` 파일 안에 `'use server'`를 선언하면, 클라이언트 번들과 서버 번들 사이에 또 다른 경계가 만들어집니다.

### "두 개의 세계, 두 개의 문"

리액트 코어 팀의 '댄 아브라모프(Dan Abramov)'는 이 개념을 '두 개의 세계, 두 개의 문'이라는 말로 아주 멋지게 설명했는데요.

RSC에는 '서버 번들'과 '클라이언트 번들'이라는 두 개의 세계가 있고, `'use client'`와 `'use server'`는 바로 이 두 세계를 넘나들게 해주는 '문'의 역할을 하는 것입니다.

![Next.js 'use client' 'use server' 실행 환경이 아니라고? - 두 개의 세계, 두 개의 문 비유 그림](https://blogger.googleusercontent.com/img/a/AVvXsEigtrtCKdurwf0hJO--DODJKPxUmt6i4c4ypDFTgH096QFeOCZYMLwUs1ReqJBkzKyJAG4SblxiO-DKQIiwfC0nUoWBXYSEax4DGVFxQL18sdb53Hkt1pFb_WkiJlsUc1AJHlKyJqnqZnPMQeWH7Y2PpdZzNgKIQBsCHvoTGcWloqd9tc7Xk2so5GUfMg0=s16000)

### 주의할 점과 팁

### 파일 단위 'use server'의 위험성

`'use server'`는 함수 단위뿐만 아니라 파일 단위로도 선언할 수 있는데요.

만약 파일 최상단에 `'use server'`를 선언하면, 그 파일에서 `export`하는 모든 함수가 서버 펑션으로 취급되어 외부로 노출될 수 있습니다.

의도치 않게 내부 함수가 API 엔드포인트처럼 공개될 수 있으니, 꼭 필요한 함수에만 개별적으로 선언하는 것이 더 안전합니다.

### server-only로 모듈 보호하기

데이터베이스 접속 로직처럼 서버에서만 실행되어야 하는 민감한 코드가 있을 수 있거든요.

이럴 때는 `server-only` 패키지를 사용해서 해당 모듈을 안전하게 보호할 수 있습니다.

```javascript
import "server-only";

// 이 아래 코드는 서버 번들에만 포함됩니다.
```

이렇게 파일 최상단에 `import "server-only";` 한 줄만 추가하면, 만약 누군가 실수로 이 파일을 클라이언트 컴포넌트에서 `import` 하려고 할 때 빌드 에러가 발생해서 실수를 원천 차단해줍니다.
