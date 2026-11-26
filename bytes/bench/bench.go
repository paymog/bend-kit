package main

import (
    "bytes"
    "fmt"
    "os"
    "runtime"
    "strconv"
    "time"
)

func envCount(name string, fallback int) int {
    if s := os.Getenv(name); s != "" { n, err := strconv.Atoi(s); if err != nil || n < 0 { panic("invalid count") }; return n }
    return fallback
}

func measure(name string, operation func() uint32) {
    count := max(1, envCount("BYTES_BENCH_COUNT", 1))
    warmup := envCount("BYTES_BENCH_WARMUP", 0)
    for i := 0; i < warmup; i++ { runtime.KeepAlive(operation()) }
    var last, total uint32
    t0 := time.Now()
    for i := 0; i < count; i++ { last = operation(); total += last }
    ms := time.Since(t0).Seconds() * 1000
    fmt.Printf("%s\t%.6f\t%d\t%d\t%d\n", name, ms, last, count, total)
}

func fill(n int) []byte {
    b := make([]byte, n)
    for i := range b { b[i] = byte((i*31 + 7) & 255) }
    copy(b[n-4:], []byte{13, 10, 13, 10})
    return b
}

func main() {
    arg := func(i, fallback int) int { if len(os.Args) > i { n, err := strconv.Atoi(os.Args[i]); if err != nil { panic(err) }; return n }; return fallback }
    L := arg(1, 28)
    n := 1 << L
    reads, b1, b2 := arg(2, 1<<24), arg(3, 1000000), arg(4, 4000000)
    measure("fill", func() uint32 { b := fill(n); return uint32(b[12345%n]) + uint32(b[n-1]) })
    b := fill(n)
    measure("sum", func() uint32 { var sum uint32; for _, v := range b { sum += uint32(v) }; return sum })
    needle := []byte{13, 10, 13, 10}
    measure("find", func() uint32 { return uint32(bytes.Index(b, needle)) })
    measure("slice", func() uint32 {
        out := make([]byte, n/2)
        copy(out, b[n/4+1:n/4+1+n/2])
        return uint32(out[0]) + uint32(out[len(out)-1])
    })
    measure("concat", func() uint32 {
        var out []byte
        chunkSize := min(n, 65536)
        for k := 0; k < n/chunkSize; k++ {
            chunk := make([]byte, chunkSize)
            for i := range chunk { chunk[i] = byte(k & 255) }
            out = append(out, chunk...)
        }
        if len(out) != n { panic("concat length") }
        return uint32(out[0]) + uint32(out[len(out)-1])
    })
    measure("random", func() uint32 {
        x, acc := uint32(1), uint32(0)
        for i := 0; i < reads; i++ { x = x*1664525 + 1013904223; acc += uint32(b[x >> (32-L)]) }
        return acc
    })
    c := append([]byte(nil), b...)
    measure("equal", func() uint32 { if bytes.Equal(b, c) { return 1 }; return 0 })
    for _, size := range []int{b1, b2} {
        measure(fmt.Sprintf("build_%d", size), func() uint32 {
            var out []byte
            for i := 0; i < size; i++ { out = append(out, byte(i&255)) }
            return uint32(size) + uint32(out[size-1])
        })
    }
}
