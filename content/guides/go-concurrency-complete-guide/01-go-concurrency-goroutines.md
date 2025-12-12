---
title: "Go Concurrency 마스터하기: 고루틴, 생각보다 쉽습니다"
date: 2025-12-11T08:00:00+09:00
description: "Go 언어의 꽃, 고루틴 핵심 개념부터 실전 패턴까지 완벽하게 정리했습니다. 헷갈리는 동시성 프로그래밍을 명쾌한 예제와 함께 마스터해 보세요."
tags: ["Go", "Golang", "Concurrency", "Goroutine", "동시성"]
weight: 1
series: ["Go Concurrency 완벽 가이드"]
series_order: 1
---

Go 언어를 배우면서 가장 흥미롭고 강력하다고 느끼는 부분이 바로 **동시성(Concurrency)**인데요.

어떤 문장을 단어 단위로 끊어서 출력하는 간단한 함수를 예로 들어 이야기를 시작해 보겠습니다.


```go
// say는 구절의 각 단어를 출력합니다.
func say(phrase string) {
    for _, word := range strings.Fields(phrase) {
        fmt.Printf("Simon says: %s...\n", word)
        dur := time.Duration(rand.Intn(100)) * time.Millisecond
        time.Sleep(dur)
    }
}
```

이제 `main` 함수에서 이 함수를 호출해 볼까요?


```go
func main() {
    say("go is awesome")
}
```

실행해 보면 아주 잘 작동합니다.

이번에는 두 명의 화자가 각자의 문장을 말하도록 만들어 볼게요.


```go
// say는 구절의 각 단어를 출력합니다.
func say(id int, phrase string) {
    for _, word := range strings.Fields(phrase) {
        fmt.Printf("Worker #%d says: %s...\n", id, word)
        dur := time.Duration(rand.Intn(100)) * time.Millisecond
        time.Sleep(dur)
    }
}
```

프로그램을 실행해 보겠습니다.


```go
func main() {
    say(1, "go is awesome")
    say(2, "cats are cute")
}
```

나쁘지는 않지만, 한 가지 아쉬운 점은 앞사람의 말이 다 끝나야 뒷사람이 말을 시작한다는 건데요.

두 사람이 동시에 말하게 하려면 `say()` 함수를 호출할 때 앞에 `go`라는 키워드만 붙여주면 됩니다.


```go
func main() {
    go say(1, "go is awesome")
    go say(2, "cats are cute")
    time.Sleep(500 * time.Millisecond)
}
```

이제 두 문장이 서로 경쟁하듯 출력되는 것을 볼 수 있습니다.

우리가 `go f()`라고 작성하면, 함수 `f()`는 다른 코드와 독립적으로 실행되는데요.

혹시 파이썬이나 자바스크립트의 `async/await` 같은 비동기 개념에 익숙하시다면, 잠시 그 기억은 접어두시는 게 좋습니다.

Go의 동시성은 접근 방식이 완전히 다르기 때문에 새로운 시각으로 바라볼 필요가 있거든요.


`go` 키워드와 함께 실행되는 함수를 우리는 '고루틴(Goroutine)'이라고 부릅니다.

Go 런타임은 이 고루틴들을 솜씨 좋게 저글링 하면서 CPU 코어에서 실행되는 운영체제 스레드에 배분해 주는데요.

OS 스레드와 비교하면 고루틴은 깃털처럼 가벼운 존재라서, 마음만 먹으면 수백, 수천 개를 생성해도 시스템에 큰 무리가 가지 않습니다.


그런데 방금 본 `main` 함수 예제에서 왜 `time.Sleep()`을 사용했는지 궁금하실 수도 있을 텐데요.

그 이유를 지금부터 명확하게 짚어드리겠습니다.


## 독립적인 고루틴과 메인 함수의 관계

고루틴은 말 그대로 완전히 독립적입니다.

우리가 `go say()`를 호출하면, 이 함수는 자기 갈 길을 떠나서 알아서 실행되는데요.

문제는 `main` 함수가 이 고루틴을 기다려주지 않는다는 점입니다.

만약 `main`을 아래처럼 작성하면 어떻게 될까요?


```go
func main() {
    go say(1, "go is awesome")
    go say(2, "cats are cute")
}
```

