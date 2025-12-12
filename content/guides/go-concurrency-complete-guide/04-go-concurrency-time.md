---
title: "Go Concurrency 마스터하기: 시간(Time) 다루기, 더 이상 Sleep은 그만"
date: 2025-12-11T08:40:00+09:00
description: "스로틀링, 백프레셔, 타임아웃, 타이머, 티커까지. Go 동시성 프로그램에서 시간을 정교하게 제어하는 모든 기법을 정리했습니다."
tags: ["Go", "Golang", "Concurrency", "Time", "Timer", "Ticker", "Context", "동시성"]
weight: 4
series: ["Go Concurrency 완벽 가이드"]
series_order: 4
---

이번 장에서는 동시성 프로그램에서 **시간**(Time)을 다루는 다양한 기법들을 살펴봅니다.

단순히 `time.Sleep`을 쓰는 것 말고도 훨씬 우아하고 강력한 도구들이 많거든요.

**스로틀링**(Throttling)부터 **백프레셔**(Backpressure), **타임아웃**, 그리고 **타이머와 티커**까지 낱낱이 파헤쳐 봅시다.

## 스로틀링 (Throttling)

처리하는 데 시간이 꽤 걸리는 작업이 있다고 가정해 봅시다.


```go
func work() {
    // 중요한 작업이지만, 속도가 빠르진 않습니다.
    time.Sleep(100 * time.Millisecond)
}
```

가장 쉬운 방법은 순차적으로 처리하는 거겠죠.

하지만 4번 호출하면 400ms가 걸립니다. 너무 느리죠.


```go
func main() {
    start := time.Now()
    work(); work(); work(); work()
    fmt.Println("4 calls took", time.Since(start))
}
```

당연히 우리는 고루틴을 써서 병렬로 처리하고 싶습니다.

하지만 무제한으로 병렬 처리를 할 수는 없습니다. 동시에 실행될 수 있는 작업의 수를 제한해야 하죠.

이전에 채널 편에서 배웠던 **세마포어(Semaphore)** 패턴을 기억하시나요? 그걸 활용해 `throttle` 래퍼 함수를 만들어 보겠습니다.


```go
func throttle(n int, fn func()) (handle func(), wait func()) {
    // n개의 고루틴을 위한 세마포어
    sema := make(chan struct{}, n)

    // 동시 실행 수를 n개로 제한하여 fn 실행
    handle = func() {
        sema <- struct{}{} // 자리가 날 때까지 여기서 대기 (블로킹)
        go func() {
            fn()
            <-sema // 작업이 끝나면 자리 비워줌
        }()
    }

    // 모든 작업이 끝날 때까지 대기
    wait = func() {
        for range n {
            sema <- struct{}{}
        }
    }

    return handle, wait
}
```

이제 클라이언트는 `throttle`을 통해 작업을 요청합니다.


```go
func main() {
    handle, wait := throttle(2, work) // 동시 실행 2개로 제한
    start := time.Now()

    handle(); handle(); handle(); handle()
    wait()

    fmt.Println("4 calls took", time.Since(start))
}
```

결과는? **200ms**만에 끝납니다!

첫 번째와 두 번째 호출은 즉시 실행되고, 세 번째와 네 번째 호출은 앞선 작업이 끝나기를 기다렸다가 실행되기 때문입니다.


이 방식은 요청량과 처리 속도가 어느 정도 균형이 맞을 때 아주 좋습니다.

하지만 요청이 감당할 수 없을 정도로 쏟아진다면? 시스템은 결국 느려지고, `handle()` 호출은 세마포어 자리를 얻기 위해 하염없이 기다리게 됩니다.


이럴 때 클라이언트에게 무작정 기다리게 하는 대신, "지금은 바빠요!"라고 즉시 에러를 뱉어주는 게 더 나을 수도 있습니다.

그게 바로 **백프레셔**(Backpressure)입니다.

## 백프레셔 (Backpressure)

로직을 조금 바꿔봅시다.

1. 세마포어에 자리가 있으면 작업을 실행한다.
2. **자리가 없으면 즉시 에러를 반환한다.**

이때 필요한 게 바로 `select` 문과 `default` 케이스입니다.


```go
handle = func() error {
    select {
    case sema <- struct{}{}: // 자리가 있으면 토큰 넣고 실행
        go func() {
            fn()
            <-sema
        }()
        return nil
    default: // 자리가 없으면 기다리지 않고 바로 에러 리턴!
        return errors.New("busy")
    }
}
```

`select`의 `default` 케이스는 다른 모든 케이스가 블로킹 상태일 때(즉, 준비되지 않았을 때) 실행됩니다.

세마포어가 꽉 차서 `sema <- struct{}{}`를 할 수 없다면, 바로 `default`로 넘어가서 "busy" 에러를 뱉는 거죠.


이제 클라이언트는 무한정 기다리는 대신, 에러를 받고 나중에 다시 시도하거나 요청 빈도를 줄이는 등의 조치를 취할 수 있게 됩니다.


## 작업 타임아웃 (Operation timeout)

가끔씩 너무 오래 걸리는 작업이 문제일 때가 있습니다.

평소엔 10ms면 끝나는데, 20% 확률로 200ms나 걸리는 변덕쟁이 함수가 있다고 칩시다.

우리는 50ms 이상은 기다려줄 생각이 없습니다.


