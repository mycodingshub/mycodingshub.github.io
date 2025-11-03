---
title: "Next.js 15 에러 핸들링 완벽 가이드, Result 타입부터 Error Boundary까지"
description: "Next.js 15와 React 19 환경에서 서버 및 클라이언트 컴포넌트의 에러를 처리하는 실전 전략을 다룹니다. Result 타입을 활용한 예상된 에러 처리부터 error.tsx를 이용한 예기치 않은 에러 처리까지, 안정적인 애플리케이션을 만드는 방법을 소개합니다."
date: 2025-10-26T09:33:00+09:00
tags: ["Next.js 15", "React 19", "에러 핸들링", "Result 타입", "Error Boundary", "서버 컴포넌트", "global-error.tsx"]
weight: 7
series: ["Next.js 15와 React 19 실전 설계, 베스트 프랙티스 완벽 가이드"]
series_order: 7
---

### 들어가며

`Next.js 15`와 `React 19`에서 에러 핸들링은 서버 컴포넌트와 클라이언트 컴포넌트에서 서로 다른 접근 방식이 필요한데요.

이번 글에서는 예상된 에러와 예상치 못한 에러 모두에 효과적으로 대응하는 실용적인 에러 핸들링 전략을 자세히 알아볼 것입니다.

### 예상된 에러는 Result 타입으로 반환하기

예상 가능한 에러는 `throw`로 던지는 대신, `Result` 타입으로 감싸서 반환하는 것을 강력히 추천하는데요.

`throw`를 쓰지 않는 데에는 몇 가지 중요한 이유가 있습니다.

타입 안정성을 확보할 수 있고, 코드의 흐름이 명확해지며, 정말 예상치 못한 에러만 에러 바운더리(Error Boundary)에서 잡도록 역할을 분리할 수 있거든요.

무엇보다 API 요청별로 부분적인 에러 UI를 보여줄 수 있어 사용자 경험을 해치지 않는다는 큰 장점이 있습니다.

#### Result 타입 정의

`Result` 타입은 성공했을 때와 실패했을 때 서로 다른 타입을 반환하는 판별 가능한 유니온 타입(Discriminated Union)으로 정의하는데요.

이렇게 하면 타입스크립트(TypeScript)가 `isSuccess` 속성만 보고도 타입을 정확히 추론해줍니다.

```typescript
// types/result.ts
type SuccessResult<T> = {
  isSuccess: true;
  data: T;
};

type ErrorResult = {
  isSuccess: false;
  errorMessage: string;
};

export type Result<S> = SuccessResult<S> | ErrorResult;
```

#### 서버 데이터 로딩에서 사용 예시

서버 측에서 데이터를 가져올 때는 이 `Result` 타입을 사용해 에러를 반환하는데요.

이렇게 하면 `try-catch` 블록 안에서 발생하는 모든 종류의 에러(HTTP 에러, 네트워크 에러 등)를 일관되게 처리할 수 있습니다.

```typescript
// lib/request.ts
import type { Result } from @/types/result;

export async function request<T>(
  url: string,
  options?: RequestInit
): Promise<Result<T>> {
  try {
    const res = await fetch(url, options);

    if (!res.ok) {
      // HTTP 에러를 Result 타입으로 반환
      return {
        isSuccess: false,
        errorMessage: `HTTP 에러: ${res.status} ${res.statusText}`,
      };
    }

    const data = await res.json();

    return {
      isSuccess: true,
      data,
    };
  } catch (error) {
    // 네트워크 에러 등을 Result 타입으로 반환
    return {
      isSuccess: false,
      errorMessage: error instanceof Error ? error.message : 예상치 못한 에러가 발생했습니다.,
    };
  }
}
```

#### 서버 액션(Server Actions)에서 사용 예시

서버 액션에서도 마찬가지로 `Result` 타입을 활용하는데요.

성공했을 때는 캐시를 갱신하고, 실패했을 때는 에러 메시지를 담은 `Result` 객체를 반환합니다.

