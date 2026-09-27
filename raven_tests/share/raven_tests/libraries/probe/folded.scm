;;  A library whose body is included with include-ci, which reads the
;;  file as though it began with #!fold-case.  Every file here is read
;;  that way already, so this says that include-ci is a declaration
;;  raven knows rather than one it gives up on.

(define-library (probe folded)

  (import (scheme base))

  (export folded-name)

  (include-ci "folded-body.scm"))
