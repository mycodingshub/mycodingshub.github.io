---
title: Next.js 서버 컴포넌트의 숨겨진 원칙 순수성과 메모이제이션
date: 2025-10-26T20:26:16+09:00
description: "React 컴포넌트는 순수해야 합니다. 서버 컴포넌트 역시 마찬가지로, Next.js는 Request Memoization과 React.cache를 통해 데이터 페칭이라는 부수 효과를 제어하고 렌더링의 일관성을 보장합니다."
tags: ["서버 컴포넌트", "순수성", "메모이제이션", "Next.js", "RSC", "Request Memoization", "React.cache"]
weight: 17
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 17
---

기존 페이지 라우터는 SSR, SSG, ISR이라는 3가지 렌더링 모델을 지원했는데요.

앱 라우터 역시 이 방식들을 계속 지원하지만, 여기에 '스트리밍 SSR(Streaming SSR)'까지 지원한다는 점에서 아주 큰 차이를 보입니다.

지금부터는 리액트와 Next.js 렌더링의 핵심 철학에 대해 알아보겠습니다.

### 서버 컴포넌트의 순수성

리액트 컴포넌트의 렌더링은 '순수(pure)'해야 한다는 아주 중요한 원칙이 있거든요.

이 원칙은 서버 컴포넌트에도 똑같이 적용되며, 데이터 페칭을 '메모이제이션(memoization)'해서 순수성을 지킬 수 있습니다.

### 왜 '순수성'이 중요할까

리액트는 아주 오래전부터 컴포넌트가 '순수'해야 한다는 점을 강조해왔는데요.

리액트의 가장 큰 특징 중 하나인 '선언형 UI'도 바로 이 컴포넌트의 순수성을 전제로 하고 있습니다.

하지만 웹 UI를 만들다 보면 어쩔 수 없이 다양한 '부수 효과(side effects)'가 발생하기 마련이거든요.

그래서 클라이언트 컴포넌트에서는 `useState()`나 `useEffect()` 같은 훅을 사용해 이런 부수 효과를 격리시키고, 컴포넌트 자체의 순수성을 지키도록 설계되어 있습니다.

리액트 18에 도입된 '동시성 렌더링(Concurrent Rendering)' 기능 역시 컴포넌트의 순수성을 전제로 하는데요.

![Next.js 서버 컴포넌트의 숨겨진 원칙 순수성과 메모이제이션 - 부수 효과가 있는 렌더링과 순수한 렌더링의 병렬 처리 비교](https://blogger.googleusercontent.com/img/a/AVvXsEhvvju0dCfZzW3ipqNIZV6Hijei1wZ5N82v2ZrRPf_XfS0KKhOlH_Mr-R_KJOn4fXah1cwRY0JTg1dVrTFHtlHZD-VvAYFgwca-OBkwaN-E_yQ-Vb6k1CNbGaDHfuKN3JAgBmEng2R6sv5aaB9FBAk9FsR6WKdE-BuaE4h-y4IEpW0r79f83tIIIPeyWJ4=s16000)

부수 효과가 포함된 렌더링을 병렬로 처리하면 그 결과를 예측할 수 없게 되지만, 순수한 렌더링은 병렬로 처리해도 항상 동일한 결과를 보장하기 때문입니다.

### RSC 시대의 순수성

RSC에서도 컴포넌트의 순수성은 여전히 아주 중요한데요.

Next.js 역시 이 원칙에 따라 다양한 API들을 설계했습니다.

### 데이터 페칭의 일관성

데이터 페칭은 사실 순수성을 해치는 대표적인 작업 중 하나인데요.

호출할 때마다 다른 값을 반환하거나, 아예 실패할 수도 있기 때문입니다.

```javascript
async function getRandomTodo() {
  // 요청마다 랜덤한 Todo를 반환하는 API
  const res = await fetch("https://dummyjson.com/todos/random");
  return (await res.json()) as Todo;
}
```

Next.js는 '리퀘스트 메모이제이션(Request Memoization)'을 통해 동일한 입력에 대한 출력을 항상 같게 유지해주거든요.

이를 통해 데이터 페칭을 지원하면서도, 렌더링 범위 내에서는 컴포넌트의 순수성을 지킬 수 있도록 설계되어 있습니다.

```javascript
export default function Page() {
  // getRandomTodo()는 한 번만 실제로 호출되고 그 결과가 메모이제이션됩니다.
  // 따라서 <ComponentA>와 <ComponentB>는 항상 같은 Todo를 표시합니다.
  return (
    <>
      <ComponentA />
      <ComponentB />
    </>
  );
}
```

### `cache()`를 이용한 메모이제이션

리퀘스트 메모이제이션은 `fetch()` 함수에만 적용되는데요.

DB 접근처럼 `fetch()`를 사용하지 않는 데이터 페칭 작업의 순수성은 '리액트 캐시(React.cache())'를 이용해 지킬 수 있습니다.

```javascript
export const getPost = cache(async (id: number) => {
  const post = await db.query.posts.findFirst({
    where: eq(posts.id, id),
  });

  if (!post) throw new NotFoundError("Post not found");
  return post;
});
```

페이지 전체에서 딱 한 번만 호출되는 데이터 페칭이라면 굳이 `cache()`로 감쌀 필요가 없다고 생각할 수도 있는데요.

하지만 저는 기본적으로 항상 메모이제이션을 해두는 것을 추천합니다.

나중에 이 함수가 여러 번 호출되도록 코드가 바뀌었을 때 발생할 수 있는 잠재적인 버그를 미리 막아주기 때문입니다.

### 쿠키 조작

Next.js에서 쿠키를 조작하는 것 역시 대표적인 부수 효과 중 하나인데요.

그래서 서버 컴포넌트에서는 쿠키를 수정하는 `.set()`이나 `.delete()` 같은 메서드를 직접 호출할 수 없습니다.

이런 작업은 반드시 '서버 액션' 안에서 처리해야 합니다.

### 알아두면 좋은 점

'리퀘스트 메모이제이션'은 `fetch()` 함수를 확장해서 구현되어 있는데요.

현재 이 확장 기능을 완전히 끄는 공식적인 방법은 없습니다.

하지만 아래처럼 `fetch()`에 전달되는 인자를 매번 다르게 만들어주면, 메모이제이션을 우회해서 항상 새로운 데이터를 가져오게 할 수는 있습니다.

```javascript
// 쿼리 문자열에 랜덤한 값을 추가
fetch(`https://.../random?_hash=${Math.random()}`);

// 매번 새로운 AbortSignal을 전달
const controller = new AbortController();
const signal = controller.signal;
fetch(`https://.../random`, { signal });
```
