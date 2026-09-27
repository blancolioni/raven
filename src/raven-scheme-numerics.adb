package body Raven.Scheme.Numerics is

   procedure Add (VM : Raven_VM);
   procedure Divide (VM : Raven_VM);
   procedure Leq (VM : Raven_VM);
   procedure Multiply (VM : Raven_VM);
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

   ------------
   -- Divide --
   ------------

   procedure Divide (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      --  Every number here is an integer, and R7RS asks for an exact
      --  rational: (/ 7 2) is 7/2 and not 3.  Until there is a tower
      --  to answer with, this divides and throws the remainder away,
      --  which is the answer a reader of (/ 6 2) expects and not the
      --  one a reader of (/ 7 2) does.

      if Y = 0 then
         raise Constraint_Error with "divide by zero";
      end if;

      VM.Set_Slot (1, X / Y);
   end Divide;

   ---------
   -- Leq --
   ---------

   procedure Leq (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X <= Y);
   end Leq;

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
      Evaluator.Bind_Foreign_Function
        ("raven-mul", Multiply'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-div", Divide'Access, 2);
   end Load_Numeric_Library;

   --------------
   -- Multiply --
   --------------

   procedure Multiply (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X * Y);
   end Multiply;

   ---------
   -- Sub --
   ---------

   procedure Sub (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X - Y);
   end Sub;


end Raven.Scheme.Numerics;
