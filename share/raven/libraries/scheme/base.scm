;;  The base library.  What it offers is written here; how it is
;;  written is in base-impl.scm, included rather than written out so
;;  that the body reads as the file it has always been.
;;
;;  What is not here is the point of the list.  The syntax-rules
;;  expander -- sr-expand and everything around it -- is how this
;;  library's macros are written, not something a program may call or
;;  take the name of.  Nor are the helpers the exported procedures are
;;  built from: append2, concatenate, all-left-assoc, apply-subtract,
;;  apply-divide, write-char-list, sum-list, reverse-onto, member-by,
;;  assoc-by, list-walk?, extreme, floor-adjust, gcd2, lcm2, optional
;;  and caddr, which the expander uses and which a program asks
;;  (scheme cxr) for.
;;
;;  define-syntax expands to a form that calls sr-expand, and that form
;;  is read where the macro is used.  It reaches sr-expand because a
;;  macro is read in the library it was written in, which is here.

(define-library (scheme base)

  (export

   ;;  equivalence and booleans
   eq? eqv? equal? boolean? not xor null?

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

   ;;  numbers.  Integer arithmetic, which is the only arithmetic
   ;;  raven has: exactness, rationals, sqrt and numerator want the
   ;;  numeric tower and are not this.  floor, ceiling, truncate and
   ;;  round are the identity here, and are exported so that a program
   ;;  which says where it expects a fraction still runs.
   = < > <= >= + - * / sum
   number? integer? exact-integer?
   zero? positive? negative? even? odd?
   abs min max gcd lcm expt square
   ;;
   ;;  truncate/ and floor/ belong with these four and are not here:
   ;;  each answers two values, and there are no multiple values yet.
   quotient remainder modulo
   truncate-quotient truncate-remainder
   floor-quotient floor-remainder
   floor ceiling truncate round

   ;;  symbols.  A symbol and the name it reads as, both ways round:
   ;;  string->symbol of symbol->string is the symbol it started as.
   symbol? gensym symbol->string string->symbol

   ;;  characters, which are immediates holding their own code point
   char? char->integer integer->char

   ;;  strings
   string-length string-append list->string string->list

   ;;  output
   write write-char write-string newline display

   ;;  errors
   error

   ;;  syntax
   define-syntax let let-syntax letrec-syntax when unless and or)

  (include "base-impl.scm"))
