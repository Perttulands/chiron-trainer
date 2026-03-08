package dispatch

import (
	"context"
	"sync"
	"time"
)

type ticker interface {
	Chan() <-chan time.Time
	Stop()
}

type realTicker struct {
	ticker *time.Ticker
}

func (r *realTicker) Chan() <-chan time.Time {
	return r.ticker.C
}

func (r *realTicker) Stop() {
	r.ticker.Stop()
}

type Runner struct {
	interval  time.Duration
	flush     func(context.Context) error
	newTicker func(time.Duration) ticker

	mu      sync.Mutex
	running bool
	stop    chan struct{}
}

func NewRunner(interval time.Duration, flush func(context.Context) error) *Runner {
	return &Runner{
		interval: interval,
		flush:    flush,
		newTicker: func(d time.Duration) ticker {
			return &realTicker{ticker: time.NewTicker(d)}
		},
	}
}

// Start launches the dispatch scheduler. It is idempotent: if the scheduler is
// already running, subsequent calls return immediately without spawning a second
// loop. This means config-reload paths can safely call Start (or ApplyRuntimeConfig)
// without producing duplicate dispatch executions.
func (r *Runner) Start() {
	r.mu.Lock()
	if r.running {
		r.mu.Unlock()
		return
	}
	r.stop = make(chan struct{})
	r.running = true
	r.mu.Unlock()

	t := r.newTicker(r.interval)

	go func() {
		defer func() {
			t.Stop()
			r.mu.Lock()
			r.running = false
			r.mu.Unlock()
		}()

		for {
			select {
			case <-t.Chan():
				// Flush runs synchronously in this goroutine. Consecutive ticks
				// are queued in the channel and drained one at a time, so no two
				// flush calls can execute concurrently.
				_ = r.flush(context.Background())
			case <-r.stop:
				return
			}
		}
	}()
}

// Stop shuts down the scheduler. It is safe to call concurrently and is a
// no-op if the scheduler is not running.
func (r *Runner) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.running {
		close(r.stop)
	}
}

// ApplyRuntimeConfig is invoked by the config reload path. Start is idempotent,
// so calling it while the scheduler is already running is safe and has no effect.
func (r *Runner) ApplyRuntimeConfig() {
	r.Start()
}