결과는 아무것도 출력되지 않습니다.

고루틴들이 입을 떼기도 전에 `main` 함수가 끝나버리고, `main`이 끝나면 프로그램 전체가 종료되기 때문입니다.


사실 `main` 함수 자체도 하나의 고루틴인데요.

프로그램이 시작될 때 암묵적으로 실행되는 고루틴이라고 보면 됩니다.

즉, 우리는 `main`, `say(1)`, `say(2)`라는 세 개의 독립적인 고루틴을 가지고 있는 셈입니다.

유일한 규칙은 `main`이 끝나면 다른 모든 것도 함께 끝난다는 것입니다.


## 웨이트 그룹 (Wait Group)

고루틴을 기다리기 위해 `time.Sleep()`을 쓰는 건 사실 좋은 방법이 아닌데요.

고루틴이 작업을 마치는 데 얼마나 걸릴지 예측할 수 없기 때문입니다.

이럴 때 사용하는 훨씬 세련된 도구가 바로 '웨이트 그룹(Wait Group)'입니다.


```go
func main() {
    var wg sync.WaitGroup // (1)

    wg.Add(1)             // (2)
    go say(&wg, 1, "go is awesome")

    wg.Add(1)             // (2)
    go say(&wg, 2, "cats are cute")

    wg.Wait()             // (3)
}

// say는 구절의 각 단어를 출력합니다.
func say(wg *sync.WaitGroup, id int, phrase string) {
    for _, word := range strings.Fields(phrase) {
        fmt.Printf("Worker #%d says: %s...\n", id, word)
        dur := time.Duration(rand.Intn(100)) * time.Millisecond
        time.Sleep(dur)
    }
    wg.Done()             // (4)
}
```

`wg` ➊ 내부에는 카운터가 하나 들어있는데요.

`wg.Add(1)` ➋을 호출하면 카운터가 1 증가하고, `wg.Done()` ➍을 호출하면 1 감소합니다.

그리고 `wg.Wait()` ➌은 카운터가 0이 될 때까지 현재 고루틴(여기서는 `main`)을 붙잡아둡니다(Block).

이렇게 하면 `main` 함수는 `say(1)`과 `say(2)`가 작업을 다 마칠 때까지 얌전히 기다렸다가 종료하게 됩니다.


하지만 이 방식에는 한 가지 단점이 있는데요.

비즈니스 로직(`say`)과 동시성 제어 로직(`wg`)이 섞여버린다는 점입니다.

이렇게 되면 나중에 `say` 함수를 동시성이 필요 없는 일반적인 코드에서 재사용하기가 까다로워집니다.


Go에서는 보통 동시성 로직과 비즈니스 로직을 분리하는 것을 권장합니다.

가장 흔한 방법은 별도의 함수로 감싸는 것인데, 우리처럼 간단한 경우에는 익명 함수(Anonymous function)를 사용하면 깔끔하게 해결됩니다.


```go
func main() {
    var wg sync.WaitGroup
    wg.Add(2)

    go func() {
        defer wg.Done()
        say(1, "go is awesome")
    }()

    go func() {
        defer wg.Done()
        say(2, "cats are cute")
    }()

    wg.Wait()
}
```

이 코드가 어떻게 작동하는지 살펴볼까요?


1.  우리는 두 개의 고루틴을 실행할 거란 걸 알고 있으니, `wg.Add(2)`를 한 번에 호출했습니다.
(물론 고루틴 시작 전에 각각 `wg.Add(1)`을 호출해도 결과는 같습니다.)
2.  익명 함수도 일반 함수처럼 `go`를 붙여서 시작할 수 있습니다.

3.  `defer wg.Done()`을 사용하면, `say` 함수 실행 중에 패닉(panic)이 발생하더라도 종료 전에 반드시 카운터를 감소시킵니다.

4.  이제 `say` 함수는 동시성에 대해 전혀 알 필요 없이 자기 할 일만 하면 됩니다.


## WaitGroup.Go (Go 1.25+)

Go 1.25 버전 이상을 사용하신다면 `WaitGroup.Go` 메서드를 사용할 수 있는데요.

이 메서드는 자동으로 카운터를 증가시키고, 고루틴을 실행한 뒤, 작업이 끝나면 카운터를 감소시켜 줍니다.

