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

   --  What is said about a form, and a form given up on.  The loader
   --  and the translator have a target and nothing else, and both had
   --  been writing to the terminal whatever the host asked for; these
   --  are the two things they need and not a VM to do as they like
   --  with.

   procedure Report_Error
     (This    : Abstraction;
      Message : String)
   is abstract;

   --  A form read as far as it could be and then given up on.  One
   --  bad form does not stop a file, which is right, but nothing
   --  downstream could tell it had happened.

   procedure Abandon_Form (This : in out Abstraction) is abstract;

   function Forms_Abandoned (This : Abstraction) return Natural
   is abstract;

   --  Where the machine's stack stands, kept where the collector can
   --  see it, and put back there.  A form that fails part way through
   --  leaves the stack wherever it had got to, so a caller holding
   --  something on it -- the forms of a library it is half way down,
   --  say -- has nowhere to carry on from unless it said where first.
   --
   --  Held while the form runs, and let go either way: released
   --  without restoring when the form ran, and with when it did not.

   procedure Hold_Stack (This : in out Abstraction) is abstract;

   procedure Release_Stack
     (This    : in out Abstraction;
      Restore : Boolean)
   is abstract;

   type Library_Id is new Natural;

   No_Library : constant Library_Id := 0;

   subtype Real_Library_Id is Library_Id range 1 .. Library_Id'Last;

   --  A library with a form in it that could not be run.  Nothing
   --  imports one: a file being read carries on at the form after a
   --  bad one, so that every bad form in it is heard about and not
   --  only the first, but a library is a unit or it is nothing, and
   --  half of one is worse than none -- the names it never got round
   --  to defining would go undefined at each use instead, a long way
   --  from the reason.

   procedure Set_Incomplete
     (This    : in out Abstraction;
      Library : Real_Library_Id)
   is abstract;

   function Is_Incomplete
     (This    : Abstraction;
      Library : Library_Id)
      return Boolean
   is abstract;

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

   --  A string object holding this text.  The reader asks for one when
   --  it reads a string written in the source, so that the string is
   --  an object the code carries rather than a form the code runs.

   --  What Show needs of a vector, which is the same as what a
   --  program needs of one.

   function Vector_Length
     (This : Abstraction;
      V    : Object)
      return Natural
   is abstract;

   function Vector_Element
     (This  : Abstraction;
      V     : Object;
      Index : Natural)
      return Object
   is abstract;

   --  A vector of the elements of the list on top of the stack, which
   --  it replaces.
   --
   --  #(1 2 3) used to read as a call of vector, so its elements were
   --  expressions: #(1 2 3) came out right because a number stands
   --  for itself, and #(a b) said "undefined: a".  R7RS says a vector
   --  written out is a literal and its elements are data, so the
   --  reader builds it rather than leaving a call for the translator.

   procedure List_To_Vector
     (This : in out Abstraction)
   is abstract;

   --  The same for #u8(...), which read as a call of bytevector and
   --  had the same trouble: its elements were expressions.

   procedure List_To_Bytevector
     (This : in out Abstraction)
   is abstract;

   function Create_String
     (This : in out Abstraction;
      Text : Wide_Wide_String)
      return Object
   is abstract;

   --  R7RS has two ways of turning an object into text and they
   --  differ on exactly two kinds of it: a string has its quotation
   --  marks and its escapes when it is to be read back and not when it
   --  is to be read, and a character has its #\ and its name.
   --  Readable picks which, and is the one every caller but display
   --  wants.

   function Show (This     : Abstraction'Class;
                  X        : Object;
                  Readable : Boolean := True)
                  return String;

   procedure Set_Parameter
     (This  : in out Abstraction;
      Name  : String;
      Value : String)
   is abstract;

   --  Whether the host asked to be shown what the machine is doing.
   --  Set_Parameter could say so and nothing could ask, so what is
   --  only of use to somebody reading a trace was written whether one
   --  had been asked for or not.

   function Tracing
     (This : Abstraction)
      return Boolean
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
   --  written, so it carries the library it was written in.  It
   --  carries two, because a macro written by a macro has two: the
   --  body is the text the outer macro wrote, and Home is that outer
   --  macro's library; what the body produces is the inner macro's
   --  own, and Expansion is the library the form that defined it was
   --  written in.
   --
   --  define-syntax is the whole of why.  A syntax-rules macro's body
   --  is always the same call of the expander, written in the library
   --  define-syntax came from; what that call produces is the rules,
   --  written where the macro was.  A macro written by hand has one
   --  library and both are it.
   --
   --  Both are ids and not objects, so they cost the collector
   --  nothing.

   function Store_Macro
     (This        : in out Abstraction;
      Params      : Object;
      Macro_Body  : Object;
      Home        : Real_Library_Id;
      Expansion   : Real_Library_Id)
      return Real_Macro_Id
   is abstract;

   procedure Get_Macro
     (This        : Abstraction;
      Id          : Real_Macro_Id;
      Params      : out Object;
      Macro_Body  : out Object;
      Home        : out Real_Library_Id;
      Expansion   : out Real_Library_Id)
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
