---
title: "Go Concurrency 마스터하기: 시그널링(Signaling), 채널보다 빠른 소통"
date: 2025-12-11T09:50:00+09:00
description: "채널만으로는 부족할 때가 있습니다. 조건 변수(Cond)를 이용한 브로드캐스팅, sync.Once를 이용한 초기화, 그리고 객체 풀(Pool)까지 고급 동기화 기법을 알아봅니다."
tags: ["Go", "Golang", "Concurrency", "Signaling", "Cond", "Broadcast", "Once", "Pool", "동시성"]
weight: 10
series: ["Go Concurrency 완벽 가이드"]
series_order: 10
---

Go에서 고루틴끼리 대화하는 주된 수단은 **채널**(Channel)입니다.

하지만 채널이 유일한 방법은 아닙니다.

때로는 **조건 변수**(Condition Variable)나 **원자적 초기화** 같은 도구가 더 효율적일 때가 있습니다.

이번 장에서는 채널 너머의 고급 동기화 기법들을 탐험해 봅시다.

## 시그널링 (Signaling)과 조건 변수 (Cond)

어떤 숫자가 준비될 때까지 기다렸다가, 준비되면 "행운의 숫자인지" 확인하는 로직이 있다고 합시다.

채널을 쓰면 간단하지만, 채널 없이 `sync.Cond`를 써서 구현할 수도 있습니다.

`sync.Cond`는 **뮤텍스(Mutex)**와 짝꿍입니다.

```go
    cond := sync.NewCond(&sync.Mutex{}) // 뮤텍스와 함께 생성
```

주요 메서드는 두 가지입니다:
1.  `Wait()`: 뮤텍스를 잠시 풀고, 신호가 올 때까지 대기(블로킹)합니다. 깨어나면 다시 뮤텍스를 잠급니다.
2.  `Signal()`: 대기 중인 고루틴 **하나**를 깨웁니다.

```go
// 생성자 (Generator)
wg.Go(func() {
    time.Sleep(10 * time.Millisecond)
    cond.L.Lock()        // (1) 잠금
    num = 1 + rand.IntN(100)
    cond.Signal()        // (2) "준비됐어!" 신호 보냄
    cond.L.Unlock()      // (3) 잠금 해제
})

// 확인자 (Checker)
wg.Go(func() {
    cond.L.Lock()
    for num == 0 {       // (4) 아직 준비 안 됐으면
        cond.Wait()      // (5) 대기 (잠금 풀고 잠들었다가, 신호 오면 깨서 다시 잠금)
    }
    // ... 숫자 확인 ...
    cond.L.Unlock()
})
```

**핵심 포인트:** `Wait()`는 항상 `for` 루프 안에서 호출해야 합니다.

신호를 받고 깨어났더라도, 그 찰나의 순간에 다른 고루틴이 상태를 바꿔버렸을 수도 있기 때문입니다.

(이를 "Spurious wakeup"이라고도 합니다.)

## 브로드캐스팅 (Broadcasting)

`Signal()`은 대기자 중 딱 한 명만 깨웁니다.

만약 여러 고루틴이 동시에 이 숫자를 기다리고 있다면요? 모두에게 "일어나!"라고 소리치고 싶다면 `Broadcast()`를 쓰면 됩니다.

```go
// 생성자
func (l *Lucky) Guess() {
    l.cond.L.Lock()
    l.num = 1 + rand.IntN(100)
    l.cond.Broadcast() // (1) "모두 일어나세요!"
    l.cond.L.Unlock()
}
```

이제 `Wait()` 하고 있던 모든 고루틴이 동시에 깨어나서 각자 할 일을 합니다.

이런 **일대다(1:N) 통신**은 채널로 구현하기가 까다로운데, `Cond`를 쓰면 아주 직관적입니다.

### 채널로 브로드캐스팅?

채널을 닫아서(`close`) 브로드캐스팅 효과를 낼 수도 있습니다.

채널이 닫히면 대기하던 모든 수신자가 깨어나니까요.

하지만 **채널은 딱 한 번만 닫을 수 있다**는 치명적인 단점이 있습니다.

