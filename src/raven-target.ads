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

   --  Every translation happens in a library, and the code it produces
   --  carries it: the operand of LD, ST and DFN names a library and a
   --  symbol, so a name written in one library and the same name
   --  written in another are two names.  A closure needs to know
   --  nothing about it, because nothing is left to decide when it runs.

   type Library_Id is new Natural;

   No_Library : constant Library_Id := 0;

   subtype Real_Library_Id is Library_Id range 1 .. Library_Id'Last;

   --  Where a form typed at the host, rather than read out of a
   --  library, is translated.

   function Interaction_Library
     (This : Abstraction)
      return Real_Library_Id
   is abstract;

   procedure Translate
     (This    : in out Abstraction;
      Library : Real_Library_Id)
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

   --  Macro definitions are stored here rather than in the translator
   --  because their Params and Macro_Body are collectable objects, and
   --  only a container the collector walks can keep them alive.  Scope
   --  is the translator's business: it holds the ids, which are not
   --  objects, in its lexical chain.

   type Macro_Id is new Natural;

   No_Macro : constant Macro_Id := 0;

   subtype Real_Macro_Id is Macro_Id range 1 .. Macro_Id'Last;

   function Store_Macro
     (This        : in out Abstraction;
      Params      : Object;
      Macro_Body  : Object)
      return Real_Macro_Id
   is abstract;

   procedure Get_Macro
     (This        : Abstraction;
      Id          : Real_Macro_Id;
      Params      : out Object;
      Macro_Body  : out Object)
   is abstract;

   --  Gives a definition back: it becomes collectable and its id may be
   --  reused.  Only the translator knows when that is safe, so only the
   --  translator calls it -- naming or unnaming a macro does not.

   procedure Release_Macro
     (This : in out Abstraction;
      Id   : Real_Macro_Id)
   is abstract;

   --  The global scope is the one macro scope that outlives a single
   --  translation, so the translator cannot hold it: each top level
   --  form gets a fresh translator, and with it a fresh lexical chain.

   procedure Define_Global_Macro
     (This : in out Abstraction;
      Name : String;
      Id   : Real_Macro_Id)
   is abstract;

   procedure Undefine_Global_Macro
     (This : in out Abstraction;
      Name : String)
   is abstract;

   function Global_Macro
     (This : Abstraction;
      Name : String)
      return Macro_Id
   is abstract;

end Raven.Target;
