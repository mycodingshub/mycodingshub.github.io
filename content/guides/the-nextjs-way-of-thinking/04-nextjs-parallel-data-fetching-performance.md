---
title: Next.js 데이터 fetching 병렬 처리로 성능 극대화하는 3가지 방법
date: 2025-10-26T19:21:00+09:00
description: 데이터 페칭 워터폴은 성능 저하의 주범입니다. Next.js에서 컴포넌트 분리, Promise.all, preload 패턴을 활용하여 데이터 요청을 병렬로 처리하고 사용자 경험을 극적으로 개선하는 3가지 방법을 알아봅니다.
tags: ["Next.js", "데이터 페칭", "병렬 처리", "성능 최적화", "워터폴", "preload 패턴", "서버 컴포넌트"]
weight: 4
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 4
---

결론부터 말씀드리면, 데이터 페칭을 최대한 '병렬'로 처리되도록 설계해야 하는데요.

이를 위해 상황에 맞게 아래 세 가지 패턴을 자유자재로 사용할 줄 알아야 합니다.

바로 '컴포넌트 분리', '병렬 fetch()', 그리고 'preload 패턴'입니다.

### 왜 병렬 처리가 중요할까

데이터끼리 서로 의존성이 있다면 어쩔 수 없이 순서대로 요청하는 '워터폴(waterfall)' 방식으로 처리해야 하거든요.

하지만 의존 관계가 없다면, 요청을 병렬로 처리해서 엄청난 성능 향상을 얻을 수 있습니다.

![Next.js 데이터 fetching 병렬 처리로 성능 극대화하는 3가지 방법 - 데이터 페칭 워터폴과 병렬 처리 속도 비교](https://blogger.googleusercontent.com/img/a/AVvXsEhDD-7i0IWiNlcVcNpEvrpjtM0H4UaMVqzMpkWlfM9BlSgw9jE70wUclAd0ee0Di94lrIBsVD8muDOa1V-74U23y1AnjmIpzUY0KDf8ekPzGziOv-GYxqxs8YKKyArBP_U0igPgHOIBybX0QM3uKN9yp5O33Zz5iKMB-kG_Xuv5gKNvnNQbQpKIdZ69vN8=s16000)

위 그림은 Next.js 공식 문서에도 나와 있는 이미지로, 병렬화가 얼마나 속도 개선에 효과적인지 한눈에 보여줍니다.

### 첫 번째 방법 데이터 페칭 단위로 컴포넌트 쪼개기

Next.js에서 데이터 페칭을 병렬화하는 가장 기본적이면서도 최고의 방법은, 데이터 페칭 단위로 컴포넌트를 잘게 쪼개는 건데요.

비동기 컴포넌트들이 서로 '형제 관계'이거나, '형제의 자손 관계'에 놓여있으면 병렬로 렌더링이 되기 때문입니다.

```javascript
function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return (
    <>
      <PostBody postId={id} />
      <CommentsWrapper>
        <Comments postId={id} />
      </CommentsWrapper>
    </>
  );
}

async function PostBody({ postId }: { postId: string }) {
  const res = await fetch(`https://dummyjson.com/posts/${postId}`);
  const post = (await res.json()) as Post;
  // ...
}

async function Comments({ postId }: { postId: string }) {
  const res = await fetch(`https://dummyjson.com/posts/${postId}/comments`);
  const comments = (await res.json()) as Comment[];
  // ...
}
```

위 코드에서 `<PostBody />`와 `<Comments />`는 서로 병렬로 렌더링되거든요.

결과적으로 각 컴포넌트 안에서 일어나는 데이터 페칭도 자연스럽게 병렬로 처리됩니다.


### 두 번째 방법 병렬 fetch() 활용하기

데이터 간 의존성은 없지만, 로직상 하나의 컴포넌트 안에서 여러 데이터를 한 번에 가져와야 할 때도 있는데요.

이럴 때는 `Promise.all()`이나 `Promise.allSettled()`를 사용하면 여러 데이터 페칭을 간단하게 병렬로 실행할 수 있습니다.

```javascript
async function Page() {
  const [user, posts] = await Promise.all([
    fetch(`https://dummyjson.com/users/${id}`).then((res) => res.json()),
    fetch(`https://dummyjson.com/posts/users/${id}`).then((res) => res.json()),
  ]);

  // ...
}
```

### 세 번째 방법 preload 패턴

컴포넌트 구조상 어쩔 수 없이 부모-자식 관계가 되면서 워터폴이 발생하는 경우도 있거든요.

이런 구조적인 워터폴은 '리퀘스트 메모이제이션'을 활용한 'preload 패턴'으로 해결할 수 있습니다.


물론 서버 간 통신은 클라이언트 통신보다 훨씬 빠르고 안정적이라서, 워터폴이 성능에 미치는 영향이 상대적으로 작긴 한데요.

하지만 무시할 수 없는 성능 병목 지점이 분명히 존재한다면, 이 preload 패턴은 아주 유용한 해결책이 됩니다.

**app/fetcher.ts**
```javascript
import "server-only";

export const preloadCurrentUser = () => {
  // preload 목적이므로 `await`하지 않습니다.
  void getCurrentUser();
};

export async function getCurrentUser() {
  const res = await fetch("https://dummyjson.com/user/me");
  return res.json() as User;
}
```

**app/products/[id]/page.tsx**
```javascript
export default function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  // <Product>나 <Comments>의 더 깊은 자손 컴포넌트에서 user 정보를 사용하기 때문에
  // 부모 컴포넌트에서 미리 preload를 실행합니다.
  preloadCurrentUser();

  return (
    <>
      <Product productId={id} />
      <Comments productId={id} />
    </>
  );
}
```

페이지 레벨에서 `preloadCurrentUser()`를 먼저 호출해서, `<Product>`와 `<Comments>`가 렌더링되는 동안 사용자 정보 조회를 '미리' 시작하는 원리거든요.

다만 이 패턴을 사용할 때는 나중에 User 정보가 필요 없게 되었을 때, 불필요한 `preloadCurrentUser()` 호출 코드를 지우는 것을 잊지 말아야 합니다.

### 고려해야 할 점

데이터 페칭 단위를 잘게 쪼개다 보면, 의도치 않게 'N+1 데이터 페칭' 문제가 발생할 수 있는데요.

이 부분에 대해서는 다음 챕터에서 자세히 알아보겠습니다.
