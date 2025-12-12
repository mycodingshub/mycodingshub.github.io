---
title: "Go Concurrency 마스터하기: 파이프라인(Pipeline) 패턴과 에러 처리"
date: 2025-12-11T08:30:00+09:00
description: "고루틴과 채널을 조립해 데이터 파이프라인을 구축하는 방법을 배웁니다. 고루틴 누수 방지, 취소(Cancel) 패턴, 그리고 우아한 에러 처리까지 실전 팁을 대방출합니다."
tags: ["Go", "Golang", "Concurrency", "Pipeline", "Select", "Error Handling", "동시성"]
weight: 3
series: ["Go Concurrency 완벽 가이드"]
series_order: 3
---

지금까지 우리는 고루틴과 채널이라는 강력한 재료들을 손질하는 법을 배웠습니다.

이제 이 재료들을 조립해서 **동시성 파이프라인**(Concurrent Pipeline)이라는 근사한 요리를 만들어볼 차례입니다.


하지만 그전에, 동시성 요리를 망치는 가장 흔한 실수, '고루틴 누수'부터 잡고 가시죠.

## 고루틴 누수 (Leaked goroutine)

여기 숫자를 특정 범위만큼 채널로 보내는 함수가 있습니다.


```go
func rangeGen(start, stop int) <-chan int {
    out := make(chan int)
    go func() {
        for i := start; i < stop; i++ {
            out <- i
        }
        close(out)
    }()
    return out
}
```

언뜻 보면 문제없어 보입니다.


```go
func main() {
    generated := rangeGen(41, 46)
    for val := range generated {
        fmt.Println(val)
    }
}
```

하지만 만약 루프를 중간에 빠져나온다면 어떻게 될까요?


```go
func main() {
    generated := rangeGen(41, 46)
    for val := range generated {
        fmt.Println(val)
        if val == 42 {
            break // 42까지만 출력하고 탈출!
        }
    }
}
```

`main` 함수는 루프를 빠져나오고 채널 읽기를 중단합니다.

하지만 `rangeGen` 안의 고루틴은 아직 `43`을 보내려고 안간힘을 쓰고 있습니다.


```go
// rangeGen 내부
for i := start; i < stop; i++ {    // (1)
    out <- i                       // (2) 블로킹!
}
```

`out` 채널을 읽어주는 사람이 없으니 이 고루틴은 ➋ 지점에서 영원히 멈춰버립니다(Blocked).

고루틴이 종료되지 않고 메모리에 계속 남아있는 현상, 이것이 바로 **고루틴 누수**입니다.

고루틴이 가볍다고는 하지만, 이런 '좀비 고루틴'이 수천 개씩 쌓이면 결국 메모리 부족 사태가 벌어집니다.


이 고루틴을 강제로 종료시킬 방법이 필요합니다.

## 취소 채널 (Cancel channel)

`main` 함수에서 `rangeGen`에게 "이제 그만하고 퇴근해"라고 신호를 보내면 어떨까요?

별도의 `cancel` 채널을 만들어서 말이죠.


```go
func main() {
    cancel := make(chan struct{})    // (1)
    defer close(cancel)              // (2)

    generated := rangeGen(cancel, 41, 46)    // (3)
    // ... (생략) ...
}
```

`cancel` 채널을 만들고 ➊, 함수 종료 시 닫히도록 `defer`를 걸어둡니다 ➋.

그리고 이 채널을 고루틴에게 전달합니다 ➌.


이제 `rangeGen`은 두 가지 일을 해야 합니다.

1. `out` 채널로 숫자를 보낸다.

2. `cancel` 채널이 닫히면 즉시 종료한다.


이걸 동시에 처리하려면 `select` 문이 필요합니다.


```go
func rangeGen(cancel <-chan struct{}, start, stop int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for i := start; i < stop; i++ {
            select {
            case out <- i:    // (1)
            case <-cancel:    // (2)
                return
            }
        }
    }()
    return out
}
```

`select`는 준비된 케이스 중 하나를 실행합니다.

`main`이 데이터를 읽고 있다면 ➊이 실행되어 값을 보냅니다.

만약 `main`이 루프를 탈출해서 `defer close(cancel)`이 실행되면, `cancel` 채널이 닫히면서 ➋ 케이스가 선택되어 고루틴이 종료됩니다.


