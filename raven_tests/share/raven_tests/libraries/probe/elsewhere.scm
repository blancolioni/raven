;;  A library that defines else (#179).  cond's else is a literal of its
;;  rules, which means else as the base library has it -- unbound -- so
;;  an else bound here is a name like any other in a cond here, and the
;;  clause it heads is a test of it.

(define-library (probe elsewhere)

  (import (scheme base))

  (export elsewhere-result)

  (begin

    (define else #f)

    ;;  Last, where else is cond's else when it is cond's else at all.

    (define elsewhere-result
      (cond (#f 'no)
            (else 'taken)))))