즉, `wg.Add()`나 `wg.Done()`을 일일이 호출할 필요가 없다는 뜻입니다.


```go
func main() {
    var wg sync.WaitGroup

    wg.Go(func() {
        fmt.Println("go is awesome")
    })

    wg.Go(func() {
        fmt.Println("cats are cute")
    })

    wg.Wait()
    fmt.Println("done")
}
```

내부 구현을 보면 우리가 방금 작성했던 패턴과 정확히 일치합니다.


```go
// https://github.com/golang/go/blob/master/src/sync/waitgroup.go
func (wg *WaitGroup) Go(f func()) {
    wg.Add(1)
    go func() {
        defer wg.Done()
        f()
    }()
}
```

저는 상황에 따라 `Go` 메서드와 `Add+Done` 방식을 섞어서 사용하도록 하겠습니다.


## ✎ 연습문제: 단어 속 숫자 세기

책 중간중간에 나오는 '✎' 기호는 연습문제를 의미하는데요.

눈으로만 보지 말고 꼭 직접 풀어보시길 권장합니다.

학습 효과의 절반은 이 연습문제에서 나오니까요.


아래는 문자열에 포함된 숫자의 개수를 세는 함수입니다.


```go
// countDigits는 문자열 내의 숫자 개수를 반환합니다.
func countDigits(str string) int {
    count := 0
    for _, char := range str {
        if unicode.IsDigit(char) {
            count++
        }
    }
    return count
}
```

여러분의 임무는 `countDigitsInWords` 함수를 완성하는 것인데요.

입력된 문장을 단어별로 쪼개고, 각 단어에 포함된 숫자의 개수를 `countDigits`를 사용해 세어야 합니다.

**핵심은 각 단어마다 별도의 고루틴을 생성해서 숫자를 세어야 한다는 점입니다.**


아직 여러 고루틴에서 공유 데이터를 수정하는 방법은 배우지 않았죠?

그래서 고루틴에서 안전하게 접근할 수 있는 `syncStats`라는 변수를 미리 준비해 두었습니다.


```go
// solution start

// countDigitsInWords는 구절 속 단어들에 포함된 숫자의 개수를 셉니다.
func countDigitsInWords(phrase string) counter {
    var wg sync.WaitGroup
    syncStats := new(sync.Map)
    words := strings.Fields(phrase)

    // 각 단어에 대해 별도의 고루틴을 사용하여
    // 숫자의 개수를 세어보세요.

    // 카운트 결과를 저장하려면
    // syncStats.Store(word, count)를 사용하세요.

    // 결과적으로 syncStats에는 단어와
    // 각 단어의 숫자 개수가 저장되어야 합니다.

    return asStats(syncStats)
}

// solution end
```

## 채널 (Channels)

고루틴을 잔뜩 실행하는 건 좋은데, 이 녀석들끼리 데이터는 어떻게 주고받아야 할까요?

Go에서는 '채널(Channel)'을 통해 고루틴 간에 값을 전달할 수 있습니다.

채널은 마치 한 고루틴이 무언가를 던지면 다른 고루틴이 그걸 받을 수 있는 창문과도 같습니다.


```sh
┌─────────────┐    ┌─────────────┐
│ goroutine A │    │ goroutine B │
│             └────┘             │
│        X <-  chan  <- X        │
│             ┌────┐             │
│             │    │             │
└─────────────┘    └─────────────┘
```


코드로 보면 다음과 같습니다.


```go
func main() {
    // 채널을 만들 때는 `make(chan 타입)`을 사용합니다.
    // 채널은 지정된 타입의 값만 받을 수 있습니다:
    messages := make(chan string)

    // 채널에 값을 보내려면
    // `channel <-` 문법을 사용합니다.
    // "ping"을 보내봅시다:
    go func() { messages <- "ping" }()

    // 채널에서 값을 받으려면
    // `<-channel` 문법을 사용합니다.
    // "ping"을 받아서 출력해 봅시다:
    msg := <-messages
    fmt.Println(msg)
}
```

프로그램이 실행되면 첫 번째 고루틴(익명 함수)이 `messages` 채널을 통해 두 번째 고루틴(`main`)에게 메시지를 보냅니다.


