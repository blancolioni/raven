;;  The base library.  What it offers is written here; how it is
;;  written is in base-impl.scm, included rather than written out so
;;  that the body reads as the file it has always been.
;;
;;  What is not here is the point of the list.  The syntax-rules
;;  expander -- sr-expand and everything around it -- is how this
;;  library's macros are written, not something a program may call or
;;  take the name of.  Nor are the helpers the exported procedures are
;;  built from: append2, concatenate, all-left-assoc, apply-subtract,
;;  apply-divide, write-char-list, sum-list, optional and caddr, which
;;  the expander uses and which a program asks (scheme cxr) for.
;;
;;  define-syntax expands to a form that calls sr-expand, and that form
;;  is read where the macro is used.  It reaches sr-expand because a
;;  macro is read in the library it was written in, which is here.

(define-library (scheme base)

  (export

   ;;  equivalence and booleans
   eq? equal? boolean? not xor null?

   ;;  pairs and lists.  Two deep is as far as R7RS takes the base
   ;;  library; caddr and everything deeper is (scheme cxr).
   cons car cdr caar cadr cdar cddr
   list length append make-list map fold assq memq xcons

   ;;  numbers
   = + - * / sum

   ;;  symbols
   symbol? gensym

   ;;  strings
   string-length string-append list->string string->list

   ;;  output
   write write-char write-string newline display

   ;;  errors
   error

   ;;  syntax
   define-syntax let let-syntax letrec-syntax when unless and or)

  (include "base-impl.scm"))
