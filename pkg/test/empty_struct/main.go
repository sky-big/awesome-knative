package main

import (
	"fmt"

	"github.com/sky-big/awesome-knative/pkg/test/empty_struct/other"
)

type EmptyStruct struct{}

func main() {
	var a EmptyStruct
	var b EmptyStruct
	fmt.Println("main.a == main.b is ", a == b)

	var c other.EmptyStruct
	var d other.EmptyStruct
	fmt.Println("other.c == other.d is ", c == d)

	fmt.Println("main.a == other.c is False")
	fmt.Println("main.b == other.d is False")
}