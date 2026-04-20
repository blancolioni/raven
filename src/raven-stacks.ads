private package Raven.Stacks is

   type Abstraction is interface;
   type Reference is access all Abstraction'Class;

   function Is_Empty
     (This : Abstraction)
      return Boolean
      is abstract;

   procedure Push
     (This  : in out Abstraction;
      Value : Object)
   is abstract
     with Post'Class => not This.Is_Empty;

   procedure Pop
     (This  : in out Abstraction;
      Value :    out Object)
   is abstract
     with Pre'Class => not This.Is_Empty;

   function Top
     (This : Abstraction)
      return Object
      is abstract
     with Pre'Class => not This.Is_Empty;

   procedure Cons (This : in out Abstraction) is abstract
     with Pre'Class => not This.Is_Empty;
   --  top is cdr, next is car

   procedure Drop
     (This : in out Abstraction'Class);

   function Pop
     (This : in out Abstraction'Class)
      return Object;

   procedure Push_Nil
     (This  : in out Abstraction'Class);

   procedure Swap
     (This : in out Abstraction)
      is abstract
     with Pre'Class => not This.Is_Empty;

end Raven.Stacks;
