---
title: Next.js 캐싱 정복 1편 - Full Route Cache와 정적 렌더링
date: 2025-10-26T20:14:00+09:00
description: "Next.js의 4가지 캐시는 성능 최적화의 핵심입니다. 이 글에서는 빌드 시점에 렌더링 결과를 저장하는 정적 렌더링과 Full Route Cache의 원리를 이해하고, revalidate를 통해 최신 상태를 유지하는 방법을 알아봅니다."
tags: ["Next.js", "캐싱", "Full Route Cache", "정적 렌더링", "동적 렌더링", "revalidate", "성능 최적화"]
weight: 13
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 13
---

Next.js에는 총 4개의 캐시 레이어가 존재하는데요.

이 캐시들은 기본적으로 아주 적극적으로 활용되도록 설계되어 있습니다.

- **리퀘스트 메모이제이션 (Request Memoization)**

> 서버에서 요청 단위로 API 응답 등을 재사용하는 캐시입니다.


- **데이터 캐시 (Data Cache)**

> 서버에서 여러 사용자나 배포에 걸쳐 API 응답 등을 재사용하는, 영구적인 캐시입니다.


- **풀 라우트 캐시 (Full Route Cache)**

> 서버에서 렌더링된 HTML과 RSC 페이로드를 저장하는, 영구적인 캐시입니다.


- **라우터 캐시 (Router Cache)**

> 클라이언트에서 RSC 페이로드를 저장해, 페이지 이동 시 요청을 줄이는 캐시입니다.

`리퀘스트 메모이제이션`은 요청 단위로만 동작해서 문제가 되는 경우가 거의 없는데요.

하지만 나머지 세 캐시는 훨씬 더 긴 시간 동안 넓은 범위에 영향을 미치기 때문에, 개발자가 그 원리를 정확히 이해하고 제어하지 않으면 예기치 못한 버그로 이어질 수 있습니다.

이제부터는 이 복잡하고 중요한 Next.js의 캐시에 대해 하나씩 파헤쳐 보겠습니다.

### 정적 렌더링과 풀 라우트 캐시

결론부터 말씀드리면, '정적 렌더링(Static Rendering)'은 빌드 시점에 HTML과 RSC 페이로드의 캐시인 '풀 라우트 캐시(Full Route Cache)'를 생성하는데요.

이 캐시는 짧은 주기로도 쉽게 재검증(revalidate)할 수 있으므로, 사용자 개별 정보가 없는 페이지라면 적극적으로 활용하는 것이 좋습니다.

### 정적 렌더링과 동적 렌더링

과거 페이지 라우터 시절에는 SSR, SSG, ISR이라는 3가지 렌더링 방식이 있었는데요.

앱 라우터에서는 이 개념이 '정적 렌더링'과 '동적 렌더링(Dynamic Rendering)'으로 재정의되었습니다.

**정적 렌더링**: 빌드 시점이나 재검증 후에 렌더링 (SSG/ISR과 유사)

**동적 렌더링**: 사용자 요청 시점에 렌더링 (SSR과 유사)

앱 라우터는 기본적으로 '정적 렌더링'을 사용하며, '동적 렌더링'은 필요할 때 직접 활성화해줘야 하는데요.

동적 렌더링으로 전환되는 조건은 다음과 같습니다.

### 1. Dynamic API 사용

`cookies()`나 `headers()` 같은 Dynamic API를 사용하면 해당 페이지는 동적 렌더링으로 전환됩니다.

### 2. 캐시를 사용하지 않는 fetch()

`fetch()` 함수의 옵션으로 `cache: "no-store"`나 `next: { revalidate: 0 }`을 지정하면 동적 렌더링이 됩니다.

v15부터 `fetch`의 기본 캐시 정책이 변경되었지만, 동적 렌더링으로 바꾸려면 여전히 `"no-store"`를 명시적으로 지정해줘야 한다는 점에 주의해야 합니다.

```javascript
// page.tsx
export default async function Page() {
  const res = await fetch("...", {
    // 동적 렌더링을 위해 "no-store"를 명시해야 합니다.
    cache: "no-store",
  });
  // ...
}
```

### 3. Route Segment Config 설정

`page.tsx`나 `layout.tsx` 파일에서 `export const dynamic = "force-dynamic";` 또는 `export const revalidate = 0;`을 설정해서 동적 렌더링을 강제할 수 있습니다.

### 4. connection() 사용

컴포넌트 내부에서 `headers()`나 캐시 없는 `fetch`를 사용하지 않으면서 동적 렌더링을 강제하고 싶을 때, `connection()` 함수를 사용할 수 있는데요.

주로 '프리즈마(Prisma)' 같은 ORM으로 DB에 직접 접근할 때 유용합니다.

### 정적 렌더링을 적극적으로 활용해야 하는 이유

정적 렌더링은 안정성과 성능 면에서 아주 뛰어난데요.

Next.js는 이 정적 렌더링의 장점을 극대화하기 위해, 렌더링 결과물인 '풀 라우트 캐시'를 아주 유연하게 제어할 수 있는 방법을 제공합니다.

### 필요할 때만 캐시를 갱신하는 '온디맨드 Revalidation'

'서버 액션(Server Actions)'이나 '라우트 핸들러' 안에서 `revalidatePath()`나 `revalidateTag()` 함수를 호출하면, 특정 경로의 풀 라우트 캐시를 원하는 시점에 바로 갱신할 수 있는데요.

데이터가 변경되었을 때 즉시 화면에 반영해야 하는 경우에 아주 유용합니다.

```javascript
"use server";

import { revalidatePath } from "next/cache";

export async function action() {
  // ... 데이터 수정 로직

  revalidatePath("/products");
}
```

### 시간 기반으로 캐시를 갱신하는 'Time-based Revalidation'

`page.tsx`나 `layout.tsx`에서 `revalidate` 옵션을 설정하면, 지정된 시간마다 캐시를 자동으로 갱신하게 할 수 있는데요.

```javascript
// layout.tsx | page.tsx
export const revalidate = 10; // 10초마다 캐시를 갱신
```

이 값을 1초 같은 아주 짧은 시간으로 설정하더라도, 순간적으로 수천 개의 요청이 몰렸을 때 실제 렌더링은 1초에 단 한 번만 일어나게 되거든요.

백엔드 API의 부하를 줄이고 안정적인 성능을 유지하는 데 아주 효과적인 방법입니다.

### 주의해야 할 점

의도치 않은 동적 렌더링 전환은 페이지 전체의 성능 저하로 이어질 수 있거든요.

특히 `cookies()`를 사용하거나, 데이터 캐시를 끈다는 주된 목적 때문에 부수적으로 동적 렌더링이 활성화될 때는 그 영향 범위를 주의 깊게 살펴야 합니다.
