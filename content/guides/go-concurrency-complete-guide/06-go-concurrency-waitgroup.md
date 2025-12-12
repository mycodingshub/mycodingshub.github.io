---
title: "Go Concurrency 마스터하기: 웨이트 그룹(WaitGroup), 동기화의 핵심 도구"
date: 2025-12-11T09:00:00+09:00
description: "고루틴 동기화를 위한 필수 도구, sync.WaitGroup의 내부 원리부터 실전 캡슐화 패턴까지 상세히 다룹니다. 값 복사 문제와 패닉 처리 방법도 놓치지 마세요."
tags: ["Go", "Golang", "Concurrency", "WaitGroup", "Sync", "Panic", "동시성"]
weight: 6
series: ["Go Concurrency 완벽 가이드"]
series_order: 6
---

Go에서 채널은 만능 동시성 도구입니다.

지금까지 우리는 채널을 이용해 **데이터 전달**, **동기화**(Done 채널), **취소**(Cancel 채널) 등을 다뤘습니다.


데이터 전달은 채널의 본업이니 아주 잘 해내죠.

작업 취소는 **컨텍스트**(Context)라는 전문 도구가 있었습니다.

그렇다면 고루틴 동기화는 어떨까요? 여기서 등장하는 전문 도구가 바로 **웨이트 그룹**(Wait Group)입니다.

## 웨이트 그룹 (Wait Group)

웨이트 그룹은 하나 이상의 고루틴이 끝날 때까지 기다리게 해줍니다.

먼저 Done 채널을 이용한 방식과 비교해 볼까요?

**Done 채널 방식:**

```go
func main() {
    done := make(chan struct{}, 1)

    go func() {
        time.Sleep(50 * time.Millisecond)
        fmt.Print(".")
        done <- struct{}{}
    }()

    <-done
    fmt.Println("done")
}
```

**웨이트 그룹 방식:**

```go
func main() {
    var wg sync.WaitGroup

    wg.Add(1)
    go func() {
        time.Sleep(50 * time.Millisecond)
        fmt.Print(".")
        wg.Done()
    }()

    wg.Wait()
    fmt.Println("done")
}
```

재미있는 점은 `WaitGroup`이 자신이 관리하는 고루틴에 대해 아무것도 모른다는 사실입니다.

오로지 내부 **카운터** 하나로만 동작합니다.

*   `wg.Add(1)`: 카운터를 1 올립니다.
*   `wg.Done()`: 카운터를 1 내립니다.
*   `wg.Wait()`: 카운터가 0이 될 때까지 대기합니다(블로킹).

**Go 1.25+ `wg.Go()` 메서드:**
Go 1.25부터는 `Add`와 `Done`을 자동으로 처리해 주는 `wg.Go()` 메서드가 추가되었습니다.

```go
func main() {
    var wg sync.WaitGroup

    wg.Go(func() {
        time.Sleep(50 * time.Millisecond)
        fmt.Print(".")
    })

    wg.Wait()
    fmt.Println("done")
}
```

보통 **결과값 없이 작업 완료만 기다릴 때**는 Done 채널보다 웨이트 그룹을 사용하는 것이 표준입니다.

## 내부 동작 원리 (Inner world)

웨이트 그룹의 개념적 구현은 대략 이렇습니다. (실제 구현은 훨씬 복잡하고 최적화되어 있습니다.)

```go
type WaitGroup struct {
    n int // 카운터
}

func (wg *WaitGroup) Add(delta int) {
    wg.n += delta
    if wg.n < 0 {
        panic("negative counter") // 카운터가 음수가 되면 패닉!
    }
}

func (wg *WaitGroup) Done() {
    wg.Add(-1)
}

func (wg *WaitGroup) Wait() {
    for wg.n > 0 {} // 0이 될 때까지 대기
}
```

**핵심 특성:**
1.  `Add`는 양수뿐만 아니라 음수도 받을 수 있습니다. (하지만 보통 `Done`을 쓰죠.)
2.  `Wait`는 카운터가 0이 되면 즉시 풀립니다. (카운터가 0일 때 `Wait`를 호출하면 그냥 통과합니다.)
3.  `Wait`가 끝난 후 카운터는 다시 0이 되므로, 웨이트 그룹을 **재사용**할 수 있습니다.

## 값 vs 포인터 (Value vs. pointer)

초보자들이 가장 많이 하는 실수가 바로 웨이트 그룹을 **값으로 전달**(Pass by value)하는 것입니다.

Go에서 구조체를 값으로 넘기면 **복사본**이 생성되는데, 웨이트 그룹은 내부 카운터까지 복사되어 버립니다.


