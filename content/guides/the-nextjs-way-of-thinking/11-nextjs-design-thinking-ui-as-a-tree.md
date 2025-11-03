---
title: Next.js 컴포넌트 설계 처음부터 제대로 하는 법 UI를 트리로 보기
date: 2025-10-26T20:03:00+09:00
description: "재작업 없는 효율적인 Next.js 개발의 시작은 UI를 컴포넌트 트리로 분해하는 것입니다. 이 글은 탑다운 설계 방식으로 데이터 코로케이션과 컴포지션 패턴을 초기에 적용하여 견고한 아키텍처를 구축하는 방법을 안내합니다."
tags: ["UI 트리", "컴포넌트 설계", "Next.js", "탑다운 설계", "데이터 코로케이션", "컴포지션 패턴", "RSC"]
weight: 11
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 11
---

결론부터 말씀드리면, 리액트 설계의 가장 기본 철학은 UI를 컴포넌트 '트리'로 설계하는 것인데요.

페이지나 레이아웃을 만들 때, 이 'UI를 트리로 분해하는' 작업부터 시작해야 합니다.

이것이야말로 '데이터 코로케이션'과 '컴포지션 패턴'을 처음부터 제대로 적용하는 가장 확실한 방법입니다.

### 왜 이 방식이 중요할까

지금까지 우리는 서버 컴포넌트와 클라이언트 컴포넌트의 설계 패턴에 대해 깊이 있게 알아봤는데요.

특히 '데이터 코로케이션'과 '컴포지션 패턴'은 개발이 한참 진행된 후에 뒤늦게 적용하려고 하면, 정말 엄청난 재작업을 유발할 수 있습니다.

그렇기 때문에 이 두 가지 핵심 패턴은 프로젝트 초기 단계부터 반드시 고려해서 설계하는 것이 무엇보다 중요하거든요.

이걸 가능하게 해주는 것이 바로 '탑다운(top-down)' 설계 방식입니다.

### '큰 컴포넌트'와 '작은 컴포넌트'

리액트는 UI를 컴포넌트라는 단위로 표현하는데요.

페이지나 레이아웃 같은 UI는 일종의 '큰 컴포넌트'이고, 이 '큰 컴포넌트'는 여러 개의 '작은 컴포넌트'들을 조합해서 만들어집니다.

RSC 시대에 와서 서버 컴포넌트라는 새로운 종류의 부품이 추가되었을 뿐, 작은 부품으로 큰 제품을 조립한다는 리액트의 기본 설계 사상은 전혀 변하지 않았거든요.

이런 '큰 컴포넌트'를 바닥부터 하나씩 쌓아 올리는 '바텀업(bottom-up)' 방식으로 만들면 재작업이 발생하기 쉬워서, 저는 전체적인 그림부터 그리는 '탑다운' 방식을 강력하게 추천합니다.

### 추천하는 개발 순서

구체적으로는 아래와 같은 순서로 진행하는 것이 가장 효과적인데요.

1.  **설계**: 만들고자 하는 UI를 트리 구조로 분해합니다.

2.  **뼈대 구현**: 분해된 컴포넌트 트리의 뼈대를 코드로 먼저 만듭니다.

3.  **세부 구현**: 각 컴포넌트의 세부적인 내용을 구현합니다.


물론 처음 정한 트리 구조를 끝까지 고집할 필요는 없거든요.

개발을 진행하면서 더 좋은 구조가 보이면 언제든지 트리를 수정하는 유연함도 중요합니다.

### 블로그 게시글 페이지 예시

아래와 같은 블로그 게시글 화면을 만든다고 가정해 보겠습니다.

![Next.js 컴포넌트 설계 처음부터 제대로 하는 법 UI를 트리로 보기 - 블로그 게시글 화면 예시](https://blogger.googleusercontent.com/img/a/AVvXsEgn7bbKjcotfLlq8CwjvSQJt6fVMAQ6AfWG48pEoll2R1nzH2Is9cKvLTFmLSIW_SLCIPm_i2cAehfW0bfsdD83zj2W1Y-dt3uiQHlWOxSC2jjK1i2nsteNL0MtQnogGtUv7012ViR3PofApQvMG3AnDODVR7S9Bq6qAyJ9pMx_JogNktnJWh2UN2uxVaM=s16000)

이 화면은 '블로그 게시글 정보', '작성자 정보', '댓글 목록'이라는 세 가지 데이터 덩어리로 구성되어 있는데요.

각각의 데이터는 별도의 API를 통해 가져온다고 가정하겠습니다.

### 1단계 UI를 트리 구조로 분해하기

먼저 화면의 각 요소가 어떤 데이터에 의존하는지를 기준으로 UI를 트리 구조로 그려보는데요.

이것이 바로 설계의 첫 단추입니다.

![Next.js 컴포넌트 설계 처음부터 제대로 하는 법 UI를 트리로 보기 - UI를 API 의존성에 따라 트리 구조로 분해한 그림](https://blogger.googleusercontent.com/img/a/AVvXsEihB9EtL8ujYaZHqsULXHUqj57cG-DUniDkkDGLOLxOMWJjqIoi5FtOV4I5lXsMzV4FknMO5XpAyL9lYJeiuB89Li2TBe35I5Hep7SlEEJi6ilte2iiIDpezlu4tTdFyh8uFXlrz2sou5gnwZqdQrzVeykZPXB-SBdZ5XoUMTRCETTxObEZWKKBCWk3mXA=s16000)

### 2단계 컴포넌트 트리의 뼈대 구현하기

이제 위에서 그린 트리를 바탕으로, 각 요소를 서버 컴포넌트로 가정하고 코드의 뼈대를 만드는데요.

여기서 데이터 페칭을 담당할 컴포넌트는 `~Container`라는 이름으로 우선 만들어 둡니다.

```javascript
// /posts/[postId]/page.tsx
export default async function Page(props: {
  params: Promise<{ postId: string }>;
}) {
  const { postId } = await props.params;

  return (
    <div className="flex flex-col gap-4">
      <PostContainer postId={postId}>
        <UserProfileContainer postId={postId} />
      </PostContainer>
      <CommentsContainer postId={postId} />
    </div>
  );
}
```

### 3단계 각 컴포넌트 세부 구현하기

마지막으로, 뼈대만 만들어 두었던 각 컨테이너 컴포넌트들의 세부적인 내용을 실제 코드로 채워나가면 됩니다.

### 다시 한번 고려해야 할 점

UI를 이렇게 작은 컴포넌트로 나누고 각 컴포넌트가 직접 데이터를 가져오게 하면, '중복 요청'이나 'N+1' 문제가 발생할 수 있는데요.

이 문제들은 앞서 다뤘던 '리퀘스트 메모이제이션'과 '데이터로더'를 통해 해결할 수 있으므로, 데이터 페칭 레이어를 잘 설계하는 것이 무엇보다 중요합니다.
