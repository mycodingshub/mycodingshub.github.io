---
title: Next.js 테스트 Container Presentational 패턴으로 정복하기
date: 2025-10-26T20:08:00+09:00
description: "RSC 환경에서는 컴포넌트 테스트가 어렵습니다. 데이터 페칭은 Container에, UI 렌더링은 Presentational에 분리하는 Container/Presentational 패턴을 활용하여 테스트 가능한 견고한 컴포넌트를 만드는 방법을 알아봅니다."
tags: ["Container/Presentational Pattern", "Next.js", "RSC", "컴포넌트 테스트", "React Testing Library", "Storybook", "테스트 용이성"]
weight: 12
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 12
---

결론부터 말씀드리면, 데이터 조회는 '컨테이너 컴포넌트(Container Components)'에, 데이터 표시는 '프레젠테이셔널 컴포넌트(Presentational Components)'에 분리하는 것이 좋은데요.

이렇게 책임을 나누면 테스트 용이성을 극적으로 향상시킬 수 있는 아주 강력한 전략입니다.

### 왜 이 패턴이 다시 필요해졌을까

리액트 컴포넌트를 테스트할 때는 보통 '리액트 테스팅 라이브러리(React Testing Library, RTL)'나 '스토리북(Storybook)'을 많이 사용하는데요.

안타깝게도 이 글을 쓰는 시점 기준으로, 이 도구들의 RSC 지원 상황은 아직 많이 부족합니다.

RTL은 현재 비동기 서버 컴포넌트를 `render()` 할 수 없어서, 서버 컴포넌트의 데이터 페칭 결과를 검증하는 테스트를 작성할 수가 없거든요.

스토리북은 실험적으로 RSC를 지원하긴 하지만, 내부적으로는 비동기 클라이언트 컴포넌트를 렌더링하는 방식이라 수많은 목(mock) 코드가 필요해서 실용성이 많이 떨어집니다.

### RSC 시대의 Container/Presentational 패턴

이런 상황을 고려하면, 우리가 만드는 서버 컴포넌트를 '테스트하기 어려운 데이터 페칭 부분'과 '테스트하기 쉬운 UI 표시 부분'으로 나누는 것이 아주 현명한 전략인데요.

바로 이 아이디어가 과거에 유행했던 'Container/Presentational 패턴'의 부활이라고 할 수 있습니다.

과거의 이 패턴은 데이터 로직과 UI 로직을 나누는 것이었다면, RSC 시대의 새로운 패턴은 그 역할이 조금 다른데요.

'컨테이너 컴포넌트'는 오직 데이터 페칭 같은 서버 사이드 처리만 담당하고, '프레젠테이셔널 컴포넌트'는 데이터를 받아 화면에 그리는 역할만 하는 '공유 컴포넌트(Shared Components)'나 '클라이언트 컴포넌트'를 의미합니다.

여기서 '공유 컴포넌트'란, `'use client'` 선언이 없으면서 서버나 클라이언트 전용 기능에 의존하지 않는 순수한 컴포넌트를 말하는데요.

이런 컴포넌트는 서버 번들에 포함되면 서버 컴포넌트로, 클라이언트 번들에 포함되면 클라이언트 컴포넌트로 동작하는 유연한 특징을 가집니다.

이렇게 책임을 분리하면, 프레젠테이셔널 컴포넌트는 기존 방식 그대로 RTL이나 스토리북으로 쉽게 테스트할 수 있게 되거든요.

컨테이너 컴포넌트는 비록 `render()` 할 수는 없지만, 그냥 일반 비동기 함수처럼 실행해서 그 반환 값을 테스트하는 방식으로 검증이 가능합니다.

### 블로그 게시글 컴포넌트 예시

블로그 게시글을 가져와 표시하는 컴포넌트를 이 패턴으로 구현해 보겠습니다.

### 컨테이너 컴포넌트 구현과 테스트

컨테이너 컴포넌트는 데이터를 가져와서 프레젠테이셔널 컴포넌트에 props로 전달하는 역할만 하는데요.

```javascript
// container.tsx
export async function PostContainer({
  postId,
  children,
}: {
  postId: string;
  children: React.ReactNode;
}) {
  const post = await getPost(postId);

  return <PostPresentation post={post}>{children}</PostPresentation>;
}
```

이 컴포넌트는 RTL로 테스트할 수 없으므로, 아래처럼 일반 함수처럼 호출해서 테스트합니다.

```javascript
// container.test.tsx
describe("PostAPI에서 데이터를 성공적으로 가져왔을 때", () => {
  test("PostPresentation에 API 결과값이 props로 전달되어야 한다", async () => {
    // msw 등으로 API mocking 설정
    server.use(/* ... */);

    const { type, props } = await PostContainer({ postId: "1" });

    expect(type).toBe(PostPresentation);
    expect(props.post).toEqual(post);
  });
});
```

### 프레젠테이셔널 컴포넌트 구현과 테스트

반면 프레젠테이셔널 컴포넌트는 데이터를 받아서 화면에 그리는 아주 단순한 역할을 하는데요.

```javascript
// presentational.tsx
export function PostPresentation({ post }: { post: Post }) {
  return (
    <>
      <h1>{post.title}</h1>
      <pre>
        <code>{JSON.stringify(post, null, 2)}</code>
      </pre>
    </>
  );
}
```

이런 단순한 컴포넌트는 기존 방식 그대로 RTL을 사용해 아주 쉽게 테스트할 수 있습니다.

```javascript
// presentational.test.tsx
test("props로 전달된 post의 title이 제목으로 표시되어야 한다", () => {
  const post = { title: "테스트 제목" };
  render(<PostPresentation post={post} />);

  expect(
    screen.getByRole("heading", { name: "테스트 제목" }),
  ).toBeInTheDocument();
});
```

### 추천 디렉터리 구조

Next.js는 파일 '코로케이션(colocation)'을 중요하게 생각하므로, 컨테이너 단위로 파일을 묶는 것을 추천하는데요.

외부에 노출되지 않아야 하는 파일들은 `_`로 시작하는 '프라이빗 폴더(Private Folder)'를 활용하면 좋습니다.

```shell
/posts/[postId]

├── page.tsx
└── _containers
    └── post
        ├── index.tsx       // 컨테이너 컴포넌트를 re-export
        ├── container.tsx
        ├── presentational.tsx
        └── ...
```

### 고려해야 할 점

이 패턴은 현재 테스트 도구들의 RSC 지원이 미비하다는 전제에서 출발했는데요.

미래에 테스트 생태계가 발전하면 이 패턴은 또 다른 형태로 변하거나, 어쩌면 더 이상 필요 없어질 수도 있다는 점은 알아두시면 좋습니다.
