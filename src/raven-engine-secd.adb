with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Text_IO;

with Raven.Engine.Libraries;
with Raven.Engine.SECD.Translator;
with Raven.Instructions;
with Raven.Objects;
with Raven.Strings;
with Raven.Translator;

package body Raven.Engine.SECD is

   use Raven.Instructions;

   type Stack_Name is (S, E, C, D);

   type Stacks is array (Stack_Name) of Object;

   type Register_Index is range 1 .. 4;

   type Registers is array (Register_Index) of Object;

   type Foreign_Function_Record (Name_Length : Natural) is
      record
         Handler   : Foreign_Function_Handler;
         Arg_Count : Natural;
         Name      : String (1 .. Name_Length);
      end record;

   package Foreign_Vectors is
     new Ada.Containers.Indefinite_Vectors
       (Raven.Objects.Foreign_Function_Id, Foreign_Function_Record);

   --  A macro definition lives here, and nowhere else: the translator
   --  holds only its id.  Only an entry that is In_Use holds objects; a
   --  released entry is cleared, so that Mark stops keeping its body
   --  alive and the slot can be reused.

   type Macro_Entry is record
      In_Use     : Boolean := False;
      Params     : Object  := Raven.Objects.Nil;
      Macro_Body : Object  := Raven.Objects.Nil;
      Home       : Raven.Target.Library_Id := Raven.Target.No_Library;
      Expansion  : Raven.Target.Library_Id := Raven.Target.No_Library;
   end record;

   package Macro_Vectors is
     new Ada.Containers.Vectors
       (Raven.Target.Real_Macro_Id, Macro_Entry);

   --  The translators running on this instance, innermost last: a
   --  macro expansion executes code, and that code can ask for another
   --  form to be translated.  A translator is a collection root, and it
   --  is one only while it runs, so the instance marks the ones it
   --  currently owns rather than the memory keeping them for ever.

   type Translator_Reference is
     access all Raven.Translator.Abstraction'Class;

   package Translator_Vectors is
     new Ada.Containers.Vectors (Positive, Translator_Reference);

   type Instance is
     new Raven.Target.Abstraction with
      record
         VM          : Raven_VM;
         Abandoned   : Natural := 0;
         St          : Stacks;
         Rs          : Registers;
         Syms        : Raven.Symbols.Reference;
         Memory      : Raven.Memory.Reference;
         Env         : Raven.Environment.Reference;
         Foreign     : Foreign_Vectors.Vector;
         Macros      : Macro_Vectors.Vector;
         Libraries   : Raven.Engine.Libraries.Instance;
         Interaction : Raven.Target.Library_Id :=
                         Raven.Target.No_Library;
         Translators : Translator_Vectors.Vector;
         Trace       : Boolean := False;
      end record;

   type Instance_Reference is access all Instance'Class;

   overriding procedure Translate
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id);

   overriding function Interaction_Library
     (This : Instance)
      return Raven.Target.Real_Library_Id
   is (This.Interaction);

   overriding function Library
     (This : Instance;
      Name : String)
      return Raven.Target.Library_Id
   is (This.Libraries.Find (Name));

   overriding function Create_Library
     (This : in out Instance;
      Name : String)
      return Raven.Target.Real_Library_Id
   is (This.Libraries.Create (Name, This.Env));

   overriding procedure Add_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Imported : Raven.Target.Real_Library_Id);

   overriding procedure Set_Export_List
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id);

   overriding procedure Add_Export
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String);

   overriding procedure Define_Name
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String);

   overriding function Resolve
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Real_Library_Id
   is (This.Libraries.Resolve (Library, Name));

   overriding function Binds
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Boolean
   is (This.Libraries.Binds (Library, Name));

   overriding procedure Add_Library_Path
     (This : in out Instance;
      Path : String);

   overriding function Library_Path
     (This  : Instance;
      Index : Positive)
      return String
   is (This.Libraries.Path (Index));

   overriding procedure Execute
     (This   : in out Instance);

   overriding function Append_Lists
     (This  : in out Instance;
      List1 : Object;
      List2 : Object)
      return Object;

   overriding procedure Bind_Foreign_Function
     (This           : in out Instance;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural);

   overriding function Is_Empty
     (This : Instance)
      return Boolean
   is (This.St (S) = Objects.Nil);

   overriding function Car
     (This : Instance;
      Cons : Object)
      return Object
   is (This.Memory.Get (Raven.Objects.Get_Address (Cons)).Car);

   overriding function Cdr
     (This : Instance;
      Cons : Object)
      return Object
   is (This.Memory.Get (Raven.Objects.Get_Address (Cons)).Cdr);

   overriding procedure Push
     (This  : in out Instance;
      Value : Object);

   overriding procedure Pop
     (This  : in out Instance;
      Value :    out Object);

   overriding function Top
     (This : Instance)
      return Object
   is (This.Memory.Get (Objects.Get_Address (This.St (S))).Car);

   overriding procedure Cons (This : in out Instance);

   overriding function To_Symbol_Id
     (This  : in out Instance;
      Name  : String)
      return Raven.Objects.Symbol_Id
   is (This.Syms.To_Symbol_Id (Name));

   overriding function New_Symbol_Id
     (This   : in out Instance;
      Prefix : String)
      return Raven.Objects.Symbol_Id
   is (This.Syms.New_Symbol_Id (Prefix));

   overriding function To_String
     (This  : Instance;
      Id    : Raven.Objects.Symbol_Id)
      return String
   is (This.Syms.To_String (Id));

   overriding procedure Report (This : Instance);

   --  Where a complaint about a form goes, and a form given up on.
   --  The machine is the only thing holding both a target and the VM
   --  whose host is to hear about it, and it keeps the count itself
   --  because it cannot see the inside of a VM to keep it there.

   overriding procedure Report_Error
     (This    : Instance;
      Message : String);

   overriding procedure Abandon_Form (This : in out Instance);

   overriding function Forms_Abandoned (This : Instance) return Natural
   is (This.Abandoned);

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object));

   overriding procedure Set_Parameter
     (This  : in out Instance;
      Name  : String;
      Value : String);

   overriding function Tracing
     (This : Instance)
      return Boolean
   is (This.Trace);

   --  What Show needs of a vector, which the memory holds.

   overriding procedure List_To_Vector
     (This : in out Instance);

   overriding procedure List_To_Bytevector
     (This : in out Instance);

   procedure List_To_Block
     (This       : in out Instance'Class;
      Bytevector : Boolean);

   overriding function Vector_Length
     (This : Instance;
      V    : Object)
      return Natural
   is (This.Memory.Vector_Length (V));

   overriding function Vector_Element
     (This  : Instance;
      V     : Object;
      Index : Natural)
      return Object
   is (This.Memory.Vector_Element (V, Index));

   overriding procedure Swap
     (This : in out Instance);

   overriding function Store_Macro
     (This        : in out Instance;
      Params      : Object;
      Macro_Body  : Object;
      Home        : Raven.Target.Real_Library_Id;
      Expansion   : Raven.Target.Real_Library_Id)
      return Raven.Target.Real_Macro_Id;

   overriding procedure Get_Macro
     (This        : Instance;
      Id          : Raven.Target.Real_Macro_Id;
      Params      : out Object;
      Macro_Body  : out Object;
      Home        : out Raven.Target.Real_Library_Id;
      Expansion   : out Raven.Target.Real_Library_Id);

   overriding procedure Release_Macro
     (This : in out Instance;
      Id   : Raven.Target.Real_Macro_Id);

   overriding procedure Define_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String;
      Id      : Raven.Target.Real_Macro_Id);

   overriding procedure Undefine_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String);

   overriding function Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id
   is (This.Libraries.Macro (Library, Name));

   overriding function Own_Macro
     (This    : Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
      return Raven.Target.Macro_Id
   is (This.Libraries.Own_Macro (Library, Name));

   overriding function To_Foreign_Value
     (This  : Instance;
      Value : Object)
      return Foreign_Value_Instance'Class
   is (This.Memory.To_Foreign_Value (Value));

   overriding function Create_String
     (This : in out Instance;
      Text : Wide_Wide_String)
      return Object
   is (This.Memory.Create_Foreign_Value (Raven.Strings.To_Value (Text)));

   function Is_Empty
     (This : in out Instance'Class;
      Name : Stack_Name)
      return Boolean
   is (This.St (Name) = Raven.Objects.Nil);

   function Pop (This : in out Instance'Class; Name : Stack_Name) return Object
     with Pre => not Is_Empty (This, Name);

   procedure Push (This : in out Instance'Class; Name : Stack_Name; Value : Object)
     with Post => not Is_Empty (This, Name);

   procedure Cons (This : in out Instance'Class; Name : Stack_Name);

   function Rplaca
     (This    : Instance'Class;
      X       : Object;
      New_Car : Object)
      return Object;

   --  The operand of LD, ST and DFN is one pair: a library and a
   --  symbol for a name the library holds, a frame and an offset for
   --  one the machine built when it applied a closure.  A symbol in
   --  the cdr is what tells them apart.

   function Is_Library_Reference
     (This : Instance'Class;
      Ref  : Object)
      return Boolean
   is (Raven.Objects.Is_Symbol (This.Cdr (Ref)));

   function Referenced_Environment
     (This : Instance'Class;
      Ref  : Object)
      return Raven.Environment.Reference
   is (This.Libraries.Environment
         (Raven.Target.Real_Library_Id
            (Raven.Objects.To_Integer (This.Car (Ref)))));

   function Referenced_Name
     (This : Instance'Class;
      Ref  : Object)
      return String
   is (This.To_String (Raven.Objects.To_Symbol (This.Cdr (Ref))));

   ----------------
   -- Add_Import --
   ----------------

   overriding procedure Add_Import
     (This     : in out Instance;
      Library  : Raven.Target.Real_Library_Id;
      Imported : Raven.Target.Real_Library_Id)
   is
   begin
      This.Libraries.Add_Import (Library, Imported);
   end Add_Import;

   ----------------
   -- Add_Export --
   ----------------

   overriding procedure Add_Export
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
   begin
      This.Libraries.Add_Export (Library, Name);
   end Add_Export;

   ---------------------
   -- Set_Export_List --
   ---------------------

   overriding procedure Set_Export_List
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id)
   is
   begin
      This.Libraries.Set_Export_List (Library);
   end Set_Export_List;

   ----------------------
   -- Add_Library_Path --
   ----------------------

   overriding procedure Add_Library_Path
     (This : in out Instance;
      Path : String)
   is
   begin
      This.Libraries.Add_Path (Path);
   end Add_Library_Path;

   ------------------
   -- Append_Lists --
   ------------------

   overriding function Append_Lists
     (This  : in out Instance;
      List1 : Object;
      List2 : Object)
      return Object
   is
      It    : Object  := List1;
      Acc   : Object  := List2;
      Count : Natural := 0;
   begin
      while It /= Objects.Nil loop
         This.Rs (1) := It;
         This.Push (S, This.Car (It));
         It := This.Cdr (This.Rs (1));
         Count := Count + 1;
      end loop;
      for I in 1 .. Count loop
         declare
            Element : constant Object := This.Pop (S);
         begin
            Acc := This.Memory.Cons (Element, Acc);
         end;
      end loop;
      return Acc;
   end Append_Lists;

   ---------------------------
   -- Bind_Foreign_Function --
   ---------------------------

   overriding procedure Bind_Foreign_Function
     (This           : in out Instance;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural)
   is
      use Raven.Objects;
      New_Entry : constant Foreign_Function_Record :=
                    (Name'Length, Handler, Argument_Count, Name);
      Id        : Foreign_Function_Id := Foreign_Function_Id'First;
      Found     : Boolean := False;
   begin
      --  A name bound again takes back the slot it had.  There are
      --  only so many foreign function ids, and rebinding must not
      --  spend one each time.

      for I in 1 .. This.Foreign.Last_Index loop
         if Ada.Strings.Equal_Case_Insensitive
           (This.Foreign (I).Name, Name)
         then
            This.Foreign (I) := New_Entry;
            Id := I;
            Found := True;
            exit;
         end if;
      end loop;

      if not Found then
         This.Foreign.Append (New_Entry);
         Id := This.Foreign.Last_Index;
      end if;

      This.Env.Define (Name, To_Object (Id));
      Ada.Text_IO.Put_Line
        ("foreign function '" & Name & "' bound to"
         & Id'Image);
   end Bind_Foreign_Function;

   -----------------
   -- Define_Name --
   -----------------

   overriding procedure Define_Name
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
   begin
      This.Libraries.Define_Name (Library, Name);
   end Define_Name;

   ----------
   -- Cons --
   ----------

   procedure Cons (This : in out Instance'Class; Name : Stack_Name) is
      Cdr : constant Object := This.Pop (Name);
      Car : constant Object := This.Pop (Name);
   begin
      This.Push (Name, This.Memory.Cons (Car, Cdr));
   end Cons;

   ----------
   -- Cons --
   ----------

   overriding procedure Cons (This : in out Instance) is
   begin
      This.Cons (S);
   end Cons;

   ------------
   -- Create --
   ------------

   function Create
     (VM      : Raven_VM;
      Memory  : Raven.Memory.Reference;
      Env     : Raven.Environment.Reference;
      Symbols : not null access Raven.Symbols.Abstraction'Class)
      return Raven.Target.Reference
   is
      This : constant Instance_Reference := new Instance'
        (VM          => VM,
         Abandoned   => 0,
         St          => [others => Raven.Objects.Nil],
         Rs          => [others => Raven.Objects.Nil],
         --  Named explicitly, because Symbols is an anonymous access
         --  parameter and Syms is a named access type.  Ada wants the
         --  conversion written; the GNAT this was developed against
         --  took it without, and a newer one on the build server does
         --  not.

         Syms        => Raven.Symbols.Reference (Symbols),
         Memory      => Memory,
         Env         => Env,
         Foreign     => <>,
         Macros      => <>,
         Libraries   => <>,
         Interaction => Raven.Target.No_Library,
         Translators => <>,
         Trace       => False);
   begin
      Memory.Add_Container (This);

      --  Where a form the host hands the machine is translated.  Env
      --  is its parent rather than its own, so that what the engine
      --  and the host bind stays visible to every library.

      This.Interaction :=
        This.Libraries.Create ("(raven user)", Env);

      return Raven.Target.Reference (This);
   end Create;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (This   : in out Instance)
   is
      use Raven.Objects;

      function Nth
        (L     : Object;
         Index : Natural)
         return Object;

      function Nth_Cdr
        (L     : Object;
         Index : Natural)
         return Object;

      function Replace_Nth
        (L         : Object;
         Index     : Natural;
         New_Value : Object)
        return Object;

      ---------
      -- Nth --
      ---------

      function Nth
        (L     : Object;
         Index : Natural)
         return Object
      is
         It : Object := L;
      begin
         for I in 1 .. Index loop
            It := This.Cdr (It);
            if It = Objects.Nil then
               return It;
            end if;
         end loop;

         --  A frame shorter than the index wanted is a call with
         --  fewer arguments than the procedure has parameters, and
         --  what it did not get is nil -- which is what optional
         --  reads, and how the library gives a procedure an argument
         --  it need not be given.
         --
         --  The loop said so for every index but the first, which
         --  does not go round it at all: a procedure of one parameter
         --  called with none asked for the car of an empty frame.

         if It = Objects.Nil then
            return It;
         end if;

         return This.Car (It);
      end Nth;

      -------------
      -- Nth_Cdr --
      -------------

      function Nth_Cdr
        (L     : Object;
         Index : Natural)
         return Object
      is
         It : Object := L;
      begin
         for I in 1 .. Index loop
            It := This.Cdr (It);
            if It = Objects.Nil then
               return It;
            end if;
         end loop;
         return It;
      end Nth_Cdr;

      -----------------
      -- Replace_Nth --
      -----------------

      function Replace_Nth
        (L         : Object;
         Index     : Natural;
         New_Value : Object)
        return Object
      is
         It : Object := L;
      begin
         for I in 1 .. Index loop
            It := This.Cdr (It);
            if It = Objects.Nil then
               return It;
            end if;
         end loop;

         --  And the same where one is assigned to rather than read.

         if It = Objects.Nil then
            return It;
         end if;

         return This.Rplaca (It, New_Value);
      end Replace_Nth;

   begin
      This.St (C) := This.Pop (S);

      if This.Trace then
         Ada.Text_IO.Put_Line
           ("executing: " & This.Show (This.St (C)));
      end if;

      loop

         if This.Trace then
            for I in This.St'Range loop
               Ada.Text_IO.Put_Line
                 (I'Image & ": " & This.Show (This.St (I)));
            end loop;
            if not Is_Instruction (This.Car (This.St (C))) then
               raise Program_Error with
                 "not an instruction: "
                 & This.Show (This.Car (This.St (C)));
            end if;
            Ada.Text_IO.Put_Line
              ("next: " & To_Instruction (This.Car (This.St (C)))'Image);
         end if;


         declare
            C_Top : constant Object := This.Pop (C);
            Next  : constant Instruction := To_Instruction (C_Top);
         begin

            case Next is
               when AP =>
                  if Is_Foreign_Function (This.Top) then
                     declare
                        FF_Id : constant Foreign_Function_Id :=
                                  To_Foreign_Function_Id
                                    (This.Pop);
                        Args  : Object := This.Pop;
                        FF    : constant Foreign_Function_Record :=
                                  This.Foreign.Element (FF_Id);
                     begin
                        for I in 1 .. FF.Arg_Count loop
                           if Args = Objects.Nil then
                              This.VM.Set_Slot_Nil (Slot_Index (I));
                           else
                              This.VM.Set_Slot
                                (Slot_Index (I),
                                 This.Car (Args));
                              Args := This.Cdr (Args);
                           end if;
                        end loop;
                        FF.Handler (This.VM);
                        This.Push (This.VM.Get_Slot (1));
                     end;
                  else
                     This.Push (D, This.St (C));
                     This.Push (D, This.St (E));
                     This.Rs (1) := This.Pop (S);

                     if not Objects.Is_Closure (This.Rs (1)) then
                        raise Constraint_Error with
                          "cannot call: "
                          & This.Show (This.Rs (1));
                     end if;

                     This.Rs (2) := This.Pop (S);
                     This.Push (D, This.St (S));
                     This.St (E) :=
                       This.Memory.Cons
                         (This.Rs (2), This.Cdr (This.Rs (1)));
                     This.St (C) :=
                       This.Car (This.Rs (1));
                     This.St (S) := Objects.Nil;
                  end if;
               when TAP =>

                  --  A tail call is a call whose value is the value of
                  --  the body it stands in, so the caller will do
                  --  nothing between the callee returning and
                  --  returning itself.  What AP saves on the dump
                  --  would be taken off it and put straight back, so
                  --  this is AP with the three pushes left out: the
                  --  callee's RTN finds the caller's caller there and
                  --  returns to it.  The dump stops growing, which is
                  --  the whole of what a tail call is for.

                  if Is_Foreign_Function (This.Top) then

                     --  There is nothing to transfer control to: a
                     --  foreign function answers where it stands.  So
                     --  a tail call of one is the call and the return
                     --  together, done here.

                     declare
                        FF_Id : constant Foreign_Function_Id :=
                                  To_Foreign_Function_Id
                                    (This.Pop);
                        Args  : Object := This.Pop;
                        FF    : constant Foreign_Function_Record :=
                                  This.Foreign.Element (FF_Id);
                     begin
                        for I in 1 .. FF.Arg_Count loop
                           if Args = Objects.Nil then
                              This.VM.Set_Slot_Nil (Slot_Index (I));
                           else
                              This.VM.Set_Slot
                                (Slot_Index (I),
                                 This.Car (Args));
                              Args := This.Cdr (Args);
                           end if;
                        end loop;
                        FF.Handler (This.VM);
                        This.Rs (1) := This.VM.Get_Slot (1);
                     end;

                     This.St (S) := This.Pop (D);
                     This.St (E) := This.Pop (D);
                     This.St (C) := This.Pop (D);
                     This.Push (This.Rs (1));
                  else
                     This.Rs (1) := This.Pop (S);

                     if not Objects.Is_Closure (This.Rs (1)) then
                        raise Constraint_Error with
                          "cannot call: "
                          & This.Show (This.Rs (1));
                     end if;

                     This.Rs (2) := This.Pop (S);

                     --  The caller's stack is dropped rather than
                     --  saved, which is right only because there is
                     --  nothing on it: the body's earlier forms were
                     --  dropped and the call's own two operands have
                     --  just come off.  RTN asserts as much when the
                     --  callee returns.

                     This.St (E) :=
                       This.Memory.Cons
                         (This.Rs (2), This.Cdr (This.Rs (1)));
                     This.St (C) :=
                       This.Car (This.Rs (1));
                     This.St (S) := Objects.Nil;
                  end if;
               when TSEL =>

                  --  SEL puts the rest of the form on the dump for
                  --  JOIN to take back.  An if in tail position has no
                  --  rest: each branch ends in a return of its own, so
                  --  there is nothing to save and nothing to come back
                  --  to.  Without this a tail call inside a branch
                  --  would find JOIN's one saved register where RTN
                  --  expects three.

                  declare
                     Cond : constant Boolean :=
                              Objects.Is_Truthy (This.Pop);
                     T    : constant Object  := This.Pop (C);
                     F    : constant Object  := This.Pop (C);
                  begin
                     This.St (C) := (if Cond then T else F);
                  end;
               when APPEND =>

                  --  The list on top goes in front, as the object on
                  --  top becomes the car for CONS.  Both lists are
                  --  held in registers: taking one apart and building
                  --  it back onto the other allocates, and neither
                  --  would survive that in a variable of ours.

                  declare
                     Count : Natural := 0;
                  begin
                     This.Rs (1) := This.Pop;
                     This.Rs (2) := This.Pop;
                     while This.Rs (1) /= Objects.Nil loop
                        This.Push (This.Car (This.Rs (1)));
                        This.Rs (1) := This.Cdr (This.Rs (1));
                        Count := Count + 1;
                     end loop;
                     for I in 1 .. Count loop
                        declare
                           Element : constant Object := This.Pop;
                        begin
                           This.Rs (2) :=
                             This.Memory.Cons (Element, This.Rs (2));
                        end;
                     end loop;
                     This.Push (This.Rs (2));
                  end;

               when ATOM =>
                  This.Push
                    (Raven.Objects.To_Object
                       (Raven.Objects.Is_Atom
                            (This.Pop)));

               when CAR =>
                  declare
                     X : constant Object := This.Pop;
                  begin
                     if not Is_Pair (X) then
                        raise Constraint_Error with
                          "car applied to non-pair: " & This.Show (X);
                     end if;
                     This.Push (This.Car (X));
                  end;
               when CDR =>
                  declare
                     X : constant Object := This.Pop;
                  begin
                     --  The same check CAR makes, which this did not.
                     --  Cdr has Is_Pair as a precondition, so without
                     --  it a cdr of something else was an assertion
                     --  failure out of the machine with contracts on
                     --  and an arbitrary cell with them off.  Every
                     --  list procedure walks with cdr, so this is the
                     --  check that decides whether a program that runs
                     --  off the end of a list is told.

                     if not Is_Pair (X) then
                        raise Constraint_Error with
                          "cdr applied to non-pair: " & This.Show (X);
                     end if;
                     This.Push (This.Cdr (X));
                  end;
               when CONS =>
                  declare
                     X : constant Object := This.Pop;
                     Y : constant Object := This.Pop;
                  begin
                     This.Push (This.Memory.Cons (X, Y));
                  end;
               when DFN =>
                  declare
                     Ref   : constant Object := This.Pop (C);
                     Value : constant Object :=
                               This.Pop;
                  begin
                     This.Referenced_Environment (Ref).Define
                       (This.Referenced_Name (Ref), Value);
                     This.Push (This.Cdr (Ref));
                  end;
               when DROP =>
                  declare
                     X : constant Object := This.Pop (S);
                  begin
                     pragma Unreferenced (X);
                  end;
               when DUM =>
                  This.Push (E, Objects.Pending);
               when EQ =>
                  declare
                     Y : constant Object := This.Pop;
                     X : constant Object := This.Pop;
                  begin
                     This.Push (Objects.To_Object (X = Y));
                  end;
               when JOIN =>
                  This.St (C) := This.Pop (D);
               when LD =>
                  declare
                     Ref : constant Object := This.Pop (C);
                  begin
                     if This.Is_Library_Reference (Ref) then
                        declare
                           Name  : constant String :=
                                     This.Referenced_Name (Ref);
                           Value : constant Object :=
                                     This.Referenced_Environment
                                       (Ref).Lookup (Name);
                        begin
                           if Value = Objects.Undefined then
                              raise Raven.Target.Undefined_Symbol with Name;
                           end if;
                           This.Push (Value);
                        end;
                     else
                        declare
                           I     : constant Natural :=
                                     Objects.To_Integer
                                       (This.Car (Ref));
                           J     : constant Integer :=
                                     Objects.To_Integer
                                       (This.Cdr (Ref));

                        begin
                           if J < 0 then
                              This.Push
                                (Nth_Cdr
                                   (Nth (This.St (E), I), abs J - 1));
                           else
                              This.Push (Nth (Nth (This.St (E), I), J));
                           end if;
                        end;
                     end if;
                  end;
               when LDC =>
                  This.Push (S, This.Pop (C));
               when LDF =>
                  declare
                     CC : constant Object := This.Pop (C);
                  begin
                     --  The code and the environment it closes over,
                     --  in a cell that says what it is.  It used to be
                     --  an ordinary pair, so car took the code out of
                     --  a procedure and a list could be called.

                     This.Push
                       (S,
                        Objects.To_Closure
                          (Objects.Get_Address
                             (This.Memory.Cons (CC, This.St (E)))));
                  end;
               when OP_ADD =>
                  declare
                     Y : constant Integer := To_Integer (This.Pop);
                     X : constant Integer := To_Integer (This.Pop);
                  begin
                     This.Push (To_Object (X + Y));
                  end;
               when OP_LEQ =>
                  declare
                     Y : constant Integer := To_Integer (This.Pop);
                     X : constant Integer := To_Integer (This.Pop);
                  begin
                     This.Push (To_Object (X <= Y));
                  end;
               when PAIR =>
                  This.Push
                    (Raven.Objects.To_Object
                       (Raven.Objects.Is_Pair
                            (This.Pop)));
               when RAP =>
                  declare
                     Omega : constant Object := This.Pop (E);
                  begin
                     pragma Assert (Omega = Objects.Pending);
                  end;

                  This.Push (D, This.St (C));
                  This.Push (D, This.St (E));
                  This.Rs (1) := This.Pop (S);
                  This.Rs (2) := This.Pop (S);
                  This.St (E) :=
                    This.Rplaca (This.Cdr (This.Rs (1)), This.Rs (2));
                  This.St (C) := This.Car (This.Rs (1));
                  This.St (S) := Objects.Nil;

               when RTN =>
                  This.Rs (1) := This.Pop;
                  pragma Assert (This.Is_Empty);
                  This.St (S) := This.Pop (D);
                  This.St (E) := This.Pop (D);
                  This.St (C) := This.Pop (D);
                  This.Push (This.Rs (1));
               when SEL =>
                  declare
                     Cond : constant Boolean := Objects.Is_Truthy (This.Pop);
                     T    : constant Object  := This.Pop (C);
                     F    : constant Object  := This.Pop (C);
                  begin
                     This.Rs (1) := (if Cond then T else F);
                     This.Push (D, This.St (C));
                     This.St (C) := This.Rs (1);
                  end;
               when ST =>
                  declare
                     Ref : constant Object := This.Pop (C);
                     New_Value  : constant Object := This.Pop;
                  begin
                     if This.Is_Library_Reference (Ref) then
                        declare
                           Name       : constant String :=
                                          This.Referenced_Name (Ref);
                           Old_Value  : constant Object :=
                                          This.Referenced_Environment
                                            (Ref).Lookup (Name);
                        begin
                           if Old_Value = Objects.Undefined then
                              raise Raven.Target.Undefined_Symbol with Name;
                           end if;
                           This.Referenced_Environment (Ref).Replace
                             (Name, New_Value);
                           This.Push (New_Value);
                        end;
                     else
                        declare
                           I     : constant Natural :=
                                     Objects.To_Integer
                                       (This.Car (Ref));
                           J     : constant Integer :=
                                     Objects.To_Integer
                                       (This.Cdr (Ref));

                        begin
                           if J < 0 then
                              raise Program_Error with
                                "cannot store to a list argument";
                           end if;
                           This.Push
                             (Replace_Nth
                                (Nth (This.St (E), I), J, New_Value));
                        end;
                     end if;
                  end;
               when STOP =>
                  exit;
                  when others =>
                  raise Constraint_Error with
                    "unimplemented: " & Next'Image;
            end case;
         end;
      end loop;
   end Execute;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      for Stack of This.St loop
         Process (Stack);
      end loop;
      for R of This.Rs loop
         Process (R);
      end loop;
      for Position in This.Macros.Iterate loop
         declare
            E : Macro_Entry := Macro_Vectors.Element (Position);
         begin
            if E.In_Use then
               Process (E.Params);
               Process (E.Macro_Body);
               This.Macros.Replace_Element (Position, E);
            end if;
         end;
      end loop;
      This.Libraries.Mark (Process);
      for T of This.Translators loop
         T.Mark (Process);
      end loop;
   end Mark;

   ----------
   -- Swap --
   ----------

   overriding procedure Swap (This : in out Instance) is
   begin
      This.Rs (3) := This.Pop (S);
      This.Rs (4) := This.Pop (S);
      This.Push (S, This.Rs (3));
      This.Push (S, This.Rs (4));
   end Swap;

   -----------------
   -- Store_Macro --
   -----------------

   overriding function Store_Macro
     (This        : in out Instance;
      Params      : Object;
      Macro_Body  : Object;
      Home        : Raven.Target.Real_Library_Id;
      Expansion   : Raven.Target.Real_Library_Id)
      return Raven.Target.Real_Macro_Id
   is
      New_Entry : constant Macro_Entry :=
                    (True, Params, Macro_Body, Home, Expansion);
   begin
      for Id in 1 .. This.Macros.Last_Index loop
         if not This.Macros (Id).In_Use then
            This.Macros (Id) := New_Entry;
            return Id;
         end if;
      end loop;

      This.Macros.Append (New_Entry);
      return This.Macros.Last_Index;
   end Store_Macro;

   ---------------
   -- Get_Macro --
   ---------------

   overriding procedure Get_Macro
     (This        : Instance;
      Id          : Raven.Target.Real_Macro_Id;
      Params      : out Object;
      Macro_Body  : out Object;
      Home        : out Raven.Target.Real_Library_Id;
      Expansion   : out Raven.Target.Real_Library_Id)
   is
      E : constant Macro_Entry := This.Macros (Id);
   begin
      Params     := E.Params;
      Macro_Body := E.Macro_Body;
      Home       := E.Home;
      Expansion  := E.Expansion;
   end Get_Macro;

   -------------------
   -- Release_Macro --
   -------------------

   overriding procedure Release_Macro
     (This : in out Instance;
      Id   : Raven.Target.Real_Macro_Id)
   is
   begin
      This.Macros (Id) := Macro_Entry'(others => <>);
   end Release_Macro;

   ------------------
   -- Define_Macro --
   ------------------

   overriding procedure Define_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String;
      Id      : Raven.Target.Real_Macro_Id)
   is
   begin
      This.Libraries.Define_Macro (Library, Name, Id);
   end Define_Macro;

   --------------------
   -- Undefine_Macro --
   --------------------

   overriding procedure Undefine_Macro
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id;
      Name    : String)
   is
   begin
      This.Libraries.Undefine_Macro (Library, Name);
   end Undefine_Macro;

   ---------
   -- Pop --
   ---------

   function Pop (This : in out Instance'Class; Name : Stack_Name) return Object is
      Stack : constant Raven.Memory.Cell_Type :=
                This.Memory.Get (Objects.Get_Address (This.St (Name)));
   begin
      This.St (Name) := Stack.Cdr;
      return Stack.Car;
   end Pop;

   ---------
   -- Pop --
   ---------

   overriding procedure Pop
     (This  : in out Instance;
      Value :    out Object)
   is
   begin
      Value := This.Pop (S);
   end Pop;

   ----------
   -- Push --
   ----------

   procedure Push
     (This  : in out Instance'Class;
      Name  : Stack_Name;
      Value : Object)
   is
   begin
      This.St (Name) := This.Memory.Cons (Value, This.St (Name));
   end Push;

   ----------
   -- Push --
   ----------

   overriding procedure Push
     (This  : in out Instance;
      Value : Object)
   is
   begin
      This.Push (S, Value);
   end Push;

   ------------
   -- Report --
   ------------

   overriding procedure Report_Error
     (This    : Instance;
      Message : String)
   is
   begin
      Raven.Write_Error (This.VM, Message);
   end Report_Error;

   overriding procedure Abandon_Form (This : in out Instance) is
   begin
      This.Abandoned := This.Abandoned + 1;
   end Abandon_Form;

   overriding procedure Report (This : Instance) is
   begin
      This.Memory.Report;
   end Report;

   ------------
   -- Rplaca --
   ------------

   function Rplaca
     (This    : Instance'Class;
      X       : Object;
      New_Car : Object)
      return Object
   is
      Address : constant Address_Type := Objects.Get_Address (X);
      Cell    : Raven.Memory.Cell_Type :=
                  This.Memory.Get (Address);
   begin
      --  Replaces a car, and asks nothing of the one it replaces.  RAP
      --  was the only caller when this was written, so it used to
      --  assert that it was filling in a dummy frame; set! on a name
      --  the machine holds on the stack replaces an argument, which is
      --  no such thing.  What RAP needs is still checked where RAP
      --  takes the dummy frame off the environment stack.

      Cell.Car := New_Car;
      This.Memory.Set (Address, Cell);
      return X;
   end Rplaca;

   -------------------
   -- Set_Parameter --
   -------------------

   overriding procedure Set_Parameter
     (This  : in out Instance;
      Name  : String;
      Value : String)
   is
   begin
      if Name = "trace-execution" then
         This.Trace := Boolean'Value (Value);
      end if;
   end Set_Parameter;

   --------------------
   -- List_To_Vector --
   --------------------

   overriding procedure List_To_Vector
     (This : in out Instance)
   is
   begin
      List_To_Block (This, Bytevector => False);
   end List_To_Vector;

   ------------------------
   -- List_To_Bytevector --
   ------------------------

   overriding procedure List_To_Bytevector
     (This : in out Instance)
   is
   begin
      List_To_Block (This, Bytevector => True);
   end List_To_Bytevector;

   -------------------
   -- List_To_Block --
   -------------------

   procedure List_To_Block
     (This       : in out Instance'Class;
      Bytevector : Boolean)
   is
      Length : Natural := 0;
      It     : Object;
   begin
      --  The list stays on the stack and in a register, because
      --  making the vector can collect and both of those are walked.
      --  A count first, which allocates nothing.

      This.Rs (1) := This.Top;

      It := This.Rs (1);
      while It /= Objects.Nil loop
         Length := Length + 1;
         It := This.Cdr (It);
      end loop;

      This.Rs (2) := (if Bytevector
                      then This.Memory.New_Bytevector (Length)
                      else This.Memory.New_Vector (Length));

      It := This.Rs (1);
      for Index in 0 .. Length - 1 loop
         This.Memory.Set_Vector_Element (This.Rs (2), Index, This.Car (It));
         It := This.Cdr (It);
      end loop;

      This.Drop;
      This.Push (This.Rs (2));

      This.Rs (1) := Objects.Nil;
      This.Rs (2) := Objects.Nil;
   end List_To_Block;

   ---------------
   -- Translate --
   ---------------

   overriding procedure Translate
     (This    : in out Instance;
      Library : Raven.Target.Real_Library_Id)
   is
      Translator : aliased Raven.Translator.Abstraction'Class :=
                     Raven.Engine.SECD.Translator.Create;
   begin
      --  Everything the translator holds -- the code it is building,
      --  and the form it is reading -- is reachable only through it,
      --  and expanding a macro runs the machine, which can collect.  So
      --  it is a root for as long as it runs, and no longer: it goes
      --  when this call returns.

      This.Translators.Append (Translator'Unchecked_Access);
      begin
         Translator.Translate (This'Unchecked_Access, Library);
      exception
         when others =>
            This.Translators.Delete_Last;
            raise;
      end;
      This.Translators.Delete_Last;
   end Translate;

end Raven.Engine.SECD;
