In this test we verify the behavior of ppxlib with regard to rewriters
error generations. We test both extenders, derivers and whole file
rewriters.

There is mainly three way for ppxs to handle errors, from best to
worst practice:

1. Putting an "error extension node" in the AST. In this test, the AST
is rewritten to contain two of these nodes.

 In the case of extenders

  $ echo "let _ = [%gen_ext_node] + [%gen_ext_node]" > impl.ml
  $ ./extender.exe impl.ml
  let _ =
    ([%ocaml.error "An error message in an extension node"]) +
      ([%ocaml.error "An error message in an extension node"])

 In the case of derivers

  $ echo "type a = int [@@deriving deriver_extension_node]" > impl.ml
  $ ./deriver.exe impl.ml
  type a = int[@@deriving deriver_extension_node]
  include
    struct
      let _ = fun (_ : a) -> ()
      [%%ocaml.error "An error message in an extension node"]
    end[@@ocaml.doc "@inline"][@@merlin.hide ]

 In the case of whole file transformations:

  $ echo "let x = 1+1. " > impl.ml
  $ ./whole_file_extension_point.exe impl.ml
  [%%ocaml.error "An error message in an extension node"]

(Note that Merlin will notify all errors, while the compiler only
notifies the first.)

2. Raising a located error. In these tests, such an error is raised
during the rewritting of the AST. By default, the exception is not
caught, so no AST is produced.

 In the case of extenders:

  $ echo "let x = 1+1. " > impl.ml
  $ echo "let _ = [%gen_raise_located_error]" >> impl.ml
  $ export OCAML_ERROR_STYLE=short
  $ ./extender.exe impl.ml
  File "impl.ml", line 2, characters 8-34:
  Error: A raised located error
  [1]

 In the case of derivers

  $ echo "type a = int" > impl.ml
  $ echo "type b = int [@@deriving deriver_located_error]" >> impl.ml
  $ ./deriver.exe impl.ml
  File "impl.ml", line 2, characters 0-47:
  Error: A raised located error
  [1]

 In the case of whole file transformations:

  $ echo "let x = 1+1. " > impl.ml
  $ ./whole_file_located_error.exe impl.ml
  File "impl.ml", line 1, characters 0-12:
  Error: A located error in a whole file transform
  [1]

When the argument `-embed-errors` is added, the exception is caught
and the whole AST is prepended with an error extension node.

 In the case of extenders:

  $ echo "let x = 1+1. " > impl.ml
  $ echo "let _ = [%gen_raise_located_error]" >> impl.ml
  $ ./extender.exe -embed-errors impl.ml
  [%%ocaml.error "A raised located error"]
  let x = 1 + 1.
  let _ = [%gen_raise_located_error ]

 In the case of derivers

  $ echo "let x = 1+1. " > impl.ml
  $ echo "type a = int" > impl.ml
  $ echo "type b = int [@@deriving deriver_located_error]" >> impl.ml
  $ ./deriver.exe -embed-errors impl.ml
  [%%ocaml.error "A raised located error"]
  type a = int
  type b = int[@@deriving deriver_located_error]

 In the case of whole file transformations:

  $ echo "let x = 1+1. " > impl.ml
  $ ./whole_file_located_error.exe -embed-errors impl.ml
  [%%ocaml.error "A located error in a whole file transform"]
  let x = 1 + 1.

3. Raising an exception. The exception is not caught by the driver.

 In the case of extensions:

  $ echo "let _ = [%gen_raise_exc] + [%gen_raise_exc]" > impl.ml
  $ ./extender.exe impl.ml
  Fatal error: exception Failure("A raised exception")
  [2]
  $ ./extender.exe -embed-errors impl.ml
  Fatal error: exception Failure("A raised exception")
  [2]

 In the case of derivers

  $ echo "type a = int" > impl.ml
  $ echo "type b = int [@@deriving deriver_raised_exception]" >> impl.ml
  $ ./deriver.exe -embed-errors impl.ml
  Fatal error: exception Failure("A raised exception")
  [2]

 In the case of whole file transformations:

  $ ./whole_file_exception.exe impl.ml
  Fatal error: exception Failure("An exception in a whole file transform")
  [2]
  $ ./whole_file_exception.exe -embed-errors impl.ml
  Fatal error: exception Failure("An exception in a whole file transform")
  [2]


4. Reporting Multiple Exceptions

When the `-embed-error` flag is not set, exceptions stop the rewriting process. Therefore, only the first exception is reported to the user
  $ ./whole_file_multiple_errors.exe impl.ml
  File "impl.ml", line 1, characters 0-12:
  Error: Raising a located exception during the first instrumentation phase
  [1]

When the `-embed-error` flag is set, located exceptions thrown during the rewriting process are caught, and collected. The "throwing transformations" are ignored. After all transformations have been applied, the collected errors are appended at the beginning of the AST.
  $ echo 'let () = print_endline "Hello, World!" ' > impl.ml
  $ ./whole_file_multiple_errors.exe -embed-errors impl.ml
  [%%ocaml.error
    "Raising a located exception during the first instrumentation phase"]
  [%%ocaml.error
    "Raising a located exception during the Global transformation phase"]
  [%%ocaml.error
    "Raising a located exception during the Last instrumentation phase"]
  let () = print_endline "Hello, World!"