작업에 제한 시간(Timeout)을 거는 `withTimeout` 래퍼를 만들어 볼까요?


```go
// withTimeout은 주어진 시간 내에 함수를 실행하고, 시간을 초과하면 에러를 반환합니다.
func withTimeout(timeout time.Duration, fn func() int) (int, error) {
    done := make(chan struct{})
    var result int

    go func() {
        result = fn()
        close(done) // 작업 완료 알림
    }()

    select {
    case <-done: // 작업이 제시간에 끝남
        return result, nil
    case <-time.After(timeout): // 시간 초과!
        return 0, errors.New("timeout")
    }
}
```

여기서 핵심은 `time.After(timeout)` 함수입니다.

이 함수는 지정된 시간이 지나면 현재 시간을 보내주는 채널을 반환합니다.

`select` 문은 `done` 채널(작업 완료)과 `time.After` 채널(시간 초과) 중 **먼저 도착하는 신호**를 처리하게 됩니다.


## 타이머 (Timer)

일정 시간 뒤에 어떤 작업을 하고 싶다면 **타이머(Timer)**를 쓰면 됩니다.


```go
    timer := time.NewTimer(100 * time.Millisecond) // (1)
    go func() {
        <-timer.C  // (2) 100ms가 지날 때까지 대기
        work()
    }()
```

`time.NewTimer`는 타이머 구조체를 반환하는데, 이 안에는 `C`라는 채널이 있습니다.

시간이 다 되면 이 채널로 현재 시간이 배달됩니다 ➋.


타이머의 장점은 중간에 취소할 수 있다는 겁니다.


```go
    if timer.Stop() {
        fmt.Println("타이머가 취소되었습니다!")
    }
```

`Stop()` 메서드는 타이머가 아직 울리지 않았다면 `true`를 반환하고 타이머를 멈춥니다.

만약 이미 울렸다면 `false`를 반환하죠.


**꿀팁:** 단순히 일정 시간 뒤에 함수를 실행하는 게 목적이라면 `time.AfterFunc`를 쓰는 게 훨씬 편합니다.


```go
    // 100ms 뒤에 work 실행 (고루틴을 직접 만들 필요 없음)
    timer := time.AfterFunc(100*time.Millisecond, work)
    
    // 취소도 가능
    timer.Stop() 
```

## 타이머 리셋 (Timer reset)과 GC 이슈

만약 루프를 돌면서 매번 `time.After`를 호출한다면 어떻게 될까요?


```go
    for {
        select {
        case <-time.After(time.Hour): // 매 반복마다 타이머 생성!
            // ...
        }
    }
```

`time.After`는 매번 새로운 타이머를 생성합니다.

루프가 아주 빠르게 돈다면 수많은 타이머가 생성되고, 가비지 컬렉터(GC)에게 큰 부담을 주게 됩니다.


이럴 때는 타이머를 하나만 만들고 계속 **재사용(Reset)**하는 것이 좋습니다.


**Go 1.23 이상**에서는 `Reset` 메서드가 아주 깔끔하게 동작합니다.


```go
    timer := time.NewTimer(timeout)
    for {
        timer.Reset(timeout) // 타이머 재설정
        select {
        case <-in:
            // ...
        case <-timer.C:
            // ...
        }
    }
```

하지만 **Go 1.23 미만** 버전을 쓰고 계신다면 주의해야 합니다.

타이머가 이미 종료되었거나 멈춘 상태이고, 채널이 비워져 있어야만 `Reset`이 안전하게 동작하기 때문입니다.

그래서 보통 `resetTimer` 같은 헬퍼 함수를 만들어 써야 했습니다. (복잡하죠? 가능하면 최신 Go 버전을 쓰세요!)


## 티커 (Ticker)

타이머가 "알람"이라면, **티커**(Ticker)는 "메트로놈"입니다.

일정 간격으로 계속 신호를 보내주죠.


```go
func main() {
    ticker := time.NewTicker(50 * time.Millisecond)
    defer ticker.Stop() // 꼭 멈춰줘야 리소스가 해제됩니다.

    go func() {
        for {
            at := <-ticker.C // 50ms마다 신호 도착
            work(at)
        }
    }()

    time.Sleep(260 * time.Millisecond) // 약 5번 실행됨
}
```

재미있는 점은 작업을 처리하는 속도가 티커의 주기보다 느리면 어떻게 되냐는 건데요.

티커는 멍청하게 신호를 쌓아두지 않습니다.

받는 쪽이 준비되지 않았으면 그냥 **건너뜁니다**(Skip).

덕분에 채널이 폭발할 걱정 없이 안전하게 주기적인 작업을 할 수 있습니다.


---

이제 여러분은 단순히 `time.Sleep`으로 떼우는 것이 아니라, 상황에 맞는 정교한 시간 제어 도구들을 손에 넣었습니다.


*   **스로틀링:** 동시 실행 수 제한
*   **백프레셔:** 바쁠 땐 과감히 거절하기 (`default` 케이스)
*   **타임아웃:** 무한 대기 방지 (`time.After`)
*   **타이머 & 티커:** 지연 실행과 주기적 실행

다음 장에서는 동시성 프로그래밍의 마법 지팡이, **컨텍스트**(Context)에 대해 알아보겠습니다.

기대해 주세요!
