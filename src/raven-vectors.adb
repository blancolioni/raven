with Raven.Objects;
with Raven.Strings;

package body Raven.Vectors is

   procedure Bytevector_Length (VM : Raven_VM);
   procedure Bytevector_Ref (VM : Raven_VM);
   procedure Bytevector_Set (VM : Raven_VM);

   procedure Check_Vector
     (VM   : Raven_VM;
      Name : String;
      V    : Object);

   function Checked_Index
     (VM   : Raven_VM;
      Name : String;
      V    : Object)
      return Natural;

   procedure Is_Bytevector (VM : Raven_VM);
   procedure Is_Vector (VM : Raven_VM);
   procedure Make_Bytevector (VM : Raven_VM);
   procedure Make_Vector (VM : Raven_VM);
   procedure String_To_UTF8 (VM : Raven_VM);
   procedure UTF8_To_String (VM : Raven_VM);
   procedure Vector_Length (VM : Raven_VM);
   procedure Vector_Ref (VM : Raven_VM);
   procedure Vector_Set (VM : Raven_VM);

   -----------------------
   -- Bytevector_Length --
   -----------------------

   procedure Bytevector_Length (VM : Raven_VM) is
      V : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Bytevector (V) then
         raise Constraint_Error with
           "bytevector-length: not a bytevector: "
           & Encode (VM.Display (V));
      end if;

      VM.Set_Slot (1, VM.Vector_Length (V));
   end Bytevector_Length;

   --------------------
   -- Bytevector_Ref --
   --------------------

   procedure Bytevector_Ref (VM : Raven_VM) is
      V : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Bytevector (V) then
         raise Constraint_Error with
           "bytevector-u8-ref: not a bytevector: "
           & Encode (VM.Display (V));
      end if;

      declare
         Element : constant Object :=
                     VM.Vector_Element
                       (V, Checked_Index (VM, "bytevector-u8-ref", V));
      begin
         VM.Set_Slot (1, Element);
      end;
   end Bytevector_Ref;

   --------------------
   -- Bytevector_Set --
   --------------------

   procedure Bytevector_Set (VM : Raven_VM) is
      V     : constant Object := VM.Get_Slot (1);
      Value : constant Integer := VM.Get_Slot (3);
   begin
      if not Raven.Objects.Is_Bytevector (V) then
         raise Constraint_Error with
           "bytevector-u8-set!: not a bytevector: "
           & Encode (VM.Display (V));
      end if;

      --  What tells a bytevector from a vector is what may go into
      --  one, and this is where that is said.

      if Value not in 0 .. 255 then
         raise Constraint_Error with
           "bytevector-u8-set!:" & Value'Image & " is not a byte";
      end if;

      VM.Set_Vector_Element
        (V, Checked_Index (VM, "bytevector-u8-set!", V), VM.Get_Slot (3));
   end Bytevector_Set;

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

   -------------------
   -- Is_Bytevector --
   -------------------

   procedure Is_Bytevector (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Raven.Objects.Is_Bytevector (VM.Get_Slot (1)));
   end Is_Bytevector;

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

      Evaluator.Bind_Foreign_Function
        ("bytevector?", Is_Bytevector'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-make-bytevector", Make_Bytevector'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("bytevector-length", Bytevector_Length'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("bytevector-u8-ref", Bytevector_Ref'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("bytevector-u8-set!", Bytevector_Set'Access, 3);
      Evaluator.Bind_Foreign_Function
        ("string->utf8", String_To_UTF8'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("utf8->string", UTF8_To_String'Access, 1);
   end Load_Vector_Library;

   ---------------------
   -- Make_Bytevector --
   ---------------------

   procedure Make_Bytevector (VM : Raven_VM) is
      Length : constant Integer := VM.Get_Slot (1);
      Fill   : constant Integer := VM.Get_Slot (2);
   begin
      if Length < 0 then
         raise Constraint_Error with
           "make-bytevector: a bytevector cannot be"
           & Length'Image & " long";
      end if;

      if Fill not in 0 .. 255 then
         raise Constraint_Error with
           "make-bytevector:" & Fill'Image & " is not a byte";
      end if;

      declare
         V : constant Object := VM.New_Bytevector (Length);
         Byte : constant Object := VM.Get_Slot (2);
      begin
         for I in 0 .. Length - 1 loop
            VM.Set_Vector_Element (V, I, Byte);
         end loop;

         VM.Set_Slot (1, V);
      end;
   end Make_Bytevector;

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

   --------------------
   -- String_To_UTF8 --
   --------------------

   --  The bytes a string comes to, which is what raven writes a
   --  string as outside itself: Encode is the UTF-8 of it.

   procedure String_To_UTF8 (VM : Raven_VM) is
   begin
      if not Raven.Strings.Is_String (VM, 1) then
         raise Constraint_Error with
           "string->utf8: not a string: "
           & Encode (VM.Display (VM.Get_Slot (1)));
      end if;

      declare
         Text : constant String := Raven.Strings.Get_String (VM, 1);
         V    : constant Object := VM.New_Bytevector (Text'Length);
      begin
         for I in Text'Range loop
            VM.Set_Vector_Element
              (V, I - Text'First,
               Raven.Objects.To_Object
                 (Integer (Character'Pos (Text (I)))));
         end loop;

         VM.Set_Slot (1, V);
      end;
   end String_To_UTF8;

   --------------------
   -- UTF8_To_String --
   --------------------

   procedure UTF8_To_String (VM : Raven_VM) is
      V : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Bytevector (V) then
         raise Constraint_Error with
           "utf8->string: not a bytevector: " & Encode (VM.Display (V));
      end if;

      declare
         Length : constant Natural := VM.Vector_Length (V);
         Text   : String (1 .. Length);
      begin
         for I in Text'Range loop
            Text (I) :=
              Character'Val
                (Integer'(Raven.Objects.To_Integer
                            (VM.Vector_Element (V, I - 1))));
         end loop;

         --  Decode says whether the bytes are UTF-8 at all, and
         --  raises where they are not, which is what should happen.

         Raven.Strings.Write_String (VM, 1, Text);
      end;
   end UTF8_To_String;

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
