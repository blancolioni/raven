with Ada.Exceptions;
with Ada.Strings.Fixed;

with Raven.Target;

package body Raven.Tests.Forms is

   --  A VM of its own with a host that hears nothing, because this
   --  suite provokes a complaint on purpose about thirty times and
   --  every one of them would otherwise be printed beside the tests
   --  that asked for it.

   type Quiet is new IO_Interface with null record;

   overriding procedure Put
     (This : in out Quiet;
      Ch   : Wide_Wide_Character)
   is null;

   overriding procedure Put_Error
     (This : in out Quiet;
      Ch   : Wide_Wide_Character)
   is null;

   overriding procedure Get
     (This      : in out Quiet;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean);

   Host : aliased Quiet;

   --  A form of the wrong shape is refused, and what it is told is
   --  what the form takes.  Both halves matter: after #56 a refusal
   --  reached the host rather than stopping the machine, but
   --  Assertion_Error is not something to tell a program about
   --  itself, and it said nothing about what was wrong.

   procedure Refused
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   --  And one of the right shape is not refused.  A check on a shape
   --  that refuses the shape it means to allow is worse than none.

   procedure Allowed
     (VM         : Raven_VM;
      Expression : String);

   -------------
   -- Allowed --
   -------------

   procedure Allowed
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression & " is allowed", "allowed", "allowed");
   exception
      when E : others =>
         Test (Expression & " is allowed", "allowed",
               Ada.Exceptions.Exception_Message (E));
   end Allowed;

   ---------
   -- Get --
   ---------

   overriding procedure Get
     (This      : in out Quiet;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean)
   is
      pragma Unreferenced (This);
   begin
      Ch := ' ';
      Available := False;
   end Get;

   --------------
   -- Refused --
   --------------

   procedure Refused
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
      use Ada.Strings.Fixed;
   begin
      VM.Evaluate (Expression);
      Test (Expression & " is refused", Expected, "it was allowed");
   exception
      when E : Raven.Target.Translation_Error =>

         --  Caught by its own name and not by others, because which
         --  exception this is is half of what is under test: an
         --  assertion out of Raven.Pairs is what it used to be.

         Test (Expression & " is refused",
               Expected,
               (if Index (Ada.Exceptions.Exception_Message (E), Expected) > 0
                then Expected
                else Ada.Exceptions.Exception_Message (E)));

      when E : others =>
         Test (Expression & " is refused",
               Expected,
               Ada.Exceptions.Exception_Name (E));
   end Refused;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests is
      VM : Raven_VM :=
             New_VM (IO           => Host'Access,
                     Library_Path => Library_Path);
   begin
      VM.Evaluate ("(import (scheme base))");

      --  define, which is where this was found.

      Refused (VM, "(define)", "define takes a name and a value");
      Refused (VM, "(define x)", "define takes a name and a value");
      Refused (VM, "(define x 1 2)", "define of a name takes one value");
      Refused (VM, "(define 1 2)", "define takes a name or a header");
      Refused (VM, "(define (f))", "define takes a name and a value");

      Allowed (VM, "(define probe-x 1)");
      Allowed (VM, "(define (probe-f x) x)");

      --  if, which took the car of what followed it and then the car
      --  of what followed that.

      Refused (VM, "(if)", "if takes a test");
      Refused (VM, "(if #t)", "if takes a test");
      Refused (VM, "(if #t 1 2 3)", "if takes a test");

      Allowed (VM, "(if #t 1 2)");
      Allowed (VM, "(if #t 1)");

      --  quote and quasiquote take one datum and no more.

      Refused (VM, "(quote)", "quote takes one datum");
      Refused (VM, "(quote 1 2)", "quote takes one datum");
      Refused (VM, "(quasiquote)", "quasiquote takes one datum");
      Refused (VM, "(quasiquote 1 2)", "quasiquote takes one datum");

      Allowed (VM, "(quote a)");
      Allowed (VM, "(quasiquote a)");

      --  lambda wants somewhere to put its parameters and something
      --  to do with them.

      Refused (VM, "(lambda)", "lambda takes a parameter list");
      Refused (VM, "(lambda (x))", "lambda takes a parameter list");

      Allowed (VM, "(lambda (x) x)");
      Allowed (VM, "(lambda () 1)");

      --  set! looked at the kind of what it found before asking
      --  whether it had found anything.

      Refused (VM, "(set!)", "set! takes a name and a value");
      Refused (VM, "(set! probe-x)", "set! takes a name and a value");
      Refused (VM, "(set! probe-x 1 2)", "set! takes a name and a value");
      Refused (VM, "(set! 1 2)", "set! requires a symbol");

      Allowed (VM, "(set! probe-x 2)");

      --  syntax-error (#156) refuses the form it is in as the forms
      --  above are refused, with its message and the rest of the form
      --  written after it -- which is how a syntax-rules template
      --  refuses a use of its macro.

      Refused (VM, "(syntax-error ""not like that"")",
               "syntax-error: not like that");
      Refused (VM, "(syntax-error ""not like that"" 1 x ""y"")",
               "syntax-error: not like that 1 x ""y""");

      Allowed
        (VM,
         "(define-syntax probe-two"
         & " (syntax-rules ()"
         & " ((_ a b) (list a b))"
         & " ((_ . other) (syntax-error ""probe-two takes two"" other))))");
      Allowed (VM, "(probe-two 1 2)");
      Refused (VM, "(probe-two 1)", "syntax-error: probe-two takes two (1)");

      --  Refused where it is expanded, so nothing of the form has run:
      --  the set! in front of it has not happened.

      Refused (VM, "(begin (set! probe-x 3) (syntax-error ""stop""))",
               "syntax-error: stop");
      Allowed (VM, "(if (= probe-x 2) 1 (car 1))");

      --  The ones the machine has an instruction for.

      Refused (VM, "(raven-eq?)", "raven-eq? takes two forms");
      Refused (VM, "(raven-eq? 1)", "raven-eq? takes two forms");
      Refused (VM, "(raven-eq? 1 2 3)", "raven-eq? takes two forms");
      Refused (VM, "(car)", "car takes one form");
      Refused (VM, "(car '(1) 2)", "car takes one form");
      Refused (VM, "(cdr)", "cdr takes one form");
      Refused (VM, "(cdr '(1) 2)", "cdr takes one form");
      Refused (VM, "(cons)", "cons takes two forms");
      Refused (VM, "(cons 1)", "cons takes two forms");
      Refused (VM, "(cons 1 2 3)", "cons takes two forms");
      Refused (VM, "(pair?)", "pair? takes one form");
      Refused (VM, "(pair? 1 2)", "pair? takes one form");

      Allowed (VM, "(raven-eq? 1 1)");

      --  A procedure of two parameters called with none.  What it was
      --  not given is nil, which is how the library gives a procedure
      --  an argument it need not be given; finding the second of them
      --  asked for the cdr of an empty frame, so (eq?) -- the
      --  library's, not the machine's -- failed a precondition too.

      Allowed (VM, "(eq?)");
      Allowed (VM, "(eq? 1)");
      Allowed (VM, "(car '(1))");
      Allowed (VM, "(cdr '(1))");
      Allowed (VM, "(cons 1 2)");
      Allowed (VM, "(pair? '(1))");

      --  apply said this much already, and says it the same way as
      --  the rest now.

      Refused (VM, "(apply)", "apply takes a procedure");
      Refused (VM, "(apply car)", "apply takes a procedure");

      Allowed (VM, "(apply car '((1)))");

      --  define-macro looked at the kind of its first argument
      --  without asking whether there was one.

      Refused (VM, "(define-macro)", "define-macro takes a header");
      Refused (VM, "(define-macro (m))", "define-macro takes a header");
      Refused (VM, "(define-macro m 1)",
               "define-macro: first argument must be");

      Allowed (VM, "(define-macro (probe-m x) x)");

      VM.Close_VM;
   end Run_Tests;

end Raven.Tests.Forms;
