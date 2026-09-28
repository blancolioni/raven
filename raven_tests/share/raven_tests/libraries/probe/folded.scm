;;  A library whose body is included with include-ci, which reads the
;;  file as though it began with #!fold-case: the body is written in
;;  capitals, and what it defines is folded-name.

(define-library (probe folded)

  (import (scheme base))

  (export folded-name)

  (include-ci "folded-body.scm"))
