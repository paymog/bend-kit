package main

import (
	"bytes"
	"fmt"
	"os"
	"strconv"
	"time"
)

func fillBuf(b []byte) uint32 {
	n := len(b)
	for i := range b {
		b[i] = byte((i*31 + 7) & 255)
	}
	b[n-4] = 13
	b[n-3] = 10
	b[n-2] = 13
	b[n-1] = 10
	return uint32(b[12345]) + uint32(b[n-1])
}

func main() {
	L := 28
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			L = v
		}
	}
	n := 1 << L
	reads, b1, b2 := 1<<24, 1000000, 4000000
	if len(os.Args) > 2 { reads, _ = strconv.Atoi(os.Args[2]) }
	if len(os.Args) > 3 { b1, _ = strconv.Atoi(os.Args[3]) }
	if len(os.Args) > 4 { b2, _ = strconv.Atoi(os.Args[4]) }

	t0 := time.Now()
	b := make([]byte, n)
	cs := fillBuf(b)
	fmt.Printf("fill\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, cs)

	t0 = time.Now()
	var sum uint32
	for _, v := range b {
		sum += uint32(v)
	}
	fmt.Printf("sum\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, sum)

	needle := []byte{13, 10, 13, 10}
	t0 = time.Now()
	findIdx := bytes.Index(b, needle)
	fmt.Printf("find\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, findIdx)

	sliceStart := n/4 + 1
	sliceLen := n / 2
	t0 = time.Now()
	s := make([]byte, sliceLen)
	copy(s, b[sliceStart:sliceStart+sliceLen])
	cs = uint32(s[0]) + uint32(s[sliceLen-1])
	fmt.Printf("slice\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, cs)

	t0 = time.Now()
	var out []byte
	chunks := n / 65536
	for k := 0; k < chunks; k++ {
		chunk := make([]byte, 65536)
		byteVal := byte(k & 255)
		for i := range chunk {
			chunk[i] = byteVal
		}
		out = append(out, chunk...)
	}
	if len(out) != n {
		os.Exit(1)
	}
	cs = uint32(out[0]) + uint32(out[len(out)-1])
	fmt.Printf("concat\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, cs)

	x, acc := uint32(1), uint32(0)
	shift := 32 - L
	t0 = time.Now()
	for i := 0; i < reads; i++ {
		x = x*1664525 + 1013904223
		idx := x >> shift
		acc += uint32(b[idx])
	}
	fmt.Printf("random\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, acc)

	c := make([]byte, n)
	copy(c, b)
	t0 = time.Now()
	eq := bytes.Equal(b, c)
	fmt.Printf("equal\t%.6f\t%d\n", time.Since(t0).Seconds()*1000.0, boolToU32(eq))
	for _, size := range []int{b1, b2} {
		t0 = time.Now()
		var built []byte
		for i := range size {
			built = append(built, byte(i&255))
		}
		cs = uint32(size) + uint32(built[size-1])
		fmt.Printf("build_%d\t%.6f\t%d\n", size, time.Since(t0).Seconds()*1000.0, cs)
	}
}

func boolToU32(b bool) uint32 {
	if b {
		return 1
	}
	return 0
}
