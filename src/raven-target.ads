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

   function Library
     (This : Abstraction;
      Name : String)
      return Library_Id
   is abstract;

   function Create_Library
     (This : in out Abstraction;
      Name : String)
      return Real_Library_Id
   is abstract;

   --  What Library imports from Imported: everything Imported has
   --  defined, and nothing it has not.  An import is looked at only
   --  when the library itself has nothing of the name, and the most
   --  recent one is looked at first.

   procedure Add_Import
     (This     : in out Abstraction;
      Library  : Real_Library_Id;
      Imported : Real_Library_Id)
   is abstract;

   --  A library that says what it offers offers exactly that.  One
   --  that says nothing -- a file that is not written as a library --
   --  offers everything it defines.

   procedure Set_Export_List
     (This    : in out Abstraction;
      Library : Real_Library_Id)
   is abstract;

   procedure Add_Export
     (This    : in out Abstraction;
      Library : Real_Library_Id;
      Name    : String)
   is abstract;

   --  A library has defined this name.  Said while the form that
   --  defines it is translated, because that is when what comes after
   --  it starts meaning it.

   procedure Define_Name
     (This    : in out Abstraction;
      Library : Real_Library_Id;
      Name    : String)
   is abstract;

   function Resolve
     (This    : Abstraction;
      Library : Real_Library_Id;
      Name    : String)
      return Real_Library_Id
   is abstract;

   --  Whether anything Library knows of accounts for the name, which
   --  Resolve cannot say: it gives back Library itself both for a name
   --  written here and for one nothing accounts for.

   function Binds
     (This    : Abstraction;
      Library : Real_Library_Id;
      Name    : String)
      return Boolean
   is abstract;

   --  Where a library name is looked for, in the order they were
   --  added.  Library_Path gives back nothing past the last.

   procedure Add_Library_Path
     (This : in out Abstraction;
      Path : String)
   is abstract;

   function Library_Path
     (This  : Abstraction;
      Index : Positive)
      return String
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

   --  A macro is expanded where it is used and read where it was
   --  written, so it carries the library it was written in.  A name
   --  free in what it expands to means what it means there, which is
   --  how a library's macro can reach what the library keeps to
   --  itself.  Home is an id and not an object, so it costs the
   --  collector nothing.

   function Store_Macro
     (This        : in out Abstraction;
      Params      : Object;
      Macro_Body  : Object;
      Home        : Real_Library_Id)
      return Real_Macro_Id
   is abstract;

   procedure Get_Macro
     (This        : Abstraction;
      Id          : Real_Macro_Id;
      Params      : out Object;
      Macro_Body  : out Object;
      Home        : out Real_Library_Id)
   is abstract;

   --  Gives a definition back: it becomes collectable and its id may be
   --  reused.  Only the translator knows when that is safe, so only the
   --  translator calls it -- naming or unnaming a macro does not.

   procedure Release_Macro
     (This : in out Abstraction;
      Id   : Real_Macro_Id)
   is abstract;

   --  A library's macro scope is the one that outlives a single
   --  translation, so the translator cannot hold it: each top level
   --  form gets a fresh translator, and with it a fresh lexical chain.
   --  Macro searches what the library imported as well; Own_Macro is
   --  what the library itself has, which is all it may take back.

   procedure Define_Macro
     (This    : in out Abstraction;
      Library : Real_Library_Id;
      Name    : String;
      Id      : Real_Macro_Id)
   is abstract;

   procedure Undefine_Macro
     (This    : in out Abstraction;
      Library : Real_Library_Id;
      Name    : String)
   is abstract;

   function Macro
     (This    : Abstraction;
      Library : Real_Library_Id;
      Name    : String)
      return Macro_Id
   is abstract;

   function Own_Macro
     (This    : Abstraction;
      Library : Real_Library_Id;
      Name    : String)
      return Macro_Id
   is abstract;

end Raven.Target;
