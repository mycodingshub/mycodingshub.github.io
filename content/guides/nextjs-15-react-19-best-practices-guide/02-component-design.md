---
title: "Next.js 15와 React 19 컴포넌트 설계, 유지보수 끝판왕 되는 법"
date: 2025-10-26T09:00:00+09:00
description: "Next.js 15와 React 19 환경에서 유지보수성과 확장성을 극대화하는 컴포넌트 설계 원칙을 소개합니다. 서버 컴포넌트와 클라이언트 컴포넌트의 올바른 분리 기준부터 단일 책임 원칙까지, 실전 베스트 프랙티스를 확인해 보세요."
tags: ["Next.js 15", "React 19", "컴포넌트 설계", "서버 컴포넌트", "클라이언트 컴포넌트", "단일 책임 원칙", "YAGNI"]
weight: 2
series: ["Next.js 15와 React 19 실전 설계, 베스트 프랙티스 완벽 가이드"]
series_order: 2
---

### 들어가며

`Next.js 15`와 `React 19`에서 컴포넌트를 설계할 때는 서버 컴포넌트(Server Component)와 클라이언트 컴포넌트(Client Component)를 제대로 나누어 쓰고, 적절한 크기로 분리하며, 각자의 역할을 명확히 하는 게 정말 중요한데요.

이번 글에서는 유지보수성과 확장성을 모두 잡는 컴포넌트 설계 원칙과 실용적인 분리 기준에 대해 자세히 알아볼 것입니다.

### 기본 방침

`Next.js 15`와 `React 19` 환경에서 컴포넌트를 설계할 때 반드시 지켜야 할 세 가지 기본 원칙이 있는데요.

이 원칙들만 잘 따라도 코드의 품질이 눈에 띄게 달라질 겁니다.

#### 1. 단일 책임 원칙

컴포넌트는 UI, 로직, 상태 관리, 데이터 처리 등 여러 책임을 한 번에 떠안지 않도록 설계해야 하거든요.

이렇게 관심사의 분리를 철저히 지키면, 테스트하기 쉽고 재사용성 높은 컴포넌트를 만들 수 있습니다.

아래는 관심사를 어떻게 분리하는지에 대한 예시인데요.

참고하시면 도움이 될 겁니다.

| 관심사 | 처리 방침 |
| --- | --- |
| UI 렌더링 | 컴포넌트 내부 |
| 데이터 조회/수정 | API 클라이언트 |
| 상태 관리/비즈니스 로직 | 커스텀 훅(Custom Hook) |
| 순수 로직(계산, 변환 등) | 유틸리티 함수 |

이 원칙을 따르면 각 계층의 책임이 명확해져서, 코드 변경 시 영향 범위를 최소화할 수 있습니다.

#### 2. YAGNI 원칙

그건 필요 없을 거야(You Arent Gonna Need It)라는 뜻의 YAGNI 원칙에 따라, 너무 이른 추상화나 과도한 분리는 오히려 개발 비용을 높이므로 피해야 하는데요.

꼭 필요한 시점에 대응하는 것이 결과적으로 과잉 설계를 막는 가장 좋은 방법입니다.

미래를 예측한 설계도 중요하지만, 현재 요구사항에 집중하고 필요할 때 리팩토링하는 편이 훨씬 더 단순하고 유지보수하기 좋은 코드를 만들어냅니다.


#### 3. 상태의 지역화 (Colocation)

상태는 꼭 필요한 가장 작은 범위 안에 두어야 하거든요.

불필요하게 상위 부모 컴포넌트까지 상태를 끌어올리지 않는 것이 핵심입니다.

상태를 필요한 곳에만 배치하면 불필요한 리렌더링을 줄일 수 있는데요.

결과적으로 코드의 지역성(Locality)과 테스트 용이성까지 높일 수 있습니다.

이 상태가 정말 여기서 필요한가?라고 끊임없이 자문하는 습관이 중요합니다.

### 분리 기준 및 가이드라인

컴포넌트를 언제 분리해야 할지, 또 언제 로직을 커스텀 훅으로 빼내야 할지에 대한 구체적인 기준을 제시해 드릴 건데요.

이 기준을 따르면 코드 관리가 훨씬 수월해질 겁니다.

#### 코드 라인 수에 따른 분리 기준

