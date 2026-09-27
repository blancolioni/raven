;;  A library that offers names under other names.
;;
;;  (export (rename internal external)) means an importer writes the
;;  external name and gets what the library calls the internal one.
;;  The internal name is the library's to keep: it is not offered as
;;  well unless it is exported under its own name too.  A macro is
;;  renamed the same way as a variable, and one name can be offered
;;  under two.

(define-library (probe renaming)

  (import (scheme base))

  (export (rename renaming-inside renaming-outside)
          renaming-plain
          (rename renaming-twice renaming-doubled)
          renaming-shown
          renaming-plain-again
          (rename renaming-plain-again renaming-alias))

  (begin

    (define renaming-inside 'inside)
    (define renaming-plain 'plain)
    (define renaming-plain-again 'again)

    (define-syntax renaming-twice
      (syntax-rules ()
        ((_ x) (list x x))))

    ;;  What the library itself calls it, which is still what it is
    ;;  called here.

    (define (renaming-shown) renaming-inside)))
