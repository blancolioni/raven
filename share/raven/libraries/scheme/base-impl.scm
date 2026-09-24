(define (eq? x y) (raven-eq? x y))

;;  eqv? is eq?, and stays eq? until there is something raven can
;;  represent that eq? answers wrongly for.  Everything it has now is
;;  an immediate or a pointer to the one object, and identity is the
;;  whole of the question for both.  Numbers are where that stops
;;  holding, and there are no numbers here yet that it does not
;;  answer for.

(define (eqv? x y) (eq? x y))

(define (null? x) (eq? x '()))

(define (list . xs) xs)
(define (xcons xs x) (cons x xs))

(define (append2 xs ys) (if (null? xs) ys (cons (car xs) (append (cdr xs) ys))))
(define (concatenate xxs) (if (null? xxs) '()
			      (append2 (car xxs) (concatenate (cdr xxs)))))
(define (append . xxs) (concatenate xxs))

(define (length xs) (if (null? xs) 0 (+ 1 (length (cdr xs)))))
(define (make-list n e) (if (= n 0) '() (cons e (make-list (- n 1) e))))

(define (reverse xs) (reverse-onto xs '()))
(define (reverse-onto xs ys)
  (if (null? xs) ys (reverse-onto (cdr xs) (cons (car xs) ys))))

(define (list-tail xs k) (if (= k 0) xs (list-tail (cdr xs) (- k 1))))
(define (list-ref xs k) (car (list-tail xs k)))

;;  list-set! waited for set-car!, which the machine could always do
;;  and had no name for.  It is list-ref with the reading replaced by
;;  a writing, and walks to the same pair.

(define (list-set! xs k value) (set-car! (list-tail xs k) value))

;;  list-copy copies the pairs and nothing else: what the last cdr is
;;  is what it stays, and something that is not a pair at all is its
;;  own copy.

(define (list-copy x) (if (pair? x) (cons (car x) (list-copy (cdr x))) x))

;;  Whether something is a list is decided by the last cdr, so there
;;  is no answering it without walking to the end.  Two things can
;;  stop the walk short of one: leaving the pairs, and never leaving
;;  them at all.
;;
;;  The second is why this is two walks rather than one.  There used
;;  to be no way to make a list that runs back into itself, so a walk
;;  that got going ended and the plain recursion was the whole of it;
;;  set-cdr! is the way, and now a list? that only looked for the end
;;  would not come back.  So a slow walk and a fast one go together,
;;  the fast one two pairs at a time, and the fast one catches the
;;  slow one exactly when the list has no end to find.

(define (list? x) (list-walk? x x))

(define (list-walk? slow fast)
  (if (null? fast)
      #t
      (if (pair? fast)
          (if (null? (cdr fast))
              #t
              (if (pair? (cdr fast))
                  (if (eq? (cddr fast) (cdr slow))
                      #f
                      (list-walk? (cdr slow) (cddr fast)))
                  #f))
          #f)))

(define (not x) (if x #f #t))
(define (xor x y) (if x (not y) y))

(define (fold f k xs) (if (null? xs) k (f (car xs) (fold f k (cdr xs)))))

(define (all-left-assoc op z xs)
  (if (null? xs) z
      (if (null? (cdr xs)) z
	  (if (op (car xs) (car (cdr xs)))
	      (all-left-assoc op z (cdr xs))
	      #f))))

(define (= . xs) (all-left-assoc eq? #t xs))


(define (+ . xs) (fold raven-add 0 xs))
(define (* . xs) (fold raven-mul 1 xs))

(define (- . xs) (apply-subtract xs))
(define (apply-subtract xs) (if (null? xs) 0
				(if (null? (cdr xs)) (raven-sub 0 (car xs))
				    (raven-sub (car xs) (fold raven-add 0 (cdr xs))))))

(define (/ . xs) (apply-divide xs))
(define (apply-divide xs) (if (null? xs) 1
			      (if (null? (cdr xs)) (raven-div 1 (car xs))
				  (raven-div (car xs) (fold raven-mul 1 (cdr xs))))))

;;  Comparison.  raven-leq is the only one the machine has and the
;;  other three are it with the arguments turned around, negated, or
;;  both.  Each is a chain, the way = is: (< 1 2 3) asks whether the
;;  whole row rises, and asks it of each neighbouring pair.

(define (< . xs) (all-left-assoc (lambda (x y) (not (raven-leq y x))) #t xs))
(define (> . xs) (all-left-assoc (lambda (x y) (not (raven-leq x y))) #t xs))
(define (<= . xs) (all-left-assoc raven-leq #t xs))
(define (>= . xs) (all-left-assoc (lambda (x y) (raven-leq y x)) #t xs))

(define (zero? x) (= x 0))
(define (positive? x) (< 0 x))
(define (negative? x) (< x 0))
(define (even? x) (zero? (remainder x 2)))
(define (odd? x) (not (even? x)))

(define (abs x) (if (negative? x) (- x) x))
(define (square x) (* x x))

;;  min and max are one walk given which of two to keep.  Each holds
;;  the answer for the rest of the list in a name rather than asking
;;  for it twice, which would be a walk of the list for every element
;;  of it.

(define (min . xs) (extreme < xs))
(define (max . xs) (extreme > xs))

(define (extreme better? xs)
  (if (null? (cdr xs))
      (car xs)
      ((lambda (rest) (if (better? (car xs) rest) (car xs) rest))
       (extreme better? (cdr xs)))))

;;  Division.  The machine divides towards zero, so what raven-div
;;  does is the truncating quotient, and the remainder follows from it
;;  without dividing again.

(define (truncate-quotient x y) (raven-div x y))
(define (truncate-remainder x y) (- x (* y (truncate-quotient x y))))

(define (quotient x y) (truncate-quotient x y))
(define (remainder x y) (truncate-remainder x y))

;;  Flooring division differs from truncating division in exactly one
;;  case: the division did not come out even and the answer is
;;  negative, where truncating rounds up towards zero and flooring
;;  rounds down away from it.  So it is the truncating quotient, one
;;  less when that case holds, and the remainder is what is left over
;;  from the quotient that was actually taken.

(define (floor-quotient x y)
  (floor-adjust y (truncate-quotient x y) (truncate-remainder x y)))

(define (floor-adjust y q r)
  (if (if (zero? r) #f (xor (negative? r) (negative? y))) (- q 1) q))

(define (floor-remainder x y) (- x (* y (floor-quotient x y))))

(define (modulo x y) (floor-remainder x y))

;;  truncate/ and floor/ are the other half of each of these: one call
;;  answering both the quotient and the remainder, so that the
;;  division is done once.  Each answers two values, and there are no
;;  multiple values here to answer with, so neither is written.  A
;;  caller that wants both asks for both, and pays for two divisions.

;;  gcd and lcm are chains over any number of arguments, and the
;;  answer of each is never negative.  gcd of nothing is 0 and lcm of
;;  nothing is 1, which are the values that leave a chain of one
;;  argument alone.

(define (gcd . xs) (fold gcd2 0 xs))
(define (gcd2 a b) (if (zero? b) (abs a) (gcd2 b (remainder a b))))

(define (lcm . xs) (fold lcm2 1 xs))
(define (lcm2 a b)
  (if (if (zero? a) #t (zero? b))
      0
      (abs (quotient (* a b) (gcd2 a b)))))

;;  expt raises to a whole power by multiplying.  A negative power is
;;  a rational, and rationals are the numeric tower rather than this.

(define (expt base power)
  (if (negative? power)
      (error "expt: a negative power is a rational, which raven has no numbers for")
      (if (zero? power) 1 (* base (expt base (- power 1))))))

;;  Every number here is an integer, so rounding one is giving it
;;  back.  They are written out rather than left out because a program
;;  that rounds is a program that works, and what it says about where
;;  it expects a fraction is worth keeping in it.

(define (floor x) x)
(define (ceiling x) x)
(define (truncate x) x)
(define (round x) x)

(define (optional value default) (if (eq? value '()) default value))

(define string-length raven-string-length)

(define list->string raven-list->string)

(define (string->list string start end)
   (raven-string->list string (optional start 0) (optional end (string-length string))))

(define (string-append . strings)
   (list->string (concatenate (map string->list strings))))

(define (map f xs) (if (null? xs) '() (cons (f (car xs)) (map f (cdr xs)))))

(define (for-each f xs)
  (if (null? xs) '() (begin (f (car xs)) (for-each f (cdr xs)))))

(define (write x) (write-string (display x)))

(define (write-char ch) (raven-write-char ch))

(define (write-char-list chars) (if (null? chars) '() (begin (write-char (car chars)) (write-char-list (cdr chars)))))

(define (write-string string) (write-char-list (string->list string)))

(define (newline) (write-char #\newline))

(define (sum-list xs) (if (null? xs) 0 (+ (car xs) (sum-list (cdr xs)))))
(define sum (lambda xs (sum-list xs)))

;;  Odds and ends the macro expander needs, and that a base library
;;  wants in any case.

;;  car, cdr, cons and pair? are forms the translator knows, which
;;  compiles them to an instruction, so the names have no value to pass
;;  to anything.  Defining them gives the name a procedure as well: a
;;  call written out still compiles to the instruction, and (map car xs)
;;  now has a car to map.

(define (car x) (car x))
(define (cdr x) (cdr x))
(define (cons x y) (cons x y))
(define (pair? x) (pair? x))

;;  apply is one of those forms too, for the same reason and with the
;;  same remedy.  A call already builds a list of its arguments and
;;  hands AP the list, so a call whose list is built already is that
;;  sequence with the building left out, and the translator writes it
;;  without a procedure to call.  This gives the name one, so that
;;  apply can be passed to something.

(define (apply f args) (apply f args))

(define (caar x) (car (car x)))
(define (cadr x) (car (cdr x)))
(define (cdar x) (cdr (car x)))
(define (cddr x) (cdr (cdr x)))
(define (caddr x) (car (cddr x)))

;;  The three member procedures are one walk, and so are the three
;;  assoc procedures: what tells them apart is only how they ask
;;  whether two things are the same.  member and assoc take that
;;  question from the caller, and ask equal? when the caller leaves it
;;  out.  The question is asked with what was looked for first, which
;;  is the order R7RS gives a compare of one's own.

(define (member-by same? x xs)
  (if (null? xs)
      #f
      (if (same? x (car xs))
          xs
          (member-by same? x (cdr xs)))))

(define (memq x xs) (member-by eq? x xs))
(define (memv x xs) (member-by eqv? x xs))
(define (member x xs compare) (member-by (optional compare equal?) x xs))

(define (assoc-by same? key alist)
  (if (null? alist)
      #f
      (if (same? key (caar alist))
          (car alist)
          (assoc-by same? key (cdr alist)))))

(define (assq key alist) (assoc-by eq? key alist))
(define (assv key alist) (assoc-by eqv? key alist))
(define (assoc key alist compare)
  (assoc-by (optional compare equal?) key alist))

;;  syntax-rules
;;
;;  (define-syntax name (syntax-rules (literal ...) (pattern template) ...))
;;
;;  Each pattern is matched against the form that used the macro, and
;;  the first one that matches gives the template that takes its place.
;;  The head of a pattern is not matched, _ matches anything without
;;  binding it, a literal matches only itself, and a pattern followed by
;;  ... matches any number of forms in a row.
;;
;;  A match is a list of (name depth value).  At depth zero the value is
;;  what the name matched; at depth n it is a list of depth n-1 values,
;;  one for each repetition, which is what a name under n ellipses holds.
;;
;;  define-syntax is a define-macro, so it inherits what define-macro
;;  guarantees, which is nothing: a name a template introduces means
;;  whatever it means where the macro is used.  Generate one with gensym
;;  where that matters.

(define sr-none (gensym 'no-match))

(define (sr-ellipsis? x)
  (if (pair? x) (eq? (car x) '...) #f))

(define (sr-vars pattern literals)
  (if (symbol? pattern)
      (if (eq? pattern '_)
          '()
          (if (eq? pattern '...)
              '()
              (if (eq? (memq pattern literals) #f)
                  (list pattern)
                  '())))
      (if (pair? pattern)
          (append (sr-vars (car pattern) literals)
                  (sr-vars (cdr pattern) literals))
          '())))

;;  Splitting a form for an ellipsis, without counting: step a lead
;;  pointer as far into the form as the pattern after the ellipsis
;;  reaches, then walk both until the lead runs out.  What the first
;;  pointer passed over is what repeats.

(define (sr-advance xs n)
  (if (pair? n)
      (if (pair? xs)
          (sr-advance (cdr xs) (cdr n))
          sr-none)
      xs))

(define (sr-walk xs lead)
  (if (pair? lead)
      ((lambda (rest)
         (cons (cons (car xs) (car rest)) (cdr rest)))
       (sr-walk (cdr xs) (cdr lead)))
      (cons '() xs)))

(define (sr-split form tail)
  ((lambda (lead)
     (if (eq? lead sr-none)
         sr-none
         (sr-walk form lead)))
   (sr-advance form tail)))

(define (sr-match pattern form literals depth bindings)
  (if (eq? bindings sr-none)
      sr-none
      (if (symbol? pattern)
          (sr-match-name pattern form literals depth bindings)
          (if (pair? pattern)
              (if (sr-ellipsis? (cdr pattern))
                  (sr-match-repeated (car pattern) (cddr pattern) form
                                     literals depth bindings)
                  (if (pair? form)
                      (sr-match (cdr pattern) (cdr form) literals depth
                                (sr-match (car pattern) (car form)
                                          literals depth bindings))
                      sr-none))
              (if (equal? pattern form) bindings sr-none)))))

(define (sr-match-name pattern form literals depth bindings)
  (if (eq? pattern '_)
      bindings
      (if (eq? (memq pattern literals) #f)
          (cons (list pattern depth form) bindings)
          (if (eq? form pattern) bindings sr-none))))

(define (sr-match-repeated sub tail form literals depth bindings)
  ((lambda (split)
     (if (eq? split sr-none)
         sr-none
         ((lambda (matches)
            (if (eq? matches sr-none)
                sr-none
                (sr-match tail (cdr split) literals depth
                          (append (sr-gather (sr-vars sub literals)
                                             sub matches depth)
                                  bindings))))
          (sr-match-each sub (car split) literals depth))))
   (sr-split form tail)))

(define (sr-match-each sub forms literals depth)
  (if (null? forms)
      '()
      ((lambda (first)
         (if (eq? first sr-none)
             sr-none
             ((lambda (rest)
                (if (eq? rest sr-none)
                    sr-none
                    (cons first rest)))
              (sr-match-each sub (cdr forms) literals depth))))
       (sr-match sub (car forms) literals depth '()))))

;;  How many ellipses of a pattern a name sits under.  That is what its
;;  depth goes up by when the pattern it is in repeats: a name two deep
;;  holds a list of lists.

(define (sr-under name pattern)
  (if (pair? pattern)
      (if (eq? (memq name (sr-vars (car pattern) '())) #f)
          (if (sr-ellipsis? (cdr pattern))
              (sr-under name (cddr pattern))
              (sr-under name (cdr pattern)))
          (if (sr-ellipsis? (cdr pattern))
              (+ 1 (sr-under name (car pattern)))
              (sr-under name (car pattern))))
      0))

(define (sr-gather names sub matches depth)
  (if (null? names)
      '()
      (cons (list (car names)
                  (+ depth 1 (sr-under (car names) sub))
                  (map (lambda (m) (caddr (assq (car names) m))) matches))
            (sr-gather (cdr names) sub matches depth))))

;;  The names a template binds are renamed, each to a symbol nothing
;;  can write, so that what the caller hands the macro keeps its own
;;  meaning inside them.  Only what the template binds is renamed: a
;;  name it merely refers to still means whatever it means where the
;;  macro is used, which is what define-macro means and no more.
;;
;;  A name that came from the pattern is the caller's own and is left
;;  alone.  lambda and let are the forms looked at: a binding the
;;  expander does not recognise is left alone too, which costs the
;;  caller nothing it had before.
;;
;;  A name written inside a quasiquote in a template is renamed as
;;  though it were code, where hygiene would hand back the name as
;;  written.  A quote is read properly; a quasiquote is not, yet.

(define (sr-names x)
  (if (symbol? x)
      (if (eq? x '...)
          '()
          (if (eq? x '_) '() (list x)))
      (if (pair? x)
          (append (sr-names (car x)) (sr-names (cdr x)))
          '())))

(define (sr-let-names bindings)
  (if (pair? bindings)
      (if (pair? (car bindings))
          (if (symbol? (caar bindings))
              (cons (caar bindings) (sr-let-names (cdr bindings)))
              (sr-let-names (cdr bindings)))
          (sr-let-names (cdr bindings)))
      '()))

(define (sr-bound-here template)
  (if (eq? (car template) 'lambda)
      (if (pair? (cdr template)) (sr-names (cadr template)) '())
      (if (eq? (car template) 'let)
          (if (pair? (cdr template)) (sr-let-names (cadr template)) '())
          '())))

(define (sr-binders template)
  (if (pair? template)
      (append (sr-bound-here template)
              (append (sr-binders (car template))
                      (sr-binders (cdr template))))
      '()))

(define (sr-introduced names bindings)
  (if (null? names)
      '()
      (if (eq? (assq (car names) bindings) #f)
          (cons (car names) (sr-introduced (cdr names) bindings))
          (sr-introduced (cdr names) bindings))))

(define (sr-fresh names)
  (if (null? names)
      '()
      (cons (cons (car names) (gensym (car names)))
            (sr-fresh (cdr names)))))

(define (sr-renames template bindings)
  (sr-fresh (sr-introduced (sr-binders template) bindings)))

(define (sr-instantiate template bindings renames)
  (if (symbol? template)
      ((lambda (found)
         (if (eq? found #f)
             ((lambda (renamed)
                (if (eq? renamed #f) template (cdr renamed)))
              (assq template renames))
             (caddr found)))
       (assq template bindings))
      (if (pair? template)
          (if (eq? (car template) 'quote)

              ;;  Quoted names are data, and stay as they were written.
              ;;  What the pattern bound still goes in.

              (cons 'quote (sr-instantiate (cdr template) bindings '()))
              (if (sr-ellipsis? (cdr template))
                  (append (sr-repeat (car template) bindings renames)
                          (sr-instantiate (cddr template) bindings renames))
                  (cons (sr-instantiate (car template) bindings renames)
                        (sr-instantiate (cdr template) bindings renames))))
          template)))

(define (sr-repeat sub bindings renames)
  ((lambda (names)
     (if (null? names)
         (error "syntax-rules: ... follows nothing that repeats")
         (sr-repeat-each sub names bindings renames)))
   (sr-repeated (sr-vars sub '()) bindings)))

(define (sr-repeated names bindings)
  (if (null? names)
      '()
      ((lambda (found)
         (if (eq? found #f)
             (sr-repeated (cdr names) bindings)
             (if (= (cadr found) 0)
                 (sr-repeated (cdr names) bindings)
                 (cons (car names) (sr-repeated (cdr names) bindings)))))
       (assq (car names) bindings))))

;;  A repetition is over when any of the names it runs through has
;;  nothing left.

(define (sr-spent? names bindings)
  (if (null? names)
      #f
      (if (null? (caddr (assq (car names) bindings)))
          #t
          (sr-spent? (cdr names) bindings))))

(define (sr-heads names bindings)
  (map (lambda (b)
         (if (eq? (memq (car b) names) #f)
             b
             (list (car b) (- (cadr b) 1) (car (caddr b)))))
       bindings))

(define (sr-rests names bindings)
  (map (lambda (b)
         (if (eq? (memq (car b) names) #f)
             b
             (list (car b) (cadr b) (cdr (caddr b)))))
       bindings))

(define (sr-repeat-each sub names bindings renames)
  (if (sr-spent? names bindings)
      '()
      (cons (sr-instantiate sub (sr-heads names bindings) renames)
            (sr-repeat-each sub names (sr-rests names bindings) renames))))

(define (sr-expand literals rules args)
  (if (null? rules)
      (error "syntax-rules: no rule matches this form")
      ((lambda (rule)
         ((lambda (bindings)
            (if (eq? bindings sr-none)
                (sr-expand literals (cdr rules) args)
                (sr-instantiate (cadr rule) bindings
                                (sr-renames (cadr rule) bindings))))
          (sr-match (cdr (car rule)) args literals 0 '())))
       (car rules))))

(define (sr-syntax-rules? spec)
  (if (pair? spec) (eq? (car spec) 'syntax-rules) #f))

;;  define-syntax writes a define-macro that hands the form it was used
;;  on to the expander, along with the literals and the rules.  So a
;;  macro defined this way is a macro like any other: it takes the scope
;;  define-macro takes, and it is expanded where it stands.
;;
;;  This is the one macro here that is not written with syntax-rules,
;;  and it is the one that cannot be: a rule of its own is what it
;;  would have to be read by.  Everything above it is written without
;;  the macros it defines, for the same reason -- the expander cannot
;;  use what only it can expand.

(define-macro (define-syntax sr-name sr-rules)
  (if (sr-syntax-rules? sr-rules)
      (if (symbol? (cadr sr-rules))
          (error "define-syntax: syntax-rules with an ellipsis of its own is not here yet")
          `(define-macro (,sr-name . sr-form)
             (sr-expand ',(cadr sr-rules) ',(cddr sr-rules) sr-form)))
      (error "define-syntax: expected (syntax-rules (literal ...) rule ...)")))

;;  The forms above are all define-syntax has to be written with.  What
;;  follows is written with it, and is what R7RS asks for rather than
;;  what was quickest to write by hand: or no longer evaluates the
;;  argument it answers with twice, because it can hold it in a name of
;;  its own and trust the name to stay its own.

(define-syntax let
  (syntax-rules ()
    ((_ ((name value) ...) body ...)
     ((lambda (name ...) body ...) value ...))))

;;  let-syntax binds macros for a body and no further.  A body is a
;;  region and a macro defined in one belongs to it, so the body of a
;;  procedure applied on the spot is all it takes.  The macros are in
;;  scope for each other, which is what letrec-syntax asks for and more
;;  than let-syntax promises, so one template serves for both.

(define-syntax let-syntax
  (syntax-rules ()
    ((_ ((name spec) ...) body ...)
     ((lambda () (define-syntax name spec) ... body ...)))))

(define-syntax letrec-syntax
  (syntax-rules ()
    ((_ ((name spec) ...) body ...)
     ((lambda () (define-syntax name spec) ... body ...)))))

(define-syntax when
  (syntax-rules ()
    ((_ test body ...) (if test (begin body ...) #f))))

(define-syntax unless
  (syntax-rules ()
    ((_ test body ...) (if test #f (begin body ...)))))

(define-syntax and
  (syntax-rules ()
    ((_) #t)
    ((_ a) a)
    ((_ a b ...) (if a (and b ...) #f))))

(define-syntax or
  (syntax-rules ()
    ((_) #f)
    ((_ a) a)
    ((_ a b ...) (let ((value a)) (if value value (or b ...))))))

;;  boolean? waits here for or rather than sitting with the other
;;  predicates, because or is now one of the forms above.

(define (boolean? x) (or (eq? x #t) (eq? x #f)))
