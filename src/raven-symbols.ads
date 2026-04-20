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

   function To_String
     (This  : Abstraction;
      Id    : Raven.Objects.Symbol_Id)
      return String
      is abstract;

end Raven.Symbols;
