with Raven.Containers;
with Raven.Engine.Environment;
with Raven.Engine.Memory;
with Raven.Engine.SECD;
with Raven.Engine.Symbols;
with Raven.Environment;
with Raven.Objects;
with Raven.Scheme;
with Raven.Symbols;
with Raven.Target;

package body Raven.Engine is

   type Slot_Array is array (Slot_Index) of Object;

   type Register_Index is range 1 .. 64;

   type Register_Array is array (Register_Index) of Object;

   type Instance is
     new Raven.Evaluator.Abstraction
     and Raven.Containers.Abstraction with
      record
         VM            : Raven_VM;
         Slots         : Slot_Array := [others     => Raven.Objects.Nil];
         Syms          : Raven.Symbols.Reference;
         Stack         : Object := Raven.Objects.Nil;
         Handles       : Object_Lists.List;
         R             : Register_Array := [others => Raven.Objects.Nil];
         Memory        : Raven.Memory.Reference;
         Env           : Raven.Environment.Reference;
         Target        : Raven.Target.Reference;
      end record;

   type Engine_Reference is access all Instance'Class;

   overriding function To_Symbol_Id
     (This  : in out Instance;
      Name  : String)
      return Raven.Objects.Symbol_Id
   is (This.Syms.To_Symbol_Id (Name));

   overriding function To_String
     (This  : Instance;
      Id    : Raven.Objects.Symbol_Id)
      return String
   is (This.Syms.To_String (Id));

   overriding function Is_Empty
     (This : Instance)
      return Boolean;

   overriding function Target
     (This : Instance)
      return Raven.Target.Reference;

   overriding procedure Before_Collection
     (This : in out Instance)
   is null;

   overriding procedure After_Collection
     (This : in out Instance)
   is null;

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object));

   overriding function Cons
     (This     : Instance;
      Car, Cdr : Object)
      return Object
   is (This.Memory.Cons (Car, Cdr));

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
      return Object;

   overriding procedure Cons (This : in out Instance);

   overriding procedure Swap (This : in out Instance);

   overriding function Get_Slot
     (This  : Instance;
      Index : Slot_Index)
      return Raven.Object
   is (This.Slots (Index));

   overriding procedure Set_Slot
     (This  : in out Instance;
      Index : Slot_Index;
      Value : Raven.Object);

   overriding function Bind_Handle_To_Name
     (This : in out Instance;
      Name : String)
      return Object_Lists.Cursor;

   overriding procedure Bind
     (This           : in out Instance;
      Name           : String;
      Value          : Object;
      Argument_Count : Natural);

   overriding procedure Bind_Foreign_Function
     (This           : in out Instance;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural);

   overriding procedure Report (This : Instance);

   ----------
   -- Bind --
   ----------

   overriding procedure Bind
     (This           : in out Instance;
      Name           : String;
      Value          : Object;
      Argument_Count : Natural)
   is
      pragma Unreferenced (Argument_Count);
   begin
      This.Env.Define (Name, Value);
   end Bind;

   -------------------------
   -- Bind_Handle_To_Name --
   -------------------------

   overriding function Bind_Handle_To_Name
     (This : in out Instance;
      Name : String)
      return Object_Lists.Cursor
   is
   begin
      This.Handles.Append
        (Raven.Objects.To_Object
           (This.To_Symbol_Id (Name)));
      return This.Handles.Last;
   end Bind_Handle_To_Name;

   ---------------------------
   -- Bind_Foreign_Function --
   ---------------------------

   overriding procedure Bind_Foreign_Function
     (This           : in out Instance;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural)
   is
   begin
      This.Target.Bind_Foreign_Function (Name, Handler, Argument_Count);
   end Bind_Foreign_Function;

   ----------
   -- Cons --
   ----------

   overriding procedure Cons (This : in out Instance) is
      Cdr : constant Object := This.Pop;
      Car : constant Object := This.Pop;
   begin
      This.Push (This.Memory.Cons (Car, Cdr));
   end Cons;

   ------------
   -- Create --
   ------------

   function Create
     (VM            : Raven_VM;
      Memory        : Raven.Memory.Reference;
      Configuration : String)
      return Raven.Evaluator.Reference
   is
      pragma Unreferenced (Configuration);
      This : constant Engine_Reference := new Instance'
        (VM     => VM,
         Env    => Raven.Engine.Environment.Create,
         Syms   => Raven.Engine.Symbols.Create,
         Memory => Memory,
         others => <>);
   begin
      This.Memory.Add_Container (This);
      This.Target :=
        Raven.Engine.SECD.Create (This.VM, This.Memory, This.Env, This.Syms);

      This.Env.Insert
        ("raven-version-major",
         Raven.Objects.To_Object (Version_Major));
      This.Env.Insert
        ("raven-version-minor",
         Raven.Objects.To_Object (Version_Minor));
      This.Env.Insert
        ("raven-version-release",
         Raven.Objects.To_Object (Version_Release));
      This.Env.Insert
        ("raven-version-name",
         Raven.Objects.To_Object
           (This.To_Symbol_Id (Version_String)));
      This.Env.Insert
        ("nil",
         Raven.Objects.Nil);
      This.Env.Insert
        ("#t",
         Raven.Objects.To_Object (True));
      This.Env.Insert
        ("#f",
         Raven.Objects.To_Object (False));
      This.Env.Insert
        ("quote",
         Raven.Objects.Quote);

      Raven.Scheme.Load_Base_Primitives (This);

      return Raven.Evaluator.Reference (This);
   end Create;

   -------------------
   -- Create_Memory --
   -------------------

   function Create_Memory
     (Size : Natural)
      return Raven.Memory.Reference
   is
   begin
      return Raven.Engine.Memory.Create (Size);
   end Create_Memory;

   --------------
   -- Is_Empty --
   --------------

   overriding function Is_Empty
     (This : Instance)
      return Boolean
   is
   begin
      return This.Stack = Raven.Objects.Nil;
   end Is_Empty;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      Process (This.Stack);
      for Slot of This.Slots loop
         Process (Slot);
      end loop;
      for Handle of This.Handles loop
         Process (Handle);
      end loop;
      for R of This.R loop
         Process (R);
      end loop;
      This.Env.Mark (Process);
   end Mark;

   ---------
   -- Pop --
   ---------

   overriding procedure Pop
     (This  : in out Instance;
      Value :    out Object)
   is
      Cell : constant Raven.Memory.Cell_Type :=
               This.Memory.Get (Raven.Objects.Get_Address (This.Stack));
   begin
      Value := Cell.Car;
      This.Stack := Cell.Cdr;
   end Pop;

   ----------
   -- Push --
   ----------

   overriding procedure Push
     (This  : in out Instance;
      Value : Object)
   is
   begin
      This.Stack := This.Memory.Cons (Value, This.Stack);
   end Push;

   ------------
   -- Report --
   ------------

   overriding procedure Report (This : Instance) is
   begin
      This.Memory.Report;
   end Report;

   ----------
   -- Swap --
   ----------

   overriding procedure Swap (This : in out Instance) is
   begin
      This.Pop (This.R (1));
      This.Pop (This.R (2));
      This.Push (This.R (1));
      This.Push (This.R (2));
   end Swap;

   --------------
   -- Set_Slot --
   --------------

   overriding procedure Set_Slot
     (This  : in out Instance;
      Index : Slot_Index;
      Value : Raven.Object)
   is
   begin
      This.Slots (Index) := Value;
   end Set_Slot;

   ------------
   -- Target --
   ------------

   overriding function Target
     (This : Instance)
      return Raven.Target.Reference
   is
   begin
      return This.Target;
   end Target;

   ---------
   -- Top --
   ---------

   overriding function Top
     (This : Instance)
      return Object
   is
   begin
      return This.Memory.Get (Raven.Objects.Get_Address (This.Stack)).Car;
   end Top;

end Raven.Engine;
