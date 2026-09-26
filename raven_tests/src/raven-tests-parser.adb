with Ada.Exceptions;
with Ada.Text_IO;

package body Raven.Tests.Parser is

   procedure Test_Parser
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

   procedure Test_Parser
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   procedure Test_Parser
     (VM         : Raven_VM;
      Expression : String);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      Test_Parser (VM, "((lambda () 1 2 3))", 3);
      Test_Parser (VM, "123", 123);
      Test_Parser (VM, "'hello-world", "hello-world");
      Test_Parser (VM, "(if #t 1011 'blah)", 1011);
      Test_Parser (VM, "(if #f 1011 'blah)", "blah");
      Test_Parser (VM, "((lambda (x) x) 12)", 12);
      Test_Parser (VM, "(eq? 1 1)");
      Test_Parser (VM, "(if (eq? 1 2) #f #t)");
      Test_Parser (VM, "((lambda (x) (if (eq? x 2) x 99)) 2)", 2);
      Test_Parser (VM, "((lambda (x) (if (eq? x 2) x 99)) 3)", 99);
      Test_Parser (VM, "(define xxx 42)");
      Test_Parser (VM, "xxx", 42);
      Test_Parser (VM, "(and #t #t)");
      Test_Parser (VM, "(boolean? #t)");
      Test_Parser (VM, "(boolean? #f)");
      Test_Parser (VM, "(not (boolean? 123))");
      Test_Parser (VM, "(not (boolean? '()))");
      Test_Parser (VM, "(not (boolean? ""True""))");
      Test_Parser (VM, "(not (boolean? boolean?))");
      Test_Parser (VM, "(not (string? #f))");
      Test_Parser (VM, "(not (string? 123))");
      Test_Parser (VM, "(not (string? '()))");
      Test_Parser (VM, "(string? ""Hello"")");
      Test_Parser (VM, "(car '(1 2))", 1);
      Test_Parser (VM, "(car (cons 1 '()))", 1);

      --  Macro tests
      Test_Parser (VM,
                   "(define-macro (my-when cond body)"
                   & " `(if ,cond ,body #f))");
      Test_Parser (VM, "(my-when #t 42)", 42);
      Test_Parser (VM, "(not (my-when #f 42))");

      Test_Parser (VM,
                   "(define-macro (my-and a b)"
                   & " `(if ,a ,b #f))");
      Test_Parser (VM, "(my-and #t 99)", 99);
      Test_Parser (VM, "(not (my-and #f 99))");

      Test_Parser (VM,
                   "(define-macro (my-or a b)"
                   & " `(if ,a ,a ,b))");
      Test_Parser (VM, "(my-or #f 7)", 7);
      Test_Parser (VM, "(my-or 5 7)", 5);
   end Run_Tests;

   -----------------
   -- Test_Parser --
   -----------------

   procedure Test_Parser
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      VM.Evaluate (Expression);
      Test ("evaluate: " & Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   exception
      when E : others =>
         Ada.Text_IO.Put (Expression);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
         raise;
   end Test_Parser;

   -----------------
   -- Test_Parser --
   -----------------

   procedure Test_Parser
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("evaluate: " & Expression,
            VM.Show_Slot (1),
            Expected);
   end Test_Parser;

   -----------------
   -- Test_Parser --
   -----------------

   procedure Test_Parser
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, VM.Get_Slot (1));
   end Test_Parser;

end Raven.Tests.Parser;
