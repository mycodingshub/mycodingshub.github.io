---
title: "Go Concurrency 마스터하기: 컨텍스트(Context), 취소와 타임아웃의 마법사"
date: 2025-12-11T08:50:00+09:00
description: "고루틴을 제어하는 만능 키, 컨텍스트(Context)를 정복합니다. 우아한 종료(Graceful Shutdown), 타임아웃, 데드라인 설정부터 Go 1.21 최신 기능까지 낱낱이 파헤칩니다."
tags: ["Go", "Golang", "Concurrency", "Context", "Cancellation", "Timeout", "동시성"]
weight: 5
series: ["Go Concurrency 완벽 가이드"]
series_order: 5
---

프로그래밍에서 **컨텍스트**(Context)는 어떤 작업이 실행되는 환경 정보를 의미합니다.

Go에서 `context`라고 하면 보통 표준 패키지인 `context.Context` 인터페이스를 말하는데요.

원래는 HTTP 요청 처리를 쉽게 하려고 만들어졌지만, 지금은 모든 동시성 코드에서 **작업 취소**와 **타임아웃 관리**의 표준으로 자리 잡았습니다.

자, 이제 채널만 쓰던 구식 방식에서 벗어나 컨텍스트의 세계로 들어가 볼까요?

## 채널로 취소하기 (복습)

먼저, 채널을 사용해 작업을 취소하는 기존 방식을 다시 한번 살펴봅시다.


```go
// execute는 fn을 고루틴에서 실행하고, 취소되지 않으면 결과를 반환합니다.
func execute(cancel <-chan struct{}, fn func() int) (int, error) {
    ch := make(chan int, 1)

    go func() {
        ch <- fn()
    }()

    select {
    case res := <-ch:
        return res, nil
    case <-cancel: // 취소 신호 수신
        return 0, errors.New("canceled")
    }
}
```

이 방식은 `cancel` 채널을 닫아서(`close`) 모든 고루틴에게 종료 신호를 보내는 방식입니다.

익숙하고 잘 동작하지만, **컨텍스트**를 쓰면 이 패턴을 훨씬 더 우아하고 강력하게 만들 수 있습니다.

## 컨텍스트로 취소하기 (Canceling with context)

Go에서 컨텍스트의 주된 목적은 **작업 취소**(Cancellation)입니다.

방금 본 `execute` 함수를 컨텍스트 버전으로 바꿔보겠습니다.


```go
func execute(ctx context.Context, fn func() int) (int, error) {
    // ... (고루틴 실행 부분 동일) ...

    select {
    case res := <-ch:
        return res, nil
    case <-ctx.Done():       // (1) 취소 신호 채널
        return 0, ctx.Err()  // (2) 취소 원인 에러 반환
    }
}
```

코드 구조는 거의 똑같습니다.

➊ `cancel` 채널 대신 `ctx.Done()` 채널을 감시합니다.

➋ "canceled" 에러를 직접 만드는 대신 `ctx.Err()`를 반환합니다.


클라이언트 코드는 이렇게 바뀝니다.


```go
func main() {
    ctx := context.Background()              // (1) 빈 컨텍스트 생성
    ctx, cancel := context.WithCancel(ctx)   // (2) 취소 가능한 컨텍스트 생성
    defer cancel()                           // (3) 함수 종료 시 자동 취소 예약

    go maybeCancel(cancel)                   // (4) 50% 확률로 취소 호출

    res, err := execute(ctx, work)           // (5)
    fmt.Println(res, err)
}
```

`context.WithCancel`은 부모 컨텍스트를 받아 **새로운 자식 컨텍스트**와 **취소 함수**(cancel function)를 반환합니다.

이 `cancel()` 함수를 호출하면 해당 컨텍스트와 그 자식 컨텍스트들의 `Done()` 채널이 닫히고 리소스가 해제됩니다.


**컨텍스트의 중요한 특징들:**

1.  **계층 구조:** 컨텍스트는 불변(Immutable)입니다. 기능을 추가하려면 기존 것(부모)을 감싸서 새 것(자식)을 만들어야 합니다.

    (예: `Background` -> `WithCancel` -> `WithTimeout`)
2.  **취소 전파:** 부모 컨텍스트가 취소되면 모든 자식들도 자동으로 취소됩니다. (반대는 성립하지 않습니다.)
3.  **안전한 다중 호출:** 채널 `close`를 두 번 하면 패닉이 나지만, `cancel()` 함수는 여러 번 호출해도 안전합니다(첫 호출만 유효하고 나머지는 무시됩니다).

## 타임아웃 (Timeout)

컨텍스트의 진짜 매력은 **수동 취소**와 **시간 제한**(Timeout)을 똑같은 방식으로 처리할 수 있다는 점입니다.