```typescript
// actions/users.ts
use server;

import { updateUserAPI } from @/apis/users.server;
import { revalidateTag } from next/cache;
import type { Result } from @/types/result;

export async function updateUser(
  userId: string,
  data: { name: string }
): Promise<Result<void>> {
  try {
    const result = await updateUserAPI(userId, data);

    if (result.isSuccess) {
      // 성공 시 캐시 갱신
      revalidateTag(users);
    }

    return result;
  } catch (error) {
    // 예상치 못한 에러도 Result 타입으로 반환
    return {
      isSuccess: false,
      errorMessage: 예상치 못한 에러가 발생했습니다.,
    };
  }
}
```

#### 클라이언트 데이터 로딩에서의 처리

클라이언트에서 데이터를 가져올 때는 예외적으로, `TanStack Query`의 강력한 에러 핸들링 기능에 에러 상태 관리를 위임하는데요.

이때는 에러를 `throw`해서 `useQuery` 훅의 `error` 속성으로 에러 객체를 넘겨주는 것이 일반적입니다.

```typescript
// apis/users.client.ts
import type { User } from @/types/user;

export async function fetchUser(userId: string): Promise<User> {
  const res = await fetch(`/api/users/${userId}`);

  if (!res.ok) {
    // 에러를 throw하면 useQuery의 error 속성으로 전달됩니다.
    throw new Error(사용자 정보를 가져오는 데 실패했습니다.);
  }

  return await res.json();
}
```

### 컴포넌트에서 부분적으로 에러 UI 보여주기

에러가 발생했다고 해서 화면 전체를 에러 UI로 덮어버리는 대신, 에러가 난 컴포넌트만 부분적으로 에러 UI를 보여주는 것이 정말 중요하거든요.

이렇게 하면 사용자는 다른 기능들을 계속 사용할 수 있어서 훨씬 더 나은 사용자 경험을 제공할 수 있습니다.

#### 서버 컴포넌트에서의 부분 에러 UI

서버 컴포넌트에서는 `Result` 타입을 사용해 컴포넌트 안에서 직접 에러를 처리하는데요.

`UserProfile` 컴포넌트에서 에러가 나도, `Tasks` 컴포넌트는 정상적으로 화면에 표시될 수 있습니다.


```typescript
// app/users/components/UserProfile.tsx
import { fetchUserProfile } from @/apis/users.server;

export default async function UserProfile() {
  const res = await fetchUserProfile();

  // isSuccess로 판별하면, TypeScript가 타입을 좁혀줍니다.
  if (!res.isSuccess) {
    return (
      <div className="error-container">
        <h1>에러</h1>
        <p>{res.errorMessage}</p>
      </div>
    );
  }

  // 여기서는 res.data에 타입 걱정 없이 접근할 수 있습니다.
  const user = res.data;

  return (
    <div>
      <h1>사용자 정보</h1>
      <p>사용자 이름: {user.name}</p>
    </div>
  );
}

// app/users/page.tsx
import { UserProfile } from ./components/UserProfile;
import { Tasks } from ./components/Tasks;

export default function Page() {
  // UserProfile에서 에러가 발생해도, Tasks는 화면에 보입니다.
  return (
    <div>
      <Suspense fallback={<p>loading...</p>}>
        <UserProfile />
      </Suspense>
      <Suspense fallback={<p>loading...</p>}>
        <Tasks />
      </Suspense>
    </div>
  );
}
```

#### 클라이언트 컴포넌트에서의 부분 에러 UI

클라이언트 컴포넌트에서는 `useQuery`가 반환하는 `error` 객체를 사용해 컴포넌트 내부에서 에러를 처리하는데요.

로딩 중일 때, 에러가 발생했을 때, 성공했을 때의 UI를 명확하게 분리해서 보여줄 수 있습니다.

```typescript
// components/UserProfile.tsx
use client;

import { useQuery } from @tanstack/react-query;
import { fetchUser } from @/apis/users.client;

type Props = {
  userId: string;
};

export function UserProfile({ userId }: Props) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: [user, userId],
    queryFn: () => fetchUser(userId),
  });

  if (isLoading) {
    return <p>로딩 중...</p>;
  }

  // 에러 발생 시 부분적으로 에러 UI를 보여줍니다.
  if (error) {
    return (
      <div className="error-container">
        <h2>에러</h2>
        <p>{error.message}</p>
      </div>
    );
  }

  return (
    <div>
      <h2>{user?.name}</h2>
      <p>{user?.email}</p>
    </div>
  );
}
```

