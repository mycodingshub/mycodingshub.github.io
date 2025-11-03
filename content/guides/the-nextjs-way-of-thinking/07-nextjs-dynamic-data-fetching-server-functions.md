---
title: Next.js 동적 데이터 fetching Server Functions로 끝내기
date: 2025-10-26T19:44:00+09:00
description: 사용자 입력에 따른 데이터 페칭은 서버 컴포넌트만으로 어렵습니다. Server Functions와 useActionState 훅을 활용해, 전체 페이지 새로고침 없이 동적으로 데이터를 가져오고 화면을 부분 렌더링하는 방법을 알아봅니다.
tags: ["Next.js", "Server Functions", "useActionState", "데이터 페칭", "동적 렌더링", "서버 액션", "RSC"]
weight: 7
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 7
---

사용자 행동에 따라 데이터를 새로 가져오고 화면을 다시 그려야 할 때가 있는데요.

이럴 때는 '서버 펑션(Server Functions)'과 `useActionState()` 훅을 사용하는 것이 정답입니다.

### 왜 이 방식이 필요할까

이전 글들에서 Next.js의 데이터 페칭은 서버 컴포넌트에서 하는 게 기본이라고 계속 말씀드렸거든요.

하지만 서버 컴포넌트는 사용자의 클릭이나 입력 같은 행동에 반응해서 데이터를 다시 가져오고 화면 일부만 새로 그리는 작업에는 적합하지 않습니다.

물론 `router.refresh()` 같은 방법으로 페이지 전체를 새로고침할 수는 있는데요.

화면의 아주 작은 일부만 바꾸고 싶을 때는 정말 부적절한 방법입니다.

### RSC 시대의 새로운 해법

Next.js의 RSC 환경에서는 '서버 펑션'과 `useActionState()` 훅을 이용해서 이 문제를 아주 우아하게 해결할 수 있는데요.

이 조합이 바로 사용자 인터랙션 기반 데이터 페칭의 핵심입니다.

`useActionState()`는 함수와 초기 상태 값을 인자로 받는 훅이거든요.

이 훅을 통해 서버 펑션을 거쳐 상태를 업데이트하는 로직을 손쉽게 관리할 수 있습니다.

사용자가 입력한 검색어로 상품을 찾는 간단한 예시 코드를 한번 살펴볼 텐데요.

`searchProducts`라는 서버 펑션을 `useActionState()`에 넘겨주고, 폼이 제출될 때마다 이 함수가 실행되는 구조입니다.

**app/search-products.ts**
```typescript
"use server";

export async function searchProducts(
  _prevState: Product[],
  formData: FormData,
) {
  const query = formData.get("query") as string;
  const res = await fetch(`https://dummyjson.com/products/search?q=${query}`);
  const { products } = (await res.json()) as { products: Product[] };

  return products;
}

// ... Product 타입 정의
```

**app/form.tsx**
```typescript
"use client";

import { useActionState } from "react-dom";
import { searchProducts } from "./search-products";

export default function Form() {
  const [products, action] = useActionState(searchProducts, []);

  return (
    <>
      <form action={action}>
        <label htmlFor="query">
          Search Product:&nbsp;
          <input type="text" id="query" name="query" />
        </label>
        <button type="submit">Submit</button>
      </form>
      <ul>
        {products.map((product) => (
          <li key={product.id}>{product.title}</li>
        ))}
      </ul>
    </>
  );
}
```

위 코드에서 검색어를 입력하고 'Submit' 버튼을 누르면, 검색 결과에 맞는 상품 목록이 화면에 나타나게 되는데요.

페이지 전체 새로고침 없이 오직 목록 부분만 업데이트되는 것이 핵심입니다.

### 고려해야 할 점들

### URL 공유 및 새로고침 문제

이 방식은 URL을 직접 업데이트하지 않기 때문에, 새로고침하거나 URL을 다른 사람에게 공유했을 때 상태가 유지되지 않는다는 단점이 있거든요.

만약 검색 페이지처럼 상태 유지가 중요하다면, 공식 튜토리얼 예제처럼 `router.replace()`를 사용해 URL을 직접 바꾸고 페이지 전체를 다시 렌더링하는 방법도 좋은 선택입니다.


하지만 사이드바의 검색 기능이나 `cmd+k`로 여는 검색 모달처럼 굳이 URL 공유나 새로고침 복원이 필요 없는 경우도 정말 많은데요.

바로 이런 경우에 서버 펑션과 `useActionState()`의 조합이 엄청난 위력을 발휘합니다.

### 데이터 '수정' 후 화면 업데이트

지금까지 설명한 내용은 사용자의 행동에 따라 데이터를 '조회'하는 경우에 대한 설계 패턴인데요.

하지만 데이터를 '수정'하고 그 결과를 다시 화면에 반영해야 하는 경우도 있습니다.

이것은 '서버 액션(Server Actions)'과 `revalidatePath()`나 `revalidateTag()`를 조합해서 구현하게 되거든요.

이 부분에 대해서는 '데이터 수정과 서버 액션' 챕터에서 더 자세히 다루겠습니다.
