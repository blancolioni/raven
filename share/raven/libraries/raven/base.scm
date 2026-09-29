;;  (raven base): everything raven's own library offers, which is the
;;  R7RS base library, what R7RS puts in (scheme write) and (scheme
;;  lazy), and names of raven's own that no R7RS library has: xor,
;;  fold, xcons, sum and gensym.  What it offers is written here; how
;;  it is written is in base-impl.scm, included rather than written out
;;  so that the body reads as the file it has always been.
;;
;;  A program does not usually ask for this library.  (scheme base),
;;  (scheme write) and (scheme lazy) each offer their part of it
;;  (#153), which a library can do now that what it offers may be
;;  what it imported (#140); a program asks for (raven base), or
;;  (only (raven base) gensym), for what is raven's alone.
;;
;;  What is not here is the point of the list.  The syntax-rules
;;  expander -- sr-expand and everything around it -- is how this
;;  library's macros are written, not something a program may call or
;;  take the name of.  Nor are the helpers the exported procedures are
;;  built from: append2, concatenate, all-left-assoc, apply-subtract,
;;  apply-divide, write-char-list, sum-list, reverse-onto, member-by,
;;  assoc-by, list-walk?, extreme, inexact-if-any, floor-adjust, gcd2, lcm2, num-eq?,
;;  sr-is?, sr-current-ellipsis, sr-ellipsis-name?, sr-escaped,
;;  sr-expand-rules, sr-aliases, sr-names-for, raven-strip-syntax,
;;  map1, map-lists, for-each1, for-each-lists, any-null?, heads,
;;  rests, str=?, str<?, do-next, cond-expand-choose, expt-by-squaring,
;;  values-rename, let-values-expand, raven-winders, raven-travel-to,
;;  raven-set-winders!, raven-handlers, raven-set-handlers!,
;;  raven-with-handlers, raven-raise, error-object, raven-parameter-set,
;;  raven-parameter-converter, raven-parameterize, raven-port-converter,
;;  make-error-object, raven-describe, raven-raise-from-machine,
;;  raven-guard-clauses,
;;  simplest-between, simplest-positive,
;;  promise, raven-promise, promise-box, set-promise-box!,
;;  make-promise-box, promise-done?, promise-value, promise-update!,
;;  fill-vector, fill-vector-at, vector-onto,
;;  vector-tail, fill-range, list->bytevector, fill-bytevector,
;;  bytevector->list, bytevector-onto, bytevector-tail, write-char-list,
;;  read-line-from, read-line-onto, read-string-from, read-chars,
;;  write-u8-list, read-u8s, read-bytevector-from, read-bytevector-into,
;;  raven-the-eof-object, raven-output-port, raven-error-port,
;;  raven-input-port, make-record-type, record-type-name,
;;  record-type-fields, record-of?, record-field-index, record-check,
;;  record-constructor, record-accessor, record-modifier,
;;  record-field-procedures, optional and
;;  caddr, which the expander
;;  uses and which a program asks (scheme cxr) for.
;;
;;  define-syntax expands to a form that calls sr-expand, and that form
;;  is read where the macro is used.  It reaches sr-expand because a
;;  macro is read in the library it was written in, which is here.

(define-library (raven base)

  (export

   ;;  equivalence and booleans
   eq? eqv? equal? boolean? boolean=? not xor null?

   ;;  pairs and lists.  Two deep is as far as R7RS takes the base
   ;;  library; caddr and everything deeper is (scheme cxr).
   cons car cdr caar cadr cdar cddr pair?
   set-car! set-cdr!
   list list? length append reverse make-list list-copy
   list-tail list-ref list-set! map for-each fold xcons
   assq assv assoc memq memv member

   ;;  calling something with a list of arguments already built, which
   ;;  is the list the machine wanted in the first place
   apply

   ;;  and asking whether a thing can be called at all, which wanted a
   ;;  closure to be something other than a pair before it could be
   ;;  asked
   procedure?

   ;;  numbers.  Exact integers of any size, exact rationals, and
   ;;  inexact numbers that are doubles.  sqrt, exp, log and the
   ;;  trigonometric functions are (scheme inexact)'s, where R7RS puts
   ;;  them.
   = < > <= >= + - * / sum
   number? integer? exact-integer?
   exact? inexact? exact inexact

   ;;  multiple values
   values call-with-values let-values let*-values define-values

   ;;  continuations
   call-with-current-continuation call/cc dynamic-wind

   ;;  exceptions
   raise raise-continuable with-exception-handler guard
   error-object? error-object-message error-object-irritants
   file-error? read-error?
   rational? real? complex? numerator denominator rationalize
   zero? positive? negative? even? odd?
   abs min max gcd lcm expt square
   number->string string->number
   ;;
   ;;  and truncate/ and floor/, which answer the quotient and the
   ;;  remainder as two values
   quotient remainder modulo
   truncate/ floor/ exact-integer-sqrt
   truncate-quotient truncate-remainder
   floor-quotient floor-remainder
   floor ceiling truncate round

   ;;  symbols.  A symbol and the name it reads as, both ways round:
   ;;  string->symbol of symbol->string is the symbol it started as.
   symbol? symbol=? gensym symbol->string string->symbol

   ;;  characters, which are immediates holding their own code point
   char? char->integer integer->char
   char=? char<? char>? char<=? char>=?

   ;;  vectors.  A vector's elements are in the cells after its
   ;;  length, so an index is arithmetic and not a walk -- which is
   ;;  what tells a vector from a list and what #43 was really about.
   vector? make-vector vector vector-length vector-ref vector-set!
   vector->list list->vector vector->string string->vector
   vector-copy vector-copy! vector-append vector-fill!
   vector-map vector-for-each

   ;;  bytevectors, which are laid out the way a vector is; what
   ;;  tells them apart is that only a byte may go into one
   bytevector? make-bytevector bytevector bytevector-length
   bytevector-u8-ref bytevector-u8-set!
   bytevector-copy bytevector-copy! bytevector-append
   utf8->string string->utf8

   ;;  strings.  One a procedure made can be changed; a literal
   ;;  cannot.
   string? string-length string-append list->string string->list
   string make-string string-ref substring string-copy
   string-set! string-fill! string-copy!
   string=? string<? string>? string<=? string>=?
   string-map string-for-each

   ;;  ports, and what is written and read through one.  Everything
   ;;  went to one place through one foreign function and nothing
   ;;  could be read at all.
   port? input-port? output-port? textual-port? binary-port?
   current-output-port current-error-port current-input-port
   open-input-string open-output-string get-output-string
   close-port close-input-port close-output-port
   input-port-open? output-port-open? call-with-port flush-output-port
   eof-object eof-object?
   read-char peek-char read-line read-string char-ready?

   ;;  and the same a byte at a time, through a port opened on a
   ;;  bytevector.  What is not here is a port on a file, which is
   ;;  where the host gets a say in what may be read at all.
   open-input-bytevector open-output-bytevector get-output-bytevector
   read-u8 peek-u8 u8-ready? write-u8
   read-bytevector read-bytevector! write-bytevector

   ;;  output.  write-simple is write, which marks no structure a
   ;;  datum shares; write-shared, which does, is not here yet.
   write write-simple write-char write-string newline display

   ;;  errors
   error

   ;;  syntax
   define-syntax syntax-error
   let let* letrec letrec* let-syntax letrec-syntax
   when unless and or cond case do

   ;;  records
   define-record-type

   ;;  parameters
   make-parameter parameterize

   ;;  what this raven is, and choosing by it
   features cond-expand

   ;;  promises, which are records of their own (#168)
   delay delay-force force make-promise promise?)

  (include "base-impl.scm"))
