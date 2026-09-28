;;  (scheme base): the R7RS base library, and nothing else (#153).
;;  Everything here is (raven base)'s, offered again: raven's library
;;  is written once, as (raven base), and each R7RS library offers its
;;  part of it.  What (raven base) has beyond this is what R7RS puts in
;;  other libraries -- write and display in (scheme write), delay and
;;  force in (scheme lazy) -- and what is raven's alone.

(define-library (scheme base)

  (import (raven base))

  (export

   ;;  equivalence and booleans
   eq? eqv? equal? boolean? boolean=? not null?

   ;;  pairs and lists.  Two deep is as far as R7RS takes the base
   ;;  library; caddr and everything deeper is (scheme cxr).
   cons car cdr caar cadr cdar cddr pair?
   set-car! set-cdr!
   list list? length append reverse make-list list-copy
   list-tail list-ref list-set! map for-each
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
   = < > <= >= + - * /
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
   symbol? symbol=? symbol->string string->symbol

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

   ;;  output.  write and display are (scheme write)'s.
   write-char write-string newline

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
   features cond-expand))
