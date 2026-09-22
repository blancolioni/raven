(define num-tests 0)
(define passed-tests 0)
(define failed-tests 0)

(define (test name expect expr)
  (if (equal? expr expect)
        (begin
          (write-string (string-append "PASS  " name))
          (newline)
          (set! passed-tests (+ 1 passed-tests)))
        (begin
          (write-string "FAIL  ") (write-string name) (write-string ": expected ") (write-string (display expect))
          (write-string ", got ")
          (write-string (display expr))
          (newline)
          (set! failed-tests (+ 1 failed-tests))))
  (set! num-tests (+ 1 num-tests)))

(define (test-production expect expr)
  (test "production" expect expr))

;;  Captured before anything else in the session allocates a string, so
;;  that they are the first foreign values of the run.  Each one needs
;;  its own id: if a later value reuses an earlier one's id, both names
;;  end up denoting the same string.

(define first-append  (string-append "first"  "-append"))
(define second-append (string-append "second" "-append"))
(define third-append  (string-append "third"  "-append"))
(define fourth-append (string-append "fourth" "-append"))

(test "nil is not truthy" #f (boolean? '()))
(test "false is not truthy" #t (if #f #f #t))
(test "true is truthy" #t (if #t #t #f))
(test "integer self-equality" #t (eq? 4 (+ 2 2)))
;;(test "1 < 2" #t (< 1 2))
(test "1 = 1" #t (= 1 1))
(test "(= 1 1 1)" #t (= 1 1 1))
(test "(= 1 1 2)" #f (= 1 1 2))
(test "boolean? true" #t (boolean? #t))
(test "boolean? false" #t (boolean? #f))
(test "boolean? non-boolean" #f (boolean? 42))
(test "cons" '(a) (cons 'a '()))
(test "cons" '((a) b c d) (cons '(a) '(b c d)))
;;(test "cons" '("a" b c) (cons "a" '(b c)))
(test "cons" '(a . 3) (cons 'a 3))
(test "cons" '((a b) . c) (cons '(a b) 'c))
(test "list" '(a 7 c) (list 'a (+ 3 4) 'c))
(test "empty list" '() (list))
(test "xcons" '(a b c) (xcons '(b c) 'a))
(test "make-list" '(c c c c) (make-list 4 'c))
(test "pair-1" #t (pair? '(a . b)))
(test "pair-2" #t (pair? '(a b c)))
(test "pair-3" #f (pair? '()))
;;(test "pair-4" #f (pair? '#(a b)))
(test "pair-5" #f (pair? 7))
(test "pair-6" #f (pair? 'a))
(test "car-1" 'a (car '(a b c)))
(test "cdr-1" '(b c)   (cdr '(a b c)))
(test "car-2" '(a) (car '((a) b c d)))
(test "cdr-2" '(b c d) (cdr '((a) b c d)))
(test "car-3" '1 (car '(1 . 2)))
(test "cdr-3" '2 (cdr '(1 . 2)))

;;  quote written out means what the reader's ' means

(test "quote written out, atom" 5 (quote 5))
(test "quote written out, symbol" 'a (quote a))
(test "quote written out, list" '(1 2 3) (quote (1 2 3)))
(test "quote written out, nil" '() (quote ()))
(test "quote written out, nested" '(quote a) (quote (quote a)))
(test "quote and ' agree" #t (equal? '(1 2) (quote (1 2))))

;;  a quotation the reader never saw: the macro builds one

(define-macro (quoting-macro x) (list 'quote x))
(test "macro builds a quotation" '(a b) (quoting-macro (a b)))

(test "append-1" '(1 2 3 4 5 6) (append '(1 2 3) '(4 5 6)))
(test "string-1" "Hello, world!" (string-append "Hello, " "world!"))
(test "string-2" "abcde" (string-append "a" "b" "c" "d" "e"))
(test "string-3" "" (string-append ""))

(test "first string of a session"  "first-append"  first-append)
(test "second string of a session" "second-append" second-append)
(test "third string of a session"  "third-append"  third-append)
(test "fourth string of a session" "fourth-append" fourth-append)
(test "distinct strings do not alias" #f (equal? first-append second-append))

(define x 33)
(test "define" 33 x)
(set! x 34)
(test "set!" 34 x)

(test "not #f" #t (not #f))
(test "not #t" #f (not #t))
(test "not 0"  #f (not 0))

(test "and no args"    #t  (and))
(test "and one arg"    42  (and 42))
(test "and true true"  99  (and #t 99))
(test "and false true" #f  (and #f 99))
(test "and true false" #f  (and #t #f))
(test "and multi"      3   (and 1 2 3))
(test "and short-circuit" #f (and #f (error "should not evaluate")))

(test "or no args"     #f  (or))
(test "or one arg"     42  (or 42))
(test "or false false" #f  (or #f #f))
(test "or true false"  #t  (or #t #f))
(test "or false true"  #t  (or #f #t))
(test "or multi"       1   (or 1 2 3))
(test "or short-circuit" #t (or #t (error "should not evaluate")))

(test "when true"  42 (when #t 42))
(test "when false" #f (when #f 42))
(test "when multi" 2  (when #t 1 2))

(test "unless false" 42 (unless #f 42))
(test "unless true"  #f (unless #t 42))
(test "unless multi" 2  (unless #f 1 2))

;;  A lexical binding shadows a macro of the same name: the innermost
;;  binding wins, whichever kind it is.

(test "parameter shadows macro" 3
      ((lambda (when) (when 1 2)) (lambda (a b) (+ a b))))
(test "rest parameter shadows macro" '(1 2)
      ((lambda and and) 1 2))
(test "macro still works outside the shadow" 42 (when #t 42))

;;  define-macro defines in the region it appears in, not in the whole
;;  program: a branch that is never reached defines nothing outside it.

(if #f (define-macro (dead-macro x) '99) '())
(test "unreachable define-macro does not leak" 7
      ((lambda (dead-macro) (dead-macro 7)) (lambda (v) v)))

(define (local-macro-host)
  (define-macro (inner-macro x) '55)
  (inner-macro 1))
(test "local macro works in its own body" 55 (local-macro-host))
(test "local macro does not escape" 8
      ((lambda (inner-macro) (inner-macro 8)) (lambda (v) v)))

(define (shadowing-host)
  (define-macro (when test . body) ''shadowed)
  (when #t 'ignored))
(test "local macro shadows global" 'shadowed (shadowing-host))
(test "global macro survives the shadow" 42 (when #t 42))

(define (outer-host)
  (define-macro (m x) ''outer)
  (define (inner-host)
    (define-macro (m x) ''inner)
    (m 1))
  (cons (m 1) (inner-host)))
(test "nested macro scopes" '(outer . inner) (outer-host))

;;  A macro defined at top level is still in scope inside a body.

(define-macro (doubled x) `(+ ,x ,x))
(define (uses-global-macro n) (doubled n))
(test "global macro reaches into a body" 10 (uses-global-macro 5))

;;  Defining a name takes it back from the macro that held it.

(define-macro (takeable x) ''macro-version)
(test "macro before define" 'macro-version (takeable 1))
(define (takeable x) 'procedure-version)
(test "define undefines the macro" 'procedure-version (takeable 1))

;;  Expanding a macro allocates, so a definition has to survive a
;;  collection that happens while its own region is being translated.

(define (macro-under-collection)
  (define-macro (build a b c) `(list (list ,a ,b ,c) (list ,c ,b ,a)))
  (append (build 1 2 3) (build 4 5 6) (build 7 8 9)
          (build 1 2 3) (build 4 5 6) (build 7 8 9)
          (build 1 2 3) (build 4 5 6) (build 7 8 9)
          (build 1 2 3) (build 4 5 6) (build 7 8 9)))
(test "local macro survives collection" '(1 2 3)
      (car (macro-under-collection)))
(test "local macro survives collection, reversed copy" '(3 2 1)
      (car (cdr (macro-under-collection))))

;;  An unquote belongs to the innermost quasiquote around it.  A
;;  quasiquote inside a quasiquote is data, and so is an unquote that
;;  belongs to it: only an unquote that reaches back out to this level
;;  is evaluated here.

(define qq-value 4)
(define qq-list (list 7 8))

(test "quasiquote, one level" '(1 2 3) `(1 ,(+ 1 1) 3))
(test "quasiquote splices" '(1 7 8) `(1 ,@qq-list))
(test "quasiquote splices in the middle" '(1 7 8 9) `(1 ,@qq-list 9))
(test "quasiquote splices twice" '(7 8 7 8) `(,@qq-list ,@qq-list))
(test "quasiquote splices an empty list" '(1 9) `(1 ,@'() 9))
(test "nested quasiquote is data" '(a (quasiquote b)) `(a `b))
(test "unquote one level in is data" '(1 (quasiquote (2 (unquote qq-value))))
      `(1 `(2 ,qq-value)))
(test "unquote-splicing one level in is data"
      '(1 (quasiquote (2 (unquote-splicing qq-list))))
      `(1 `(2 ,@qq-list)))

;;  Only the innermost unquote belongs to the outer quasiquote: the
;;  call it sits in is reproduced, and never made.

(test "an unquote inside an unquote reaches back out"
      '(a (quasiquote (b (unquote (c 4)))))
      `(a `(b ,(c ,qq-value))))

(test "an unquote two levels in is data twice over"
      '(a (quasiquote (b (quasiquote (c (unquote qq-value))))))
      `(a `(b `(c ,qq-value))))
(test "an unquote of an unquote is evaluated where it lands"
      '(a (quasiquote (b (unquote 4))))
      `(a `(b ,,qq-value)))
(test "an unquote in the tail of a template" '(1 . 4) `(1 . ,qq-value))

(write-string "Tests: ")
(write-string (display num-tests))
(write-string ", Passed: ")
(write-string (display passed-tests))
(write-string ", Failed: ")
(write-string (display failed-tests))
(newline)

