---
title: "Go Concurrency 마스터하기: 뮤텍스(Mutex), 데이터 경쟁을 막는 방패"
date: 2025-12-11T09:20:00+09:00
description: "여러 고루틴이 공유 데이터에 동시에 접근할 때 발생하는 데이터 경쟁(Data Race)을 해결하는 방법을 알아봅니다. Mutex, RWMutex, 그리고 채널을 이용한 동기화 기법까지 완벽 정리!"
tags: ["Go", "Golang", "Concurrency", "Mutex", "RWMutex", "Data Race", "동시성"]
weight: 7
series: ["Go Concurrency 완벽 가이드"]
series_order: 7
---

여러 고루틴이 동시에 같은 데이터를 건드리면 어떻게 될까요?

슬프게도, 아무 일도 일어나지 않거나 끔찍한 일이 벌어집니다.

이번 장에서는 동시성 프로그래밍의 가장 큰 적인 **데이터 경쟁**(Data Race)과 이를 해결하는 **뮤텍스**(Mutex)에 대해 알아보겠습니다.

## 동시 수정의 위험성 (Concurrent modification)

지금까지 우리는 채널을 통해 고루틴끼리 데이터를 주고받았기 때문에 안전했습니다.

하지만 만약 여러 고루틴이 **같은 맵**(Map)에 동시에 접근해서 값을 쓴다면 어떻게 될까요?


```go
func main() {
    in := generate(100, 3) // 단어 생성 채널

    // 두 개의 고루틴이 같은 counter 맵을 수정하려고 합니다.
    count := func(counter map[string]int) {
        defer wg.Done()
        for word := range in {
            counter[word]++ // 문제 발생 지점!
        }
    }

    counter := map[string]int{}
    go count(counter)
    go count(counter)
    wg.Wait()
}
```

이 코드를 실행하면 Go 런타임은 즉시 패닉을 일으킵니다.

`fatal error: concurrent map writes`

`counter[word]++`라는 코드는 우리 눈엔 한 줄처럼 보이지만, 실제로는 값을 읽고, 더하고, 다시 쓰는 여러 단계로 이루어져 있습니다.

여러 고루틴이 이 단계를 뒤죽박죽 섞어서 실행하면 데이터가 오염될 수 있기 때문에 Go는 이를 엄격하게 막습니다.

## 데이터 경쟁 (Data race)

이렇게 여러 고루틴이 동시에 같은 변수에 접근하고, 그중 하나라도 값을 변경하려는 상황을 **데이터 경쟁**(Data Race)이라고 합니다.


맵(Map)은 Go 런타임이 친절하게 감지해서 패닉을 터뜨려주지만, 일반 변수나 슬라이스 등은 조용히 잘못된 값을 만들어낼 수 있어 더욱 위험합니다.

이를 찾기 위해 Go는 강력한 도구를 제공합니다. 바로 **레이스 디텍터**(Race Detector)입니다.

```bash
go run -race main.go
```

`-race` 플래그를 붙여서 실행하면 프로그램이 조금 느려지는 대신, 데이터 경쟁이 발생하는 순간을 정확하게 포착해서 알려줍니다.

**동시성 코드를 짤 때는 반드시 레이스 디텍터를 사용하는 습관을 들이세요.**

## 순차적 수정 (Sequential modification)

데이터 경쟁을 피하는 가장 쉬운 방법은 **동시에 수정하지 않는 것**입니다.

예를 들어 각 고루틴이 자신만의 맵을 만들어서 카운팅을 하고, 나중에 `merge` 함수가 하나로 합치는 방식이 있겠죠.


하지만 때로는 공유 데이터를 직접 수정해야 할 때가 있습니다.

이때 필요한 것이 바로 **뮤텍스**(Mutex)입니다.

## 뮤텍스 (Mutex)

뮤텍스는 **상호 배제**(Mutual Exclusion)의 약자입니다.

쉽게 말해 "내가 쓰고 있으니까 넌 기다려!"라고 문을 잠그는 자물쇠입니다.


