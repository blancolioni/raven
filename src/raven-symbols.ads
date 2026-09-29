with Raven.Objects;

private package Raven.Symbols is

   type Abstraction is interface;
   type Reference is access all Abstraction'Class;

   function To_Symbol_Id
     (This  : in out Abstraction;
      Name  : String)
      return Raven.Objects.Symbol_Id
      is abstract;

   function To_Symbol
     (This : in out Abstraction'Class;
      Name : String)
      return Object
   is (Raven.Objects.To_Object (This.To_Symbol_Id (Name)));

   --  A generated symbol has a name, so that it can be shown, but it
   --  is not interned under it: reading that name gives a different
   --  symbol.  That is what puts a name a macro introduces beyond the
   --  reach of anything written at the call site.

   function New_Symbol_Id
     (This   : in out Abstraction;
      Prefix : String)
      return Raven.Objects.Symbol_Id
      is abstract;

   function New_Symbol
     (This   : in out Abstraction'Class;
      Prefix : String)
      return Object
   is (Raven.Objects.To_Object (This.New_Symbol_Id (Prefix)));

   function To_String
     (This  : Abstraction;
      Id    : Raven.Objects.Symbol_Id)
      return String
      is abstract;

   --  An alias (#24) is a generated symbol that stands for a name a
   --  syntax-rules template wrote, in the library the macro was written
   --  in.  Being generated, nothing a caller writes is it, so no binding
   --  the caller makes can take it over; and it knows what it stands
   --  for, so the translator can read it where the template was
   --  written.  Library is that library's id, which is never zero.
   --
   --  Alias_Original and Alias_Library of a symbol that is not an
   --  alias are the symbol itself and zero.

   --  Scope is how many of the translator's scopes there were where the
   --  macro was bound (#181), for a macro a body defined, whose template
   --  means that body's names by the names it wrote; nought for a macro a
   --  library defined.

   function New_Alias_Id
     (This     : in out Abstraction;
      Original : Raven.Objects.Symbol_Id;
      Library  : Positive;
      Scope    : Natural := 0)
      return Raven.Objects.Symbol_Id
      is abstract;

   function Alias_Scope
     (This : Abstraction;
      Id   : Raven.Objects.Symbol_Id)
      return Natural
      is abstract;

   function Alias_Original
     (This : Abstraction;
      Id   : Raven.Objects.Symbol_Id)
      return Raven.Objects.Symbol_Id
      is abstract;

   function Alias_Library
     (This : Abstraction;
      Id   : Raven.Objects.Symbol_Id)
      return Natural
      is abstract;

end Raven.Symbols;
