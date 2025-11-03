---
title: Next.js 데이터 fetching 컴포넌트 안으로 옮기면 생기는 놀라운 변화
date: 2025-10-26T19:16:00+09:00
description: 과거 Next.js의 props drilling은 큰 단점이었습니다. 이제 App Router에서는 데이터 페칭을 컴포넌트에 직접 배치하여 독립성을 높이고 코드를 간결하게 만듭니다. Request Memoization이 이 모든 것을 가능하게 합니다.
tags: ["데이터 페칭", "Next.js", "App Router", "props drilling", "코로케이션", "Request Memoization", "서버 컴포넌트"]
weight: 2
series: ["Next.js 답게 개발하기: 앱 라우터의 설계 원리와 실전 가이드"]
series_order: 2
---

결론부터 말하자면, 데이터 페칭은 그 데이터를 직접 사용하는 컴포넌트 바로 안쪽에 배치하는 '코로케이션(colocation)' 전략을 사용하는 게 좋은데요.

이렇게 하면 컴포넌트의 독립성을 극적으로 높일 수 있는 아주 중요한 원칙입니다.

### 과거 방식의 고질적인 문제

'페이지 라우터(Pages Router)' 시절에는 서버 사이드 데이터 페칭을 `getServerSideProps`나 `getStaticProps` 같은 함수를 페이지 컴포넌트 '바깥'에 선언해서 처리했거든요.

이건 결국 '프롭스 드릴링(Props Drilling)', 소위 말하는 'props 바케스 릴레이'를 유발하는 주된 원인이었습니다.

부모 컴포넌트가 자식에게, 또 그 자식이 손자 컴포넌트에게 props를 계속해서 전달해야 하는 이 방식은 코드를 불필요하게 길게 만들고 컴포넌트 간의 의존성을 높이는 아주 큰 단점이 있었는데요.

실제 예시를 보면 바로 이해가 되실 겁니다.

### 페이지 라우터 방식의 예시 코드

아래는 상품 상세 페이지를 가정한 코드인데요.

API에서 받아온 `product`라는 props가 최상위 페이지부터 가장 말단의 컴포넌트까지 그대로 전달되고 있습니다.

```javascript
type ProductProps = {
  product: Product;
};

export const getServerSideProps = (async () => {
  const res = await fetch("https://dummyjson.com/products/1");
  const product = await res.json();
  return { props: { product } };
}) satisfies GetServerSideProps<ProductProps>;

export default function ProductPage({
  product,
}: InferGetServerSidePropsType<typeof getServerSideProps>) {
  return (
    <ProductLayout>
      <ProductContents product={product} />
    </ProductLayout>
  );
}

function ProductContents({ product }: ProductProps) {
  return (
    <>
      <ProductHeader product={product} />
      <ProductDetail product={product} />
      <ProductFooter product={product} />
    </>
  );
}

// ...
```

이해를 돕기 위해 조금 과장된 면이 있긴 하지만, 이런 '바케스 릴레이' 코드는 페이지 라우터에서는 정말 흔하게 발생하는 문제였거든요.

항상 페이지 최상단에서 필요한 모든 데이터를 미리 다 가져온 다음, 그걸 맨 아래 컴포넌트까지 일일이 흘려보내 줘야 했습니다.

이런 설계는 개발자가 항상 '페이지'라는 거대한 단위로만 생각하게 만들어서, 진정한 컴포넌트 기반 개발과는 거리가 멀었는데요.

개발자의 인지 부하를 높이는 아주 비효율적인 방식이었습니다.

### 앱 라우터의 새로운 해법

하지만 '앱 라우터(App Router)'에서는 서버 컴포넌트를 사용할 수 있기 때문에, 데이터 페칭을 가장 말단의 컴포넌트로 '이동'시키는 방식을 강력하게 권장하는데요.

이것이 바로 진정한 컴포넌트 기반 개발의 시작입니다.

물론 페이지 규모가 아주 작다면 페이지 컴포넌트에서 그냥 데이터를 한 번에 가져와도 큰 문제는 없을 겁니다.

하지만 페이지가 조금이라도 복잡해지기 시작하면 중간에서 props를 전달하는 코드가 생겨나기 마련이거든요.

그래서 가능한 한 데이터를 사용하는 가장 끝단의 컴포넌트에서 직접 페칭하는 습관을 들이는 것이 좋습니다.

혹시 '그렇게 하면 똑같은 데이터를 여러 번 요청하게 되는 거 아닌가?' 하고 걱정하실 수도 있는데요.

Next.js의 '리퀘스트 메모이제이션(Request Memoization)' 기능 덕분에 전혀 걱정할 필요가 없습니다.

앱 라우터는 동일한 요청이 여러 번 발생하더라도 실제 데이터 페칭은 단 한 번만 실행되도록 아주 스마트하게 설계되었거든요.

이것이 바로 코로케이션을 안심하고 사용할 수 있는 이유입니다.

### 앱 라우터 방식의 개선된 코드

앞서 보여드린 상품 페이지 코드를 앱 라우터 방식으로 바꾼다면 아래와 같은 모습이 될 텐데요.

얼마나 코드가 깔끔해졌는지 한번 확인해 보세요.

```javascript
type ProductProps = {
  product: Product;
};

// <ProductLayout>은 layout.tsx로 이동했다고 가정합니다.
export default function ProductPage() {
  return (
    <>
      <ProductHeader />
      <ProductDetail />
      <ProductFooter />
    </>
  );
}

async function ProductHeader() {
  const product = await fetchProduct();

  return <>...</>;
}

async function ProductDetail() {
  const product = await fetchProduct();

  return <>...</>;
}

// ...

async function fetchProduct() {
  // Request Memoization 덕분에 실제 fetch는 단 한 번만 실행됩니다.
  const res = await fetch("https://dummyjson.com/products/1");
  return res.json();
}
```

데이터 페칭 로직이 각 컴포넌트 안으로 옮겨가면서 '바케스 릴레이' 코드가 완전히 사라진 것을 볼 수 있는데요.

`ProductHeader`나 `ProductDetail` 같은 자식 컴포넌트들이 이제 각자 필요한 정보를 스스로 가져오기 때문에, 더 이상 페이지 전체에서 어떤 데이터를 내려주는지 신경 쓸 필요가 없어졌습니다.

### 딱 한 가지 알아둬야 할 점

이처럼 데이터 페칭 코로케이션을 가능하게 만드는 핵심 기술이 바로 '리퀘스트 메모이제이션(Request Memoization)'인데요.

따라서 이 기능을 정확하게 이해하고 최적의 설계를 하는 것이 무엇보다 중요합니다.

이 부분에 대해서는 바로 다음 챕터에서 훨씬 더 자세하게 다뤄보도록 하겠습니다.