이제 `main`이 언제 멈추든 상관없이 고루틴 누수는 발생하지 않습니다.


## 취소(Cancel) vs 완료(Done)

잠깐 용어 정리를 하자면, `cancel` 채널은 지난 장에서 배운 `done` 채널과 매우 비슷합니다.

보통 실무에서는 둘 다 `done`이나 `stop` 같은 이름으로 혼용해서 쓰기도 합니다.

이 책에서는 헷갈림을 방지하기 위해 다음과 같이 구분하겠습니다.


*   **Cancel**: "작업을 중단해!" (외부 -> 고루틴)
*   **Done**: "나 다 끝났어!" (고루틴 -> 외부)

## 채널 병합 (Merging)

여러 채널에서 오는 데이터를 하나의 채널로 합치고 싶을 때가 있습니다.

이걸 **Fan-in** 패턴이라고도 하는데요.


가장 단순한 방법은 순차적으로 읽는 겁니다.


```go
func merge(in1, in2 <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for val := range in1 { out <- val } // in1 다 읽고
        for val := range in2 { out <- val } // 그다음 in2 읽기
    }()
    return out
}
```

하지만 이건 동시성이 없죠. `in1`을 읽는 동안 `in2`는 기다려야 합니다.


### 병합: 동시성 활용 (Concurrently)

각 채널을 읽는 고루틴을 따로 띄우면 해결됩니다.


```go
func merge(in1, in2 <-chan int) <-chan int {
    var wg sync.WaitGroup
    out := make(chan int)

    // in1 읽는 고루틴
    wg.Go(func() {
        for val := range in1 { out <- val }
    })

    // in2 읽는 고루틴
    wg.Go(func() {
        for val := range in2 { out <- val }
    })

    // 둘 다 끝나면 out 채널 닫기
    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

이제 두 채널의 데이터가 동시에 `out`으로 쏟아집니다. 아주 빠르죠.

### 병합: Select 활용

고루틴을 여러 개 띄우지 않고 `select`로 해결할 수도 있습니다.

단, 채널이 닫힌 경우를 잘 처리해야 합니다.

닫힌 채널을 `nil`로 만들어버리면 `select`에서 해당 케이스가 무시된다는 점(지난 시간에 배운 꿀팁!)을 활용해 봅시다.


```go
func merge(in1, in2 <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for in1 != nil || in2 != nil { // 둘 중 하나라도 살아있으면 반복
            select {
            case val1, ok := <-in1:
                if ok {
                    out <- val1
                } else {
                    in1 = nil // 닫혔으면 nil로 변경 -> select에서 제외됨
                }
            case val2, ok := <-in2:
                // ... (위와 동일 로직) ...
            }
        }
    }()
    return out
}
```

## 파이프라인 (Pipeline)

드디어 파이프라인입니다!

파이프라인은 데이터를 입력받아 가공하고 출력하는 단계(Stage)들의 연결입니다.

각 단계는 고루틴으로 돌아가고, 단계 사이는 채널로 연결됩니다.


**Reader(생성) -> Processor(가공) -> Writer(출력)**

예를 들어 **[숫자 생성] -> [행운의 숫자 필터링] -> [채널 병합] -> [합계 계산] -> [결과 출력]** 이라는 5단계 파이프라인을 구축한다고 해봅시다.


```sh
┌─────────────┐
│   rangeGen  │
└─────────────┘
       │
  readerChan─┬────────┬──────────────┬──────────────┐
┌─────────────┐┌─────────────┐┌─────────────┐┌─────────────┐
│  takeLucky  ││  takeLucky  ││  takeLucky  ││  takeLucky  │
└─────────────┘└─────────────┘└─────────────┘└─────────────┘
       │               │              │              │
 luckyChans[0]   luckyChans[1]  luckyChans[2]  luckyChans[3]
       │               │              │              │
┌──────────────────────────────────────────────────────────┐
│                           merge                          │
└──────────────────────────────────────────────────────────┘
       │
   mergedChan
       │
┌─────────────┐
│     sum     │
└─────────────┘
       │
   totalChan
       │
