package main

import (
	_ "embed"
	"fmt"

	"github.com/anssihalmeaho/funl/funl"
	"github.com/anssihalmeaho/funl/std"
	"github.com/anssihalmeaho/fuvaluez/fuvaluez"
)

//go:embed todoapp.fnl
var program string

//go:embed domain.fnl
var domain string

//go:embed uc.fnl
var uc string

//go:embed http.fnl
var http string

//go:embed er.fnl
var er string

//go:embed imported/httprouter.fnl
var httprouter string

func addOwnModules() (err error) {
	if err = funl.AddFunModToNamespace("httprouter", []byte(httprouter)); err != nil {
		return
	}
	if err = funl.AddFunModToNamespace("domain", []byte(domain)); err != nil {
		return
	}
	if err = funl.AddFunModToNamespace("uc", []byte(uc)); err != nil {
		return
	}
	if err = funl.AddFunModToNamespace("er", []byte(er)); err != nil {
		return
	}
	return nil
}

func init() {
	funl.AddExtensionInitializer(initMyExt)
	funl.AddExtensionInitializer(addOwnModules)
}

func convGetter(inGetter func(string) fuvaluez.FZProc) func(string) std.StdFuncType {
	return func(name string) std.StdFuncType {
		return std.StdFuncType(inGetter(name))
	}
}

func initMyExt() (err error) {
	stdModuleName := "valuez"
	topFrame := &funl.Frame{
		Syms:     funl.NewSymt(),
		OtherNS:  make(map[funl.SymID]funl.ImportInfo),
		Imported: make(map[funl.SymID]*funl.Frame),
	}
	stdFuncs := []std.StdFuncInfo{
		{
			Name:   "open",
			Getter: convGetter(fuvaluez.GetVZOpen),
		},
		{
			Name:   "new-col",
			Getter: convGetter(fuvaluez.GetVZNewCol),
		},
		{
			Name:   "get-col",
			Getter: convGetter(fuvaluez.GetVZGetCol),
		},
		{
			Name:   "get-col-names",
			Getter: convGetter(fuvaluez.GetVZGetColNames),
		},
		{
			Name:   "put-value",
			Getter: convGetter(fuvaluez.GetVZPutValue),
		},
		{
			Name:   "get-values",
			Getter: convGetter(fuvaluez.GetVZGetValues),
		},
		{
			Name:   "take-values",
			Getter: convGetter(fuvaluez.GetVZTakeValues),
		},
		{
			Name:   "update",
			Getter: convGetter(fuvaluez.GetVZUpdate),
		},
		{
			Name:   "trans",
			Getter: convGetter(fuvaluez.GetVZTrans),
		},
		{
			Name:   "view",
			Getter: convGetter(fuvaluez.GetVZView),
		},
		{
			Name:   "del-col",
			Getter: convGetter(fuvaluez.GetVZDelCol),
		},
		{
			Name:   "close",
			Getter: convGetter(fuvaluez.GetVZClose),
		},
	}
	err = std.SetSTDFunctions(topFrame, stdModuleName, stdFuncs)
	return
}

func main() {
	funl.PrintingRTElocationAndScopeEnabled = true

	retv, err := funl.FunlMainWithArgs(program, []*funl.Item{}, "main", "todoapp.fnl", std.InitSTD)
	if err != nil {
		fmt.Println("Error: ", err)
		return
	}
	fmt.Println(fmt.Sprintf("Result is %v", retv))
}