```go
    count := func(lock *sync.Mutex, counter map[string]int) {
        defer wg.Done()
        for word := range in {
            lock.Lock()       // (2) 문 잠금! (다른 고루틴은 여기서 대기)
            counter[word]++   // 안전하게 데이터 수정
            lock.Unlock()     // (3) 문 열림!
        }
    }

    var lock sync.Mutex       // (1) 뮤텍스 생성
    go count(&lock, counter)
    go count(&lock, counter)
```

1.  고루틴이 `Lock()`을 호출하면 뮤텍스를 획득합니다.
2.  이미 다른 고루틴이 획득했다면, `Unlock()`이 호출될 때까지 대기(블로킹)합니다.
3.  데이터 수정이 끝나면 반드시 `Unlock()`을 호출해줘야 다른 고루틴이 일할 수 있습니다.

**주의:** 뮤텍스도 `sync.WaitGroup`처럼 내부 상태를 가지므로, 함수로 전달할 때는 반드시 **포인터**(`*sync.Mutex`)를 사용해야 합니다.

## 읽기-쓰기 뮤텍스 (Read-write mutex)

일반 뮤텍스는 무조건 한 번에 한 명만 접근할 수 있습니다.

그런데 만약 **데이터를 읽기만 하는 고루틴**이 아주 많고, **쓰는 고루틴**은 가끔 있다면 어떨까요?

읽기 작업끼리는 서로 방해할 필요가 없는데 말이죠.


이럴 때 `sync.RWMutex`를 사용합니다.

*   `Lock()` / `Unlock()`: 쓰기 잠금. 아무도 없을 때만 잠글 수 있습니다. (독점)
*   `RLock()` / `RUnlock()`: 읽기 잠금. 다른 읽기 잠금과는 공존할 수 있습니다. (공유)

```go
// 쓰기 고루틴 (Writer)
func writer() {
    lock.Lock()   // 쓰기 잠금: 아무도 못 들어옴 (읽기도 안됨)
    // ... 데이터 수정 ...
    lock.Unlock()
}

// 읽기 고루틴 (Reader)
func reader() {
    lock.RLock()  // 읽기 잠금: 다른 읽기 고루틴은 들어올 수 있음
    // ... 데이터 읽기 ...
    lock.RUnlock()
}
```

이렇게 하면 여러 Reader들이 동시에 데이터를 읽을 수 있어서 성능이 훨씬 좋아집니다.

Writer가 등장하면 모든 Reader가 끝날 때까지 기다렸다가 단독으로 작업하고, 그동안 새로운 Reader들은 대기하게 됩니다.

## 채널을 뮤텍스처럼 쓰기 (Channel as mutex)

Go의 철학 중 하나는 *"메모리를 공유하여 통신하지 말고, 통신하여 메모리를 공유하라"* 입니다.

하지만 뮤텍스는 명백히 메모리를 공유하는 방식이죠.

재미있는 건, **채널**을 이용해 뮤텍스 흉내를 낼 수 있다는 겁니다.


버퍼 크기가 1인 채널을 준비합니다.

```go
    lock := make(chan token, 1) // (1) 1칸짜리 채널 (세마포어 역할)

    count := func(lock chan token, counter map[string]int) {
        for word := range in {
            lock <- token{}     // (2) 값 넣기 == Lock()
            counter[word]++     // 임계 구역 (Critical Section)
            <-lock              // (3) 값 빼기 == Unlock()
        }
    }
```

채널이 꽉 차면(`1`개) 다른 고루틴은 값을 넣을 수 없어 대기하게 됩니다.

마치 뮤텍스가 잠긴 것처럼요.

실제로는 뮤텍스가 성능면에서 더 낫지만, 채널만으로도 동기화 메커니즘을 구현할 수 있다는 점은 Go의 유연성을 잘 보여줍니다.

---

이제 여러분은 여러 고루틴이 안전하게 데이터를 공유하는 방법을 알게 되었습니다.

하지만 뮤텍스를 너무 남발하면 코드가 복잡해지고, 자칫하면 서로가 서로를 기다리는 **데드락**(Deadlock)에 빠질 수도 있으니 조심해야 합니다.


다음 장에서는 또 다른 골치 아픈 문제인 **경쟁 상태**(Race Conditions)에 대해 더 깊이 이야기해보겠습니다.
