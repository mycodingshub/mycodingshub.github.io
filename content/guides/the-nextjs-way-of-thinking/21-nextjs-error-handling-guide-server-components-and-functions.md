---
title: Next.js 에러 핸들링 완벽 가이드 서버 컴포넌트와 서버 펑션
date: 2025-10-26T20:40:16+09:00
description: "Next.js 에러는 서버 컴포넌트와 서버 펑션에서 주로 발생합니다. 서버 컴포넌트 에러는 error.tsx로 UI를 정의하고, 서버 펑션 에러는 throw 대신 반환 값으로 처리하여 사용자 경험을 지키는 방법을 알아봅니다."
tags: ["에러 핸들링", "Next.js", "서버 컴포넌트", "서버 펑션", "error.tsx", "not-found.tsx", "서버 액션"]
weight: 21
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 21
---

Next.js의 에러는 크게 '서버 컴포넌트'와 '서버 펑션' 두 곳에서 발생하는데요.

서버 컴포넌트에서 에러가 나면 `error.tsx`나 `not-found.tsx` 파일로 에러 전용 UI를 보여주고, 서버 펑션에서 발생하는 에러는 기본적으로 '반환 값'으로 표현하는 것이 좋습니다.

### Next.js 에러 핸들링의 복잡성

Next.js의 에러는 '어디서' 발생했는지(클라이언트 or 서버), 그리고 '무슨 작업을 하다가' 발생했는지(데이터 조회 or 수정)에 따라 다르게 접근해야 하는데요.

특히 외부 데이터와 상호작용이 잦은 서버 컴포넌트와 서버 펑션은 에러 발생 가능성이 높아서, 견고한 에러 핸들링이 아주 중요합니다.

참고로, 지금부터 설명할 Next.js의 에러 핸들링 메커니즘은 주로 '서버 사이드'에서 발생한 에러에 대한 것인데요.

클라이언트 사이드에서 발생하는 렌더링 에러는 리액트의 `<ErrorBoundary>`를 사용해 직접 처리해야 합니다.

### 서버 컴포넌트의 에러 처리

Next.js에서는 서버 컴포넌트가 실행되는 도중에 에러가 발생했을 때 보여줄 UI를, 경로(Route Segment) 단위로 `error.tsx`라는 파일에 정의할 수 있는데요.

에러가 발생하면 기존 레이아웃은 그대로 유지된 채, 페이지 영역만 `error.tsx`의 내용으로 대체됩니다.

![Next.js 에러 핸들링 완벽 가이드 서버 컴포넌트와 서버 펑션 - 에러 발생 시 error.tsx UI가 렌더링되는 이미지](https://blogger.googleusercontent.com/img/a/AVvXsEjF4Z7oqzDrHyNx0yL-6FI5aRp-Xvm2nHpa63sln3nb_86q5Jtj7kTYjaqAu6sSAhDMEtWbtpf6JKHtf_AYah6Aw2EZ7crO8FSYm10pIKoM7vNBaIk3bV-BmzFEREKq-LdPK4ZKlzCkxCoR8sfLbGX3yX9jD_qS_-vIgWDctjSTN9AleHvCPZ1ra0wgLoY=s16000)

`error.tsx`는 반드시 클라이언트 컴포넌트로 만들어야 하며, props로 `reset` 함수를 받는데요.

이 `reset` 함수를 실행하면, 에러가 났던 페이지 렌더링을 다시 시도하는, 일종의 '새로고침' 효과를 줄 수 있습니다.

```javascript
"use client";

import { useEffect } from "react";

export default function ErrorPage({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Sentry 같은 에러 로깅 서비스에 에러를 기록합니다.
    console.error(error);
  }, [error]);

  return (
    <div>
      <h2>문제가 발생했습니다!</h2>
      <button type="button" onClick={() => reset()}>
        다시 시도
      </button>
    </div>
  );
}
```

### 404 Not Found 에러 처리

404 에러는 SEO에도 영향을 미치기 때문에 다른 에러들과는 조금 특별하게 취급되는데요.

Next.js에서는 `notFound()`라는 전용 함수를 제공하며, 이 함수가 호출됐을 때 보여줄 UI는 `not-found.tsx` 파일에 정의할 수 있습니다.

### 서버 펑션의 에러 처리

서버 펑션의 에러는 '예측 가능한 에러'와 '예측 불가능한 에러'로 나누어 생각해야 하는데요.

서버 펑션은 주로 데이터 수정을 위한 '서버 액션'으로 사용됩니다.


만약 서버 액션에서 에러를 `throw` 해버리면, 앞서 본 `error.tsx` 화면이 나타나게 되는데요.

이렇게 되면 사용자가 폼에 열심히 입력했던 내용이 모두 사라져서 처음부터 다시 시작해야 하는, 아주 나쁜 사용자 경험으로 이어질 수 있습니다.


따라서, 유효성 검사 실패처럼 '예측 가능한 에러'는 `throw` 하는 대신, 에러 정보를 담은 '객체를 반환'하는 방식으로 처리하는 것이 좋은데요.

이렇게 하면 폼의 상태는 그대로 유지하면서 사용자에게 에러 메시지만 보여줄 수 있습니다.

아래는 `conform` 라이브러리를 사용한 예시인데요.

유효성 검사 에러가 났을 때 `throw` 하지 않고 `submission.reply()`를 반환하는 것이 핵심입니다.

```javascript
"use server";

import { redirect } from "next/navigation";
import { parseWithZod } from "@conform-to/zod";
import { loginSchema } from "@/app/schema";

export async function login(prevState: unknown, formData: FormData) {
  const submission = parseWithZod(formData, {
    schema: loginSchema,
  });

  if (submission.status !== "success") {
    return submission.reply(); // 에러 정보를 담아 반환
  }

  // ...

  redirect("/dashboard");
}
```

만약 별도의 폼 라이브러리를 사용하지 않는다면, 아래처럼 직접 에러 메시지를 담은 객체를 정의해서 반환하면 됩니다.

```javascript
"use server";

export async function login(prevState: unknown, formData: FormData) {
  if (formData.get("email") !== "") {
    return { message: "이메일 주소는 필수 항목입니다." };
  }
  // ...
}
