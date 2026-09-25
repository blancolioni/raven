;;  A file with a form in it that cannot be run.  It names something
;;  nothing has defined, so the loader gives up on that form and goes
;;  on to the one after it.
;;
;;  Which is the right thing to do -- one bad form should not stop a
;;  file -- and it used to be the quietest thing in raven.  The form
;;  was reported to the terminal whatever the host had asked for, and
;;  nothing downstream could tell it had happened: a suite sixteen of
;;  whose tests never ran printed the same last line as one where
;;  every one of them had.
;;
;;  The bad form is out here rather than inside the library below
;;  because a form that cannot be run inside a define-library takes
;;  the rest of the library with it, which is its own problem.

(probe-no-such-procedure 2)

(define-library (probe abandoned)

  (import (scheme base))

  (export abandoned-before abandoned-after)

  (begin

    (define abandoned-before 1)

    (define abandoned-after 3)))
