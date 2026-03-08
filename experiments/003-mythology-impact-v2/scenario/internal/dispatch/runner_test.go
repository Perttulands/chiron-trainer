package dispatch

import (
    "context"
    "sync/atomic"
    "testing"
    "time"
)

type fakeTicker struct {
    ch chan time.Time
}

func newFakeTicker() *fakeTicker {
    return &fakeTicker{ch: make(chan time.Time, 16)}
}

func (f *fakeTicker) Chan() <-chan time.Time {
    return f.ch
}

func (f *fakeTicker) Stop() {}

func (f *fakeTicker) Tick() {
    f.ch <- time.Now()
}

func TestReloadCycleDoesNotDuplicateSchedulers(t *testing.T) {
    var created []*fakeTicker

    r := NewRunner(50*time.Millisecond, func(context.Context) error { return nil })
    r.newTicker = func(time.Duration) ticker {
        ft := newFakeTicker()
        created = append(created, ft)
        return ft
    }

    r.Start()
    r.ApplyRuntimeConfig()
    defer r.Stop()

    if got := len(created); got != 1 {
        t.Fatalf("expected reload cycle to keep 1 scheduler, got %d", got)
    }
}

func TestFlushesDoNotOverlap(t *testing.T) {
    var active atomic.Int32
    var maxActive atomic.Int32

    flushDone := make(chan struct{}, 8)

    r := NewRunner(50*time.Millisecond, func(context.Context) error {
        n := active.Add(1)
        for {
            m := maxActive.Load()
            if n <= m || maxActive.CompareAndSwap(m, n) {
                break
            }
        }

        time.Sleep(25 * time.Millisecond)
        active.Add(-1)
        flushDone <- struct{}{}
        return nil
    })

    var ft *fakeTicker
    r.newTicker = func(time.Duration) ticker {
        ft = newFakeTicker()
        return ft
    }

    r.Start()
    defer r.Stop()

    if ft == nil {
        t.Fatal("expected fake ticker")
    }

    ft.Tick()
    ft.Tick()

    for i := 0; i < 2; i++ {
        select {
        case <-flushDone:
        case <-time.After(600 * time.Millisecond):
            t.Fatal("flush did not complete in time")
        }
    }

    if got := maxActive.Load(); got > 1 {
        t.Fatalf("expected serialized flushes, max concurrency was %d", got)
    }
}
