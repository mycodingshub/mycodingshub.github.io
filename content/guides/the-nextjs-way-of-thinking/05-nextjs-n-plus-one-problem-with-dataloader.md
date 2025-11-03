---
title: Next.js N+1 문제 DataLoader로 해결하는 가장 확실한 방법
date: 2025-10-26T19:24:00+09:00
description: Next.js에서 컴포넌트를 분리하면 N+1 문제로 불필요한 API 요청이 급증할 수 있습니다. GraphQL에서 널리 쓰이는 DataLoader를 활용하여 여러 요청을 하나로 묶어 성능을 최적화하는 방법을 알아봅니다.
tags: ["N+1 문제", "DataLoader", "Next.js", "데이터 페칭", "성능 최적화", "서버 컴포넌트", "batch processing"]
weight: 5
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 5
---

결론부터 말씀드리면, 컴포넌트의 독립성을 높이다 보면 필연적으로 'N+1 데이터 페칭' 문제가 생기기 쉬운데요.

이 문제는 '데이터로더(DataLoader)'의 배치 처리 기능을 이용해 해결하는 것이 정답입니다.

### 미리 알아두실 점

시작하기 전에 한 가지 중요한 전제가 있는데요.

이 글의 내용은 백엔드 API가 여러 개의 ID를 한 번에 조회하는 기능을 이미 지원하고 있다는 가정하에 진행됩니다.

### N+1 문제는 왜 발생할까

앞선 글에서 데이터 페칭 '코로케이션'이나 '병렬 처리'를 위해 컴포넌트를 잘게 쪼개는 것을 추천했는데요.

이렇게 컴포넌트를 잘게 나누다 보면 페이지 전체에서 발생하는 데이터 페칭을 관리하기가 점점 어려워지거든요.

이때 발생하는 두 가지 문제가 있는데, 첫 번째는 '중복 데이터 페칭'입니다.

하지만 이 문제는 Next.js의 '리퀘스트 메모이제이션(Request Memoization)' 기능이 해결해주므로, 데이터 페칭 레이어만 잘 분리해두면 크게 걱정할 필요가 없습니다.

문제는 바로 두 번째, 'N+1 데이터 페칭'인데요.

데이터 페칭 단위를 잘게 나눌수록 이 N+1 문제가 발생할 가능성은 기하급수적으로 높아집니다.

아래 코드는 게시물 목록을 가져온 뒤, 각 목록의 자식 컴포넌트에서 작성자 정보를 개별적으로 조회하는 예시인데요.

바로 이런 구조에서 N+1 문제가 발생합니다.

**page.tsx**
```typescript
import { type Post, getPosts, getUser } from "./fetcher";

export const dynamic = "force-dynamic";

export default async function Page() {
  const { posts } = await getPosts();

  return (
    <>
      <h1>Posts</h1>
      <ul>
        {posts.map((post) => (
          <li key={post.id}>
            <PostItem post={post} />
          </li>
        ))}
      </ul>
    </>
  );
}

async function PostItem({ post }: { post: Post }) {
  const user = await getUser(post.userId);

  return (
    <>
      <h3>{post.title}</h3>
      <dl>
        <dt>author</dt>
        <dd>{user?.username ?? "[unknown author]"}</dd>
      </dl>
      <p>{post.body}</p>
    </>
  );
}
```

**fetcher.ts**
```typescript
export async function getPosts() {
  const res = await fetch("https://dummyjson.com/posts");
  return (await res.json()) as {
    posts: Post[];
  };
}

// ... Post, User 타입 정의

export async function getUser(id: number) {
  const res = await fetch(`https://dummyjson.com/users/${id}`);
  return (await res.json()) as User;
}
```

이 페이지가 렌더링될 때 `getPosts()`가 1번, 그리고 게시물 개수(N)만큼 `getUser()`가 N번 호출되는데요.

결과적으로 아래와 같이 총 'N+1'번의 데이터 페칭이 발생하게 됩니다.

https://dummyjson.com/posts

https://dummyjson.com/users/1

https://dummyjson.com/users/2

https://dummyjson.com/users/3

...

### DataLoader를 이용한 해결책

이런 N+1 문제를 피하기 위해 API 쪽에서는 보통 `https://dummyjson.com/users/?id=1&id=2&id=3`처럼 여러 ID를 한 번에 조회하는 기능을 만들어두거든요.

Next.js에서는 바로 이 API와 '데이터로더(DataLoader)' 라이브러리를 함께 사용해서 N+1 문제를 해결할 수 있습니다.

'데이터로더'는 원래 '그래프큐엘(GraphQL)' 서버에서 널리 쓰이는 라이브러리로, 데이터 요청을 모아서 한 번에 처리(배치 처리)하고 캐싱하는 기능을 제공하는데요.

아주 짧은 시간 동안 여러 번 호출된 `dataLoader.load(id)`를 하나로 모아, ID 배열을 배치 함수에 넘겨주는 방식으로 동작합니다.

### Next.js에서 DataLoader 사용하기

서버 컴포넌트들은 서로 병렬로 렌더링되기 때문에, 각 컴포넌트에서 `await myLoader.load(id)`를 호출해도 데이터로더가 이 요청들을 똑똑하게 모아서 한 번에 처리해주는데요.

앞서 보여드린 예시 코드의 `getUser()` 함수를 데이터로더를 사용해서 다시 작성해 보겠습니다.

**fetcher.ts (개선된 버전)**
```typescript
import DataLoader from "dataloader";
import * as React from "react";

// ...

const getUserLoader = React.cache(
  () => new DataLoader((keys: readonly number[]) => batchGetUser(keys)),
);

export async function getUser(id: number) {
  const userLoader = getUserLoader();
  return userLoader.load(id);
}

async function batchGetUser(keys: readonly number[]) {
  // 실제 dummyjson은 이 기능을 지원하지 않지만, 예시를 위한 코드입니다.
  const res = await fetch(
    `https://dummyjson.com/users/?${keys.map((key) => `id=${key}`).join("&")}`,
  );
  const { users } = (await res.json()) as { users: User[] };
  return users;
}

// ...
```

여기서 가장 중요한 포인트는 데이터로더 인스턴스를 생성하는 부분을 `React.cache()`로 감싸준 것인데요.

데이터로더 자체에 캐시 기능이 있기 때문에, 모든 유저 요청에 걸쳐 동일한 인스턴스를 공유하면 다른 유저의 데이터가 노출될 수 있습니다.


`React.cache()`는 요청(request) 단위로 값을 캐싱해주므로, 각 유저의 요청마다 새로운 데이터로더 인스턴스가 생성되도록 보장해주는 아주 중요한 역할을 합니다.


이렇게 구현하면 기존의 `getUser()` 함수 인터페이스는 전혀 바꾸지 않으면서도, N+1 데이터 페칭 문제를 깔끔하게 해결할 수 있습니다.

### 다른 대안은 없을까

여기서 소개한 패턴은 일종의 '지연 로딩(Lazy Loading)' 방식인데요.

만약 백엔드 API의 구현이나 성능상의 이유로 이 방식이 적합하지 않다면, '즉시 로딩(Eager Loading)' 패턴을 고려해볼 수 있습니다.

즉, N+1의 첫 번째 요청('1')에서 관련된 모든 정보(N)를 한꺼번에 다 가져오는 방식인데요.

하지만 이 방식은 자칫 잘못하면 책임이 너무 커다란 '갓 에이피아이(God API)'를 만들게 될 위험이 있습니다.
