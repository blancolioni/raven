(define (eq? x y) (raven-eq? x y))
(define (null? x) (eq? x '()))

(define-macro (when test . body)
  `(if ,test (begin ,@body) #f))

(define-macro (unless test . body)
  `(if ,test #f (begin ,@body)))

(define-macro (and . args)
  (if (null? args)
      #t
      (if (null? (cdr args))
          (car args)
          `(if ,(car args) (and ,@(cdr args)) #f))))

(define-macro (or . args)
  (if (null? args)
      #f
      (if (null? (cdr args))
          (car args)
          `(if ,(car args) ,(car args) (or ,@(cdr args))))))

(define (boolean? x) (or (eq? x #t) (eq? x #f)))

(define (list . xs) xs)
(define (xcons xs x) (cons x xs))

(define (append2 xs ys) (if (null? xs) ys (cons (car xs) (append (cdr xs) ys))))
(define (concatenate xxs) (if (null? xxs) '()
			      (append2 (car xxs) (concatenate (cdr xxs)))))
(define (append . xxs) (concatenate xxs))

(define (length xs) (if (null? xs) 0 (+ 1 (length (cdr xs)))))
(define (make-list n e) (if (= n 0) '() (cons e (make-list (- n 1) e))))

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
(define (* . xs) (fold raven-mul 0 xs))

(define (- . xs) (apply-subtract xs))
(define (apply-subtract xs) (if (null? xs) 0
				(if (null? (cdr xs)) (raven-sub 0 (car xs))
				    (raven-sub (car xs) (fold raven-add 0 (cdr xs))))))

(define (/ . xs) (apply-divide xs))
(define (apply-divide xs) (if (null? xs) 1
			      (if (null? (cdr xs)) (raven-div 1 (car xs))
				  (raven-div (car xs) (fold raven-mul 1 (cdr xs))))))

(define (optional value default) (if (eq? value '()) default value))

(define string-length raven-string-length)

(define list->string raven-list->string)

(define (string->list string start end)
   (raven-string->list string (optional start 0) (optional end (string-length string))))

(define (string-append . strings)
   (list->string (concatenate (map string->list strings))))

(define (map f xs) (if (null? xs) '() (cons (f (car xs)) (map f (cdr xs)))))

(define (write x) (write-string (display x)))

(define (write-char ch) (raven-write-char ch))

(define (write-char-list chars) (if (null? chars) '() (begin (write-char (car chars)) (write-char-list (cdr chars)))))

(define (write-string string) (write-char-list (string->list string)))

(define (newline) (write-char #\newline))

(define (sum-list xs) (if (null? xs) 0 (+ (car xs) (sum-list (cdr xs)))))
(define sum (lambda xs (sum-list xs)))

;;  Odds and ends the macro expander needs, and that a base library
;;  wants in any case.

;;  car, cdr and cons are forms the translator knows, which compiles
;;  them to an instruction, so the names have no value to pass to
;;  anything.  Defining them gives the name a procedure as well: a call
;;  written out still compiles to the instruction, and (map car xs) now
;;  has a car to map.

(define (car x) (car x))
(define (cdr x) (cdr x))
(define (cons x y) (cons x y))

(define (caar x) (car (car x)))
(define (cadr x) (car (cdr x)))
(define (cdar x) (cdr (car x)))
(define (cddr x) (cdr (cdr x)))
(define (caddr x) (car (cddr x)))

;;  let is a define-macro rather than a define-syntax because the
;;  expander below is written with it.  It is the plain let: a named
;;  let, which binds a procedure to loop with, is not here yet.

(define-macro (let bindings . body)
  `((lambda ,(map car bindings) ,@body) ,@(map cadr bindings)))

(define (assq key alist)
  (if (null? alist)
      #f
      (if (eq? (caar alist) key)
          (car alist)
          (assq key (cdr alist)))))

(define (memq x xs)
  (if (null? xs)
      #f
      (if (eq? (car xs) x)
          xs
          (memq x (cdr xs)))))

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
      (let ((rest (sr-walk (cdr xs) (cdr lead))))
        (cons (cons (car xs) (car rest)) (cdr rest)))
      (cons '() xs)))

(define (sr-split form tail)
  (let ((lead (sr-advance form tail)))
    (if (eq? lead sr-none)
        sr-none
        (sr-walk form lead))))

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
  (let ((split (sr-split form tail)))
    (if (eq? split sr-none)
        sr-none
        (let ((matches (sr-match-each sub (car split) literals depth)))
          (if (eq? matches sr-none)
              sr-none
              (sr-match tail (cdr split) literals depth
                        (append (sr-gather (sr-vars sub literals)
                                           sub matches depth)
                                bindings)))))))

(define (sr-match-each sub forms literals depth)
  (if (null? forms)
      '()
      (let ((first (sr-match sub (car forms) literals depth '())))
        (if (eq? first sr-none)
            sr-none
            (let ((rest (sr-match-each sub (cdr forms) literals depth)))
              (if (eq? rest sr-none)
                  sr-none
                  (cons first rest)))))))

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
      (let ((found (assq template bindings)))
        (if (eq? found #f)
            (let ((renamed (assq template renames)))
              (if (eq? renamed #f) template (cdr renamed)))
            (caddr found)))
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
  (let ((names (sr-repeated (sr-vars sub '()) bindings)))
    (if (null? names)
        (error "syntax-rules: ... follows nothing that repeats")
        (sr-repeat-each sub names bindings renames))))

(define (sr-repeated names bindings)
  (if (null? names)
      '()
      (let ((found (assq (car names) bindings)))
        (if (eq? found #f)
            (sr-repeated (cdr names) bindings)
            (if (= (cadr found) 0)
                (sr-repeated (cdr names) bindings)
                (cons (car names) (sr-repeated (cdr names) bindings)))))))

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
      (let ((rule (car rules)))
        (let ((bindings (sr-match (cdr (car rule)) args literals 0 '())))
          (if (eq? bindings sr-none)
              (sr-expand literals (cdr rules) args)
              (sr-instantiate (cadr rule) bindings
                              (sr-renames (cadr rule) bindings)))))))

(define (sr-syntax-rules? spec)
  (if (pair? spec) (eq? (car spec) 'syntax-rules) #f))

;;  define-syntax writes a define-macro that hands the form it was used
;;  on to the expander, along with the literals and the rules.  So a
;;  macro defined this way is a macro like any other: it takes the scope
;;  define-macro takes, and it is expanded where it stands.

;;  let-syntax binds macros for a body and no further.  A body is a
;;  region, and a macro defined in one belongs to it, so the body of a
;;  procedure that is applied on the spot is all it takes.  The macros
;;  are in scope for each other, which is what letrec-syntax asks for
;;  and more than let-syntax promises, so one serves for both.

(define-macro (let-syntax sr-bindings . sr-body)
  `((lambda ()
      ,@(map (lambda (b) `(define-syntax ,(car b) ,(cadr b))) sr-bindings)
      ,@sr-body)))

(define-macro (letrec-syntax sr-bindings . sr-body)
  `(let-syntax ,sr-bindings ,@sr-body))

(define-macro (define-syntax sr-name sr-rules)
  (if (sr-syntax-rules? sr-rules)
      (if (symbol? (cadr sr-rules))
          (error "define-syntax: syntax-rules with an ellipsis of its own is not here yet")
          `(define-macro (,sr-name . sr-form)
             (sr-expand ',(cadr sr-rules) ',(cddr sr-rules) sr-form)))
      (error "define-syntax: expected (syntax-rules (literal ...) rule ...)")))
