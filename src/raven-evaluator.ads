with Raven.Pairs;
with Raven.Reportable;
with Raven.Stacks;
with Raven.Symbols;
with Raven.Target;

private package Raven.Evaluator is

   type Abstraction is interface
     and Raven.Stacks.Abstraction
     and Raven.Symbols.Abstraction
     and Raven.Pairs.Abstraction
     and Raven.Reportable.Abstraction;

   type Reference is access all Abstraction'Class;

   function Target
     (This : Abstraction)
      return Raven.Target.Reference
      is abstract;

   function Bind_Handle_To_Name
     (This : in out Abstraction;
      Name : String)
      return Object_Lists.Cursor
      is abstract;

   procedure Bind_Foreign_Function
     (This           : in out Abstraction;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural)
   is abstract;

   procedure Bind
     (This           : in out Abstraction;
      Name           : String;
      Value          : Object;
      Argument_Count : Natural)
   is abstract;

   function Cons
     (This     : Abstraction;
      Car, Cdr : Object)
      return Object
      is abstract;

   function Get_Slot
     (This  : Abstraction;
      Index : Slot_Index)
      return Object
      is abstract;

   procedure Set_Slot
     (This  : in out Abstraction;
      Index : Slot_Index;
      Value : Object)
   is abstract;

end Raven.Evaluator;
