---
title: 서버 컴포넌트를 지키는 마지막 방어선 컴포지션 패턴
date: 2025-10-26T19:58:00+09:00
description: "'use client'를 선언하면 그 아래 모든 것이 클라이언트 컴포넌트가 됩니다. 이 문제를 해결하고 서버 컴포넌트를 지키기 위해, children props로 컴포넌트를 주입하는 강력한 설계 기법인 컴포지션 패턴을 알아봅니다."
tags: ["Composition Pattern", "Next.js", "use client", "서버 컴포넌트", "클라이언트 컴포넌트", "RSC", "컴포넌트 설계"]
weight: 10
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 10
---

결론부터 말씀드리면, '컴포지션 패턴'을 제대로 활용해야 하는데요.

이것이야말로 서버 컴포넌트 중심의 설계를 유지하면서도 클라이언트 컴포넌트를 꼭 필요한 곳에만 똑똑하게 심을 수 있는 핵심 기술입니다.

### 왜 이 패턴이 필요할까

RSC의 장점을 제대로 살리려면 서버 컴포넌트 위주로 설계하는 게 정말 중요하다고 계속 말씀드렸거든요.

하지만 이걸 실제로 구현하려면, 클라이언트 컴포넌트가 가진 두 가지 중요한 제약 사항을 반드시 고려해야 합니다.

### 제약 1 클라이언트 번들은 서버 모듈을 임포트할 수 없다

클라이언트 번들에 포함되는 파일은 서버 컴포넌트를 포함한 서버 전용 모듈을 직접 `import` 할 수 없는데요.

따라서 아래와 같은 코드는 에러를 발생시킵니다.

```javascript
"use client";

import { useState } from "react";
import { UserInfo } from "./user-info"; // 서버 컴포넌트라 import 불가!

export function SideMenu() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <UserInfo />
      <div>
        <button type="button" onClick={() => setOpen((prev) => !prev)}>
          toggle
        </button>
        <div>...</div>
      </div>
    </>
  );
}
```

이 규칙의 유일한 예외는 바로 `'use server'`가 붙은 '서버 펑션(Server Functions)' 뿐입니다.

### 제약 2 암묵적인 클라이언트 번들 포함

또 한 가지 중요한 점은, 한 파일에 `'use client'`를 선언하면, 그 파일이 불러오는 모든 자식 모듈들까지 전부 클라이언트 번들에 포함된다는 점인데요.

그래서 그 컴포넌트들은 모두 클라이언트 컴포넌트로서 동작할 수 있어야만 하는, 암묵적인 규칙이 생기는 것입니다.

### 두 가지 해결 전략

이러한 제약 속에서 서버 컴포넌트 중심의 설계를 지키려면, 클라이언트 컴포넌트를 효과적으로 분리하고 독립시켜야 하는데요.

여기에는 크게 두 가지 방법이 있습니다.

### 첫 번째 방법 컴포넌트 트리의 끝을 클라이언트 컴포넌트로 만들기

가장 간단한 방법은 컴포넌트 트리의 가장 말단, 즉 '잎(leaf)'에 해당하는 부분만 클라이언트 컴포넌트로 만드는 건데요.

다른 말로 하면, `'use client'` 경계선을 최대한 아래쪽으로 유지하는 전략입니다.

예를 들어 검색창이 있는 헤더를 만든다면, 헤더 전체가 아니라 상호작용이 필요한 '검색창' 부분만 클라이언트 컴포넌트로 분리하는 방식이거든요.

이렇게 하면 헤더 자체는 서버 컴포넌트로 유지할 수 있습니다.

```javascript
// header.tsx
import { SearchBar } from "./search-bar"; // 클라이언트 컴포넌트

// 헤더 자체는 서버 컴포넌트로 유지
export function Header() {
  return (
    <header>
      <h1>My App</h1>
      <SearchBar />
    </header>
  );
}
```

### 두 번째 방법 컴포지션 패턴 활용하기

하지만 어쩔 수 없이 상위 컴포넌트를 클라이언트 컴포넌트로 만들어야 할 때도 있거든요.

바로 이럴 때 '컴포지션 패턴'이 아주 강력한 해결책이 됩니다.

핵심 아이디어는 이렇습니다.

클라이언트 컴포넌트 파일 안에서 서버 컴포넌트를 직접 `import` 할 수는 없지만, `children` 같은 props를 통해 서버 컴포넌트를 '주입'받는 것은 완벽하게 가능하거든요.

앞서 에러가 났던 `<SideMenu>` 코드를 컴포지션 패턴으로 다시 작성해 보겠습니다.

**side-menu.tsx (클라이언트 컴포넌트)**
```javascript
"use client";

import { useState } from "react";

// `children` props를 통해 서버 컴포넌트를 전달받을 수 있습니다.
export function SideMenu({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      {children}
      <div>
        <button type="button" onClick={() => setOpen((prev) => !prev)}>
          toggle
        </button>
        <div>...</div>
      </div>
    </>
  );
}
```

**page.tsx (서버 컴포넌트)**
```javascript
import { UserInfo } from "./user-info"; // 서버 컴포넌트
import { SideMenu } from "./side-menu"; // 클라이언트 컴포넌트

export function Page() {
  return (
    <div>
      {/* 클라이언트 컴포넌트의 자식으로 서버 컴포넌트를 전달! */}
      <SideMenu>
        <UserInfo />
      </SideMenu>
      <main>{/* ... */}</main>
    </div>
  );
}
```

이렇게 하면 클라이언트 컴포넌트인 `<SideMenu>`는 상태 관리를 하고, 그 안에 렌더링될 서버 컴포넌트인 `<UserInfo>`는 부모인 `<Page>`가 결정해서 넘겨주는 구조가 되는데요.

이것이 바로 '컴포지션 패턴'이라고 불리는, 아주 중요하고 우아한 설계 패턴입니다.

### 고려해야 할 점

컴포지션 패턴을 사용하면 서버 컴포넌트 중심 설계를 지킬 수 있는데요.

하지만 이미 상위 컴포넌트를 클라이언트 컴포넌트로 만들어 버린 뒤에 나중에 이 패턴을 적용하려고 하면, 아주 큰 수정이 필요하거나 이미 설계가 꼬여버렸을 가능성이 큽니다.

이런 재작업을 막기 위해서는, 처음부터 컴포넌트 UI를 트리 구조로 분해해서 설계하는 습관이 중요한데요.

이 부분에 대해서는 다음 글에서 더 자세히 다루겠습니다.
