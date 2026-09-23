(import (scheme base) (scheme cxr))

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
(test "1 = 1" #t (= 1 1))
(test "(= 1 1 1)" #t (= 1 1 1))
(test "(= 1 1 2)" #f (= 1 1 2))

;;  Integer arithmetic.

;;  A negative number written out.  The reader classifies -13 as one
;;  integer token and read its value back as a Natural, which raised
;;  a range check out of the reader, so a negative number could not be
;;  written at all and had to be said as (- 13).

(test "a negative literal reads" -13 (- 13))
(test "a negative literal is the number" #t (= -13 (- 0 13)))
(test "a positive literal may be signed" 13 +13)
(test "a negative literal in a quotation" '(-1 -2) (list -1 -2))
(test "arithmetic on a negative literal" -10 (+ -13 3))

;;  The comparisons.  raven-leq was bound and nothing in scheme used
;;  it; these are it, turned around and negated.  Each is a chain, the
;;  way = is.

(test "1 < 2" #t (< 1 2))
(test "2 < 1" #f (< 2 1))
(test "1 < 1" #f (< 1 1))
(test "(< 1 2 3)" #t (< 1 2 3))
(test "(< 1 3 2)" #f (< 1 3 2))
(test "< over negatives" #t (< -2 -1))

(test "2 > 1" #t (> 2 1))
(test "1 > 2" #f (> 1 2))
(test "1 > 1" #f (> 1 1))
(test "(> 3 2 1)" #t (> 3 2 1))
(test "(> 3 1 2)" #f (> 3 1 2))
(test "> over negatives" #t (> -1 -2))

(test "1 <= 1" #t (<= 1 1))
(test "1 <= 2" #t (<= 1 2))
(test "2 <= 1" #f (<= 2 1))
(test "(<= 1 1 2)" #t (<= 1 1 2))
(test "(<= 1 2 1)" #f (<= 1 2 1))

(test "1 >= 1" #t (>= 1 1))
(test "2 >= 1" #t (>= 2 1))
(test "1 >= 2" #f (>= 1 2))
(test "(>= 2 1 1)" #t (>= 2 1 1))
(test "(>= 2 1 3)" #f (>= 2 1 3))

(test "zero? of zero" #t (zero? 0))
(test "zero? of one" #f (zero? 1))
(test "zero? of a negative" #f (zero? -1))

(test "positive? of one" #t (positive? 1))
(test "positive? of zero" #f (positive? 0))
(test "positive? of a negative" #f (positive? -1))

(test "negative? of a negative" #t (negative? -1))
(test "negative? of zero" #f (negative? 0))
(test "negative? of one" #f (negative? 1))

(test "even? of zero" #t (even? 0))
(test "even? of two" #t (even? 2))
(test "even? of three" #f (even? 3))
(test "even? of a negative even" #t (even? -4))
(test "even? of a negative odd" #f (even? -3))

(test "odd? of three" #t (odd? 3))
(test "odd? of zero" #f (odd? 0))
(test "odd? of a negative odd" #t (odd? -3))

(test "abs of a positive" 3 (abs 3))
(test "abs of a negative" 3 (abs -3))
(test "abs of zero" 0 (abs 0))

(test "square" 16 (square 4))
(test "square of a negative" 16 (square -4))
(test "square of zero" 0 (square 0))

(test "min of one" 3 (min 3))
(test "min" 1 (min 3 1 2))
(test "min over negatives" -2 (min -1 -2))
(test "max of one" 3 (max 3))
(test "max" 3 (max 3 1 2))
(test "max over negatives" -1 (max -1 -2))

;;  Division.  quotient truncates towards zero and floor-quotient
;;  rounds down, so the two differ exactly when the division does not
;;  come out even and the answer is negative.  remainder takes the
;;  sign of what was divided and modulo takes the sign of what it was
;;  divided by, which is the whole reason for having both.

(test "quotient" 3 (quotient 13 4))
(test "quotient, negative over positive" -3 (quotient -13 4))
(test "quotient, positive over negative" -3 (quotient 13 -4))
(test "quotient, negative over negative" 3 (quotient -13 -4))
(test "quotient that comes out even" -3 (quotient -12 4))

(test "remainder" 1 (remainder 13 4))
(test "remainder, negative over positive" -1 (remainder -13 4))
(test "remainder, positive over negative" 1 (remainder 13 -4))
(test "remainder, negative over negative" -1 (remainder -13 -4))
(test "remainder that comes out even" 0 (remainder 12 4))

(test "modulo" 1 (modulo 13 4))
(test "modulo, negative over positive" 3 (modulo -13 4))
(test "modulo, positive over negative" -3 (modulo 13 -4))
(test "modulo, negative over negative" -1 (modulo -13 -4))
(test "modulo that comes out even" 0 (modulo 12 4))

(test "floor-quotient" 3 (floor-quotient 13 4))
(test "floor-quotient, negative over positive" -4 (floor-quotient -13 4))
(test "floor-quotient, positive over negative" -4 (floor-quotient 13 -4))
(test "floor-quotient, negative over negative" 3 (floor-quotient -13 -4))
(test "floor-quotient that comes out even" -3 (floor-quotient -12 4))

;;  The R7RS spellings are the same procedures under the older names.

(test "truncate-quotient is quotient" #t
      (= (truncate-quotient -13 4) (quotient -13 4)))
(test "truncate-remainder is remainder" #t
      (= (truncate-remainder -13 4) (remainder -13 4)))
(test "floor-remainder is modulo" #t
      (= (floor-remainder -13 4) (modulo -13 4)))

;;  What holds of every division: the quotient and the remainder put
;;  the number back together, whichever way the quotient was rounded.

(test "truncating division puts 13 and 4 back together" 13
      (+ (* 4 (truncate-quotient 13 4)) (truncate-remainder 13 4)))
(test "flooring division puts -13 and 4 back together" -13
      (+ (* 4 (floor-quotient -13 4)) (floor-remainder -13 4)))

(test "gcd of nothing" 0 (gcd))
(test "gcd of one" 32 (gcd 32))
(test "gcd" 4 (gcd 32 36))
(test "gcd is never negative" 4 (gcd 32 -36))
(test "gcd of a negative alone" 4 (gcd -4))
(test "gcd with zero" 5 (gcd 0 5))
(test "gcd of three" 2 (gcd 12 18 8))

(test "lcm of nothing" 1 (lcm))
(test "lcm of one" 32 (lcm 32))
(test "lcm" 288 (lcm 32 36))
(test "lcm is never negative" 288 (lcm 32 -36))
(test "lcm with zero" 0 (lcm 0 5))
(test "lcm of three" 12 (lcm 2 3 4))

(test "expt to the zeroth" 1 (expt 2 0))
(test "expt to the first" 5 (expt 5 1))
(test "expt" 1024 (expt 2 10))
(test "expt of a negative base, even power" 4 (expt -2 2))
(test "expt of a negative base, odd power" -8 (expt -2 3))
(test "expt of zero to the zeroth" 1 (expt 0 0))

;;  Rounding an integer gives it back.  These are here so that a
;;  program which says where it expects a fraction runs.

(test "floor of an integer" 5 (floor 5))
(test "ceiling of an integer" 5 (ceiling 5))
(test "truncate of an integer" 5 (truncate 5))
(test "round of an integer" 5 (round 5))
(test "floor of a negative integer" -5 (floor -5))
(test "round of a negative integer" -5 (round -5))
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

;;  The list procedures R7RS asks the base library for.  Each is here
;;  on an ordinary list, on the empty list, and -- where the answer
;;  turns on it -- on a list that does not end in nil.

(test "reverse" '(3 2 1) (reverse '(1 2 3)))
(test "reverse of one" '(1) (reverse '(1)))
(test "reverse of nothing" '() (reverse '()))
(test "reverse leaves its argument alone" '(1 2 3)
      ((lambda (xs) (reverse xs) xs) (list 1 2 3)))
(test "reverse builds pairs of its own" #f
      ((lambda (xs) (eq? (reverse xs) xs)) (list 1)))

(test "list-tail, none of it" '(1 2 3) (list-tail '(1 2 3) 0))
(test "list-tail, some of it" '(3) (list-tail '(1 2 3) 2))
(test "list-tail, all of it" '() (list-tail '(1 2 3) 3))

(test "list-ref, the first" 1 (list-ref '(1 2 3) 0))
(test "list-ref, the last" 3 (list-ref '(1 2 3) 2))

(test "list-copy" '(1 2 3) (list-copy '(1 2 3)))
(test "list-copy of nothing" '() (list-copy '()))
(test "list-copy is a copy" #f
      ((lambda (xs) (eq? xs (list-copy xs))) (list 1 2 3)))
(test "list-copy keeps an improper tail" '(1 2 . 3) (list-copy '(1 2 . 3)))
(test "list-copy of what is not a pair" 7 (list-copy 7))

(test "list? of a list" #t (list? '(1 2 3)))
(test "list? of nothing" #t (list? '()))
(test "list? of an improper list" #f (list? '(1 2 . 3)))
(test "list? of a pair that is not a list" #f (list? '(1 . 2)))
(test "list? of what is not a pair at all" #f (list? 7))

;;  for-each is map without the answer: it is asked for what the
;;  procedure does, in the order the list is written.

(define for-each-seen '())
(for-each (lambda (x) (set! for-each-seen (cons x for-each-seen))) '(1 2 3))
(test "for-each visits every element" '(1 2 3) (reverse for-each-seen))

(define for-each-count 0)
(for-each (lambda (x) (set! for-each-count (+ for-each-count 1))) '())
(test "for-each over nothing does nothing" 0 for-each-count)

;;  eqv? is eq? for everything raven has, and answers the same
;;  questions.

(test "eqv? of a symbol with itself" #t (eqv? 'a 'a))
(test "eqv? of two symbols" #f (eqv? 'a 'b))
(test "eqv? of a number with itself" #t (eqv? 42 42))
(test "eqv? of two numbers" #f (eqv? 42 43))
(test "eqv? of nil with nil" #t (eqv? '() '()))
(test "eqv? of two lists that read alike" #f (eqv? (list 1) (list 1)))
(test "eqv? of a list with itself" #t
      ((lambda (xs) (eqv? xs xs)) (list 1)))

;;  memq, memv and member: the sublist that starts where the thing was
;;  found, and #f when it is not there.  member is the one that looks
;;  inside what it is comparing, and the one that takes a question of
;;  its own.

(test "memq finds a symbol" '(b c) (memq 'b '(a b c)))
(test "memq of what is not there" #f (memq 'z '(a b c)))
(test "memq of nothing" #f (memq 'a '()))
(test "memq answers with the tail itself" #t
      ((lambda (xs) (eq? (memq 'b xs) (cdr xs))) '(a b c)))

(test "memv finds a number" '(2 3) (memv 2 '(1 2 3)))
(test "memv of what is not there" #f (memv 9 '(1 2 3)))

(test "member looks inside" '((1 2) (3 4)) (member '(1 2) '((0) (1 2) (3 4))))
(test "memq does not look inside" #f (memq '(1 2) '((0) (1 2) (3 4))))
(test "member of what is not there" #f (member '(9) '((0) (1 2))))
;;  A compare of the caller's own is asked (compare obj element),
;;  which is the order R7RS gives it and the only order that lets it
;;  mean anything but sameness.

(test "member with a question of its own" '((b 2) (c 3))
      (member 'b '((a 1) (b 2) (c 3))
              (lambda (key entry) (eq? key (car entry)))))

;;  assq, assv and assoc: the pair whose car matches, and #f when
;;  there is none.

(define probe-alist '((a 1) (b 2) (c 3)))

(test "assq finds a key" '(b 2) (assq 'b probe-alist))
(test "assq of what is not there" #f (assq 'z probe-alist))
(test "assq of nothing" #f (assq 'a '()))
(test "assq answers with the pair itself" #t
      ((lambda (al) (eq? (assq 'a al) (car al))) probe-alist))

(test "assv finds a number key" '(2 two) (assv 2 '((1 one) (2 two))))
(test "assv of what is not there" #f (assv 9 '((1 one) (2 two))))

(test "assoc looks inside a key" '((1 2) found)
      (assoc '(1 2) '(((0) zero) ((1 2) found))))
(test "assq does not look inside a key" #f
      (assq '(1 2) '(((0) zero) ((1 2) found))))
(test "assoc of what is not there" #f (assoc '(9) '(((0) zero))))
(test "assoc with a question of its own" '((b y) 2)
      (assoc 'b '(((a x) 1) ((b y) 2))
             (lambda (key k) (eq? key (car k)))))

;;  The expander is written with memq and assq, so the tests above are
;;  not the only thing that would notice if they stopped answering.
;;  The macros below are expanded either way; this says so out loud.

(define-syntax probe-after-memq
  (syntax-rules (literally)
    ((_ literally x) (list 'literally x))
    ((_ x ...) (list x ...))))
(test "the expander still reads a literal" '(literally 1)
      (probe-after-memq literally 1))
(test "the expander still reads an ellipsis" '(1 2 3)
      (probe-after-memq 1 2 3))
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

;;  symbol? and gensym.  A generated symbol has a name, so that an
;;  expansion can be read, but it is not the symbol that name reads
;;  as: nothing written at the call site can capture it.

(test "symbol? of a symbol" #t (symbol? 'a))
(test "symbol? of a number" #f (symbol? 1))
(test "symbol? of a list" #f (symbol? '(a)))
(test "symbol? of nil" #f (symbol? '()))
(test "symbol? of a generated symbol" #t (symbol? (gensym)))

(test "a generated symbol is not another" #f (eq? (gensym) (gensym)))
(test "a generated symbol is itself"
      #t ((lambda (g) (eq? g g)) (gensym)))
(test "a generated symbol is not the name it was made from"
      #f (eq? (gensym 'a) 'a))

;;  The name a macro introduces does not take over a name the caller
;;  is using: the macro binds a generated symbol, and the x in its
;;  template still means the caller's x.

(define captured-x 10)
(define-macro (add-to-captured-x y)
  ((lambda (tmp) `((lambda (,tmp) (+ ,tmp captured-x)) ,y))
   (gensym 'captured-x)))
(test "a generated name does not capture" 13 (add-to-captured-x 3))

;;  There are more symbols to be had than the few hundred a session
;;  interns, which is what generating one per expansion needs.

(define (generate-symbols n)
  (if (= n 0) '() (cons (gensym) (generate-symbols (- n 1)))))
(test "a thousand generated symbols" 1000 (length (generate-symbols 1000)))

;;  define-syntax and syntax-rules.  A pattern is matched against the
;;  form that used the macro, and the first rule that matches gives the
;;  template that takes its place.

(define-syntax unless-not
  (syntax-rules ()
    ((_ test then otherwise) (if test otherwise then))))
(test "syntax-rules, a fixed pattern" 'yes (unless-not #f 'yes 'no))

(define-syntax listing
  (syntax-rules ()
    ((_ x ...) (list x ...))))
(test "syntax-rules, an ellipsis" '(1 2 3) (listing 1 2 3))
(test "syntax-rules, an ellipsis over nothing" '() (listing))

(define-syntax second-of
  (syntax-rules ()
    ((_ _ y) y)))
(test "syntax-rules, a wildcard" 2 (second-of 1 2))

(define-syntax went
  (syntax-rules (to from)
    ((_ to x) (list 'went-to x))
    ((_ from x) (list 'came-from x))))
(test "syntax-rules, a literal" '(went-to 1) (went to 1))
(test "syntax-rules, another literal" '(came-from 2) (went from 2))

(define-syntax any-of
  (syntax-rules ()
    ((_) #f)
    ((_ a) a)
    ((_ a b ...) (if a a (any-of b ...)))))
(test "syntax-rules, the first rule that matches" #f (any-of))
(test "syntax-rules, a rule that uses its own macro" 3 (any-of #f #f 3))

(define-syntax unzip
  (syntax-rules ()
    ((_ (a b) ...) (list (list a ...) (list b ...)))))
(test "syntax-rules, an ellipsis over a pattern" '((1 3) (2 4))
      (unzip (1 2) (3 4)))

(define-syntax first-and-last
  (syntax-rules ()
    ((_ a b ... c) (list a c))))
(test "syntax-rules, a pattern after an ellipsis" '(1 4)
      (first-and-last 1 2 3 4))

;;  A name a template binds is renamed, so a form the caller hands the
;;  macro keeps its own meaning inside it.  Each of these answers the
;;  other thing if the binder takes the caller's name over.

(define caught 9)

(define-syntax holds-a-lambda
  (syntax-rules ()
    ((_ e) ((lambda (caught) (list caught e)) 1))))
(test "a lambda in a template does not capture" '(1 9) (holds-a-lambda caught))

(define-syntax holds-a-let
  (syntax-rules ()
    ((_ e) (let ((caught 1)) (list caught e)))))
(test "a let in a template does not capture" '(1 9) (holds-a-let caught))

;;  or, written the way R7RS writes it, which needs both: a name to
;;  hold the value it tests, and that name not to be the caller's.

(define-syntax an-or
  (syntax-rules ()
    ((_) #f)
    ((_ a) a)
    ((_ a b ...) (let ((caught a)) (if caught caught (an-or b ...))))))
(test "or over a name the template also binds" 9 (an-or #f caught))
(test "or takes the first of its arguments that holds" 2 (an-or #f 2 3))

;;  A name the template only refers to is left alone, and a quoted name
;;  is data.

(define-syntax quotes-a-name
  (syntax-rules ()
    ((_ x) (list 'caught x))))
(test "a quoted name in a template is data" '(caught 9) (quotes-a-name caught))

;;  The library's own macros are written with syntax-rules now.  or
;;  holds what it tests in a name of its own, which it could not do
;;  while a name a template binds was the caller's.

(test "let binds" 3 (let ((a 1) (b 2)) (+ a b)))
(test "let takes a body of several forms" 2 (let ((a 1)) 9 2))

(define or-calls 0)
(define (counted v)
  (set! or-calls (+ or-calls 1))
  v)
(test "or answers with the first argument that holds" 7 (or (counted 7) 9))
(test "or asked for it once" 1 or-calls)

;;  let-syntax binds macros for a body and no further, and the macros
;;  it binds are in scope for each other.

(test "let-syntax binds for its body" 42
      (let-syntax ((twice-of (syntax-rules () ((_ x) (+ x x)))))
        (twice-of 21)))
(test "let-syntax does not escape" 5
      ((lambda (twice-of) (twice-of 5)) (lambda (v) v)))
(test "letrec-syntax, one macro using another" 12
      (letrec-syntax ((double (syntax-rules () ((_ x) (+ x x))))
                      (quadruple (syntax-rules () ((_ x) (double (double x))))))
        (quadruple 3)))

;;  define-syntax is a define-macro, so it takes the scope define-macro
;;  takes: one written in a body belongs to that body.

(define (uses-local-syntax)
  (define-syntax twice (syntax-rules () ((_ x) (+ x x))))
  (twice 21))
(test "define-syntax in a body" 42 (uses-local-syntax))
(test "define-syntax in a body does not escape" 5
      ((lambda (twice) (twice 5)) (lambda (v) v)))

;;  A name under two ellipses holds a list of lists, and repeats twice
;;  over on the way out.

(define-syntax rows
  (syntax-rules ()
    ((_ (a ...) ...) (list (list a ...) ...))))
(test "syntax-rules, an ellipsis inside an ellipsis" '((1 2) (3 4))
      (rows (1 2) (3 4)))

;;  Two names repeating together, which is what a binding form needs.

(define-syntax my-let
  (syntax-rules ()
    ((_ ((name value) ...) body ...)
     ((lambda (name ...) body ...) value ...))))
(test "syntax-rules, two names repeating together" 3
      (my-let ((x 1) (y 2)) (+ x y)))
(test "syntax-rules, a body of more than one form" 2 (my-let ((x 1)) 9 2))

;;  A pattern can end in a name, which takes whatever is left.

(define-syntax with-rest
  (syntax-rules ()
    ((_ a . rest) (list a (list . rest)))))
(test "syntax-rules, a pattern that ends in a name" '(1 (2 3))
      (with-rest 1 2 3))

;;  A name the base library keeps to itself is not this library's to
;;  take.  The expander its macros are written with is the case that
;;  matters: before there were libraries, defining sr-expand here made
;;  every syntax-rules macro expand to whatever it answered.  A macro
;;  is read in the library it was written in, so it still finds the
;;  expander, and the definition below is ours and only ours.

(define (sr-expand a b c) 42)

(define-syntax probe-still-expands
  (syntax-rules ()
    ((_ x) (+ x 1))))

(test "a private expander cannot be taken" 8 (probe-still-expands 7))
(test "and the name is still ours" 42 (sr-expand 1 2 3))

;;  (scheme cxr): every composition of car and cdr three and four
;;  deep.  cxr-tree is four deep and its sixteen leaves are all
;;  different, so each accessor has an answer of its own and one
;;  that reaches the wrong place shows it.

(define cxr-tree
  '((((1 . 2) . (3 . 4)) . ((5 . 6) . (7 . 8)))
    .
    (((9 . 10) . (11 . 12)) . ((13 . 14) . (15 . 16)))))

(test "caaar" '(1 . 2) (caaar cxr-tree))
(test "caadr" '(9 . 10) (caadr cxr-tree))
(test "cadar" '(5 . 6) (cadar cxr-tree))
(test "caddr" '(13 . 14) (caddr cxr-tree))
(test "cdaar" '(3 . 4) (cdaar cxr-tree))
(test "cdadr" '(11 . 12) (cdadr cxr-tree))
(test "cddar" '(7 . 8) (cddar cxr-tree))
(test "cdddr" '(15 . 16) (cdddr cxr-tree))
(test "caaaar" 1 (caaaar cxr-tree))
(test "caaadr" 9 (caaadr cxr-tree))
(test "caadar" 5 (caadar cxr-tree))
(test "caaddr" 13 (caaddr cxr-tree))
(test "cadaar" 3 (cadaar cxr-tree))
(test "cadadr" 11 (cadadr cxr-tree))
(test "caddar" 7 (caddar cxr-tree))
(test "cadddr" 15 (cadddr cxr-tree))
(test "cdaaar" 2 (cdaaar cxr-tree))
(test "cdaadr" 10 (cdaadr cxr-tree))
(test "cdadar" 6 (cdadar cxr-tree))
(test "cdaddr" 14 (cdaddr cxr-tree))
(test "cddaar" 4 (cddaar cxr-tree))
(test "cddadr" 12 (cddadr cxr-tree))
(test "cdddar" 8 (cdddar cxr-tree))
(test "cddddr" 16 (cddddr cxr-tree))

;;  The same names on a proper list, which is what they are for.

(test "caddr of a list" 3 (caddr '(1 2 3)))
(test "cadddr of a list" 4 (cadddr '(1 2 3 4)))
(test "cdddr of a list" '(4) (cdddr '(1 2 3 4)))
(test "cddddr of a list" '(5) (cddddr '(1 2 3 4 5)))

;;  A string written in the source is one object, made when it is
;;  read.  It used to read as the form that builds a string, so every
;;  evaluation of a literal spent another of the foreign values there
;;  are a limited number of -- which is what made a loop holding
;;  strings run out so quickly.

(define (probe-literal) "shared")

(test "a literal is one object" #t (eq? (probe-literal) (probe-literal)))
(test "two literals are two" #f (eq? "a" "a"))

;;  And there is room for more than a handful of them.  Five hundred
;;  strings, all live at once because the list holds them: this was an
;;  error, out of the machine and past anything scheme could do about
;;  it, once there were ninety-nine.

(define (probe-strings n)
  (if (= n 0) '() (cons (display n) (probe-strings (- n 1)))))

(test "five hundred live strings" 500 (length (probe-strings 500)))

(write-string "Tests: ")
(write-string (display num-tests))
(write-string ", Passed: ")
(write-string (display passed-tests))
(write-string ", Failed: ")
(write-string (display failed-tests))
(newline)