컴포넌트의 코드 라인 수에 따른 분리 기준과 이상적인 분포는 다음과 같은데요.

이 목표를 기준으로 프로젝트를 관리해 보세요.

| 라인 수 범위 | 이상적인 비율 (목표) | 코멘트 |
| --- | --- | --- |
| 1~100 라인 | 70~80% | 골든존. 대부분의 컴포넌트는 이 범위에 속해야 합니다. |
| 101~200 라인 | 15~25% | 복잡한 UI (폼, 모달, 상세 화면 등)가 해당됩니다. |
| 201~300 라인 | 0~5% | 예외 케이스. 코드 리뷰 시 분리 대상으로 검토해야 합니다. |
| 300 라인 초과 | 0% | 원칙적으로 금지. 발견 즉시 분리를 검토해야 합니다. |

이 분포를 목표로 하면 컴포넌트의 가독성과 유지보수성을 높은 수준으로 유지할 수 있습니다.

#### 관심사 단위로 분리하기

하나의 컴포넌트에 관심사가 3개 이상 공존한다면 분리를 고민해 봐야 하는데요.

예를 들어 데이터 가져오기, 업데이트, 유효성 검사, 데이터 가공, UI 렌더링 등이 모두 섞여 있는 경우가 바로 그 예입니다.

`TaskList` 컴포넌트를 예로 들어보겠습니다.

수정 전 `TaskList` 컴포넌트가 아래와 같이 5개의 관심사를 모두 가지고 있다고 가정해 보죠.


*   1. 조회 (I/O) 할 일 목록 데이터 가져오기
*   2. 수정 (I/O) 할 일의 상태 업데이트하기
*   3. 검증 필터 입력 값에 대한 유효성 검사
*   4. 정렬 UI 내에서 정렬 조건 변경하기
*   5. UI 렌더링 할 일 목록과 각 항목 렌더링하기

이런 경우, 다음과 같이 컴포넌트와 훅을 분리하는 것이 바람직한데요.

이렇게 관심사별로 나누면 각 계층의 책임이 명확해지고, 테스트와 재사용이 쉬운 코드가 완성됩니다.

#### 기타 분리 기준

그 외에도 다음과 같은 경우에 분리를 검토하는 것이 좋은데요.

이 기준들을 참고하면 컴포넌트가 비대해지는 것을 효과적으로 막을 수 있습니다.

*   조건부 UI의 크기

    조건 분기 이후의 UI(HTML) 코드가 30라인을 넘어가면, 각 분기마다 컴포넌트를 분리하는 것을 고려해야 합니다.

*   반복되는 UI 요소

    리스트의 각 행이나 카드처럼 동일한 형태의 UI가 반복된다면, 반복되는 부분을 별도의 컴포넌트로 만들어야 합니다.

*   과도한 훅 사용

    하나의 컴포넌트에서 훅(Hook) 호출이 6개를 넘어간다면, 관련된 로직들을 묶어 커스텀 훅으로 분리하는 것이 좋습니다.

*   복잡한 로직 블록

    관련된 로직만으로 30~40라인 이상이 된다면, 커스텀 훅이나 유틸리티 함수로 분리해야 합니다.

*   많은 이벤트 핸들러

    `onClick` 같은 이벤트 핸들러가 5개 이상이라면, 이 또한 커스텀 훅이나 유틸리티 함수로 분리하는 것을 검토해야 합니다.

### 서버 컴포넌트(Server Component) 규칙

서버 컴포넌트를 다룰 때 지켜야 할 몇 가지 규칙과 설계 방침이 있는데요.

이를 통해 서버 컴포넌트의 장점을 극대화할 수 있습니다.

#### page.tsx는 동기적 서버 컴포넌트로

`page.tsx` 파일은 기본적으로 동기적으로 작동하는 서버 컴포넌트로 만들고, 서스펜드(suspend)되지 않도록 해야 하는데요.

즉, `await`나 `use`를 직접 사용하지 않는 것이 원칙입니다.

다만, `await` 없이 서버 데이터 요청을 시작하고, 그 `Promise` 객체를 자식 컴포넌트에 그대로 넘겨주는 방식은 괜찮습니다.


