---
title: "Go Concurrency 마스터하기: 경쟁 상태(Race Condition), 뮤텍스 너머의 세계"
date: 2025-12-11T09:30:00+09:00
description: "뮤텍스만으로는 막을 수 없는 경쟁 상태(Race Condition)의 함정! Compare-and-Set(CAS), 멱등성(Idempotence), 그리고 Shared Nothing 아키텍처까지 심도 있게 다룹니다."
tags: ["Go", "Golang", "Concurrency", "Race Condition", "CAS", "Idempotence", "Shared Nothing", "동시성"]
weight: 8
series: ["Go Concurrency 완벽 가이드"]
series_order: 8
---

지난 장에서 배운 뮤텍스(Mutex)로 **데이터 경쟁**(Data Race)은 막을 수 있습니다.

하지만 **경쟁 상태**(Race Condition)는 차원이 다른 문제입니다.

데이터 경쟁이 "메모리 접근 오류"라면, 경쟁 상태는 "논리적 순서 오류"입니다.

이번 장에서는 이 까다로운 괴물을 길들이는 법을 배워봅시다.

## 경쟁 상태 (Race condition)

간단한 은행 계좌 예제를 봅시다.

```go
// Get과 Set 메서드는 뮤텍스로 보호되어 있어서 스레드 안전(Thread-safe)합니다.
func (a *Accounts) Get(name string) int { /* ... */ }
func (a *Accounts) Set(name string, amount int) { /* ... */ }
```

앨리스는 50원을 가지고 있습니다.

두 개의 고루틴이 동시에 물건을 사려고 합니다.
1. "Castle" (40원)
2. "Plants" (20원)

```go
    // 고루틴 1: Castle 구매
    wg.Go(func() {
        balance := acc.Get("alice")             // (1) 잔액 확인
        if balance < castle.price { return }    // (2) 충분한가?
        acc.Set("alice", balance-castle.price)  // (3) 결제 및 잔액 갱신
    })

    // 고루틴 2: Plants 구매
    wg.Go(func() {
        balance := acc.Get("alice")             // (4) 잔액 확인
        if balance < plants.price { return }    // (5) 충분한가?
        acc.Set("alice", balance-plants.price)  // (6) 결제 및 잔액 갱신
    })
```

`Get`과 `Set`은 각각 안전하지만, 이 둘을 조합한 "구매 로직"은 안전하지 않습니다.


**시나리오:**
1. 고루틴 1이 잔액 50원을 읽습니다 ➊. (구매 가능)
2. 고루틴 2도 잔액 50원을 읽습니다 ➍. (구매 가능!)
3. 고루틴 1이 40원을 차감해 잔액을 10원으로 만듭니다 ➌.
4. 고루틴 2는 아까 읽은 50원을 기준으로 20원을 차감해 잔액을 30원으로 만듭니다 ➏.

결과: 앨리스는 60원어치 물건을 샀는데, 잔액은 30원이 남았습니다.

이것이 바로 **경쟁 상태**(Race Condition)입니다.

개별 동작(`Get`, `Set`)은 안전하지만, 실행 순서가 뒤섞이면서 전체 시스템의 상태가 꼬여버린 것이죠.

**해결책 1: 로직 전체를 뮤텍스로 보호하기**

```go
    // 고루틴 1
    mu.Lock() // 구매 시작 전 잠금
    defer mu.Unlock()

    balance := acc.Get("alice")
    if balance < castle.price { return }
    acc.Set("alice", balance-castle.price)
```

이제 구매 로직 전체가 원자적(Atomic)으로 실행됩니다.

안전하지만, 잠금 범위가 넓어지면 성능 저하가 올 수 있습니다.

## Compare-and-Set (CAS)

**해결책 2: CAS 방식 사용하기**

"잔액을 읽은 시점과 수정하는 시점 사이에 값이 바뀌지 않았을 때만 수정한다"는 전략입니다.

```go
// CompareAndSet은 현재 잔액이 old와 같을 때만 new로 바꿉니다.
func (a *Accounts) CompareAndSet(name string, old, new int) bool {
    a.mu.Lock()
    defer a.mu.Unlock()
    if a.bal[name] != old { // 값이 그새 바뀌었다면?
        return false        // 실패!
    }
    a.bal[name] = new
    return true
}
```

이제 구매 로직은 이렇게 바뀝니다.

