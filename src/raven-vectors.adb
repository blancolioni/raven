with Raven.Objects;

package body Raven.Vectors is

   procedure Is_Vector (VM : Raven_VM);
   procedure Make_Vector (VM : Raven_VM);
   procedure Vector_Length (VM : Raven_VM);
   procedure Vector_Ref (VM : Raven_VM);
   procedure Vector_Set (VM : Raven_VM);

   procedure Check_Vector
     (VM   : Raven_VM;
      Name : String;
      V    : Object);

   function Checked_Index
     (VM   : Raven_VM;
      Name : String;
      V    : Object)
      return Natural;

   ------------------
   -- Check_Vector --
   ------------------

   procedure Check_Vector
     (VM   : Raven_VM;
      Name : String;
      V    : Object)
   is
   begin
      if not Raven.Objects.Is_Vector (V) then
         raise Constraint_Error with
           Name & ": not a vector: " & Encode (VM.Display (V));
      end if;
   end Check_Vector;

   -------------------
   -- Checked_Index --
   -------------------

   --  The index is in slot 2 wherever one is taken, and is within the
   --  vector or it is nothing: reading past the end would read the
   --  cell after it, which belongs to whatever was made next.

   function Checked_Index
     (VM   : Raven_VM;
      Name : String;
      V    : Object)
      return Natural
   is
      Index  : constant Integer := VM.Get_Slot (2);
      Length : constant Natural := VM.Vector_Length (V);
   begin
      if Index not in 0 .. Length - 1 then
         raise Constraint_Error with
           Name & ":" & Index'Image & " is not an index of a vector of"
           & Length'Image;
      end if;

      return Index;
   end Checked_Index;

   ---------------
   -- Is_Vector --
   ---------------

   procedure Is_Vector (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Raven.Objects.Is_Vector (VM.Get_Slot (1)));
   end Is_Vector;

   -------------------------
   -- Load_Vector_Library --
   -------------------------

   procedure Load_Vector_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Evaluator.Bind_Foreign_Function
        ("vector?", Is_Vector'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-make-vector", Make_Vector'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("vector-length", Vector_Length'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("vector-ref", Vector_Ref'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("vector-set!", Vector_Set'Access, 3);
   end Load_Vector_Library;

   -----------------
   -- Make_Vector --
   -----------------

   procedure Make_Vector (VM : Raven_VM) is
      Length : constant Integer := VM.Get_Slot (1);
   begin
      if Length < 0 then
         raise Constraint_Error with
           "make-vector: a vector cannot be" & Length'Image & " long";
      end if;

      --  Making the vector may collect, and what is to fill it is in
      --  slot 2, which is where the collector looks.  So the fill is
      --  read back out of the slot afterwards and not before.

      declare
         V : constant Object := VM.New_Vector (Length);
         Fill : constant Object := VM.Get_Slot (2);
      begin
         for I in 0 .. Length - 1 loop
            VM.Set_Vector_Element (V, I, Fill);
         end loop;

         VM.Set_Slot (1, V);
      end;
   end Make_Vector;

   -------------------
   -- Vector_Length --
   -------------------

   procedure Vector_Length (VM : Raven_VM) is
      V : constant Object := VM.Get_Slot (1);
   begin
      Check_Vector (VM, "vector-length", V);
      VM.Set_Slot (1, VM.Vector_Length (V));
   end Vector_Length;

   ----------------
   -- Vector_Ref --
   ----------------

   procedure Vector_Ref (VM : Raven_VM) is
      V : constant Object := VM.Get_Slot (1);
   begin
      Check_Vector (VM, "vector-ref", V);

      declare
         Element : constant Object :=
                     VM.Vector_Element
                       (V, Checked_Index (VM, "vector-ref", V));
      begin
         VM.Set_Slot (1, Element);
      end;
   end Vector_Ref;

   ----------------
   -- Vector_Set --
   ----------------

   procedure Vector_Set (VM : Raven_VM) is
      V : constant Object := VM.Get_Slot (1);
   begin
      Check_Vector (VM, "vector-set!", V);

      VM.Set_Vector_Element
        (V, Checked_Index (VM, "vector-set!", V), VM.Get_Slot (3));

      --  The vector is left in slot 1, so vector-set! answers with
      --  it, which is the shape set-car! and write-char take.
   end Vector_Set;

end Raven.Vectors;