┌─────────────┐
│ printTotal  │
└─────────────┘
```

코드로 보면 각 단계가 하나의 함수가 되고, 채널을 주고받습니다.


```go
func main() {
    // 1. Reader: 1~1000 숫자 생성
    readerChan := rangeGen(1, 1000)

    // 2. Processor: 행운의 숫자 필터링 (4개 고루틴으로 병렬 처리)
    luckyChans := make([]<-chan int, 4)
    for i := range 4 {
        luckyChans[i] = takeLucky(readerChan)
    }

    // 3. Processor: 병렬 처리된 채널 하나로 병합
    mergedChan := merge(luckyChans)

    // 4. Processor: 합계 계산
    totalChan := sum(mergedChan)

    // 5. Writer: 결과 출력
    printTotal(totalChan)
}
```

이렇게 파이프라인을 구축하면:

*   각 단계의 로직이 분리되어 코드가 깔끔해집니다.
*   병목이 생기는 단계(`takeLucky`)만 고루틴 개수를 늘려 성능을 튜닝하기 쉽습니다.

## 고루틴 누수 방지 (심화편)

파이프라인에서 고루틴이 누수되는 또 다른 흔한 원인은 바로 `select` 내부에서의 블로킹입니다.


```go
func modify(cancel <-chan struct{}, in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for {
            select {
            case num := <-in:
                time.Sleep(10 * time.Millisecond) // (1) 작업 중...
                out <- num * 2                    // (2) 여기서 막히면?
            case <-cancel:
                return
            }
        }
    }()
    return out
}
```

만약 ➊에서 작업하다가 ➋로 넘어가려는 순간에 외부에서 `cancel` 채널이 닫히고 데이터를 받는 쪽도 사라졌다면?

고루틴은 `out <- num * 2`를 하려고 ➋에서 영원히 기다리게 됩니다.

이미 `select`의 `case` 안으로 들어왔기 때문에 `<-cancel`은 체크되지 않죠.


이걸 막으려면 값을 보낼 때도 `select`를 써야 합니다 (중첩 select).


```go
            case num := <-in:
                // ... 작업 수행 ...
                select {
                case out <- result: // 보낼 수 있으면 보내고
                case <-cancel:      // 취소되면 바로 종료!
                    return
                }
```

**원칙: 채널을 읽거나 쓸 때는 언제나 취소(cancel) 가능성을 열어둬야 합니다.**


## 에러 처리 (Error handling)

파이프라인 중간에 에러가 발생하면 어떻게 해야 할까요?

예를 들어 `calculate` 단계에서 외부 API를 호출하다가 실패했다면요?


### 1. 첫 에러 발생 시 즉시 중단

별도의 에러 채널(`errc`)을 만들어서 에러가 발생하면 즉시 보내고 종료하는 방식입니다.


```go
func calculate(in <-chan int) (<-chan Answer, <-chan error) {
    // ...
    if err != nil {
        errc <- err // 에러 발생!
        return      // 즉시 종료
    }
    // ...
}
```

하지만 에러 하나 때문에 전체 파이프라인을 멈추기 싫다면요?

### 2. 결과와 에러를 함께 전달 (Composite result)

결과 구조체에 에러 필드를 포함시키는 방법입니다. 가장 널리 쓰이는 방식이죠.


```go
type Result[T any] struct {
    val T
    err error
}

func calculate(in <-chan int) <-chan Result[Answer] {
    // ...
    ans, err := fetchAnswer(n)
    out <- Result{ans, err} // 에러도 값처럼 전달
    // ...
}
```

다음 단계에서 `res.Err()`를 확인해서 성공/실패를 분기 처리하면 됩니다.


### 3. 에러만 따로 수집

에러 채널을 따로 두고, 에러가 발생하면 그쪽으로 "로그"처럼 던져버리고 계속 진행하는 방식입니다.

단, 이 에러 채널이 꽉 차서 메인 로직이 블로킹되지 않도록 버퍼를 넉넉히 주거나 `select-default` 패턴을 써서 에러를 버리기도(drop) 해야 합니다.


---

이제 여러분은 파이프라인을 조립하고, 누수를 막고, 에러를 우아하게 처리하는 법까지 익혔습니다.

이 정도면 실전에서 꽤 복잡한 동시성 요구사항도 거뜬히 처리할 수 있습니다.


다음 장에서는 동시성 프로그래밍에서 빠질 수 없는 주제, **시간**(Time)을 다루는 법에 대해 알아보겠습니다.
