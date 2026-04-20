package body Raven.Scheme.Numerics is

   procedure Add (VM : Raven_VM);
   procedure Leq (VM : Raven_VM);
   procedure Sub (VM : Raven_VM);

   ---------
   -- Add --
   ---------

   procedure Add (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X + Y);
   end Add;

   ---------
   -- Leq --
   ---------

   procedure Leq (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X <= Y);
   end Leq;

   ---------
   -- Sub --
   ---------

   procedure Sub (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X - Y);
   end Sub;

   --------------------------
   -- Load_Numeric_Library --
   --------------------------

   procedure Load_Numeric_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Evaluator.Bind_Foreign_Function
        ("raven-add", Add'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-leq", Leq'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-sub", Sub'Access, 2);
   end Load_Numeric_Library;


end Raven.Scheme.Numerics;
