package main

import (
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"slices"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/jackc/pgx/v5/stdlib"
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

func validateRun(mode, url string, workers, reqs, ramp int) error {
	if mode != "pg" && mode != "my" {
		return errors.New("mode must be pg or my")
	}
	if url == "" {
		return errors.New("uri is required")
	}
	if workers <= 0 || reqs <= 0 {
		return errors.New("workers and reqs must be >0")
	}
	if ramp < 0 {
		return errors.New("ramp must be >=0")
	}
	return nil
}

func validateInit(mode, dsn, sqlfile string) error {
	if mode != "pg" && mode != "my" {
		return errors.New("mode must be pg or my")
	}
	if dsn == "" {
		return errors.New("dsn required")
	}
	if sqlfile == "" {
		return errors.New("sql file required")
	}
	return nil
}

func main() {
	mode := flag.String("mode", "", "pg or my")
	action := flag.String("action", "", "init or run")
	uri := flag.String("uri", "", "benchmark URL")
	workers := flag.Int("workers", 0, "number of workers")
	reqs := flag.Int("reqs", 0, "requests per worker")
	ramp := flag.Int("ramp", 0, "ramp seconds")
	dsn := flag.String("dsn", "", "database connection string")
	sqlfile := flag.String("sql", "", "path to sql file")
	flag.Parse()

	switch *action {
	case "init":
		if err := validateInit(*mode, *dsn, *sqlfile); err != nil {
			fmt.Println("Error:", err)
			os.Exit(1)
		}
		b, err := os.ReadFile(*sqlfile)
		if err != nil {
			fmt.Println("failed to read sql file:", err)
			os.Exit(1)
		}
		db, err := sql.Open(map[string]string{"pg": "pgx", "my": "mysql"}[*mode], *dsn)
		if err != nil {
			fmt.Println("db open error:", err)
			os.Exit(1)
		}
		defer db.Close()
		if _, err := db.Exec(string(b)); err != nil {
			fmt.Println("sql exec error:", err)
			os.Exit(1)
		}
		fmt.Println("init done")
		return

	case "run":
		if err := validateRun(*mode, *uri, *workers, *reqs, *ramp); err != nil {
			fmt.Println("Error:", err)
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

	default:
		fmt.Println("Usage: benchmarker -action <init|run> [flags...]")
		os.Exit(1)
	}
}
