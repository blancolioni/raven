with Raven.Objects;

private package Raven.Pairs is

   type Abstraction is interface;
   type Reference is access all Abstraction'Class;

   function Car
     (This : Abstraction;
      Pair : Object)
      return Object
      is abstract
     with Pre'Class => Raven.Objects.Is_Pair (Pair);

   function Cdr
     (This : Abstraction;
      Pair : Object)
      return Object
      is abstract
     with Pre'Class => Raven.Objects.Is_Pair (Pair);

   function Caar (This : Abstraction'Class;
                  Cons : Object)
                  return Object
   is (This.Car (This.Car (Cons)));

   function Cadr (This : Abstraction'Class;
                  Cons : Object)
                  return Object
   is (This.Car (This.Cdr (Cons)));

   function Cdar (This : Abstraction'Class;
                  Cons : Object)
                  return Object
   is (This.Cdr (This.Car (Cons)));

   function Cddr (This : Abstraction'Class;
                  Cons : Object)
                  return Object
   is (This.Cdr (This.Cdr (Cons)));

   function Caddr (This : Abstraction'Class;
                   Cons : Object)
                   return Object
   is (This.Car (This.Cdr (This.Cdr (Cons))));

end Raven.Pairs;
