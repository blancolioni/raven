;;  A library whose macro writes a macro (#180).  The macro it writes
;;  calls maker-helper, which this library keeps to itself; defined at
;;  the use site, the written macro still means this library's.

(define-library (probe maker)

  (import (scheme base))

  (export def-maker)

  (begin

    (define (maker-helper) 'maker)

    (define-syntax def-maker
      (syntax-rules ()
        ((_ name)
         (define-syntax name
           (syntax-rules () ((_) (maker-helper)))))))))