```go
    balance := acc.Get("alice")
    // ... 잔액 확인 ...
    
    // "내가 아까 본 잔액이 그대로라면 결제해줘"
    if acc.CompareAndSet("alice", balance, balance-castle.price) {
        fmt.Println("구매 성공")
    } else {
        fmt.Println("구매 실패 (잔액이 변경됨)")
    }
```

실패 시 재시도(Retry)하는 루프를 추가하면 더욱 견고해집니다.

이 방식은 락을 짧게 잡으면서도 데이터 일관성을 지킬 수 있어 널리 사용됩니다.

## 멱등성 (Idempotence)과 원자성 (Atomicity)

**멱등성**은 같은 연산을 여러 번 수행해도 결과가 달라지지 않는 성질입니다.

예를 들어 `Close()` 함수를 여러 번 호출해도 리소스 해제는 딱 한 번만 일어나야 합니다.

```go
func (w *Worker) Close() {
    if w.closed { return } // (1) 이미 닫혔으면 리턴
    w.res.free()           // (2) 리소스 해제
    w.closed = true        // (3) 플래그 설정
}
```

이 코드도 경쟁 상태에 취약합니다.

두 고루틴이 동시에 ➊을 통과하면 둘 다 리소스 해제 ➋를 시도해서 패닉이 날 수 있습니다.

**안전한 멱등성 구현:**

1.  **Mutex 사용:** `Close` 메서드 전체를 뮤텍스로 감쌉니다. (가장 확실한 방법)
2.  **sync.Once 사용:** "단 한 번 실행"을 보장하는 `sync.Once`를 사용합니다. (다음 장에서 다룸)
3.  **select는 비추천:** `select`의 케이스 선택은 원자적이지 않아서 미묘한 레이스 컨디션이 발생할 수 있습니다.

## Locker 인터페이스와 TryLock

Go의 `sync.Mutex`와 `sync.RWMutex`는 모두 `Lock()`과 `Unlock()` 메서드를 가집니다.

이 공통점을 묶은 인터페이스가 `sync.Locker`입니다.

구체적인 락 구현체 대신 `Locker` 인터페이스를 받도록 코드를 짜면 유연성이 높아집니다.

**TryLock:**

"락을 걸 수 있으면 걸고, 못 걸면(이미 잠겨있으면) 기다리지 않고 포기해라"라는 메서드입니다.

`if !mu.TryLock() { return error }` 처럼 사용합니다.

하지만 `TryLock`이 필요하다면 보통 설계에 문제가 있을 가능성이 큽니다.

대부분의 경우 일반 `Lock`이나 채널을 사용하는 것이 더 낫습니다.

## Shared Nothing 아키텍처

경쟁 상태를 피하는 가장 근본적인 방법은 무엇일까요?

바로 **공유 상태**(Shared State)**를 없애는 것**입니다.

모든 구매 요청을 채널을 통해 하나의 **Processor 고루틴**에게 보낸다고 상상해 보세요.

```go
// Processor는 요청을 순차적으로 처리하는 단일 고루틴입니다.
func Processor(acc map[string]int) (chan<- Request, <-chan Purchase) {
    // ...
    go func() {
        for req := range in {
            // 여기는 오직 나 혼자만 실행됨! (동시성 문제 X)
            if acc[req.buyer] >= req.set.price {
                 acc[req.buyer] -= req.set.price
                 // ... 성공 처리 ...
            }
        }
    }()
    // ...
}
```

1.  구매자들은 요청을 채널에 넣습니다. (보내기만 함)
2.  Processor는 채널에서 요청을 하나씩 꺼내 처리합니다. (순차 처리)
3.  계좌 정보(`acc`)는 오직 Processor만 건드립니다. (공유되지 않음)

이 방식은 뮤텍스도 필요 없고, 경쟁 상태를 고민할 필요도 없습니다.

이것이 바로 "**메모리를 공유하여 통신하지 말고, 통신하여 메모리를 공유하라**"는 Go의 철학이 가장 잘 드러나는 패턴입니다.

---

이제 여러분은 경쟁 상태의 위험성과, 이를 해결하는 다양한 무기(전체 잠금, CAS, Shared Nothing)를 손에 넣었습니다.

동시성 프로그래밍은 단순히 문법을 아는 것을 넘어, 이러한 논리적 오류를 잡아내는 싸움입니다.

다음 장에서는 또 다른 유용한 동기화 도구인 **세마포어**(Semaphore)에 대해 알아보겠습니다.
