---
title: Next.js 데이터 수정 Server Actions 하나로 끝내는 법
date: 2025-10-26T20:23:16+09:00
description: "App Router 시대의 데이터 수정은 Server Actions가 정답입니다. 복잡한 라이브러리 없이 클라이언트와 서버를 넘나들며 데이터를 수정하고, 캐시 revalidate와 효율적인 리디렉션까지 한 번에 처리하는 방법을 알아봅니다."
tags: ["Server Actions", "Next.js", "데이터 수정", "데이터 조작", "revalidate", "RSC", "App Router"]
weight: 16
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 16
---

결론부터 말씀드리면, 앱 라우터 시대의 데이터 '수정' 작업은 '서버 액션(Server Actions)'으로 구현하는 것이 기본이자 정답입니다.

### 과거 방식의 한계

과거 페이지 라우터 시절에는 데이터를 '가져오는' 방법은 공식적으로 제공됐지만, 데이터를 '수정하는' 명확한 방법은 없었거든요.

그래서 SWR이나 리액트 쿼리 같은 서드파티 라이브러리를 사용하거나, API Routes를 활용하는 등 각자 다른 방식으로 데이터 수정 로직을 구현해야 했습니다.

하지만 앱 라우터는 여러 계층의 캐시를 아주 적극적으로 활용하기 때문에, 데이터가 수정되었을 때 이 캐시들을 똑똑하게 갱신(revalidate)해주는 과정이 반드시 필요한데요.

이 때문에 과거의 라이브러리나 구현 패턴들을 앱 라우터에서 그대로 사용하기는 매우 까다로워졌습니다.

### Server Actions가 정답인 이유

앱 라우터에서는 데이터 수정을 위해 '서버 액션'을 사용하는 것이 강력하게 권장되는데요.

서버 액션을 사용하면, tRPC 같은 별도의 라이브러리 없이도 클라이언트와 서버의 경계를 넘어 함수를 아주 쉽게 호출할 수 있습니다.

```javascript
// app/create-todo.ts
"use server";

export async function createTodo(formData: FormData) {
  // ... DB에 데이터를 생성하는 로직
}
```

```javascript
// app/page.tsx
"use client";

import { createTodo } from "./create-todo";

export default function CreateTodo() {
  return (
    <form action={createTodo}>
      {/* ... */}
      <button>Create Todo</button>
    </form>
  );
}
```

위 코드처럼, 서버에서 실행될 `createTodo` 함수를 클라이언트 컴포넌트의 `<form>`에 `action`으로 그냥 넘겨주기만 하면 되는데요.

이 폼이 제출되면 서버에서 `createTodo` 함수가 마법처럼 실행됩니다.

이렇게 간단한 구현만으로도 Next.js가 제공하는 수많은 이점을 누릴 수 있는데요.

어떤 장점들이 있는지 살펴보겠습니다.

### 1. 복잡한 캐시 갱신을 한 번에

데이터가 수정되면 관련된 캐시를 모두 갱신해야 한다고 말씀드렸는데요.

서버 액션 안에서 `revalidatePath()`나 `revalidateTag()`를 호출하면, 서버의 '데이터 캐시'와 '풀 라우트 캐시'는 물론이고 클라이언트의 '라우터 캐시'까지 한 번에 모두 갱신됩니다.

```javascript
// app/actions.ts
"use server";

export async function updateTodo() {
  // ... 데이터 수정 로직
  revalidateTag("todos");
}
```

### 2. 효율적인 리디렉션

데이터를 수정한 뒤 다른 페이지로 이동시키는 경우는 아주 흔한데요.

서버 액션 안에서 Next.js가 제공하는 `redirect()` 함수를 호출하면, 응답에 이동할 페이지의 RSC 페이로드가 함께 포함됩니다.

덕분에 기존처럼 '데이터 수정 요청'과 '다음 페이지 정보 요청'으로 두 번 통신할 필요 없이, 단 한 번의 통신으로 모든 것이 끝나거든요.

사용자 경험을 크게 향상시키는 아주 효율적인 방식입니다.

```javascript
// app/actions.ts
"use server";

import { redirect } from "next/navigation";

export async function createTodo(formData: FormData) {
  // ... 데이터 생성 로직

  redirect("/thanks");
}
```

### 3. 자바스크립트 없이도 동작

서버 액션은 `<form>`의 기본 동작을 활용하기 때문에, 사용자가 브라우저에서 자바스크립트를 껐거나 아직 자바스크립트 파일이 로드되지 않은 상태에서도 완벽하게 동작하는데요.

이것은 웹 접근성을 높이고 초기 입력 지연(FID)을 개선하는 데도 큰 도움이 됩니다.

### 고려해야 할 점들

### 외부에서의 데이터 수정

데이터 수정이 꼭 우리 웹사이트 안에서만 일어나는 것은 아니거든요.

예를 들어, 헤드리스 CMS에서 콘텐츠를 수정했을 때도 Next.js가 가진 캐시를 갱신해줘야 합니다.

바로 이런 경우를 위해 '라우트 핸들러'에서도 `revalidatePath()` 같은 함수를 사용할 수 있는데요.

외부 시스템에서 웹훅(webhook)을 통해 이 라우트 핸들러를 호출하는 방식으로 서버 캐시를 갱신할 수 있습니다.

### 브라우저 '뒤로 가기'와 스크롤 위치

서버 액션에서 `revalidatePath()`를 호출하면 클라이언트의 라우터 캐시가 파괴되는데요.

이 상태에서 사용자가 '뒤로 가기'를 하면, 캐시가 없기 때문에 화면이 즉시 그려지지 않아 스크롤 위치가 초기화되는 문제가 발생할 수 있습니다.

### 동시 실행 불가

서버 액션은 한 번에 하나씩, 순서대로 실행되도록 설계되었는데요.

대부분의 경우에는 문제가 없지만, 만약 서버 액션을 아주 짧은 시간 안에 여러 번 호출해야 하는 특수한 UI를 만든다면 문제가 될 수도 있습니다.