**잘못된 예 (값 전달):**

```go
func runWork(wg sync.WaitGroup) { // wg가 복사됨!
    wg.Add(1)
    go func() {
        wg.Done() // 복사본의 카운터만 줄어듦
    }()
}

func main() {
    var wg sync.WaitGroup
    runWork(wg) // main의 wg는 카운터가 여전히 0
    wg.Wait()   // 기다리지 않고 바로 통과!
}
```

`runWork`는 복사된 `wg`를 가지고 놀기 때문에, `main` 함수에 있는 원본 `wg`에는 아무런 영향을 주지 못합니다.

따라서 반드시 **포인터**로 전달해야 합니다.

**올바른 예 (포인터 전달):**

```go
func runWork(wg *sync.WaitGroup) { // 포인터로 받음
    wg.Add(1)
    // ...
}

func main() {
    var wg sync.WaitGroup
    runWork(&wg) // 주소 전달
    wg.Wait()
}
```

## 캡슐화 (Encapsulation)

하지만 가장 좋은 방법은 클라이언트가 웨이트 그룹의 존재조차 모르게 하는 것입니다.

동기화 로직을 함수나 구조체 내부로 숨기는(캡슐화) 것이죠.

**함수로 감싸기:**

```go
// RunConc는 함수들을 동시에 실행하고 모두 끝날 때까지 기다립니다.
func RunConc(funcs ...func()) {
    var wg sync.WaitGroup
    wg.Add(len(funcs))
    for _, fn := range funcs {
        go func() {
            defer wg.Done()
            fn()
        }()
    }
    wg.Wait()
}
```

이제 클라이언트는 `sync.WaitGroup`을 import 할 필요도 없이 편하게 쓸 수 있습니다.

**구조체로 감싸기:**

조금 더 복잡한 요구사항(작업 추가 후 나중에 한 번에 실행 등)이 있다면 전용 타입을 만들 수도 있습니다.

```go
type ConcRunner struct {
    wg    sync.WaitGroup
    funcs []func()
}

func (cg *ConcRunner) Run() {
    cg.wg.Add(len(cg.funcs))
    // ... 고루틴 실행 ...
    cg.wg.Wait()
}
```

여기서 `wg` 필드를 포인터(`*sync.WaitGroup`)가 아닌 값(`sync.WaitGroup`)으로 선언해도 되는 이유는,

`ConcRunner`의 메서드들이 포인터 리시버(`func (cg *ConcRunner)`)를 사용하기 때문에 `cg.wg`도 원본을 참조하기 때문입니다.

## Wait 이후에 Add 하기?

보통은 `Wait` 호출 전에 모든 `Add`를 마칩니다.

하지만 기술적으로는 `Wait` 도중에 다른 고루틴에서 `Add`를 호출하는 것도 가능합니다.

(물론 복잡해져서 잘 쓰지는 않습니다.)

또한 여러 고루틴에서 동시에 `wg.Wait()`를 호출할 수도 있습니다.

이 경우 모든 `Wait` 호출자가 블로킹되었다가, 카운터가 0이 되는 순간 다 같이 깨어납니다.

이 특성은 나중에 **세마포어** 패턴 등에서 활용될 수 있습니다.

## 패닉 처리 (Panic)

웨이트 그룹으로 관리되는 고루틴에서 패닉이 발생하면 어떻게 될까요?


```go
func work() {
    panic("으악!")
}

func main() {
    var wg sync.WaitGroup
    wg.Go(work)
    wg.Wait()
}
```

`main` 함수에 `recover`를 심어놔도 소용없습니다.

**패닉은 발생한 고루틴 안에서만 잡을 수 있기 때문입니다.**

부모 고루틴(main)은 자식 고루틴의 패닉을 직접 받아낼 수 없습니다.

각 고루틴 내부에서 `defer recover()`를 사용해 개별적으로 처리해야 합니다.

```go
    for range 4 {
        wg.Go(func() {
            defer func() {
                if r := recover(); r != nil {
                    fmt.Println("패닉 복구됨:", r)
                }
            }()
            work()
        })
    }
```

이때, 여러 고루틴이 공유 변수(예: `panicked` 플래그)를 건드리게 되면 **경쟁 상태**(Race Condition)가 발생할 수 있으니 주의해야 합니다.


---

이제 웨이트 그룹을 사용해 고루틴들을 확실하게 기다리는 법을 알게 되었습니다.

다음 장에서는 동시성 프로그래밍의 가장 큰 골칫덩어리, **데이터 경쟁**(Data Race)에 대해 깊이 파고들어 보겠습니다.
