;;  A library with a declaration nothing knows.
;;
;;  It used to be reported and dropped, and the library handed out
;;  without whatever the declaration was to give it -- for an export
;;  that renames, or a cond-expand, a library missing exports or read
;;  down the wrong branch, and imported as though it were whole.  Now it
;;  counts as a form that could not be run does, and nothing imports
;;  the library, including what its begin did define.

(define-library (probe undeclared)

  (import (scheme base))

  (export undeclared-name)

  (no-such-declaration undeclared-name)

  (begin (define undeclared-name 'undeclared)))
