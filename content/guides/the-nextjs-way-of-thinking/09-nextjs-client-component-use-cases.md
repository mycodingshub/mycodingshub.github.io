---
title: Next.js 'use client' 꼭 써야만 하는 3가지 결정적 순간
date: 2025-10-26T19:55:00+09:00
description: Next.js에서는 서버 컴포넌트가 기본이지만, 이벤트 처리, 외부 라이브러리 사용, 성능 최적화 등 'use client'가 필수적인 3가지 상황이 있습니다. 언제 클라이언트 컴포넌트를 사용해야 하는지 명확히 알아봅니다.
tags: ["use client", "Next.js", "클라이언트 컴포넌트", "서버 컴포넌트", "RSC", "성능 최적화", "RSC Payload"]
weight: 9
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 9
---

'데이터 페칭'에서는 서버 컴포넌트 중심으로 설계 패턴을 알아봤는데요.

Next.js의 전체적인 컴포넌트 설계는 서버 컴포넌트를 중심으로, 필요한 곳에 클라이언트 컴포넌트를 적절히 조합하는 방식으로 이루어집니다.

그렇기 때문에, 우리는 언제 클라이언트 컴포넌트로 전환해야 하는지, 즉 언제 `'use client'`를 선언해야 하는지 정확하게 판단할 줄 알아야 하거든요.

이것이 바로 이번 챕터의 핵심 주제입니다.

제가 생각하는 클라이언트 컴포넌트를 사용해야 하는 대표적인 경우는 크게 세 가지인데요.

하나씩 자세히 살펴보겠습니다.

### 첫 번째 클라이언트 사이드 전용 기능이 필요할 때

가장 명확하고 당연한 경우인데요.

바로 클라이언트 사이드, 즉 사용자의 브라우저에서만 실행 가능한 기능이 필요할 때입니다.

`onClick()`이나 `onChange()` 같은 이벤트 핸들러를 사용해야 할 때가 대표적이거든요.

`useState()`나 `useEffect()` 같은 상태 및 라이프사이클 훅을 사용하거나, `window` 객체 같은 브라우저 전용 API를 써야 할 때도 마찬가지입니다.

```javascript
"use client";

import { useState } from "react";

export default function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>You clicked {count} times</p>
      <button onClick={() => setCount(count + 1)}>Click me</button>
    </div>
  );
}
```

### 두 번째 외부 라이브러리를 사용할 때

우리가 사용하는 수많은 서드파티 라이브러리 중에는 아직 RSC를 완벽하게 지원하지 않는 경우가 많거든요.

이럴 때는 우리가 직접 `'use client'` 경계선을 만들어주는 래퍼(wrapper) 컴포넌트를 만들어야 합니다.

라이브러리 컴포넌트를 감싸는 컴포넌트를 만들고 `'use client'`를 선언해서 `re-export` 하거나, 아니면 라이브러리를 사용하는 컴포넌트 자체에 `'use client'`를 명시해주는 방식인데요.

어떤 방식이든 반드시 클라이언트 경계를 설정해 주어야 합니다.

```javascript
// 방법 1: 라이브러리 컴포넌트를 re-export하는 래퍼
"use client";

import { Accordion } from "third-party-library";

export default Accordion;
```

```javascript
// 방법 2: 라이브러리를 사용하는 컴포넌트에 직접 선언
"use client";

import { Accordion } from "third-party-library";

export function SideBar() {
  return (
    <div>
      <Accordion>{/* ... */}</Accordion>
    </div>
  );
}
```

### 세 번째 RSC 페이로드 전송량을 줄여야 할 때

세 번째는 조금 더 전략적인 판단이 필요한 경우인데요.

바로 'RSC 페이로드(Payload)'의 전송량을 줄여 성능을 최적화해야 할 때입니다.

클라이언트 컴포넌트가 많아지면 자바스크립트 번들 사이즈가 커지고, 반대로 서버 컴포넌트가 많아지면 서버에서 클라이언트로 전송되는 RSC 페이로드의 크기가 커지거든요.

이 둘은 서로 트레이드오프 관계에 있습니다.

여기서 중요한 점은, 자바스크립트 번들은 처음에 단 한 번만 로드되지만, RSC 페이로드는 서버 컴포넌트가 렌더링될 때마다 '매번' 전송된다는 건데요.

따라서 자주 렌더링되는 컴포넌트의 HTML 구조가 매우 복잡하다면, RSC 페이로드 크기가 부담스러워질 수 있습니다.

예를 들어, 아래처럼 수많은 '테일윈드(tailwind)' 클래스가 적용된 컴포넌트가 있다고 가정해 보겠습니다.

```javascript
export async function Product() {
  const product = await fetchProduct();

  return (
    <div class="... /* 엄청나게 많은 tailwind 클래스 */">
      <div class="... /* 엄청나게 많은 tailwind 클래스 */">
        <div class="... /* 엄청나게 많은 tailwind 클래스 */">
          <div class="... /* 엄청나게 많은 tailwind 클래스 */">
            {/* product 데이터 사용 */}
          </div>
        </div>
      </div>
    </div>
  );
}
```

이런 경우, 데이터 페칭은 서버 컴포넌트에서 하되, 복잡한 UI 렌더링 부분만 클라이언트 컴포넌트로 분리하면 RSC 페이로드의 크기를 획기적으로 줄일 수 있습니다.

```javascript
// 데이터 페칭은 서버 컴포넌트에서 담당
export async function Product() {
  const product = await fetchProduct();

  return <ProductPresentaional product={product} />;
}

// UI 렌더링은 클라이언트 컴포넌트에 위임
"use client";

export function ProductPresentaional({ product }: { product: Product }) {
  return (
    <div class="... /* 엄청나게 많은 tailwind 클래스 */">
      {/* ... */}
    </div>
  );
}
```

### 주의해야 할 점들

### 암묵적인 클라이언트 컴포넌트

이전 글에서 설명했듯이 `'use client'`는 번들 경계선을 만드는 역할을 하거든요.

만약 너무 상위 컴포넌트에서 `'use client'`를 선언해버리면, 그 아래에 있는 모든 자식 컴포넌트들이 의도치 않게 전부 클라이언트 컴포넌트가 되어버립니다.

이렇게 되면 RSC의 장점을 제대로 활용할 수 없게 되므로 주의해야 하는데요.

이 문제를 해결하는 방법은 다음 챕터에서 다룰 '컴포지션 패턴(Composition Pattern)'입니다.

### 서버에서 클라이언트로 넘겨주는 Props

서버 컴포넌트에서 클라이언트 컴포넌트로 props를 넘겨줄 때는 한 가지 중요한 제약이 있거든요.

바로 리액트가 '직렬화(serialize)' 가능한 값만 전달할 수 있다는 점입니다.

함수나 `Date` 객체 같은 복잡한 값들은 직접 전달할 수 없으니, 이 점을 항상 기억해야 합니다.