```typescript
// app/tasks/page.tsx
import { fetchTasks } from @/apis/tasks.server;
import { TaskList } from ./components/TaskList;

export default function TasksPage() {
  // await 하지 않고 Promise 객체 그대로 전달
  // 자식 컴포넌트에서 use 훅으로 데이터를 풀어 사용
  const tasksPromise = fetchTasks();

  return (
    <div>
      <h1>할 일 목록</h1>
      <Suspense fallback={<p>Loading...</p>}>
        <TaskList tasksPromise={tasksPromise} />
      </Suspense>
    </div>
  );
}
```

#### 스트리밍과 Suspense의 적극적인 활용

서버 컴포넌트에서는 스트리밍(Streaming)을 활용해 사용자 경험을 크게 향상시킬 수 있거든요.

기본적으로 API 같은 리소스 단위로 컴포넌트를 분리하고, 비동기 컴포넌트는 반드시 `Suspense`로 감싸서 상위 컴포넌트가 멈추지 않도록 해야 합니다.

```typescript
// app/dashboard/page.tsx
import { Suspense } from react;
import { UserInfo } from ./components/UserInfo;
import { RecentTasks } from ./components/RecentTasks;
import { Analytics } from ./components/Analytics;

export default function DashboardPage() {
  return (
    <div>
      <h1>대시보드</h1>

      {/* 각 컴포넌트가 독립적으로 스트리밍됩니다. */}
      <Suspense fallback={<p>사용자 정보를 불러오는 중...</p>}>
        <UserInfo />
      </Suspense>

      <Suspense fallback={<p>최근 할 일을 불러오는 중...</p>}>
        <RecentTasks />
      </Suspense>

      <Suspense fallback={<p>분석 데이터를 불러오는 중...</p>}>
        <Analytics />
      </Suspense>
    </div>
  );
}
```

#### 에러 UI 분리

서버 컴포넌트에서 데이터 요청 실패 시 보여줄 에러 UI는 해당 컴포넌트 내부에 직접 작성하는 것이 좋은데요.

이렇게 하면 페이지 전체가 에러 화면으로 바뀌는 것을 막고, 문제가 발생한 부분만 에러 UI로 대체할 수 있습니다.

```typescript
// app/user/[id]/page.tsx
import { fetchUser } from @/apis/users.server;
import { UserProfile } from ./components/UserProfile;

type Props = {
  params: Promise<{ id: string }>;
};

export default async function UserProfile({ params }: Props) {
  const { id } = await params;
  const result = await fetchUser(id);

  // 에러 발생 시, 컴포넌트 내에서 에러 UI를 보여줍니다.
  if (!result.isSuccess) {
    return (
      <div>
        <h1>에러</h1>
        <p>{result.errorMessage}</p>
      </div>
    );
  }

  const userProfile = result.data;

  return <div>사용자 이름: {userProfile.name}</div>;
}
```

### 클라이언트 컴포넌트(Client Component) 규칙

다음은 클라이언트 컴포넌트에 대한 규칙과 설계 방침인데요.

이 원칙들을 지키면 성능 저하를 막을 수 있습니다.


#### 클라이언트 컴포넌트는 최소한으로

클라이언트 컴포넌트는 정말 필요한 최소한의 부분에만 적용하고, 기본적으로는 서버 컴포넌트를 사용하는 것이 좋거든요.

클라이언트 컴포넌트가 꼭 필요한 경우는 다음과 같습니다.

*   사용자 상호작용이 필요한 부분

    버튼 클릭이나 폼 입력처럼 사용자와의 인터랙션이 있는 곳입니다.

*   브라우저 API를 사용하는 곳

    `localStorage`나 `window` 객체처럼 브라우저에서만 제공하는 API를 사용하는 경우입니다.

*   React 훅을 사용하는 곳

    `useState`나 `useEffect` 같이 상태나 라이프사이클 관리가 필요한 컴포넌트입니다.


이런 부분들만 클라이언트 컴포넌트로 만들면, 자바스크립트(JavaScript) 번들 사이즈를 줄여 성능을 크게 향상시킬 수 있는데요.

물론, 근본적으로 `useState`나 `useEffect` 자체도 꼭 필요할 때만 사용하는 것이 매우 중요합니다.

#### Suspense로 감싸기

`use`, `useSearchParams`, 동적 `import`를 사용하는 클라이언트 컴포넌트 역시 비동기적으로 동작하기 때문에, 반드시 `Suspense`로 감싸 상위 컴포넌트에 영향을 주지 않도록 해야 합니다.

