;;  A library with two forms in it that cannot be run.  Each names
;;  something nothing has defined.
;;
;;  Two of them, because one would not say what is worth saying here:
;;  the library is read whole, so both are heard about, where the
;;  first of them used to raise out of the begin and take the rest of
;;  the library with it -- everything after it undefined, and only the
;;  one report.
;;
;;  And then nothing imports it.  A file being read carries on at the
;;  form after a bad one so that every bad form in it is heard about;
;;  a library is a unit or it is nothing, and half of one is worse
;;  than none, because the names it never got round to defining would
;;  go undefined at each use instead, a long way from the reason.

(define-library (probe abandoned)

  (import (scheme base))

  (export abandoned-one abandoned-two)

  (begin

    (define abandoned-one 1)

    ;;  Each bad form allocates its way to a collection before it
    ;;  fails.  Where the rest of the library is kept while a form
    ;;  runs has to be somewhere the collector walks: kept anywhere
    ;;  else, it would be put back as it had been before everything
    ;;  moved, and what came after the bad form would be read out of
    ;;  the half of the heap that had just been left behind.

    (define (probe-churn n)
      (if (= n 0) '() (cons n (probe-churn (- n 1)))))

    (probe-no-such-procedure (probe-churn 2000))

    (define abandoned-two 3)

    (probe-no-such-procedure-either (probe-churn 2000))))
