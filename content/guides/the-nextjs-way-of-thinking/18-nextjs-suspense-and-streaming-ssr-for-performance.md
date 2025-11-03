---
title: Next.js Suspense와 스트리밍으로 사용자 경험 극대화하기
date: 2025-10-26T20:30:16+09:00
description: "동적 렌더링 시 무거운 컴포넌트는 사용자 경험을 해칩니다. Suspense와 스트리밍 SSR을 활용하여 로딩이 오래 걸리는 컴포넌트만 지연시키고, 사용자에게 즉각적으로 화면을 보여주는 방법을 알아봅니다."
tags: ["Suspense", "스트리밍", "Streaming SSR", "Next.js", "동적 렌더링", "성능 최적화", "TTFB"]
weight: 18
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 18
---

결론부터 말씀드리면, 동적 렌더링 환경에서 특히 무거운 컴포넌트는 `<Suspense>`로 감싸서 렌더링을 지연시키고, '스트리밍 SSR'을 활용하는 것이 좋은데요.

이것이 바로 사용자 경험을 극대화하는 핵심 전략입니다.

### 왜 렌더링을 지연시켜야 할까

동적 렌더링 페이지는 전체가 한 번에 그려지기 때문에, 데이터 캐시를 잘 활용해야 한다고 말씀드렸거든요.

하지만 캐시할 수 없는 데이터 중에서도 유독 로딩이 오래 걸리는 작업이 있을 수 있습니다.

이런 느린 작업 하나 때문에 페이지 전체의 로딩이 늦어지는 것은 아주 비효율적입니다.

### `<Suspense>`와 스트리밍의 마법

Next.js는 '스트리밍 SSR'이라는 아주 강력한 기능을 지원하는데요.

로딩이 오래 걸리는 서버 컴포넌트를 `<Suspense>`로 감싸주면, Next.js는 우선 `<Suspense>`의 `fallback` UI를 포함한 HTML을 즉시 사용자에게 보냅니다.

사용자는 느린 컴포넌트를 기다릴 필요 없이 페이지의 나머지 부분을 바로 볼 수 있고, 그동안 서버에서는 느린 컴포넌트의 렌더링을 계속 진행하는데요.

렌더링이 완료되면, 그 결과물만 클라이언트로 '스트리밍'해서 `fallback` UI를 대체합니다.

이미 데이터 페칭 단위로 컴포넌트를 잘게 쪼개는 설계를 했다면, 필요한 곳에 `<Suspense>` 경계를 추가하는 것만으로 이 기능을 아주 쉽게 구현할 수 있습니다.

### 간단한 구현 예시

아래 코드는 3초가 걸리는 무거운 `<LazyComponent>`를 `<Suspense>`로 감싸는 예시인데요.

덕분에 사용자는 3초를 기다릴 필요 없이 페이지 제목과 `<Clock>` 컴포넌트를 즉시 볼 수 있습니다.

```javascript
import { setTimeout } from "node:timers/promises";
import { Suspense } from "react";
import { Clock } from "./clock";

export const dynamic = "force-dynamic";

export default function Page() {
  return (
    <div>
      <h1>Streaming SSR</h1>
      <Clock />
      <Suspense fallback={<>loading...</>}>
        <LazyComponent />
      </Suspense>
    </div>
  );
}

async function LazyComponent() {
  await setTimeout(3000);

  return <p>Lazy Component</p>;
}
```

![Next.js Suspense와 스트리밍으로 사용자 경험 극대화하기 - 스트리밍 SSR 로딩 중 화면](https://blogger.googleusercontent.com/img/a/AVvXsEhA5mLM-Pjjj7eCERMPeqbSlv06iP8YDwulUiijADrKtjBAid030WhWjIpufToV6Ip95h5xjQpszqOtBmmXnQiX_R7M8DWEJjoA2LtE_V03tdkoWjHk44Q2GPy3iTkG-YA5ih5_CpmbLP6mcowmWnJQ8f9AX3nWPnOXzNHF1crmkaT4G9FYl4AAM7eTCA8=s16000)

우선 `fallback`으로 지정한 "loading..." 텍스트가 바로 표시됩니다.

![Next.js Suspense와 스트리밍으로 사용자 경험 극대화하기 - 스트리밍 SSR 렌더링 완료 화면](https://blogger.googleusercontent.com/img/a/AVvXsEjNrOF6nogmhAMsc-UYV0bQblBbiEhofLXd2o-2zBoTaieaxH3nigjL4ThEPHtpRbKrm2O5GWwVDJOA7l03j5lkhirTRoyHtTeF-Na7oIFqIu-5mDabQKU38aL4rwzHeDz5ZBCh_397a4VRodYfmjY7JOaLa5M3reZH7JU93fbQHkDW6-qpxpIcldZTysA=s16000)

그리고 3초가 지나면, `<LazyComponent>`의 렌더링 결과가 스트리밍되어 화면에 나타납니다.

### 고려해야 할 점들

### 레이아웃 시프트(Layout Shift) 문제

스트리밍을 사용하면 `fallback` UI가 나중에 실제 콘텐츠로 대체되면서 화면이 밀리는, 소위 '레이아웃 시프트'가 발생할 수 있는데요.

만약 최종 콘텐츠의 높이가 고정되어 있다면, `fallback` UI의 높이도 똑같이 맞춰주면 이 문제를 해결할 수 있습니다.

하지만 높이가 유동적이라면, '첫 바이트까지의 시간(TTFB)'을 줄이는 것과 '누적 레이아웃 이동(CLS)'을 줄이는 것 사이에서 트레이드오프가 발생하는데요.

제 경험상, 200ms 정도 걸리는 작업이라면 굳이 스트리밍을 사용하지 않는 편이 낫고, 1초 이상 걸리는 작업이라면 망설임 없이 스트리밍을 선택하는 것이 좋습니다.

### 스트리밍과 SEO

과거에는 '보이지 않는 콘텐츠는 검색 엔진이 평가하지 않는다'는 말이 있었기 때문에, 스트리밍이 SEO에 불리할 수 있다는 우려가 있었는데요.

하지만 Vercel에서 진행한 대규모 조사에 따르면, 스트리밍으로 나중에 렌더링된 콘텐츠도 구글 검색 엔진에 의해 정상적으로 평가되는 것으로 확인되었습니다.

물론 자바스크립트에 의존하는 콘텐츠의 인덱싱에는 약간의 시간이 걸리지만, 그 속도가 충분히 빠르기 때문에 스트리밍 SSR이 SEO에 미치는 영향은 거의 없다고 봐도 무방합니다.
