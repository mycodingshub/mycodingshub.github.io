---
title: Next.js에서 req res 없이 요청과 응답 다루는 법
date: 2025-10-26T20:33:16+09:00
description: "Next.js 서버 컴포넌트에서는 req, res 객체에 직접 접근할 수 없습니다. 대신 params, headers(), cookies() 등 Next.js가 제공하는 전용 API를 사용하여 요청 정보를 안전하게 참조하고 응답을 제어하는 방법을 알아봅니다."
tags: ["Next.js", "서버 컴포넌트", "req", "res", "요청 정보", "응답 조작", "headers"]
weight: 19
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 19
---

Next.js는 기존 웹 프레임워크와는 다른 독특한 특징들이 있는데요.

예를 들어 `req`, `res` 같은 요청/응답 객체에 직접 접근할 수 없거나, 요청 중간에 인증/인가 체크를 끼워 넣는 미들웨어 레이어가 조금 다르게 동작합니다.

지금부터는, 다른 프레임워크와는 다른 Next.js만의 몇 가지 중요한 개발 프랙티스에 대해 알아보겠습니다.

### 요청 참조와 응답 조작

결론부터 말씀드리면, 서버 컴포넌트나 서버 펑션에서는 기존 프레임워크처럼 `req`, `res` 객체를 직접 참조할 수 없거든요.

그 대신, 필요한 정보에 접근할 수 있도록 Next.js가 제공하는 전용 API들을 사용해야 합니다.

### 왜 직접 참조할 수 없을까

과거 페이지 라우터나 다른 웹 프레임워크에서는 `req` 객체에서 쿠키나 헤더 정보를 읽고, `res` 객체로 응답 헤더를 설정하는 방식이 아주 흔했는데요.

하지만 서버 컴포넌트와 서버 펑션의 세계에서는 이런 방식이 더 이상 통하지 않습니다.

### Next.js가 제공하는 새로운 API들

Next.js는 `req`, `res` 객체 대신, 각 목적에 맞는 명확한 API들을 제공하는데요.

어떤 API들이 있는지 하나씩 살펴보겠습니다.

### URL 정보 참조하기

**`params` props**

`/posts/[slug]` 같은 다이나믹 라우트의 URL 경로 정보를 담고 있는 props입니다.


**`useParams()`**

클라이언트 컴포넌트에서 `params`와 동일한 정보에 접근할 때 사용하는 훅입니다.


**`searchParams` props**

`/products?id=1` 같은 URL 쿼리 스트링 정보를 담고 있는 props입니다.


**`useSearchParams()`**

클라이언트 컴포넌트에서 쿼리 스트링 정보에 접근할 때 사용하는 훅입니다.


### 헤더 정보 참조하기

**`headers()`**

서버 컴포넌트 같은 서버 측 처리 과정에서 요청 헤더 정보를 참조할 때 사용하는 함수입니다.


```javascript
import { headers } from "next/headers";

export default async function Page() {
  const headersList = await headers();
  const referrer = headersList.get("referrer");

  return <div>Referrer: {referrer}</div>;
}
```

### 쿠키 정보 참조 및 변경하기

**`cookies()`**

서버 측에서 쿠키 정보를 읽거나 변경할 때 사용하는 함수입니다.

한 가지 중요한 점은, 쿠키를 수정하는 `.set()`이나 `.delete()` 같은 작업은 서버 컴포넌트에서는 불가능하고, 오직 '서버 액션'이나 '라우트 핸들러' 안에서만 사용할 수 있다는 것입니다.

```javascript
// app/actions.ts
"use server";

import { cookies } from "next/headers";

async function create(data) {
  const cookieStore = await cookies();
  cookieStore.set("name", "lee");
  // ...
}
```

### 응답 상태 코드 제어하기

Next.js는 스트리밍을 지원하기 때문에, HTTP 상태 코드를 직접 설정하는 확실한 방법이 없는데요.

그 대신 `notFound()`나 `redirect()` 같은 특수한 함수들을 제공합니다.

이 함수들이 호출되면, Next.js는 응답이 아직 시작되지 않았다면 상태 코드를 설정하고, 이미 응답이 시작되었다면 `<meta>` 태그를 삽입해서 브라우저에게 해당 상태를 전달합니다.


**`notFound()`**: 404 에러를 발생시키고 `not-found.tsx` 파일을 렌더링합니다.

**`redirect()`**: 사용자를 다른 페이지로 리디렉션합니다.

**`permanentRedirect()`**: 영구적인 리디렉션을 수행합니다.

**`unauthorized()`**: 401 인증 에러를 발생시킵니다. (실험적 기능)

**`forbidden()`**: 403 인가 에러를 발생시킵니다. (실험적 기능)

### 알아두면 좋은 점

과거에는 `req` 객체를 확장해서 `req.session` 같은 곳에 사용자 세션 정보를 담아두는 방식이 흔했는데요.

Next.js에서는 이런 방식이 불가능합니다.

대신 `cookies()`를 활용하거나, Redis 같은 별도의 저장소를 이용해 세션 관리 메커니즘을 직접 구현해야 합니다.