`use`와 `Suspense`를 조합하면 클라이언트 컴포넌트에서도 스트리밍을 구현할 수 있습니다.


```typescript
// app/tasks/page.tsx
// (위 서버 컴포넌트 예시와 동일)

// app/tasks/components/TaskList.tsx
use client

import { Result } from @/types/Result;
import { use } from react;

type Props = {
  tasksPromise: Promise<Result<Tasks[]>>
}

export default function TaskList({ tasksPromise }: Props) {
  // use 훅으로 Promise의 내용물을 추출합니다.
  const tasks = use(tasksPromise)

  return (
    // ...
    // ...
  );
}
```

### 기타 규칙

마지막으로, 컴포넌트 설계와 관련된 몇 가지 추가 규칙을 알아볼 건데요.

이것들까지 챙기면 더욱 완성도 높은 프로젝트를 만들 수 있습니다.

#### 컴포지션 패턴(Composition Pattern) 활용

클라이언트 컴포넌트 아래에 서버 컴포넌트를 배치해야 할 경우, 직접 `import`하지 않는 것이 좋은데요.

대신, 클라이언트 컴포넌트의 `children`으로 서버 컴포넌트를 전달하는 컴포지션 패턴을 사용해야 합니다.

```typescript
// app/dashboard/page.tsx
import { ClientWrapper } from ./components/ClientWrapper;
import { ServerContent } from ./components/ServerContent;

export default function Page() {
  return (
    <ClientWrapper>  {/* 클라이언트 컴포넌트 */}
      {/* 서버 컴포넌트를 children으로 전달 */}
      <Suspense fallback={<p>로딩 중...</p>}>
        <ServerContent /> {/* 서버 컴포넌트 */}
      </Suspense>
    </ClientWrapper>
  );
}
```

#### loading.tsx 배치

동적 API를 사용하는 페이지는 전체가 동적 렌더링(Dynamic Rendering, SSR과 유사) 대상이 되거든요.

따라서 부분적으로 `Suspense`를 사용하더라도, 만일을 대비해 `loading.tsx` 파일을 반드시 배치해 두어야 합니다.

`loading.tsx`는 페이지 전체의 로딩 상태를 보여주는 파일로, 페이지 전환 시에도 사용되기 때문에, 부분적인 `Suspense`와 함께 사용하면 훨씬 더 나은 사용자 경험을 제공할 수 있습니다.

```typescript
// app/tasks/loading.tsx
export default function Loading() {
  return <p>할 일 목록을 불러오는 중...</p>;
}
```

#### default export로 통일

컴포넌트는 기본적으로 `default export`를 사용하는 것으로 통일하는 것이 좋은데요.

`page.tsx`, `layout.tsx`, `loading.tsx` 같은 `Next.js`의 표준 파일들이 `default export`를 사용하고 있기 때문에, 프로젝트 전체의 일관성을 유지하기 위함입니다.

물론, 프로젝트에 이미 다른 규칙이 있다면 그 규칙을 따르면 되는데요.

기본적으로는 한 파일에서 여러 컴포넌트를 `export`하는 상황은 만들지 않는 것을 전제로 합니다.

```typescript
// components/UserProfile.tsx
export default function UserProfile() {
  return <div>User Profile</div>;
}
```

### 마치며

이번 글에서는 `Next.js 15`와 `React 19` 환경에서의 컴포넌트 설계에 대해, 기본 원칙부터 구체적인 분리 기준, 그리고 서버 컴포넌트와 클라이언트 컴포넌트의 활용법까지 자세히 다뤄봤는데요.

컴포넌트 설계는 애플리케이션의 유지보수성과 확장성을 결정하는 매우 중요한 과정입니다.

단일 책임 원칙, 상태의 지역화, YAGNI 원칙을 항상 염두에 두면서, 적절한 크기로 컴포넌트와 로직을 나누는 것이 핵심인데요.

또한, 서버 컴포넌트와 클라이언트 컴포넌트의 특성을 정확히 이해하고 상황에 맞게 사용함으로써, 최적의 성능과 사용자 경험을 구현할 수 있습니다.

끝까지 읽어주셔서 정말 감사합니다.