채널을 통해 값을 보내는 것은 **동기적(Synchronous)** 작업인데요.

보내는 고루틴이 채널에 값을 쓰면(`messages <- "ping"`), 누군가 그 값을 가져갈 때까지(`<-messages`) 해당 고루틴은 멈춰서 기다립니다(Block).

받는 사람이 나타나야 비로소 다음 코드를 실행하죠.


```go
func main() {
    messages := make(chan string)

    go func() {
        fmt.Println("B: Sending message...")
        messages <- "ping"                    // (1)
        fmt.Println("B: Message sent!")       // (2)
    }()

    fmt.Println("A: Doing some work...")
    time.Sleep(500 * time.Millisecond)
    fmt.Println("A: Ready to receive a message...")

    <-messages                               //  (3)

    fmt.Println("A: Messege received!")
    time.Sleep(100 * time.Millisecond)
}
```

고루틴 B가 채널에 메시지를 보내고 나면 ➊, 그 즉시 블로킹(대기) 상태가 됩니다.

고루틴 A가 메시지를 받아야만 ➌ 고루틴 B가 다시 깨어나서 "Message sent!"를 출력 ➋ 할 수 있습니다.


이처럼 채널은 단순히 데이터를 전달하는 것뿐만 아니라, 독립적인 고루틴들의 타이밍을 맞추는(동기화) 역할도 수행합니다.

이 기능은 나중에 아주 유용하게 쓰이니 잘 기억해 두세요.


## ✎ 연습문제: 결과 채널 (Result channel)

프로그래밍에서 자주 보게 되는 '생산자-소비자(Producer-Consumer)' 패턴을 아시나요?


*   생산자: 데이터를 공급합니다.
*   소비자: 데이터를 받아 처리합니다.

이번 연습문제에서는 생산자와 소비자가 채널을 통해 어떻게 상호작용하는지 살펴보겠습니다.

우리가 계속 다루고 있는 단어 속 숫자 세기 함수를 다시 가져와 볼까요.


다음 단계를 따라 코드를 작성해 보세요.


1.  고루틴을 하나 시작합니다.
2.  이 고루틴 안에서 단어들을 순회하며 각 단어의 숫자를 세고, 그 결과를 `counted` 채널에 보냅니다 (생산자).
3.  외부 함수에서는 채널에서 값을 읽어와 `stats` 카운터를 채웁니다 (소비자).

이번에는 웨이트 그룹(Wait Group)을 사용하지 마세요.

당분간은 채널만으로 충분하거든요.


```go
// solution start

// countDigitsInWords는 구절 속 단어들에 포함된 숫자의 개수를 셉니다.
func countDigitsInWords(phrase string) counter {
    words := strings.Fields(phrase)
    counted := make(chan int)

    go func() {
        // 단어들을 순회하면서,
        // 각 단어의 숫자 개수를 세고,
        // 그 결과를 counted 채널에 쓰세요.
    }()

    // counted 채널에서 값을 읽어서
    // stats를 채우세요.

    // 결과적으로 stats에는 단어와
    // 각 단어의 숫자 개수가 저장되어야 합니다.

    return stats
}

// solution end
```


혹시 Go의 동시성을 이미 접해보신 분이라면, 이번 챕터의 해결책들이 조금... 독특하거나 투박해 보일 수 있는데요.

동시성을 처음 접하는 분들이 압도되지 않도록 의도적으로 단순화했기 때문입니다.

몇 챕터만 지나면 핵심 개념들을 배우고, 훨씬 더 'Go다운(Idiomatic)' 코드를 작성하게 될 테니 걱정 마세요.


## 제너레이터 (Generator)

지금까지는 `countDigitsInWords` 함수가 모든 단어를 미리 알고 있다고 가정했는데요.

하지만 현실 세계에서 그런 호사를 누리기는 쉽지 않습니다.

데이터가 데이터베이스에서 오거나 네트워크를 통해 실시간으로 들어올 수도 있고, 함수는 단어가 총 몇 개인지 전혀 모를 수도 있으니까요.


이런 상황을 시뮬레이션하기 위해, 구절(string) 대신 `next`라는 제너레이터 함수를 전달받도록 해보겠습니다.

