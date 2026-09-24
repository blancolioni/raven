package body Raven.Tests.Library is

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Library
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean);

   procedure Test_Value
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

   procedure Probe_False (VM : Raven_VM);

   procedure Probe_True (VM : Raven_VM);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      Test_Library (VM, "(not #f)", True);
      Test_Library (VM, "(not #t)", False);
      Test_Library (VM, "(and #f #f)", False);
      Test_Library (VM, "(and #t #f)", False);
      Test_Library (VM, "(and #f #t)", False);
      Test_Library (VM, "(and #t #t)", True);
      Test_Library (VM, "(or #f #f)", False);
      Test_Library (VM, "(or #f #t)", True);
      Test_Library (VM, "(or #t #f)", True);
      Test_Library (VM, "(or #t #t)", True);

      --  car refused something that was not a pair and cdr did not,
      --  so a cdr of one was an assertion failure out of the machine
      --  with contracts on and an arbitrary cell with them off.  Both
      --  say what happened now.

      Test_Error (VM, "(car 5)");
      Test_Error (VM, "(cdr 5)");
      Test_Error (VM, "(car '())");
      Test_Error (VM, "(cdr '())");
      Test_Error (VM, "(car 'a)");
      Test_Error (VM, "(cdr 'a)");
      Test_Error (VM, "(car #\a)");
      Test_Error (VM, "(cdr #\a)");

      --  And a pair still comes apart.

      Test_Value (VM, "(car '(1 2))", 1);
      Test_Value (VM, "(car (cdr '(1 2)))", 2);
      Test_Value (VM, "(car (cdr (cons 1 (cons 2 '()))))", 2);

      --  Which is the point of it: every list procedure walks with
      --  cdr, so this is the check that decides whether a program that
      --  runs off the end of a list is told.

      Test_Error (VM, "(length 5)");
      Test_Error (VM, "(list-tail '(1 2) 5)");
      Test_Error (VM, "(list-ref '(1 2) 5)");
      Test_Error (VM, "(map car 5)");

      --  A walk that stops where it should is unaffected.

      Test_Value (VM, "(length '(1 2 3))", 3);
      Test_Value (VM, "(list-ref '(1 2 3) 2)", 3);

      --  A foreign function can be bound again under the same name,
      --  and the new handler is the one that runs.

      VM.Bind_Foreign_Function ("probe-answer", Probe_False'Access, 0);
      Test_Library (VM, "(probe-answer)", False);
      VM.Bind_Foreign_Function ("probe-answer", Probe_True'Access, 0);
      Test_Library (VM, "(probe-answer)", True);
   end Run_Tests;

   -----------------
   -- Probe_False --
   -----------------

   procedure Probe_False (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, False);
   end Probe_False;

   ----------------
   -- Probe_True --
   ----------------

   procedure Probe_True (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, True);
   end Probe_True;

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

   ------------------
   -- Test_Library --
   ------------------

   procedure Test_Library
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, VM.Get_Slot (1) = Expected);
   end Test_Library;

   ----------------
   -- Test_Value --
   ----------------

   procedure Test_Value
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   end Test_Value;

end Raven.Tests.Library;