#### 서버 액션에서의 부분 에러 UI

폼을 전송하는 서버 액션에서도 컴포넌트 안에서 에러 상태를 직접 관리하는데요.

이렇게 하면 에러가 발생해도 폼 입력 내용은 그대로 유지하면서 에러 메시지만 보여줄 수 있어 사용자 경험이 크게 향상됩니다.

```typescript
// components/UserEditForm.tsx
use client;

import { useState, useTransition } from react;
import { updateUser } from @/actions/users;

type Props = {
  userId: string;
  initialName: string;
};

export function UserEditForm({ userId, initialName }: Props) {
  const [name, setName] = useState(initialName);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const handleSubmit = () => {
    setError(null);

    startTransition(async () => {
      const result = await updateUser(userId, { name });

      if (!result.isSuccess) {
        // 에러 메시지를 부분적으로 보여줍니다.
        setError(result.errorMessage);
      } else {
        alert(수정되었습니다.);
      }
    });
  };

  return (
    <div>
      <input
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      <button onClick={handleSubmit} disabled={isPending}>
        {isPending ? 수정 중... : 수정}
      </button>
      {/* 에러는 부분적으로 표시되고, 폼 전체는 계속 사용 가능합니다. */}
      {error && <p className="error-message">{error}</p>}
    </div>
  );
}
```

### 예상치 못한 에러는 error.tsx와 global-error.tsx로 잡기

예상된 에러는 `Result` 타입이나 `useQuery`로 처리할 수 있지만, 버그처럼 전혀 예상치 못한 에러는 다른 방법으로 대처해야 하는데요.

`Next.js 15`는 이를 위해 `error.tsx`와 `global-error.tsx`라는 에러 바운더리(Error Boundary) 기능을 제공합니다.

#### error.tsx의 역할

`error.tsx` 파일은 해당 디렉토리와 그 하위 디렉토리에서 발생한 예상치 못한 에러를 잡아내는 역할을 하는데요.

에러는 가장 가까운 부모의 에러 바운더리로 전파되기 때문에, 여러 다른 깊이의 디렉토리에 `error.tsx`를 배치하면 에러 발생 위치를 더 세밀하게 파악할 수 있습니다.

```typescript
// app/dashboard/error.tsx
use client;

import { useEffect } from react;

type Props = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function Error({ error, reset }: Props) {
  useEffect(() => {
    // Sentry 같은 에러 모니터링 서비스로 에러를 전송
    console.error(Error:, error);
  }, [error]);

  return (
    <div className="error-page">
      <h2>에러가 발생했습니다.</h2>
      <p>{error.message}</p>
      <button onClick={reset}>다시 시도</button>
    </div>
  );
}
```

#### global-error.tsx의 역할

`global-error.tsx`는 루트 레이아웃(`app/layout.tsx`)에서 발생한 에러를 잡기 위한 아주 특별한 파일인데요.

일반 `error.tsx`는 루트 레이아웃 자체의 에러는 잡을 수 없기 때문에, `global-error.tsx`가 꼭 필요합니다.

이 파일은 `<html>`과 `<body>` 태그를 직접 포함해야 하며, 애플리케이션 전체의 최후의 보루 역할을 합니다.

```typescript
// app/global-error.tsx
use client;

import { useEffect } from react;

type Props = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function GlobalError({ error, reset }: Props) {
  useEffect(() => {
    // Sentry로 에러 전송
    console.error(Global Error:, error);
  }, [error]);

  return (
    <html>
      <body>
        <div className="global-error-page">
          <h2>예기치 않은 오류가 발생했습니다.</h2>
          <p>죄송합니다. 애플리케이션에 오류가 발생했습니다.</p>
          <button onClick={reset}>다시 시도</button>
        </div>
      </body>
    </html>
  );
}
```

### 에러 내용 정규화하기

서버에서 발생한 에러 객체를 클라이언트에 그대로 보내면, `Next.js`의 보안 기능 때문에 일반적인 에러 메시지로 바뀌어 버리거든요.

그 때문에 상태 코드에 따라 다른 에러 메시지를 보여주는 등의 처리가 불가능해집니다.

또한, 민감한 정보가 담긴 에러 메시지나 시스템 내부 구조가 드러나는 스택 트레이스가 사용자에게 그대로 노출될 위험도 있는데요.

