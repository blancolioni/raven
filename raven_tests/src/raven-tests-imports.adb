with Ada.Exceptions;
with Ada.Text_IO;

with Raven.Target;

package body Raven.Tests.Imports is

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Name
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   procedure Test_Number
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

   procedure Test_Translation_Error
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Undefined
     (VM         : Raven_VM;
      Expression : String);

   --------------
   -- Evaluate --
   --------------

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
   exception
      when E : others =>
         Ada.Text_IO.Put (Expression);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
         raise;
   end Evaluate;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      --  Nothing of a library is here until it is asked for.

      Test_Undefined (VM, "alpha-name");

      --  (scheme base) is the R7RS base library and nothing else
      --  (#153).  write and display are (scheme write)'s, the promises
      --  (scheme lazy)'s, and xor, fold, xcons, sum and gensym are
      --  raven's own, in (raven base); none of them is here.

      Test_Undefined (VM, "(display 1)");
      Test_Undefined (VM, "(write 1)");
      Test_Undefined (VM, "(force 1)");
      Test_Undefined (VM, "(make-promise 1)");
      Test_Undefined (VM, "(delay 1)");
      Test_Undefined (VM, "(xor #t #f)");
      Test_Undefined (VM, "(fold + 0 '(1))");
      Test_Undefined (VM, "(xcons '(1) 2)");
      Test_Undefined (VM, "(sum 1)");
      Test_Undefined (VM, "(gensym)");

      --  And each is where R7RS puts it.  (only ...) keeps the rest of
      --  (raven base) out, so the test above still means something
      --  for the names it does not take.

      Evaluate (VM, "(import (scheme lazy))");
      Test_Number (VM, "(force (delay (+ 1 2)))", 3);
      Test_Number (VM, "(force (make-promise 4))", 4);
      Evaluate (VM, "(import (only (raven base) xor))");
      Test_Name (VM, "(xor #t #f)", "#t");
      Test_Undefined (VM, "(gensym)");

      Evaluate (VM, "(import (probe alpha))");

      --  What the library offers.

      Test_Name (VM, "alpha-name", "alpha");
      Test_Number (VM, "alpha-shared", 1);

      --  What it keeps.  This is the whole of the issue: before
      --  libraries, everything a file defined was everyone's.

      Test_Undefined (VM, "(alpha-helper 1)");

      --  A macro whose rules name what its own library keeps to
      --  itself still reaches it, because the macro carries the
      --  library its rules were written in.

      Test_Number (VM, "(alpha-twice 21)", 42);

      --  And a binding here of the name its template writes does not
      --  take it over (#24): the template's alpha-helper is the
      --  library's, whatever the caller calls alpha-helper.

      Test_Number
        (VM, "(let ((alpha-helper (lambda (x) 0))) (alpha-twice 21))", 42);

      --  A second library defines a name the first one defines, and
      --  each keeps its own.  Here the most recent import is the one
      --  that answers.

      Evaluate (VM, "(import (probe beta))");
      Test_Name (VM, "beta-name", "beta");
      Test_Number (VM, "alpha-shared", 2);

      --  (probe beta) imports (probe alpha) itself, and what it read
      --  there is what it has.

      Test_Name (VM, "beta-alpha-name", "alpha");

      --  A definition here takes the name from what was imported, and
      --  leaves the libraries it came from alone.

      Evaluate (VM, "(define alpha-shared 99)");
      Test_Number (VM, "alpha-shared", 99);
      Test_Number (VM, "(alpha-twice 21)", 42);

      --  define-syntax is a macro of the base library, used here.

      Evaluate
        (VM,
         "(define-syntax probe-thrice"
         & " (syntax-rules () ((_ x) (+ x x x))))");
      Test_Number (VM, "(probe-thrice 5)", 15);

      --  A library that is not there is reported and is not fatal.

      Evaluate (VM, "(import (probe nowhere))");
      Test_Name (VM, "alpha-name", "alpha");

      --  A form that cannot be run is given up on and counted, where
      --  nothing downstream could tell it had happened before.
      --
      --  Two of them in this library, and both are heard about: the
      --  first used to raise out of the begin and take the rest of
      --  the library with it, so everything after it went undefined
      --  and the second was never reached to be reported.

      declare
         Before : constant Natural := VM.Forms_Abandoned;
      begin
         Evaluate (VM, "(import (probe abandoned))");

         Test ("a library is read past a form it cannot run",
               VM.Forms_Abandoned = Before + 2);
      end;

      --  And then nothing imports it.  A library is a unit or it is
      --  nothing: what it did define is not there either, because
      --  half a library is worse than none.

      Test_Undefined (VM, "abandoned-one");
      Test_Undefined (VM, "abandoned-two");

      --  Asking again is refused again.  The second import used to
      --  find the library loaded and hand it over.

      Evaluate (VM, "(import (probe abandoned))");
      Test_Undefined (VM, "abandoned-one");

      --  A file of loose forms is a library too, and carries on the
      --  same way and is refused the same way.

      declare
         Before : constant Natural := VM.Forms_Abandoned;
      begin
         Evaluate (VM, "(import (probe loose))");

         Test ("a file is read past a form it cannot run",
               VM.Forms_Abandoned = Before + 2);
      end;

      Test_Undefined (VM, "loose-between");

      --  And a library with nothing wrong with it still arrives.

      Test_Name (VM, "alpha-name", "alpha");

      --  Two libraries that ask for each other: the second to ask
      --  gets what has been read of the first so far, which is
      --  reported, and both are readable afterwards.

      Evaluate (VM, "(import (probe ring-a))");
      Test_Name (VM, "ring-a-name", "ring-a");
      Evaluate (VM, "(import (probe ring-b))");
      Test_Name (VM, "ring-b-name", "ring-b");

      --  Each offers ring-shared and neither defines it, so following
      --  it back goes round the ring: it is not here, and asking does
      --  not go round for ever (#140).

      Test_Undefined (VM, "ring-shared");

      --  The base library's list procedures are written on walks it
      --  keeps to itself: one for the member family and one for the
      --  assoc family, each taking the question to ask.  Those are how
      --  the exported names are written, not names a program may take.

      Test_Undefined (VM, "(member-by eq? 1 '(1))");
      Test_Undefined (VM, "(assoc-by eq? 1 '((1 . 2)))");
      Test_Undefined (VM, "(reverse-onto '(1) '())");

      --  What they are written for is exported, and answers here.

      Test_Number (VM, "(car (reverse '(1 2 3)))", 3);
      Test_Number (VM, "(cdr (assv 2 '((1 . 10) (2 . 20))))", 20);
      Test_Number (VM, "(car (memv 2 '(1 2 3)))", 2);

      --  The same holds of the arithmetic: the walk min and max share
      --  and the pieces the division names are built from are how
      --  they are written, not names a program may take.

      Test_Undefined (VM, "(extreme < '(1 2))");
      Test_Undefined (VM, "(gcd2 4 6)");
      Test_Undefined (VM, "(lcm2 4 6)");
      Test_Undefined (VM, "(floor-adjust 4 1 1)");

      --  truncate/ and floor/ each answer two values, which they could
      --  not while there were no multiple values (#48); and the helpers
      --  that let-values is written with stay the library's own.

      Test_Name (VM, "(call-with-values (lambda () (floor/ -13 4)) list)",
                 "(-4 3)");
      Test_Name
        (VM, "(call-with-values (lambda () (truncate/ -13 4)) list)",
         "(-3 -1)");
      Test_Undefined (VM, "(values-rename '(a b))");

      --  What is here answers, and a negative number now reads.

      Test_Number (VM, "(modulo -13 4)", 3);
      Test_Number (VM, "(remainder -13 4)", -1);
      Test_Number (VM, "(max 3 1 2)", 3);
      Test_Number (VM, "(gcd 32 -36)", 4);

      --  list? walks twice over at two speeds so that it comes back
      --  from a list that runs back into itself.  The second walk is
      --  how it is written and not a name a program may take.

      Test_Undefined (VM, "(list-walk? '(1) '(1))");

      --  The primitives the machine could always do and had no name
      --  for.  Each answers here, which is also where a host's own
      --  forms are translated, so they are the library's and not
      --  something only the suite can see.

      Test_Number (VM, "(char->integer #\A)", 65);
      Test_Name (VM, "(symbol->string 'probe-name)", "probe-name");
      Test_Number (VM, "(apply + '(1 2 3))", 6);
      Test_Number (VM, "(apply + 1 2 '(3 4))", 10);
      Test_Number (VM, "(car (list-set! (list 1 2) 0 7))", 7);
      Test_Number (VM, "(if (char? #\a) 1 0)", 1);
      Test_Number (VM, "(if (exact-integer? 1) 1 0)", 1);

      --  A form the translator refuses reaches the host now, where it
      --  used to be reported and swallowed -- so Execute ran whatever
      --  had been emitted before the refusal, which for a form
      --  refused early is nothing, and the machine read an
      --  instruction off an empty code list.  These could not be
      --  written until #56; the first was written, watched take the
      --  harness down, and taken out again.

      Test_Translation_Error (VM, "(apply +)");
      Test_Translation_Error (VM, "(set! 1 2)");
      Test_Translation_Error (VM, "(lambda (1) 1)");
      Test_Translation_Error (VM, "(define (f 1) 1)");

      --  And the VM is still usable afterwards, which is the other
      --  half of being told rather than taken down.

      Test_Number (VM, "(+ 1 2)", 3);
      Test_Number (VM, "(apply + '(1 2 3))", 6);

      --  pair? is exported now, so it answers as a value and not only
      --  as a call the translator turns into an instruction.

      Test_Number (VM, "(if (pair? '(1)) 1 0)", 1);
      Test_Number (VM, "(length (map pair? '(1 (2) 3)))", 3);
      Test_Number (VM, "(if ((lambda (f) (f '(1))) pair?) 1 0)", 1);

      --  atom? was a form of the translator's and is not R7RS, so the
      --  name means nothing now -- which is what any name that is not
      --  defined means.

      Test_Undefined (VM, "(atom? 1)");
      Test_Undefined (VM, "atom?");

      --  A standard library asked for by name, off the same path the
      --  base library came from.  caddr is (scheme cxr)'s: R7RS takes
      --  the base library two deep and no further, so this is what a
      --  program that wants it has to say.

      Test_Undefined (VM, "(caddr '(1 2 3))");
      Evaluate (VM, "(import (scheme cxr))");
      Test_Number (VM, "(caddr '(1 2 3))", 3);
      Test_Number (VM, "(cadddr '(1 2 3 4))", 4);

      --  And (scheme inexact), where R7RS puts sqrt and the rest, so that
      --  a program that wants no floating point does not get it.

      Test_Undefined (VM, "(sqrt 4)");
      Evaluate (VM, "(import (scheme inexact))");
      Test_Number (VM, "(sqrt 4)", 2);

      --  A library that chooses its declarations by feature.  Every
      --  name it exports is chosen by a cond-expand, so if the choosing
      --  went wrong the import would find names undefined.

      Evaluate (VM, "(import (probe conditional))");
      Test_Name (VM, "conditional-which", "raven");
      Test_Name (VM, "conditional-library", "found");
      Test_Name (VM, "conditional-nested", "nested");

      --  A library that offers names under other names.  What an
      --  importer writes is the external name; the internal one stays
      --  the library's own, unless it is offered under that name too.

      Test_Undefined (VM, "renaming-outside");
      Evaluate (VM, "(import (probe renaming))");
      Test_Name (VM, "renaming-outside", "inside");
      Test_Undefined (VM, "renaming-inside");
      Test_Name (VM, "renaming-plain", "plain");
      Test_Name (VM, "(renaming-shown)", "inside");
      Test_Name (VM, "(renaming-doubled 3)", "(3 3)");
      Test_Undefined (VM, "(renaming-twice 3)");
      Test_Name (VM, "renaming-plain-again", "again");
      Test_Name (VM, "renaming-alias", "again");

      --  include-ci reads a file as though it began with #!fold-case,
      --  so the capitals it is written in are folded; a name is its
      --  name as written everywhere else, so the capitals themselves
      --  mean nothing here (#160).

      Evaluate (VM, "(import (probe folded))");
      Test_Name (VM, "folded-name", "folded");
      Test_Undefined (VM, "Folded-Name");

      --  A declaration nothing knows counts against the library, as a
      --  form it cannot run does, and nothing imports it.

      declare
         Before : constant Natural := VM.Forms_Abandoned;
      begin
         Evaluate (VM, "(import (probe undeclared))");
         Test ("a declaration nothing knows is counted",
               VM.Forms_Abandoned = Before + 1);
      end;

      Test_Undefined (VM, "undeclared-name");

      --  Import sets (#27).  (probe gamma) is imported only through
      --  them, so what one leaves out is not here by another way.

      Evaluate (VM, "(import (only (probe gamma) gamma-a))");
      Test_Name (VM, "gamma-a", "a");
      Test_Undefined (VM, "gamma-b");
      Test_Undefined (VM, "(gamma-twice 1)");

      Evaluate (VM, "(import (except (probe gamma) gamma-a gamma-b))");
      Test_Name (VM, "gamma-c", "c");
      Test_Undefined (VM, "gamma-b");

      --  A macro taken under another name still reads its template in
      --  the library it was written in.

      Test_Number (VM, "(gamma-twice 4)", 8);

      Evaluate (VM, "(import (prefix (probe gamma) g:))");
      Test_Name (VM, "g:gamma-b", "b");
      Test_Number (VM, "(g:gamma-twice 5)", 10);
      Test_Undefined (VM, "g:gamma-helper");

      Evaluate
        (VM,
         "(import (rename (probe gamma) (gamma-b bee) (gamma-twice double)))");
      Test_Name (VM, "bee", "b");
      Test_Number (VM, "(double 6)", 12);

      --  However nested, innermost first: only, then rename, then
      --  prefix.

      Evaluate
        (VM,
         "(import (prefix (rename (only (probe gamma) gamma-c)"
         & " (gamma-c sea)) p-))");
      Test_Name (VM, "p-sea", "c");
      Test_Undefined (VM, "p-gamma-c");
      Test_Undefined (VM, "sea");

      --  A rename is all at once, so two names can trade places.

      Evaluate
        (VM,
         "(import (rename (prefix (only (probe gamma) gamma-a gamma-b) s-)"
         & " (s-gamma-a s-gamma-b) (s-gamma-b s-gamma-a)))");
      Test_Name (VM, "s-gamma-a", "b");
      Test_Name (VM, "s-gamma-b", "a");

      --  A name the library does not offer is reported, imports
      --  nothing, and is not fatal.

      Evaluate (VM, "(import (only (probe gamma) gamma-a gamma-nowhere))");
      Evaluate (VM, "(import (rename (probe gamma) (gamma-nowhere x-a)))");
      Test_Undefined (VM, "gamma-nowhere");
      Test_Undefined (VM, "x-a");
      Test_Name (VM, "gamma-a", "a");

      --  And inside a library.

      Evaluate (VM, "(import (probe sets))");
      Test_Name (VM, "sets-name", "a");
      Test_Number (VM, "(sets-twice 7)", 14);
      Test_Undefined (VM, "in-gamma-a");

      --  A library that offers what it imported (#140).  A reference
      --  was compiled into the library that offered the name, which
      --  had imported it and never defined it, so it was undefined.
      --
      --  (probe chain) first, which offers what (probe reexport)
      --  offers: two steps back to (probe gamma), where the names are
      --  defined, and nothing of (probe reexport) is here yet to answer
      --  in its place.  The macro reads its template where it was
      --  written, which is further back still.

      Evaluate (VM, "(import (probe chain))");
      Test_Name (VM, "chained", "c");
      Test_Number (VM, "(reexport-twice 3)", 6);
      Test_Undefined (VM, "reexport-renamed");

      Evaluate (VM, "(import (probe reexport))");
      Test_Name (VM, "gamma-b", "b");
      Test_Name (VM, "reexport-renamed", "c");
      Test_Number (VM, "(reexport-twice 4)", 8);

      --  What the machine does for the base library is bound under a
      --  raven- name, so the R7RS name is only where a library offers
      --  it (#166).  vector-ref was a foreign function of that name,
      --  and so in every library whatever it imported.

      Evaluate (VM, "(import (probe bare))");
      Test_Name (VM, "bare-name", "bare");
      Test_Undefined (VM, "(bare-first (vector 1))");

      Evaluate (VM, "(import (probe hiding))");
      Test_Undefined (VM, "(hiding-first (vector 1))");
      Test_Number (VM, "(hiding-prefixed (vector 5))", 5);
      Test_Number (VM, "(hiding-length (vector 1 2 3))", 3);

      --  A caller's forward reference through a library's macro is the
      --  caller's (#178), though the library has a name of its own the
      --  same: it went to the library, and stayed there after the
      --  caller had defined it.

      Evaluate (VM, "(import (probe forward))");
      Evaluate (VM, "(define (forward-user) (call-it forward-helper))");
      Evaluate (VM, "(define (forward-helper) 'caller)");
      Test_Name (VM, "(forward-user)", "caller");
      Test_Name (VM, "(forward-own)", "library");

      --  A macro a library's macro writes here means by its template's
      --  names what the library meant (#180), though the name is one the
      --  library keeps and this library has one of its own.  Its rules
      --  were quoted, which read every alias in them as a plain name.

      Evaluate (VM, "(import (probe maker))");
      Evaluate (VM, "(define (maker-helper) 'host)");
      Evaluate (VM, "(def-maker call-maker)");
      Test_Name (VM, "(call-maker)", "maker");
      Test_Name (VM, "(maker-helper)", "host");

      --  A literal of a macro's rules matches a name that means what it
      --  means where the macro was written (#179), so an else a library
      --  defines is not cond's else there.

      Evaluate (VM, "(import (probe elsewhere))");
      Test_Name (VM, "elsewhere-result", "#f");

      --  A record type defined in a library (#154).  What it offers
      --  works here, on records made here; what it keeps is not here.

      Evaluate (VM, "(import (probe records))");
      Test_Number (VM, "(pair-of-left (make-pair-of 3 4))", 3);
      Test_Number (VM, "(pair-of-sum (make-pair-of 3 4))", 7);
      Test_Name (VM, "(pair-of? (make-pair-of 3 4))", "#t");
      Test_Name (VM, "(pair-of? (vector 3 4))", "#f");
      Test_Undefined (VM, "(pair-of-right (make-pair-of 3 4))");
      Test_Undefined (VM, "(set-pair-of-left! (make-pair-of 3 4) 1)");
   end Run_Tests;

   ---------------
   -- Test_Name --
   ---------------

   procedure Test_Name
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      Evaluate (VM, Expression);
      --  As a person reads it rather than as the reader would read
      --  it back: this asks for a name, and a name that came from
      --  symbol->string is a string, which quotes itself when it is
      --  written readably.

      Test ("library: " & Expression,
            VM.Show_Slot (1, Readable => False), Expected);
   end Test_Name;

   -----------------
   -- Test_Number --
   -----------------

   procedure Test_Number
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      Evaluate (VM, Expression);
      Test ("library: " & Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   end Test_Number;

   ----------------------------
   -- Test_Translation_Error --
   ----------------------------

   procedure Test_Translation_Error
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("library: " & Expression & " is refused", False);
   exception
      when Raven.Target.Translation_Error =>
         Test ("library: " & Expression & " is refused", True);
   end Test_Translation_Error;

   --------------------
   -- Test_Undefined --
   --------------------

   procedure Test_Undefined
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("library: " & Expression & " is not here", False);
   exception
      when Raven.Target.Undefined_Symbol =>
         Test ("library: " & Expression & " is not here", True);
   end Test_Undefined;

end Raven.Tests.Imports;
