---
title: "Go Concurrency 마스터하기: 원자적 연산(Atomics), 락(Lock) 없이 안전하게"
date: 2025-12-11T10:00:00+09:00
description: "뮤텍스보다 빠르고 가벼운 동기화 기법, 원자적 연산(Atomics)을 파헤칩니다. sync/atomic 패키지 사용법부터 원자적 변수, 그리고 락프리(Lock-free) 자료구조의 기초까지."
tags: ["Go", "Golang", "Concurrency", "Atomic", "Lock-free", "CompareAndSwap", "동시성"]
weight: 11
series: ["Go Concurrency 완벽 가이드"]
series_order: 11
---

멀티 코어의 성능을 극한으로 끌어올리려면, 가끔은 **뮤텍스**(Mutex)조차 무겁게 느껴질 때가 있습니다.

이럴 때 사용하는 비밀 병기가 바로 **원자적 연산**(Atomic Operations)입니다.

락(Lock) 없이도 안전하게 공유 데이터를 수정하는 마법 같은 기술, 함께 배워봅시다.

## 원자적이지 않은 증가 (Non-atomic increment)

아주 단순한 카운터 예제를 봅시다.

```go
total := 0
// 5개의 고루틴이 각각 10,000번씩 total을 증가시킵니다.
// 예상 결과: 50,000
```

하지만 실행해 보면 50,000보다 작은 값이 나옵니다.

`total++` 연산은 겉보기엔 하나지만, 실제로는 **[읽기] -> [수정] -> [쓰기]** 라는 3단계로 이루어져 있기 때문입니다.

여러 고루틴이 동시에 읽고 쓰다 보면 중간 단계에서 값이 유실되는 **데이터 경쟁**(Data Race)이 발생합니다.

이걸 해결하기 위해 뮤텍스를 쓸 수도 있지만, 이번엔 **원자적 연산**만으로 해결해 보겠습니다.

## 원자적 연산 (Atomic operations)

원자적 연산이란 더 이상 쪼갤 수 없는, 한 번에 실행되는 연산을 말합니다.

Go의 `sync/atomic` 패키지는 CPU의 저수준 명령어를 사용해 이를 지원합니다.

주요 원자적 타입들:
*   `atomic.Bool`
*   `atomic.Int32` / `Int64`
*   `atomic.Uint32` / `Uint64`
*   `atomic.Value` (임의의 타입)
*   `atomic.Pointer` (제네릭 포인터)

주요 메서드들:
1.  **Load / Store:** 값을 안전하게 읽고 씁니다.
2.  **Add:** 값을 안전하게 더합니다. (뺄셈은 음수를 더하면 됩니다.)
3.  **Swap:** 새 값을 저장하고 이전 값을 반환합니다.
4.  **CompareAndSwap (CAS):** 현재 값이 예상한 값(old)과 같을 때만 새 값(new)으로 바꿉니다.

```go
var n atomic.Int32

n.Store(10)          // 쓰기
val := n.Load()      // 읽기
n.Add(1)             // 증가 (11)
old := n.Swap(20)    // 교체 (old=11, n=20)

// CAS: 현재 값이 20이면 30으로 변경
swapped := n.CompareAndSwap(20, 30) // true
```

이제 카운터 예제를 고쳐볼까요?

```go
var total atomic.Int32

// ... 고루틴 내부 ...
total.Add(1) // 안전한 증가!

// ... 종료 후 ...
fmt.Println(total.Load()) // 정확히 50,000 출력
```

뮤텍스 없이도 완벽하게 동기화가 되었습니다!

## 원자적 연산의 조합 (Composition)

"원자적 연산들을 모아 놓으면 전체도 원자적이겠지?"

**아니요, 그렇지 않습니다.** 이것이 원자적 연산의 함정입니다.

```go
var counter atomic.Int32

func increment() {
    // 짝수면 1 증가, 홀수면 2 증가
    if counter.Load()%2 == 0 {
        time.Sleep(10 * time.Millisecond)
        counter.Add(1)
    } else {
        time.Sleep(10 * time.Millisecond)
        counter.Add(2)
    }
}
```

`Load`와 `Add`는 각각 원자적이지만, 그 사이(`if`문과 `Sleep`)에는 틈이 있습니다.

이 틈 사이로 다른 고루틴이 끼어들어 값을 바꿀 수 있으므로, 전체 로직은 **경쟁 상태**(Race Condition)에 빠지게 됩니다.

(데이터 경쟁은 없지만, 논리적 결과는 예측 불가능해집니다.)

여러 단계의 연산을 하나로 묶어 원자적으로 만들고 싶다면?
1.  **뮤텍스**(Mutex)를 써야 합니다.
2.  또는, **CAS**(Compare-And-Swap)를 이용한 루프를 돌려야 합니다.

## 뮤텍스 대신 원자적 연산 쓰기

단순한 상태 플래그나 카운터 같은 경우, 뮤텍스 대신 원자적 연산을 쓰면 코드가 훨씬 가벼워집니다.

**예시: 단 한 번만 닫히는 게이트**

**뮤텍스 버전:**
```go
type Gate struct {
    closed bool
    mu     sync.Mutex
}

func (g *Gate) Close() {
    g.mu.Lock()
    defer g.mu.Unlock()
    if g.closed { return }
    g.closed = true
    // ... 리소스 해제 ...
}
```

**원자적 연산 버전 (atomic.Bool):**
```go
type Gate struct {
    closed atomic.Bool
}

func (g *Gate) Close() {
    // false -> true 변경을 시도. 성공하면 true 반환
    if !g.closed.CompareAndSwap(false, true) {
        return // 이미 true였다면(닫혔다면) 리턴
    }
    // ... 리소스 해제 ...
}
```

`CompareAndSwap` 한 줄로 검사와 수정을 동시에 처리했습니다.

이런 패턴을 잘 활용하면 락 없는(Lock-free) 알고리즘을 구현할 수 있습니다.

---

원자적 연산은 강력하지만, 남용하면 코드를 이해하기 어렵게 만듭니다.

단순한 카운터나 플래그에는 적극적으로 활용하되, 복잡한 로직 보호에는 여전히 뮤텍스가 정답이라는 점을 기억하세요.

다음 장에서는 동시성 코드를 안전하게 테스트하는 방법에 대해 알아보겠습니다.
