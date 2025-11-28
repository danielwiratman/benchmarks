package main

import (
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"slices"
	"sync"
	"time"
)

type Result struct {
	Latency time.Duration
	Error   bool
}

func runWorker(url string, n int, delay time.Duration, out chan<- Result, c *http.Client) {
	time.Sleep(delay)
	for range n {
		t := time.Now()
		resp, err := c.Get(url)
		if err != nil {
			out <- Result{Error: true}
			continue
		}
		resp.Body.Close()
		out <- Result{Latency: time.Since(t)}
	}
}

func pct(v []time.Duration, p float64) time.Duration {
	if len(v) == 0 {
		return 0
	}
	i := int(float64(len(v))*p + 0.5)
	if i >= len(v) {
		i = len(v) - 1
	}
	return v[i]
}

func validate(mode, url string, workers, reqs, ramp int) error {
	if mode != "pg" && mode != "my" {
		return errors.New("mode must be 'pg' or 'my'")
	}
	if url == "" {
		return errors.New("uri is required")
	}
	if workers <= 0 || reqs <= 0 || ramp < 0 {
		return errors.New("workers, reqs must be >0 and ramp >=0")
	}
	return nil
}

func main() {
	mode := flag.String("mode", "", "pg or my")
	uri := flag.String("uri", "", "benchmark URL")
	workers := flag.Int("workers", 0, "number of workers")
	reqs := flag.Int("reqs", 0, "requests per worker")
	ramp := flag.Int("ramp", 0, "ramp seconds")
	flag.Parse()

	if err := validate(*mode, *uri, *workers, *reqs, *ramp); err != nil {
		fmt.Println("Error:", err)
		fmt.Printf("Usage: %s -mode <pg|my> -uri <url> -workers N -reqs N -ramp N\n", os.Args[0])
		os.Exit(1)
	}

	total := *workers * *reqs
	results := make(chan Result, total)
	client := &http.Client{Timeout: 5 * time.Second}
	var wg sync.WaitGroup
	delay := time.Duration(*ramp) * time.Second / time.Duration(*workers)

	start := time.Now()

	for i := 0; i < *workers; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			runWorker(*uri, *reqs, time.Duration(id)*delay, results, client)
		}(i)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	var errs int
	var sum time.Duration
	var lat []time.Duration

	for r := range results {
		if r.Error {
			errs++
			continue
		}
		lat = append(lat, r.Latency)
		sum += r.Latency
	}

	slices.Sort(lat)

	elapsed := time.Since(start)
	ok := len(lat)
	all := ok + errs
	avg := time.Duration(0)
	if ok > 0 {
		avg = sum / time.Duration(ok)
	}

	fmt.Println("\n===== Benchmark Results =====")
	fmt.Printf("Mode: %s\n", *mode)
	fmt.Printf("Total: %d\n", all)
	fmt.Printf("Success: %d\n", ok)
	fmt.Printf("Errors: %d\n", errs)
	fmt.Printf("Avg: %v\n", avg)
	fmt.Printf("P95: %v\n", pct(lat, 0.95))
	fmt.Printf("P99: %v\n", pct(lat, 0.99))
	fmt.Printf("RPS: %.2f\n", float64(all)/elapsed.Seconds())
	fmt.Printf("Time: %v\n", elapsed)
	fmt.Println("=============================\n")
}
