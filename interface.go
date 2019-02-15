package goose

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"

	"github.com/tchajed/goose/coq"
)

// File converts an entire package (possibly multiple files) to a coq.File
// (which is just a list of declarations)
func (ctx Ctx) File(fs ...*ast.File) (file coq.File, err error) {
	defer func() {
		if r := recover(); r != nil {
			if r, ok := r.(gooseError); ok {
				err = r.err
			} else {
				panic(r)
			}
		}
	}()
	var decls []coq.Decl
	for _, f := range fs {
		for _, d := range f.Decls {
			if d := ctx.maybeDecl(d); d != nil {
				decls = append(decls, d)
			}
		}
	}
	return coq.File(decls), nil
}

type TranslationError struct {
	Message string
	Err     error
}

func (e *TranslationError) Error() string {
	if e.Err == nil {
		return e.Message
	}
	return fmt.Sprintf("%s\n%s", e.Message, e.Err)
}

func (config Config) TranslatePackage(srcDir string) (coq.File, *TranslationError) {
	fset := token.NewFileSet()
	filter := func(os.FileInfo) bool { return true }
	packages, err := parser.ParseDir(fset, srcDir, filter, parser.ParseComments)
	if err != nil {
		return nil, &TranslationError{
			Message: "code does not parse",
			Err:     err,
		}
	}

	if len(packages) > 1 {
		return nil, &TranslationError{Message: "found multiple packages"}
	}

	var pkgName string
	var files []*ast.File
	for pName, p := range packages {
		for _, f := range p.Files {
			files = append(files, f)
		}
		pkgName = pName
	}

	ctx := NewCtx(fset, config)
	err = ctx.TypeCheck(pkgName, files)
	if err != nil {
		return nil, &TranslationError{
			Message: "code does not type check",
			Err:     err,
		}
	}

	f, err := ctx.File(files...)
	if err != nil {
		return nil, &TranslationError{
			Message: "failed to convert to Coq",
			Err:     err,
		}
	}
	return f, nil
}