따라서 에러 내용을 서버에서 미리 정규화(Normalize)해서, 안전하고 사용자 친화적인 메시지로 바꿔서 클라이언트에 보내는 것이 매우 중요합니다.

#### 커스텀 에러 클래스 구현

커스텀 에러 클래스를 만들면 에러 정보를 구조화해서 다루기 훨씬 편해지거든요.

특히 `serialize` 메서드를 만들어 UI에 보여줄 형태로 정규화하고, `toUserMessage` 메서드로 상태 코드에 맞는 사용자 친화적인 메시지를 반환하도록 설계하면 됩니다.

```typescript
// lib/errors.ts
export class ApiError extends Error {
  public readonly statusCode: number;
  public readonly code: string;

  constructor(message: string, statusCode: number, code?: string) {
    super(message);
    this.name = ApiError;
    this.statusCode = statusCode;
    this.code = code || UNKNOWN_ERROR;
  }

  // 에러 내용을 시리얼라이즈 (UI용으로 정규화)
  serialize() {
    return {
      name: this.name,
      message: this.toUserMessage(),
      statusCode: this.statusCode,
      code: this.code,
    };
  }

  // 사용자 친화적인 메시지로 변환
  private toUserMessage(): string {
    switch (this.statusCode) {
      case 400:
        return 입력 내용에 오류가 있습니다. 다시 한번 확인해 주세요.;
      case 401:
        return 로그인이 필요합니다.;
      case 403:
        return 접근 권한이 없습니다.;
      case 404:
        return 찾으시는 정보를 찾을 수 없었습니다.;
      case 500:
        return 서버에 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.;
      default:
        return 오류가 발생했습니다.;
    }
  }
}
```

#### 더 상세한 에러 정보 반환하기

UI에서 에러 종류에 따라 다른 화면을 보여주고 싶다면, 에러 정보를 더 구조화해서 반환해야 하는데요.

`Result` 타입의 에러 부분을 `errorMessage` 문자열 대신, 메시지, 코드, 상태 코드를 담는 객체로 바꾸는 것입니다.

```typescript
// types/result.ts 수정
type ErrorResult = {
  isSuccess: false;
  error: {
    message: string;
    code: string;
    statusCode?: number;
  };
};

// apis/users.server.ts 수정
// ...
if (!res.ok) {
  const error = new ApiError(Failed to fetch user, res.status, USER_FETCH_ERROR);
  return {
    isSuccess: false,
    error: { // 구조화된 에러 정보 반환
      message: error.toUserMessage(),
      code: error.code,
      statusCode: error.statusCode,
    },
  };
}
// ...
```

이렇게 하면, 컴포넌트에서는 에러의 상태 코드나 코드 값에 따라 분기 처리를 해서 훨씬 더 풍부한 UI를 보여줄 수 있습니다.

```typescript
// app/users/[id]/page.tsx
// ...
if (!res.isSuccess) {
  // 에러 코드에 따라 다른 UI를 보여줍니다.
  if (res.error.statusCode === 404) {
    return (
      <div>
        <p>사용자를 찾을 수 없습니다.</p>
        <Link href="/users">사용자 목록으로 돌아가기</Link>
      </div>
    );
  }

  return (
    <div>
      <h1>에러</h1>
      <p>{res.error.message}</p>
    </div>
  );
}
// ...
```

### 마치며

이번 글에서는 `Next.js 15`와 `React 19` 환경에서 에러를 다루는 실용적인 방법들을 알아봤는데요.

에러 핸들링은 단순히 에러를 화면에 보여주는 것을 넘어, 사용자 경험과 애플리케이션의 품질에 직접적인 영향을 미치는 아주 중요한 요소입니다.

예상된 에러는 `Result` 타입으로, 부분적인 에러 UI로 사용자 경험 지키기, 예상치 못한 에러는 `error.tsx`로 잡기, 그리고 에러 내용 정규화로 보안과 친절함 모두 잡기.

이 네 가지 핵심 원칙을 잘 조합하면, 견고하면서도 사용하기 편리한 애플리케이션을 만들 수 있을 겁니다.

끝까지 읽어주셔서 정말 감사합니다.
