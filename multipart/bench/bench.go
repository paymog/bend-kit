// Multipart benchmark: Go's mime/multipart (see README.md).
package main

import (
	"bytes"
	"fmt"
	"io"
	"mime/multipart"
	"time"
)

const B = "bend-kit-0123456789abcdef0123456789abcdef"

func blob() []byte {
	b, x := make([]byte, 1<<20), uint32(1)
	for i := range b {
		x = x*1103515245 + 12345
		b[i] = byte(x >> 24)
	}
	return b
}

func chk(h uint32, b []byte) uint32 {
	for _, c := range b {
		h = h*31 + uint32(c)
	}
	return h
}

func ms(t0 time.Time) float64 { return float64(time.Since(t0).Nanoseconds()) / 1e6 }

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	data := blob()

	t0 := time.Now()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	must(w.SetBoundary(B))
	f, err := w.CreateFormField("title")
	must(err)
	f.Write([]byte("hello multipart"))
	f, err = w.CreateFormFile("blob", "blob.bin")
	must(err)
	f.Write(data)
	f, err = w.CreateFormField("note")
	must(err)
	f.Write([]byte("end"))
	must(w.Close())
	t := ms(t0)
	out := buf.Bytes()
	fmt.Printf("encode\t%.3f\t%d\n", t, chk(0, out)+uint32(len(out)))

	t0 = time.Now()
	r := multipart.NewReader(bytes.NewReader(out), B)
	var names, bodies [][]byte
	for {
		p, err := r.NextPart()
		if err == io.EOF {
			break
		}
		must(err)
		b, err := io.ReadAll(p)
		must(err)
		names, bodies = append(names, []byte(p.FormName())), append(bodies, b)
	}
	t = ms(t0)
	h, n := uint32(0), 0
	for i := range names {
		h = chk(chk(h, names[i]), bodies[i])
		n += len(names[i]) + len(bodies[i])
	}
	fmt.Printf("decode\t%.3f\t%d\n", t, h+uint32(n))
}
