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

      --  truncate/ and floor/ each answer two values, and there are
      --  no multiple values yet, so neither is here.

      Test_Undefined (VM, "(truncate/ 13 4)");
      Test_Undefined (VM, "(floor/ 13 4)");

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

      --  include-ci is include here, because every file is read with
      --  its identifiers folded already.

      Evaluate (VM, "(import (probe folded))");
      Test_Name (VM, "folded-name", "folded");

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
