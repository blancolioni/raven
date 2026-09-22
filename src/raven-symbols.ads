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

end Raven.Symbols;