`next()`를 호출할 때마다 소스에서 다음 단어를 하나씩 가져오고, 더 이상 단어가 없으면 빈 문자열을 반환한다고 가정합시다.


순차적으로 실행되는 프로그램은 다음과 같은 모습일 겁니다.


```go
// counter는 각 단어의 숫자 개수를 저장합니다.
// 키는 단어이고, 값은 숫자의 개수입니다.
type counter map[string]int

// countDigitsInWords는 next()로 다음 단어를 가져와서
// 단어 속 숫자의 개수를 셉니다.
func countDigitsInWords(next func() string) counter {
    stats := counter{}

    for {
        word := next()
        if word == "" {
            break
        }
        count := countDigits(word)
        stats[word] = count
    }

    return stats
}

func main() {
    phrase := "0ne 1wo thr33 4068"
    next := wordGenerator(phrase)
    stats := countDigitsInWords(next)
    printStats(stats)
}
```

이제 여기에 동시성을 더해보겠습니다.


## ✎ 연습문제: 고루틴을 활용한 제너레이터

다음 단계를 따라 문제를 해결해 보세요.


1.  고루틴을 하나 시작합니다.
2.  이 고루틴 안에서 제너레이터로부터 단어를 가져와 숫자를 세고, 결과를 `counted` 채널에 씁니다.
3.  외부 함수에서는 채널에서 값을 읽어 `stats`를 채웁니다.

만약 이전 연습문제와 똑같은 방식으로 풀려고 하면 두 가지 문제에 부딪힐 겁니다.


1.  **종료 시점:** 더 이상 단어가 없을 때 루프를 어떻게 빠져나올까요?
2.  **데이터 매핑:** 채널에서 받은 숫자 개수(`count`)가 어떤 단어에 대한 것인지 어떻게 알 수 있을까요?

두 문제를 해결하기 위해 `counted` 채널에 무엇을 보내야 할지 고민해 보세요.

`pair`라는 타입을 눈여겨보시기 바랍니다.


```go
// solution start

// countDigitsInWords는 next()로 다음 단어를 가져와서
// 단어 속 숫자의 개수를 셉니다.
func countDigitsInWords(next func() string) counter {
    counted := make(chan ...)

    go func() {
        // 제너레이터에서 단어를 가져와서,
        // 각 단어의 숫자 개수를 세고,
        // 그 결과를 counted 채널에 쓰세요.
    }()

    // counted 채널에서 값을 읽어서
    // stats를 채우세요.

    // 결과적으로 stats에는 단어와
    // 각 단어의 숫자 개수가 저장되어야 합니다.

    return stats
}

// solution end
```


## ✎ 연습문제: 리더와 워커 (Reader and Worker)

이전 연습문제에서는 하나의 고루틴이 단어를 가져오는 일과 숫자를 세는 일을 모두 처리했는데요.

```sh
┌───────────────┐
│ loops through │               ┌────────────────┐
│ words and     │ → (counted) → │ fills stats    │
│ counts digits │               └────────────────┘
└───────────────┘
  goroutine          channel      outer function
```

작업이 더 복잡해지면, 데이터를 읽어오는 고루틴(Reader)과 데이터를 처리하는 고루틴(Worker)을 분리하는 것이 유리합니다.

이번에는 이 방식을 적용해 보겠습니다.

```sh
┌───────────────┐               ┌───────────────┐
│ sends words   │               │ counts digits │               ┌────────────────┐
│ to be counted │ → (pending) → │ in words      │ → (counted) → │ fills stats    │
│               │               │               │               └────────────────┘
└───────────────┘               └───────────────┘
  reader             channel      worker             channel      outer function
```


다음과 같이 구현해 보세요.

1.  제너레이터에서 단어를 가져와 `pending` 채널로 보내는 고루틴(리더)을 시작합니다.
2.  `pending` 채널에서 단어를 읽어 숫자를 세고, 결과를 `counted` 채널로 보내는 두 번째 고루틴(워커)을 시작합니다.
3.  외부 함수에서는 `counted` 채널을 읽어 최종 `stats` 카운터를 업데이트합니다.

