---
title: "Go Concurrency 마스터하기: 세마포어(Semaphore), 동시성 제한의 기술"
date: 2025-12-11T09:40:00+09:00
description: "고루틴의 동시 실행 개수를 제한하고 싶다면? 뮤텍스보다 유연한 세마포어(Semaphore)의 세계로 초대합니다. 랑데부(Rendezvous)와 장벽(Barrier) 패턴까지 마스터해 보세요."
tags: ["Go", "Golang", "Concurrency", "Semaphore", "Rendezvous", "Barrier", "동시성"]
weight: 9
series: ["Go Concurrency 완벽 가이드"]
series_order: 9
---

멀티 코어의 힘을 풀가동하는 것도 좋지만, 때로는 시스템의 일부분에서 동시성을 **제한**해야 할 때가 있습니다.

너무 많은 요청으로 외부 시스템을 마비시키지 않으려면 말이죠.

이럴 때 사용하는 도구가 바로 **세마포어**(Semaphore)입니다.

## 뮤텍스: 한 번에 하나만

먼저 뮤텍스를 복습해 볼까요? 뮤텍스는 화장실 열쇠와 같습니다. 한 번에 딱 한 명만 들어갈 수 있죠.

```go
type External struct {
    lock sync.Mutex
}

func (e *External) Call() {
    e.lock.Lock()
    defer e.lock.Unlock()
    // 외부 시스템 호출 (한 번에 하나씩만 실행됨)
    time.Sleep(10 * time.Millisecond)
}
```

이 방식은 안전하지만, 동시성을 전혀 활용하지 못합니다.

만약 외부 시스템이 "최대 4개까지는 동시에 처리할 수 있어"라고 한다면? 뮤텍스는 너무 가혹한 제약이 됩니다.

## 세마포어: 한 번에 N개만

우리는 N개의 고루틴이 동시에 실행되도록 허용하고 싶습니다.

세마포어는 **N개의 열쇠가 있는 화장실**이라고 생각하면 됩니다.

1.  `Acquire`: 빈 열쇠가 있으면 가져갑니다. 없으면 대기합니다.
2.  `Release`: 다 쓴 열쇠를 반납합니다. (기다리던 다른 사람이 가져갈 수 있게 됩니다.)

Go에는 `sync.Semaphore`라는 표준 타입이 없지만, 채널을 이용해 쉽게 흉내 낼 수 있습니다.

하지만 여기서는 개념적인 `Semaphore` 타입을 사용한다고 가정하고 코드를 작성해 보겠습니다. (실제로는 `golang.org/x/sync/semaphore` 패키지를 쓰거나 직접 구현합니다.)

```go
type External struct {
    sema Semaphore // 세마포어
}

func NewExternal(maxConc int) *External {
    return &External{NewSemaphore(maxConc)} // 최대 N개 허용
}

func (e *External) Call() {
    e.sema.Acquire() // 열쇠 획득 (꽉 차면 대기)
    defer e.sema.Release() // 열쇠 반납

    // 외부 시스템 호출 (최대 N개 고루틴이 동시 실행)
    time.Sleep(10 * time.Millisecond)
}
```

이제 `Call` 메서드를 호출하는 고루틴이 아무리 많아도, 실제 작업은 최대 N개까지만 동시에 진행됩니다.

나머지는 `Acquire`에서 줄 서서 기다리게 되죠.

### 세마포어 구현해보기 (채널 활용)

사실 Go에서는 **버퍼 있는 채널**이 훌륭한 세마포어 역할을 합니다.

```go
type Semaphore chan struct{}

func NewSemaphore(n int) Semaphore {
    return make(chan struct{}, n) // 버퍼 크기 N
}

func (s Semaphore) Acquire() {
    s <- struct{}{} // 버퍼에 빈 공간이 없으면 블로킹
}

func (s Semaphore) Release() {
    <-s // 버퍼에서 값을 빼내어 공간 확보
}
```

아주 간단하죠? 이것이 Go 스타일의 세마포어입니다.

## 랑데부 (Rendezvous)

두 고루틴이 서로를 기다렸다가 동시에 출발하는 패턴을 **랑데부**(Rendezvous)라고 합니다.

마치 약속 장소에 먼저 도착한 친구가 늦게 오는 친구를 기다렸다가 같이 카페에 가는 것과 같죠.

**시나리오:**
*   고루틴 1: 준비 완료 -> (고루틴 2 기다림) -> 출발
*   고루틴 2: 준비 완료 -> (고루틴 1 기다림) -> 출발

채널을 이용해 구현해 볼까요?

```go
    ready1 := make(chan struct{})
    ready2 := make(chan struct{})

    // 고루틴 1
    wg.Go(func() {
        fmt.Println("1: 준비 완료")
        close(ready1) // 나 준비됐어!
        <-ready2      // 너 준비됐니? (대기)
        fmt.Println("1: 출발!")
    })

    // 고루틴 2
    wg.Go(func() {
        fmt.Println("2: 준비 완료")
        close(ready2) // 나 준비됐어!
        <-ready1      // 너 준비됐니? (대기)
        fmt.Println("2: 출발!")
    })
```

서로 상대방의 신호를 확인한 뒤에야 다음 단계("출발")로 넘어갑니다.

이 패턴은 두 작업의 타이밍을 정확히 맞춰야 할 때 유용합니다.

## 동기화 장벽 (Synchronization Barrier)

랑데부가 둘만의 약속이라면, **장벽**(Barrier)은 단체 미팅입니다.

N명의 고루틴이 모두 특정 지점(장벽)에 도착할 때까지 아무도 지나갈 수 없습니다.

N명이 다 모이면? 장벽이 열리고 모두 와르르 통과합니다.

**활용 예:**
*   **병렬 정렬:** 데이터를 쪼개서 정렬하는 고루틴들이 모두 끝나야 병합(Merge)을 시작할 수 있습니다.
*   **게임 로딩:** 모든 플레이어의 로딩이 끝나야 게임을 시작할 수 있습니다.

장벽을 구현하는 방법은 여러 가지가 있지만, `sync.WaitGroup`을 응용하거나 채널을 조합해서 만들 수 있습니다.

핵심은 **카운터가 N이 될 때까지 대기하고, N이 되면 모든 대기자를 깨운다**는 것입니다.

---

뮤텍스, 세마포어, 랑데부, 장벽...

이들은 모두 고루틴들의 무질서한 질주를 제어하기 위한 신호등과 같습니다.

적재적소에 사용하면 복잡한 동시성 흐름을 아주 우아하게 제어할 수 있습니다.

다음 장에서는 고루틴끼리 신호를 주고받는 또 다른 방법, **시그널링**(Signaling)에 대해 알아보겠습니다.
