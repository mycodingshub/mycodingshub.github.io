---
title: "Go Concurrency 마스터하기: 동시성 코드 테스트, synctest로 시간 여행하기"
date: 2025-12-11T10:10:00+09:00
description: "동시성 코드 테스트의 난관을 극복하는 법! synctest 패키지를 활용해 고루틴 대기, 채널 상태 확인, 고루틴 누수 탐지, 그리고 가짜 시간을 이용한 타임아웃 테스트까지 마스터합니다."
tags: ["Go", "Golang", "Concurrency", "Testing", "Synctest", "Time Travel", "Goroutine Leak", "동시성"]
weight: 12
series: ["Go Concurrency 완벽 가이드"]
series_order: 12
---

잘 설계된 동시성 프로그램은 채널과 웨이트 그룹 같은 표준 도구만으로도 테스트가 가능합니다.

하지만 현실은 늘 복잡하죠.

고루틴이 언제 끝날지 몰라 `time.Sleep`을 넣으며 기도해 본 적이 있나요?

이번 장에서는 Go 1.25에 도입된 혁신적인 **`synctest` 패키지**를 중심으로 동시성 테스트의 신세계를 경험해 보겠습니다.

## 고루틴이 끝날 때까지 기다리기 (Waiting for goroutines)

비동기로 계산하고 결과를 채널로 돌려주는 함수는 테스트가 쉽습니다.

채널에서 값을 받을 때까지 기다리면 되니까요.

```go
func Test(t *testing.T) {
    got := <-Calc() // 채널 수신 대기 (자동 동기화)
    if got != 42 { t.Errorf(...) }
}
```

하지만 채널을 반환하지 않고 내부 상태만 바꾸는 함수라면 어떨까요?

```go
func Calc() {
    go func() { state.Store(42) }()
}
```

이걸 테스트하려면 고루틴이 끝날 때까지 기다려야 하는데, `time.Sleep`은 불안정하고 느립니다.

이때 `synctest`가 등장합니다.

### synctest 사용하기

`synctest.Test`는 고립된 **버블**(Bubble)을 만듭니다.

이 안에서 생성된 고루틴들은 모두 버블의 일부가 되며, `synctest.Wait`를 통해 완벽하게 제어할 수 있습니다.

```go
func TestSync(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        Calc() // 내부 고루틴 실행

        synctest.Wait() // 모든 자식 고루틴이 멈출 때까지 대기

        got := state.Load()
        if got != 42 { t.Errorf(...) }
    })
}
```

`synctest.Wait`는 버블 안의 다른 모든 고루틴이 종료되거나 **영구적으로 블로킹**(durably blocked)될 때까지 현재 고루틴을 멈춥니다.

덕분에 `time.Sleep` 없이도 즉시 테스트가 통과됩니다.

## 채널 상태 확인하기

채널이 제대로 닫혔는지 확인하고 싶을 때도 `synctest`가 유용합니다.

```go
func TestClose(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        out := Generate(2)
        <-out; <-out // 데이터 소비

        synctest.Wait() // 생성 고루틴이 끝날 때까지 대기

        // 이제 채널은 닫혀있어야 함
        select {
        case _, ok := <-out:
            if ok { t.Errorf("채널이 닫히지 않음") }
        default:
            t.Errorf("채널이 닫히지 않음")
        }
    })
}
```

`synctest.Wait` 덕분에 고루틴 종료와 채널 닫힘이 보장된 상태에서 안전하게 검사할 수 있습니다.

## 고루틴 누수 탐지 (Checking for leaks)

고루틴 누수는 동시성 프로그램의 암적인 존재입니다.

`synctest`는 이를 자동으로 잡아냅니다.

```go
func TestLeak(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        // 버퍼 없는 채널에 쓰려다 블로킹된 고루틴 발생!
        Map(func() int { return 11 }) 
        
        synctest.Wait()
    })
}
```

테스트가 끝날 때, 버블 안에 여전히 블로킹된 고루틴이 있다면 `synctest`는 패닉을 일으키며 누수를 알려줍니다.

`main bubble goroutine has exited but blocked goroutines remain`

## 영구적 블로킹 (Durable blocking)

`synctest.Wait`는 고루틴이 **영구적으로 블로킹**되었다고 판단하면 대기를 풉니다.

`synctest`가 정의하는 영구적 블로킹은 다음과 같습니다:

*   버블 내부 채널의 송수신
*   버블 내부 채널들로만 구성된 `select`
*   `WaitGroup.Wait`
*   `Cond.Wait`
*   `time.Sleep`

반면, **뮤텍스 잠금(`Lock`)**, **I/O**, **외부 채널** 등은 영구적 블로킹으로 간주하지 않습니다.

따라서 뮤텍스 락 때문에 멈춘 고루틴은 `synctest.Wait`가 기다려주지 않고 무시하거나 타임아웃이 발생할 수 있습니다.

## 시간 여행: 즉시 대기 (Instant waiting)

`synctest` 버블 안의 시간은 **가짜 시계**(Fake Clock)를 사용합니다.

이 시계는 필요할 때 미래로 점프할 수 있습니다.

3초 뒤에 타임아웃이 발생하는 코드를 테스트해 볼까요?

```go
func TestTimeout(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        ch := make(chan int)
        // 3초 타임아웃이 있는 함수 실행
        _, err := Calc(ch) 
        
        if err != ErrTimeout { t.Errorf(...) }
    })
}
```

놀랍게도 이 테스트는 **즉시 실행**됩니다!

버블 안의 모든 고루틴이 블로킹 상태이고, 이를 풀 수 있는 유일한 방법이 시간 경과라면, 가짜 시계는 즉시 3초 뒤로 이동합니다.

덕분에 타임아웃 테스트를 기다릴 필요 없이 순식간에 끝낼 수 있습니다.

**주의:** 시간 여행이 작동하려면 모든 고루틴이 영구적으로 블로킹되어 있어야 합니다. (예: `select`나 `time.Sleep`에 갇혀있음)

## 종료 및 리소스 해제 확인 (Cleanup)

서버나 워커를 종료할 때 고루틴이 잘 정리되는지 확인하려면 `defer`나 `t.Cleanup`을 활용하세요.

```go
func TestServerStop(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        srv := NewServer()
        srv.Start()
        t.Cleanup(srv.Stop) // 테스트 종료 직전 실행

        // ... 테스트 로직 ...
    })
}
```

`t.Cleanup`은 `synctest.Test`가 끝나기 직전에 실행됩니다.

이때 `Stop`이 호출되어 내부 고루틴이 종료되면, 버블은 "모든 고루틴 종료됨"을 확인하고 깔끔하게 테스트를 마칩니다.

만약 `Stop`이 제대로 동작하지 않아 고루틴이 남으면? 바로 패닉으로 알려줍니다.

`t.Context()`를 사용하면 테스트 종료 시 자동으로 취소되는 컨텍스트를 얻을 수 있어 더 편리합니다.

---

`synctest` 패키지는 동시성 테스트의 게임 체인저입니다.

이제 우리는 불안정한 `time.Sleep`이나 복잡한 목킹(Mocking) 없이도, 시간을 제어하며 정교한 동시성 테스트를 작성할 수 있게 되었습니다.

다음 장에서는 동시성의 내부 동작 원리에 대해 더 깊이 파고들어 보겠습니다.