반복적인 이벤트 알림에는 `sync.Cond`가 제격입니다.

## 발행/구독 (Publish/Subscribe) 패턴

`Cond`를 쓰지 않고 채널만으로 1:N 통신을 하려면 직접 **발행/구독 시스템**을 만들어야 합니다.

구독자 리스트를 관리하고, 이벤트가 발생하면 `for` 문을 돌며 구독자들의 채널에 메시지를 쏘는 방식이죠.

```go
func (l *Lucky) Guess() {
    subs := <-l.sbox // 구독자 목록 가져오기
    num := 1 + rand.IntN(100)
    for _, sub := range subs {
        select {
        case sub <- num: // 각 채널에 전송
        default:         // 못 받으면 스킵 (Non-blocking)
        }
    }
    l.sbox <- subs
}
```

이 방식은 구현이 좀 복잡하지만, `select`를 활용해 "준비 안 된 구독자는 건너뛰기" 같은 유연한 처리가 가능합니다.

## 단 한 번만 실행 (Run once) - sync.Once

초기화 로직처럼 **프로그램 수명 동안 딱 한 번만 실행**되어야 하는 코드가 있다면 `sync.Once`가 정답입니다.

여러 고루틴이 동시에 달려들어도, 오직 승리한 한 명만 실행하고 나머지는 그 실행이 끝날 때까지 기다립니다.

```go
var once sync.Once

func (c *CurrencyConverter) Convert(...) float64 {
    once.Do(c.init) // (1) c.init은 평생 딱 한 번만 실행됨
    return ...
}
```

이제 뮤텍스나 플래그(`initialized = true`) 검사를 직접 짤 필요가 없습니다.

데이터 경쟁 없이 안전하고 깔끔하게 초기화할 수 있죠.

### 편리한 Once 함수들 (Go 1.21+)

최신 Go에서는 더 편리한 함수들을 제공합니다.
*   `sync.OnceFunc`: 한 번만 실행되는 함수를 반환합니다.
*   `sync.OnceValue`: 한 번만 실행되고, 그 결과값을 계속 반환하는 함수를 만듭니다. (캐싱 효과!)

```go
// 랜덤 숫자를 딱 한 번만 생성하고, 이후엔 계속 그 값만 리턴
initN := sync.OnceValue(randomN) 

fmt.Println(initN()) // 42
fmt.Println(initN()) // 42 (다시 계산 안 함)
```

## 객체 풀 (Object pool) - sync.Pool

메모리 할당(`make`)은 공짜가 아닙니다.

짧은 수명을 가진 객체를 반복적으로 생성하고 버리면 가비지 컬렉터(GC)가 힘들어합니다.

이때 `sync.Pool`을 쓰면 객체를 재사용할 수 있습니다.

```go
    pool := sync.Pool{
        New: func() any { return new([]byte) }, // (1) 없으면 새로 생성
    }

    // 사용
    buf := pool.Get().(*[]byte) // (2) 풀에서 꺼내기
    // ... 작업 ...
    pool.Put(buf)               // (3) 다 썼으면 반납
```

벤치마크를 돌려보면 메모리 할당 횟수가 획기적으로 줄어드는 것을 볼 수 있습니다.

하지만 주의할 점은 풀에 들어간 객체는 언제든 GC에 의해 수거될 수 있다는 것입니다.

따라서 영구적인 저장소로는 사용할 수 없고, **임시 버퍼** 등을 최적화할 때 주로 쓰입니다.

---

이번 장에서는 채널 외의 동기화 도구들을 살펴봤습니다.
*   **sync.Cond:** 1:N 알림 (브로드캐스팅)
*   **sync.Once:** 단 한 번 실행 보장 (초기화)
*   **sync.Pool:** 객체 재사용 (GC 부담 경감)

이 도구들은 특정한 상황에서 채널보다 훨씬 강력하고 효율적입니다.

하지만 남용하지는 마세요. 대부분의 경우엔 여전히 채널이 가장 Go다운 해결책입니다.

다음 장에서는 동시성 프로그래밍의 가장 밑바닥, **원자적 연산**(Atomics)의 세계로 내려가 보겠습니다.
