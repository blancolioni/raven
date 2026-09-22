package body Raven.Tests.Library is

   procedure Test_Library
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean);

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

end Raven.Tests.Library;
