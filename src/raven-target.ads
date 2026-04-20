with Raven.Containers;
with Raven.Objects;
with Raven.Pairs;
with Raven.Reportable;
with Raven.Stacks;
with Raven.Symbols;

private package Raven.Target is

   Undefined_Symbol  : exception;
   Translation_Error : exception;

   type Abstraction is interface
     and Raven.Containers.Abstraction
     and Raven.Pairs.Abstraction
     and Raven.Reportable.Abstraction
     and Raven.Stacks.Abstraction
     and Raven.Symbols.Abstraction;

   type Reference is access all Abstraction'Class;

   procedure Translate
     (This   : in out Abstraction)
   is abstract;

   procedure Execute
     (This   : in out Abstraction)
   is abstract;

   procedure Bind_Foreign_Function
     (This           : in out Abstraction;
      Name           : String;
      Handler        : Foreign_Function_Handler;
      Argument_Count : Natural)
   is abstract;

   function To_Foreign_Value
     (This  : Abstraction;
      Value : Object)
      return Foreign_Value_Instance'Class
      is abstract
     with Pre'Class => Raven.Objects.Is_Foreign_Value (Value);

   function Show (This : Abstraction'Class;
                  X    : Object)
                  return String;

   procedure Set_Parameter
     (This  : in out Abstraction;
      Name  : String;
      Value : String)
   is abstract;

   function Append_Lists
     (This  : in out Abstraction;
      List1 : Object;
      List2 : Object)
      return Object
   is abstract;

   procedure Define_Macro
     (This        : in out Abstraction;
      Name        : String;
      Params      : Object;
      Macro_Body  : Object)
   is abstract;

   function Is_Macro
     (This : Abstraction;
      Name : String)
      return Boolean
   is abstract;

   procedure Get_Macro
     (This        : Abstraction;
      Name        : String;
      Params      : out Object;
      Macro_Body  : out Object)
   is abstract;

end Raven.Target;