```go
func main() {
    timeout := 50 * time.Millisecond
    // 50ms가 지나면 자동으로 취소되는 컨텍스트 생성
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel() // 타임아웃 전에 일이 끝나더라도 리소스 해제를 위해 호출해야 함

    res, err := execute(ctx, work)
    fmt.Println(res, err)
}
```

`context.WithTimeout`을 사용하면 지정된 시간이 지난 후 자동으로 컨텍스트가 취소됩니다.

이때 `execute` 함수는 전혀 수정할 필요가 없습니다.

수동 취소든 타임아웃이든, `execute` 입장에서는 `ctx.Done()`이 닫히는 건 똑같거든요.

(에러 메시지는 `context deadline exceeded`로 다르게 나옵니다.)

### 부모와 자식의 타임아웃

부모 컨텍스트에 200ms 제한이 있는데, 자식 컨텍스트에 50ms 제한을 걸면 어떻게 될까요?

자식은 50ms 뒤에 취소됩니다.


반대로 부모가 200ms, 자식이 500ms라면요?

**더 짧은 쪽(부모의 200ms)이 이깁니다.**

자식 컨텍스트는 부모의 제약보다 더 오래 살아남을 수 없습니다.

## 데드라인 (Deadline)

`WithTimeout`이 "지금부터 5초 뒤"라면, `WithDeadline`은 "오늘 오후 3시 정각"처럼 **특정 시각**을 지정합니다.

사실 `WithTimeout`은 내부적으로 `WithDeadline`을 호출해서 구현되어 있습니다.


```go
    deadline := time.Now().Add(150 * time.Millisecond)
    ctx, cancel := context.WithDeadline(context.Background(), deadline)
    defer cancel()
```

## 취소 원인 (Cancellation cause) - Go 1.20+

기존에는 컨텍스트가 취소되면 `context canceled`라는 단순한 에러만 얻을 수 있었습니다.

"왜 취소됐는지" 이유를 알고 싶다면 Go 1.20부터 추가된 기능을 쓰면 됩니다.


```go
    // Go 1.20+
    ctx, cancel := context.WithCancelCause(context.Background())
    cancel(errors.New("밤이 너무 어두워서 취소함")) // 취소 이유 전달

    fmt.Println(context.Cause(ctx)) 
    // "밤이 너무 어두워서 취소함"
```

Go 1.21부터는 타임아웃 시에도 원인을 지정할 수 있는 `WithTimeoutCause`도 추가되었습니다.


## context.AfterFunc - Go 1.21+

컨텍스트가 취소되었을 때 **후처리 작업**(Cleanup)을 하고 싶다면 어떻게 할까요?

기존에는 고루틴을 하나 띄워서 `<-ctx.Done()`을 기다리게 했습니다.

하지만 Go 1.21에 추가된 `context.AfterFunc`를 쓰면 훨씬 깔끔합니다.


```go
    ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
    defer cancel()

    // 컨텍스트가 취소되면 cleanup 함수가 별도 고루틴에서 실행됨
    stopCleanup := context.AfterFunc(ctx, cleanup)
    
    // ... 작업 수행 ...

    // 만약 작업이 성공해서 cleanup이 필요 없다면?
    stopCleanup() // 예약된 함수 실행 취소
```

`AfterFunc`는 컨텍스트가 취소되는 순간 실행될 콜백 함수를 등록합니다.

만약 등록 시점에 이미 취소된 컨텍스트라면 즉시 실행됩니다.

반환된 함수(`stopCleanup`)를 호출하면 예약된 실행을 취소할 수도 있습니다.


## 값을 담은 컨텍스트 (Context with values)

컨텍스트는 취소뿐만 아니라, **요청 범위의 데이터**(Request-scoped data)를 전달하는 저장소 역할도 합니다.

`context.WithValue`를 사용하면 됩니다.


```go
    type contextKey string
    var userKey = contextKey("user")

    // "user" 키에 "admin" 값을 저장
    ctx = context.WithValue(ctx, userKey, "admin")
```

꺼낼 때는 `Value()` 메서드를 씁니다.


```go
    if user := ctx.Value(userKey); user != nil {
        fmt.Println("User:", user)
    }
```

**주의할 점:**
1.  키 충돌을 막기 위해 문자열 대신 **전용 타입**(custom type)을 키로 사용하세요.
2.  이 기능은 정말 필요한 경우(로그 ID, 인증 토큰 등)에만 제한적으로 사용하세요. 함수의 파라미터로 명시적으로 전달하는 것이 훨씬 명확하고 좋습니다.


---

이제 여러분은 컨텍스트를 이용해 동시성 작업을 안전하게 취소하고, 타임아웃을 걸고, 필요한 메타 데이터를 전달하는 방법을 마스터했습니다.

특히 원격 호출이나 긴 파이프라인 작업에서 컨텍스트는 선택이 아닌 필수입니다.


다음 장에서는 여러 고루틴을 기다리는 또 다른 방법, **웨이트 그룹**(Wait Groups)에 대해 깊이 있게 다뤄보겠습니다.
