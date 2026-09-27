;;  A library that chooses what it is by what this raven is.
;;
;;  cond-expand as a declaration picks the declarations of the first
;;  clause whose requirement holds, and reads them as though they had
;;  been written where it stands: an export, an import and a begin can
;;  each be chosen.  The clauses not chosen are not read at all, so one
;;  may name a library that does not exist or a procedure nothing
;;  defines.

(define-library (probe conditional)

  (import (scheme base))

  (export conditional-which conditional-library conditional-nested)

  ;;  ratios is not true yet and raven is, so the second clause is
  ;;  chosen; the first would be an error if it were read.

  (cond-expand
   (ratios
    (begin (define conditional-which (no-such-procedure))))
   (raven
    (begin (define conditional-which 'raven)))
   (else
    (begin (define conditional-which 'else))))

  ;;  A library that is here, and one that is not, which is asked
  ;;  without reading either.

  (cond-expand
   ((library (probe no-such-library))
    (import (probe no-such-library))
    (begin (define conditional-library 'missing)))
   ((library (probe alpha))
    (begin (define conditional-library 'found)))
   (else
    (begin (define conditional-library 'neither))))

  ;;  One inside another, and the declarations of the inner one read as
  ;;  though they were written at the top.

  (cond-expand
   ((and raven (not ratios))
    (cond-expand
     ((or ratios full-unicode)
      (begin (define conditional-nested 'nested)))))))
