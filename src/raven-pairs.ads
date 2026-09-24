with Raven.Objects;

private package Raven.Pairs is

   type Abstraction is interface;
   type Reference is access all Abstraction'Class;

   --  These read a cell, and both a pair and a closure are one, so
   --  what they ask is Has_Address rather than Is_Pair.  What a
   --  program may take apart is decided by the CAR and CDR
   --  instructions, which still ask for a pair and refuse a closure --
   --  which is the whole point of giving a closure a tag.

   function Car
     (This : Abstraction;
      Pair : Object)
      return Object
      is abstract
     with Pre'Class => Raven.Objects.Has_Address (Pair);

   function Cdr
     (This : Abstraction;
      Pair : Object)
      return Object
      is abstract
     with Pre'Class => Raven.Objects.Has_Address (Pair);

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