```go
// solution start

// countDigitsInWords는 next()로 다음 단어를 가져와서
// 단어 속 숫자의 개수를 셉니다.
func countDigitsInWords(next func() string) counter {
    pending := make(chan string)
    counted := make(chan pair)

    // 카운트할 단어를 전송합니다 (리더)
    go func() {
        // 제너레이터에서 단어를 가져와서
        // pending 채널로 보내세요.
    }()

    // 단어 속 숫자를 셉니다 (워커)
    go func() {
        // pending 채널에서 단어를 읽어서,
        // 각 단어의 숫자 개수를 세고,
        // 결과를 counted 채널로 보내세요.
    }()

    // counted 채널에서 값을 읽어서
    // stats를 채우세요.

    // 결과적으로 stats에는 단어와
    // 각 단어의 숫자 개수가 저장되어야 합니다.

    return stats
}

// solution end
```


## ✎ 연습문제: 이름 있는 고루틴 (Named Goroutines)

리더와 워커로 로직을 나누고 나니, `countDigitsInWords` 함수가 꽤나 뚱뚱해졌습니다.

코드를 보면 명확하게 세 가지 논리 블록으로 나뉘는 게 보이실 텐데요.


1.  카운트할 단어 전송
2.  단어 속 숫자 세기
3.  최종 결과 집계

이 블록들을 각각 별도의 함수로 추출해서 채널을 통해 데이터를 주고받게 만들면 훨씬 깔끔하겠죠?


```go
func countDigitsInWords(next func() string) counter {
    pending := make(chan string)
    go submitWords(next, pending)

    counted := make(chan pair)
    go countWords(pending, counted)

    return fillStats(counted)
}
```

위 구조에 맞게 프로그램을 리팩터링 해보세요.


```go
// solution start

// submitWords는 카운트할 단어를 보냅니다.

// countWords는 단어 속 숫자를 셉니다.

// fillStats는 최종 통계를 준비합니다.

// solution end
```


## 출력 채널 (Output Channel)

우리가 만든 함수는 꽤 괜찮아 보이지만, 한 가지 개선할 점이 있습니다.

`pending` 채널은 부모 함수에서 생성된 뒤 `submitWords`라는 자식 함수에게 전달되는데요.

이것보다는 `submitWords` 함수 내부에서 채널을 생성하고 반환해서, `submitWords`가 그 채널을 완전히 소유하게 하는 편이 더 낫습니다.

`countWords`와 `counted` 채널도 마찬가지고요.


그렇게 하면 `countDigitsInWords` 함수는 이렇게 바뀝니다.


```go
func countDigitsInWords(next func() string) counter {
    pending := submitWords(next)
    counted := countWords(pending)
    return fillStats(counted)
}
```

이제 소유권이 명확해졌고, 프로그램의 흐름을 파악하기가 훨씬 쉬워졌습니다.

그런데 고루틴들은 다 어디로 갔을까요?

바로 `submitWords`와 `countWords` 함수 내부로 들어갔습니다.


```go
// submitWords는 카운트할 단어를 보냅니다.
func submitWords(next func() string) chan string {
    out := make(chan string)
    go func() {
        for {
            word := next()
            out <- word
            if word == "" {
                break
            }
        }
    }()
    return out
}

// countWords는 단어 속 숫자를 셉니다.
func countWords(in chan string) chan pair {
    out := make(chan pair)
    go func() {
        for {
            word := <-in
            count := countDigits(word)
            out <- pair{word, count}
            if word == "" {
                break
            }
        }
    }()
    return out
}
```

이 방식은 장단점이 있는데요.

`submitWords`와 `countWords` 함수는 고루틴을 시작해야 하니 조금 복잡해졌지만, 반대로 `countDigitsInWords`는 훨씬 단순하고 견고해졌습니다.

어떤 방식을 선택할지는 여러분의 취향에 달렸지만, 두 가지 방식을 섞어서 쓰는 건 피하는 게 좋습니다.

**함수에서 출력 채널을 반환하고 내부 고루틴에서 그 채널을 채우는 것,**

이것은 Go에서 아주 흔하게 사용되는 패턴이니 꼭 익혀두세요.

---

지금까지 Go의 고루틴에 대해 알아보았는데요.

아직 갈 길이 멀지만, 아주 중요한 첫걸음을 뗐습니다!

다음 장에서는 채널에 대해 더 깊이 있게 파고들어 보겠습니다.
