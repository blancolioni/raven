with Ada.Exceptions;
with Ada.Text_IO;

package body Raven.Tests.Strings is

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_String
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

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
      Test_String (VM, "(string-append ""ab"" ""cd"")", "abcd");

      --  Where to start and where to stop have to be within the
      --  string.  string->list was bound as taking one argument and
      --  threw both away, so there was nothing to be outside of.

      Test_Error (VM, "(string->list ""abc"" 0 4)");
      Test_Error (VM, "(string->list ""abc"" 2 1)");
      Test_Error (VM, "(substring ""abc"" 0 9)");
      Test_Error (VM, "(string-ref ""abc"" 9)");

      --  The escapes R7RS asks for in a string.  \a and \b were not
      --  among them, and anything the reader did not know reported
      --  itself and then raised as well, which took the form and the
      --  host with it.

      Test_String (VM, "(char->integer (car (string->list ""\a"")))", "7");
      Test_String (VM, "(char->integer (car (string->list ""\b"")))", "8");

      --  The six it did know, which have to go on working.

      Test_String (VM, "(char->integer (car (string->list ""\t"")))", "9");
      Test_String (VM, "(char->integer (car (string->list ""\n"")))", "10");
      Test_String (VM, "(char->integer (car (string->list ""\r"")))", "13");
      Test_String (VM, "(char->integer (car (string->list ""\\"")))", "92");
      Test_String (VM, "(char->integer (car (string->list ""\|"")))", "124");
      Test_String (VM, "(char->integer (car (string->list ""\x41;"")))", "65");

      --  An escape is one character of the string, whatever it is.

      Test_String (VM, "(string-length ""a\ab"")", "3");
      Test_String (VM, "(string-length ""a\bb"")", "3");
      Test_String (VM, "(string-length ""a\x41;b"")", "3");

      --  And one the reader does not know is reported and stands for
      --  itself, rather than ending the session.  The line it writes
      --  on standard error is the point of the test.

      Test_String (VM, "(string-length ""a\qb"")", "3");
      Test_String
        (VM, "(char->integer (car (cdr (string->list ""a\qb""))))", "113");

      --  Two strings that are live at the same time must not alias each
      --  other: each foreign value needs its own id.

      Evaluate (VM, "(define pair-a (string-append ""ab"" ""cd""))");
      Evaluate (VM, "(define pair-b (string-append ""ef"" ""gh""))");
      Test_String (VM, "pair-a", "abcd");
      Test_String (VM, "pair-b", "efgh");

      --  A run of allocations, to catch an id allocator that only loses
      --  every second value.

      Evaluate (VM, "(define run-1 (string-append ""r"" ""1""))");
      Evaluate (VM, "(define run-2 (string-append ""r"" ""2""))");
      Evaluate (VM, "(define run-3 (string-append ""r"" ""3""))");
      Evaluate (VM, "(define run-4 (string-append ""r"" ""4""))");
      Evaluate (VM, "(define run-5 (string-append ""r"" ""5""))");
      Test_String (VM, "run-1", "r1");
      Test_String (VM, "run-2", "r2");
      Test_String (VM, "run-3", "r3");
      Test_String (VM, "run-4", "r4");
      Test_String (VM, "run-5", "r5");

      --  An existing string keeps its value when later strings are made.

      Evaluate (VM, "(define kept (string-append ""keep"" ""me""))");
      Evaluate (VM, "(define ignored-1 (string-append ""throw"" ""away""))");
      Evaluate (VM, "(define ignored-2 (string-append ""throw"" ""away""))");
      Test_String (VM, "kept", "keepme");
      Test_String (VM, "(string-length kept)", "6");

      --  display allocates strings too, so the same aliasing shows up
      --  when its results are combined.

      Test_String
        (VM,
         "(string-append (raven-display-text 12) (raven-display-text 34))",
         "1234");

      --  Nested appends: the intermediate result must survive the
      --  allocation of the outer one.

      Test_String (VM,
                   "(string-append (string-append ""a"" ""b"")"
                   & " (string-append ""c"" ""d""))",
                   "abcd");

      --  The shape the scheme test harness uses.

      Test_String (VM,
                   "(string-append ""PASS  "" ""nil is not truthy"")",
                   "PASS  nil is not truthy");
   end Run_Tests;

   ----------------
   -- Test_Error --
   ----------------

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression & " is an error", False);
   exception
      when Constraint_Error =>
         Test (Expression & " is an error", True);
   end Test_Error;

   -----------------
   -- Test_String --
   -----------------

   procedure Test_String
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      Evaluate (VM, Expression);
      Test ("evaluate: " & Expression,
            VM.Get_Slot (1),
            Expected);
   end Test_String;

end Raven.Tests.Strings;
