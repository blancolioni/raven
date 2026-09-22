with Ada.Exceptions;
with Ada.Text_IO;

package body Raven.Tests.Strings is

   procedure Evaluate
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

      Test_String (VM, "(string-append (display 12) (display 34))", "1234");

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
