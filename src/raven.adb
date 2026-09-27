with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Unchecked_Deallocation;
with Raven.Engine;
with Raven.Evaluator;
with Raven.Features;
with Raven.IO;
with Raven.Loader;
with Raven.Memory;
with Raven.Objects;
with Raven.Parser;
with Raven.Strings;
with Raven.Target;
with Raven_Config;
with Resources;

package body Raven is

   function Decode (S : String) return Wide_Wide_String
   is (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (S));

   function Encode (T : Wide_Wide_String) return String
   is (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (T));

   package Raven_Resources is
     new Resources (Raven_Config.Crate_Name);

   type Raven_VM_Record is
      record
         User_Data   : User_Data_Reference;
         Evaluator   : Raven.Evaluator.Reference;
         Memory      : Raven.Memory.Reference;
         Target      : Raven.Target.Reference;
         IO          : IO_Reference;
      end record;

   --  What the base library's features and cond-expand are written
   --  on.  They are bound here, before (scheme base) is read, because
   --  the requirement test is the loader's and wants the target, which
   --  only the VM reaches.

   procedure Features_Of (VM : Raven_VM);
   procedure Holds_Requirement (VM : Raven_VM);

   procedure Check_Kind
     (This     : Raven_VM;
      Index    : Slot_Index;
      Expected : Value_Kind;
      Name     : String);

   ----------------------
   -- Add_Library_Path --
   ----------------------

   procedure Add_Library_Path
     (This : Raven_VM;
      Path : String)
   is
   begin
      This.Data.Target.Add_Library_Path (Path);
   end Add_Library_Path;

   ---------------------------
   -- Bind_Foreign_Function --
   ---------------------------

   procedure Bind_Foreign_Function
     (This           : Raven_VM;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural)
   is
   begin
      This.Data.Evaluator.Bind_Foreign_Function
        (Name, Handler, Argument_Count);
   end Bind_Foreign_Function;

   ---------------
   -- Bind_Name --
   ---------------

   function Bind_Name
     (This : Raven_VM;
      Name : String)
      return Handle
   is
   begin
      return (Position => This.Data.Evaluator.Bind_Handle_To_Name (Name));
   end Bind_Name;

   ---------
   -- Car --
   ---------

   function Car (This : Raven_VM'Class;
                 Pair : Object)
                 return Object
   is
   begin
      return This.Data.Memory.Get (Objects.Get_Address (Pair)).Car;
   end Car;

   ---------
   -- Cdr --
   ---------

   function Cdr (This : Raven_VM'Class;
                 Pair : Object)
                 return Object
   is
   begin
      return This.Data.Memory.Get (Objects.Get_Address (Pair)).Cdr;
   end Cdr;

   ----------------
   -- Check_Kind --
   ----------------

   procedure Check_Kind
     (This     : Raven_VM;
      Index    : Slot_Index;
      Expected : Value_Kind;
      Name     : String)
   is
   begin
      if This.Kind (Index) /= Expected then
         raise Constraint_Error with
           Name & ": slot" & Index'Image & " holds "
           & Encode (This.Display (This.Get_Slot (Index)))
           & ", which is not " & Name;
      end if;
   end Check_Kind;

   ------------------
   -- Close_Handle --
   ------------------

   procedure Close_VM (This : in out Raven_VM) is
      procedure Free is
        new Ada.Unchecked_Deallocation (Raven_VM_Record, Raven_VM_Access);

      procedure Free is
        new Ada.Unchecked_Deallocation
          (Raven.Evaluator.Abstraction'Class, Raven.Evaluator.Reference);

      procedure Free is
        new Ada.Unchecked_Deallocation
          (Raven.Memory.Abstraction'Class, Raven.Memory.Reference);
   begin
      --  Closing one that is closed already is not an error: a host
      --  with a cleanup path will reach here twice and should not
      --  have to remember which time it is.

      if This.Data = null then
         return;
      end if;

      --  The values go first, while everything they might reach is
      --  still standing.  Free is how a foreign value gives back what
      --  it stood for, and a collection is what usually calls it --
      --  there being none at shutdown is why an open port used to
      --  stay open for the life of the process.

      This.Data.Memory.Close;

      --  Then what the engine made, then the engine, then the heap.
      --  The heap is the large one: Heap_Size cells, half a megabyte
      --  at the default, and it was never given back.

      This.Data.Evaluator.Close;
      Free (This.Data.Evaluator);
      Free (This.Data.Memory);

      --  The user data and the host are the host's, and are not
      --  raven's to give back.

      Free (This.Data);
   end Close_VM;

   --------------------------
   -- Create_Foreign_Value --
   --------------------------

   function Create_Foreign_Value
     (This  : Raven_VM'Class;
      Value : Foreign_Value_Instance'Class)
      return Object
   is
   begin
      return This.Data.Memory.Create_Foreign_Value (Value);
   end Create_Foreign_Value;

   -------------
   -- Display --
   -------------

   function Display
     (This     : Raven_VM'Class;
      Value    : Object;
      Readable : Boolean := True)
      return Wide_Wide_String
   is
      Image : constant String := This.Data.Target.Show (Value, Readable);
   begin
      return Decode (Image);
   end Display;

   -------------
   -- Display --
   -------------

   function Display
     (This        : Foreign_Value_Instance;
      Show_Object : not null access function (X : Object) return String)
      return String
   is (Foreign_Value_Instance'Class (This).Show (Show_Object));

   -----------
   -- Equal --
   -----------

   function Equal
     (This : Raven_VM'Class;
      X, Y : Object)
      return Boolean
   is
      use Raven.Objects;
      B : Boolean := False;

      function Equal_Object (P, Q : Object) return Boolean;

      ------------------
      -- Equal_Object --
      ------------------

      function Equal_Object (P, Q : Object) return Boolean
      is (This.Equal (P, Q));

   begin
      if X = Y then
         B := True;
      elsif not Tag_Equal (X, Y) then
         B := False;
      elsif Is_Foreign_Value (X) then
         B := This.To_Foreign_Value (X).Equal
           (This.To_Foreign_Value (Y), Equal_Object'Access);
      elsif Is_Foreign_Function (X) then
         B := False;
      elsif Is_Pair (X) then
         B := This.Equal (This.Car (X), This.Car (Y))
           and then This.Equal (This.Cdr (X), This.Cdr (Y));
      elsif Is_Vector (X) or else Is_Bytevector (X) then

         --  Element by element, the way a pair is car and cdr.  Two
         --  vectors of different lengths are not equal, and asking
         --  the shorter one for an element it has not got would read
         --  the cell after it.

         B := This.Vector_Length (X) = This.Vector_Length (Y);

         if B then
            for I in 0 .. This.Vector_Length (X) - 1 loop
               if not This.Equal (This.Vector_Element (X, I),
                                  This.Vector_Element (Y, I))
               then
                  B := False;
                  exit;
               end if;
            end loop;
         end if;
      elsif Is_Atom (X) then
         B := False;
      else
         B := False;
      end if;
      return B;
   end Equal;

   --------------
   -- Evaluate --
   --------------

   procedure Evaluate
     (This       : Raven_VM;
      Expression : String)
   is
   begin
      Raven.Parser.Parse_Expression
        (Expression, This.Data.Target);

      --  What a program opens with is not an expression and has no
      --  value.  It has to be acted on before whatever is typed next
      --  is translated, which is the same reason the loader looks at a
      --  form before translating it.

      if Raven.Loader.Take_Declaration (This.Data.Target) then
         This.Set_Slot_Nil (1);
         return;
      end if;

      This.Data.Target.Translate
        (This.Data.Target.Interaction_Library);
      This.Data.Target.Execute;

      This.Set_Slot (1, This.Data.Target.Pop);

   end Evaluate;

   --------------
   -- Evaluate --
   --------------

   procedure Evaluate
     (This  : Raven_VM;
      Value : Handle)
   is
      Fn : constant Object := Object_Lists.Element (Value.Position);
   begin
      This.Data.Target.Push (Fn);
      This.Data.Target.Translate
        (This.Data.Target.Interaction_Library);
      This.Data.Target.Execute;
      This.Set_Slot (1, This.Data.Target.Pop);
   end Evaluate;

   -----------------
   -- Features_Of --
   -----------------

   procedure Features_Of (VM : Raven_VM) is
   begin
      VM.Set_Slot_Nil (1);

      for Index in reverse 1 .. Raven.Features.Count loop
         VM.Set_Slot_Symbol (2, Raven.Features.Feature (Index));
         VM.Slot_Cons (1, 2);
      end loop;
   end Features_Of;

   ---------------------
   -- Forms_Abandoned --
   ---------------------

   function Forms_Abandoned (This : Raven_VM) return Natural is
   begin
      --  Kept by the target, because the machine is what counts them
      --  and the machine cannot see the inside of a VM.

      return This.Data.Target.Forms_Abandoned;
   end Forms_Abandoned;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index)
      return Object
   is
   begin
      return This.Data.Evaluator.Get_Slot (Index);
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Boolean
   is
   begin
      return Raven.Objects.Is_Truthy (This.Get_Slot (Index));
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Integer
   is
   begin
      return Raven.Objects.To_Integer (This.Get_Slot (Index));
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return String
   is
   begin
      --  This used to answer with a rendering of whatever was there,
      --  so a host that asked for a string and was given a list got
      --  something that looked like an answer.  Show_Slot is where
      --  that went, under a name that says what it does.

      if not Raven.Strings.Is_String (This, Index) then
         raise Constraint_Error with
           "slot" & Index'Image & " holds "
           & Encode (This.Display (This.Get_Slot (Index)))
           & ", which is not a string";
      end if;

      return Raven.Strings.Get_String (This, Index);
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Float
   is
   begin
      Check_Kind (This, Index, Float_Kind, "a float");
      return Raven.Objects.To_Float (This.Get_Slot (Index));
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Wide_Wide_Character
   is
   begin
      Check_Kind (This, Index, Character_Kind, "a character");
      return Raven.Objects.To_Character (This.Get_Slot (Index));
   end Get_Slot;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (This  : Raven_VM;
      Index : Slot_Index)
      return Handle
   is
   begin
      --  A slot is where a foreign function is handed its arguments
      --  and leaves its answer, and it holds them only until the
      --  machine runs again.  A handle on what is in one is how a
      --  host keeps it: the handle is a root, so what it names stays
      --  where it can be found and is moved with everything else.
      --
      --  This used to answer with nothing at all, so the only handle
      --  a host could get was on a name it looked up -- which meant a
      --  foreign value could not keep a value it was given.

      return Handle'
        (Position => This.Data.Evaluator.Hold (This.Get_Slot (Index)));
   end Get_Slot;

   -----------------------
   -- Holds_Requirement --
   -----------------------

   procedure Holds_Requirement (VM : Raven_VM) is
      Requirement : constant Object := VM.Get_Slot (1);
   begin
      VM.Set_Slot
        (1, Raven.Loader.Requirement_Holds (VM.Data.Target, Requirement));
   end Holds_Requirement;

   --------------------
   -- Import_Library --
   --------------------

   procedure Import_Library
     (This : Raven_VM'Class;
      Name : String;
      Path : String)
   is
   begin
      Raven.Loader.Import (This.Data.Target, Name, Path);
   end Import_Library;

   ----------
   -- Kind --
   ----------

   function Kind
     (This  : Raven_VM;
      Index : Slot_Index)
      return Value_Kind
   is
      use Raven.Objects;
      X : constant Object := This.Get_Slot (Index);
   begin
      if X = Nil then
         return Nil_Kind;
      elsif X = To_Object (True) or else X = To_Object (False) then
         return Boolean_Kind;
      elsif Is_Eof (X) then
         return Eof_Kind;
      elsif Is_Integer (X) then
         return Integer_Kind;
      elsif Is_Float (X) then
         return Float_Kind;
      elsif Is_Character (X) then
         return Character_Kind;
      elsif Is_Symbol (X) then
         return Symbol_Kind;
      elsif Is_Pair (X) then
         return Pair_Kind;
      elsif Is_Vector (X) then
         return Vector_Kind;
      elsif Is_Bytevector (X) then
         return Bytevector_Kind;
      elsif Is_Closure (X) or else Is_Foreign_Function (X) then
         return Procedure_Kind;
      elsif Is_Foreign_Value (X) then

         --  A string is one of these, and is the one a host is most
         --  likely to be handed, so it answers for itself.

         return (if Raven.Strings.Is_String (This, Index)
                 then String_Kind
                 else Foreign_Kind);
      else
         return Other_Kind;
      end if;
   end Kind;

   --------------------
   -- New_Bytevector --
   --------------------

   function New_Bytevector
     (This   : Raven_VM'Class;
      Length : Natural)
      return Object
   is (This.Data.Memory.New_Bytevector (Length));

   ----------------
   -- New_Symbol --
   ----------------

   function New_Symbol
     (This   : Raven_VM'Class;
      Prefix : String)
      return Object
   is
   begin
      return This.Data.Target.New_Symbol (Prefix);
   end New_Symbol;

   ----------------
   -- New_Vector --
   ----------------

   function New_Vector
     (This   : Raven_VM'Class;
      Length : Natural)
      return Object
   is (This.Data.Memory.New_Vector (Length));

   -------------
   -- New_VM  --
   -------------

   function New_VM
     (IO            : IO_Reference := null;
      User_Data     : access User_Data_Interface'Class := null;
      Configuration : String := "";
      Library_Path  : String := "";
      Heap_Size     : Positive := Default_Heap_Size)
      return Raven_VM
   is
      Libraries : constant String :=
                    (if Library_Path = ""
                     then Standard_Library_Path
                     else Library_Path);

      Memory : constant Raven.Memory.Reference :=
                 Raven.Engine.Create_Memory (Heap_Size);

      This : constant Raven_VM :=
               (Data => new Raven_VM_Record'
                  (User_Data   => User_Data_Reference (User_Data),
                   IO          => (if IO = null
                                   then Raven.IO.Standard_IO
                                   else IO),
                   Memory      => Memory,
                   Evaluator   => null,
                   Target      => null));
   begin
      This.Data.Evaluator := Raven.Engine.Create (This, Memory, Configuration);
      This.Data.Target    := This.Data.Evaluator.Target;

      This.Add_Library_Path (Libraries);

      This.Bind_Foreign_Function
        ("raven-features", Features_Of'Access, 0);
      This.Bind_Foreign_Function
        ("raven-feature-requirement?", Holds_Requirement'Access, 1);

      Raven.Loader.Import
        (This.Data.Target, "(scheme base)",
         Libraries & "/scheme/base.scm");
      return This;
   end New_VM;

   -------------------------
   -- Query_Foreign_Value --
   -------------------------

   procedure Query_Foreign_Value
     (This    : Raven_VM'Class;
      Value   : Object;
      Process : not null access
        procedure (Item : Foreign_Value_Instance'Class))
   is
   begin
      This.Data.Memory.Query_Foreign_Value (Value, Process);
   end Query_Foreign_Value;

   --------------------
   -- Read_Character --
   --------------------

   procedure Read_Character
     (This      : Raven_VM'Class;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean)
   is
   begin
      This.Data.IO.Get (Ch, Available);
   end Read_Character;

   -------------
   -- Release --
   -------------

   procedure Release
     (This  : Raven_VM;
      Value : in out Handle)
   is
   begin
      if not Is_Null (Value) then
         This.Data.Evaluator.Release (Value.Position);
      end if;
   end Release;

   ------------------
   -- Report_State --
   ------------------

   procedure Report_State (This : Raven_VM) is
   begin
      This.Data.Evaluator.Report;
   end Report_State;

   -------------
   -- Set_Car --
   -------------

   procedure Set_Car (This  : Raven_VM'Class;
                      Pair  : Object;
                      Value : Object)
   is
      Address : constant Address_Type := Objects.Get_Address (Pair);
      Cell    : Raven.Memory.Cell_Type := This.Data.Memory.Get (Address);
   begin
      Cell.Car := Value;
      This.Data.Memory.Set (Address, Cell);
   end Set_Car;

   -------------
   -- Set_Cdr --
   -------------

   procedure Set_Cdr (This  : Raven_VM'Class;
                      Pair  : Object;
                      Value : Object)
   is
      Address : constant Address_Type := Objects.Get_Address (Pair);
      Cell    : Raven.Memory.Cell_Type := This.Data.Memory.Get (Address);
   begin
      Cell.Cdr := Value;
      This.Data.Memory.Set (Address, Cell);
   end Set_Cdr;

   -------------------
   -- Set_Parameter --
   -------------------

   procedure Set_Parameter
     (This  : Raven_VM;
      Name  : String;
      Value : String)
   is
   begin
      This.Data.Target.Set_Parameter (Name, Value);
   end Set_Parameter;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Float)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.To_Object (Value));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Wide_Wide_Character)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.To_Object (Value));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM'Class;
      Index : Slot_Index;
      Value : Object)
   is
   begin
      This.Data.Evaluator.Set_Slot (Index, Value);
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Boolean)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.To_Object (Value));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Integer)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.To_Object (Value));
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : String)
   is
   begin
      --  A string, which is what Get_Slot of one answers with.  This
      --  made a symbol of the name, so the two were not each other's
      --  opposite and a foreign function had no way at all to answer
      --  with a string.

      Raven.Strings.Write_String (This, Index, Value);
   end Set_Slot;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (This  : Raven_VM;
      Index : Slot_Index;
      Value : Handle)
   is
   begin
      This.Set_Slot (Index, Object_Lists.Element (Value.Position));
   end Set_Slot;

   ------------------
   -- Set_Slot_Nil --
   ------------------

   procedure Set_Slot_Nil
     (This  : Raven_VM;
      Index : Slot_Index)
   is
   begin
      This.Set_Slot (Index, Raven.Objects.Nil);
   end Set_Slot_Nil;

   ----------------------
   -- Set_Slot_Symbol --
   ----------------------

   procedure Set_Slot_Symbol
     (This  : Raven_VM;
      Index : Slot_Index;
      Name  : String)
   is
   begin
      This.Set_Slot (Index, This.Data.Target.To_Symbol (Name));
   end Set_Slot_Symbol;

   ------------------------
   -- Set_Vector_Element --
   ------------------------

   procedure Set_Vector_Element
     (This  : Raven_VM'Class;
      V     : Object;
      Index : Natural;
      Value : Object)
   is
   begin
      This.Data.Memory.Set_Vector_Element (V, Index, Value);
   end Set_Vector_Element;

   ---------------
   -- Show_Slot --
   ---------------

   function Show_Slot
     (This     : Raven_VM;
      Index    : Slot_Index;
      Readable : Boolean := True)
      return String
   is
   begin
      return Encode (This.Display (This.Get_Slot (Index), Readable));
   end Show_Slot;

   ----------------
   -- Slot_Apply --
   ----------------

   procedure Slot_Apply
     (This  : Raven_VM;
      Index : Slot_Index;
      Count : Natural)
   is
   begin
      Check_Kind (This, Index, Procedure_Kind, "a procedure");
      This.Data.Target.Apply (Index, Count);
   end Slot_Apply;

   -----------------------------
   -- Slot_Bytevector_Element --
   -----------------------------

   function Slot_Bytevector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural)
      return Natural
   is
   begin
      Check_Kind (This, Index, Bytevector_Kind, "a bytevector");
      return Raven.Objects.To_Integer
        (This.Vector_Element (This.Get_Slot (Index), At_Index));
   end Slot_Bytevector_Element;

   ----------------------------
   -- Slot_Bytevector_Length --
   ----------------------------

   function Slot_Bytevector_Length
     (This  : Raven_VM;
      Index : Slot_Index)
      return Natural
   is
   begin
      Check_Kind (This, Index, Bytevector_Kind, "a bytevector");
      return This.Vector_Length (This.Get_Slot (Index));
   end Slot_Bytevector_Length;

   --------------
   -- Slot_Car --
   --------------

   procedure Slot_Car
     (This  : Raven_VM;
      Index : Slot_Index;
      Into  : Slot_Index)
   is
   begin
      Check_Kind (This, Index, Pair_Kind, "a pair");
      This.Set_Slot (Into, This.Car (This.Get_Slot (Index)));
   end Slot_Car;

   --------------
   -- Slot_Cdr --
   --------------

   procedure Slot_Cdr
     (This  : Raven_VM;
      Index : Slot_Index;
      Into  : Slot_Index)
   is
   begin
      Check_Kind (This, Index, Pair_Kind, "a pair");
      This.Set_Slot (Into, This.Cdr (This.Get_Slot (Index)));
   end Slot_Cdr;

   ---------------
   -- Slot_Cons --
   ---------------

   procedure Slot_Cons
     (This     : Raven_VM;
      Index    : Slot_Index;
      Car_Slot : Slot_Index)
   is
   begin
      This.Data.Evaluator.Set_Slot
        (Index,
         This.Data.Evaluator.Cons
           (This.Data.Evaluator.Get_Slot (Car_Slot),
            This.Data.Evaluator.Get_Slot (Index)));
   end Slot_Cons;

   ----------------
   -- Slot_Equal --
   ----------------

   function Slot_Equal
     (This        : Raven_VM;
      Left, Right : Slot_Index)
      return Boolean
   is
   begin
      return This.Equal (This.Get_Slot (Left), This.Get_Slot (Right));
   end Slot_Equal;

   -------------------------
   -- Slot_New_Bytevector --
   -------------------------

   procedure Slot_New_Bytevector
     (This   : Raven_VM;
      Index  : Slot_Index;
      Length : Natural)
   is
   begin
      This.Set_Slot (Index, This.New_Bytevector (Length));
   end Slot_New_Bytevector;

   ---------------------
   -- Slot_New_Vector --
   ---------------------

   procedure Slot_New_Vector
     (This   : Raven_VM;
      Index  : Slot_Index;
      Length : Natural)
   is
   begin
      This.Set_Slot (Index, This.New_Vector (Length));
   end Slot_New_Vector;

   ---------------------------------
   -- Slot_Set_Bytevector_Element --
   ---------------------------------

   procedure Slot_Set_Bytevector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural;
      Value    : Natural)
   is
   begin
      Check_Kind (This, Index, Bytevector_Kind, "a bytevector");

      --  What tells a bytevector from a vector is what may go into
      --  one, and this is a way in that did not exist before.

      if Value not in 0 .. 255 then
         raise Constraint_Error with
           "bytevector:" & Value'Image & " is not a byte";
      end if;

      This.Set_Vector_Element
        (This.Get_Slot (Index), At_Index, Raven.Objects.To_Object (Value));
   end Slot_Set_Bytevector_Element;

   ------------------
   -- Slot_Set_Car --
   ------------------

   procedure Slot_Set_Car
     (This  : Raven_VM;
      Index : Slot_Index;
      From  : Slot_Index)
   is
   begin
      Check_Kind (This, Index, Pair_Kind, "a pair");
      This.Set_Car (This.Get_Slot (Index), This.Get_Slot (From));
   end Slot_Set_Car;

   ------------------
   -- Slot_Set_Cdr --
   ------------------

   procedure Slot_Set_Cdr
     (This  : Raven_VM;
      Index : Slot_Index;
      From  : Slot_Index)
   is
   begin
      Check_Kind (This, Index, Pair_Kind, "a pair");
      This.Set_Cdr (This.Get_Slot (Index), This.Get_Slot (From));
   end Slot_Set_Cdr;

   -----------------------------
   -- Slot_Set_Vector_Element --
   -----------------------------

   procedure Slot_Set_Vector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural;
      From     : Slot_Index)
   is
   begin
      Check_Kind (This, Index, Vector_Kind, "a vector");
      This.Set_Vector_Element
        (This.Get_Slot (Index), At_Index, This.Get_Slot (From));
   end Slot_Set_Vector_Element;

   -------------------------
   -- Slot_Vector_Element --
   -------------------------

   procedure Slot_Vector_Element
     (This     : Raven_VM;
      Index    : Slot_Index;
      At_Index : Natural;
      Into     : Slot_Index)
   is
   begin
      Check_Kind (This, Index, Vector_Kind, "a vector");
      This.Set_Slot
        (Into, This.Vector_Element (This.Get_Slot (Index), At_Index));
   end Slot_Vector_Element;

   ------------------------
   -- Slot_Vector_Length --
   ------------------------

   function Slot_Vector_Length
     (This  : Raven_VM;
      Index : Slot_Index)
      return Natural
   is
   begin
      Check_Kind (This, Index, Vector_Kind, "a vector");
      return This.Vector_Length (This.Get_Slot (Index));
   end Slot_Vector_Length;

   ---------------------------
   -- Standard_Library_Path --
   ---------------------------

   function Standard_Library_Path return String is
   begin
      return Raven_Resources.Resource_Path & "/libraries";
   end Standard_Library_Path;

   -----------------
   -- Symbol_Name --
   -----------------

   function Symbol_Name
     (This  : Raven_VM;
      Index : Slot_Index)
      return String
   is
   begin
      Check_Kind (This, Index, Symbol_Kind, "a symbol");
      return This.Data.Target.To_String
        (Raven.Objects.To_Symbol (This.Get_Slot (Index)));
   end Symbol_Name;

   ----------------------
   -- To_Foreign_Value --
   ----------------------

   function To_Foreign_Value
     (This : Raven_VM'Class;
      Value : Object)
      return Foreign_Value_Instance'Class
   is
   begin
      return This.Data.Memory.To_Foreign_Value (Value);
   end To_Foreign_Value;

   ---------------
   -- To_Symbol --
   ---------------

   function To_Symbol
     (This : Raven_VM'Class;
      Name : String)
      return Object
   is
   begin
      return This.Data.Target.To_Symbol (Name);
   end To_Symbol;

   ---------------
   -- User_Data --
   ---------------

   function User_Data
     (This : Raven_VM)
      return User_Data_Reference
   is
   begin
      return This.Data.User_Data;
   end User_Data;

   --------------------
   -- Vector_Element --
   --------------------

   function Vector_Element
     (This  : Raven_VM'Class;
      V     : Object;
      Index : Natural)
      return Object
   is (This.Data.Memory.Vector_Element (V, Index));

   -------------------
   -- Vector_Length --
   -------------------

   function Vector_Length
     (This : Raven_VM'Class;
      V    : Object)
      return Natural
   is (This.Data.Memory.Vector_Length (V));

   ---------------------
   -- Write_Character --
   ---------------------

   procedure Write_Character
     (This   : Raven_VM'Class;
      Ch     : Wide_Wide_Character;
      Errors : Boolean)
   is
   begin
      --  Which of the two the host is told apart by.  Before it had
      --  somewhere else to put a character, an error went where
      --  everything else went and this flag was thrown away.

      if Errors then
         This.Data.IO.Put_Error (Ch);
      else
         This.Data.IO.Put (Ch);
      end if;
   end Write_Character;

   -----------------
   -- Write_Error --
   -----------------

   procedure Write_Error
     (This    : Raven_VM'Class;
      Message : String)
   is
      Text : constant Wide_Wide_String := Decode (Message);
   begin
      for Ch of Text loop
         This.Data.IO.Put_Error (Ch);
      end loop;

      This.Data.IO.Put_Error (Wide_Wide_Character'Val (10));
   end Write_Error;

end Raven;
