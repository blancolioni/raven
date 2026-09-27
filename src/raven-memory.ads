with Raven.Containers;
with Raven.Objects;
with Raven.Reportable;

private package Raven.Memory is

   type Abstraction is interface and Raven.Reportable.Abstraction;

   type Reference is access all Abstraction'Class;

   type Cell_Type is
      record
         Car, Cdr : Object;
      end record;

   function Get
     (This    : Abstraction;
      Address : Address_Type)
      return Cell_Type
      is abstract;

   procedure Set
     (This    : in out Abstraction;
      Address : Address_Type;
      Cell    : Cell_Type)
      is abstract;

   function Cons
     (This : in out Abstraction;
      Car  : Object;
      Cdr  : Object)
      return Object
      is abstract;

   --  A vector of this many elements, every one of them nil.  The
   --  cells it takes are contiguous, so an element is reached by
   --  arithmetic; asking for one may collect, and nothing of the
   --  vector exists until it answers, so there is nothing of it to
   --  keep alive across that.

   function New_Vector
     (This   : in out Abstraction;
      Length : Natural)
      return Object
   is abstract;

   --  Laid out the way a vector is, so everything below answers for
   --  one of these as well.

   function New_Bytevector
     (This   : in out Abstraction;
      Length : Natural)
      return Object
   is abstract;

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

   procedure Set_Vector_Element
     (This  : in out Abstraction;
      V     : Object;
      Index : Natural;
      Value : Object)
   is abstract;

   procedure Add_Container
     (This      : in out Abstraction;
      Container : not null access Raven.Containers.Abstraction'Class)
   is abstract;

   function Create_Foreign_Value
     (This  : in out Abstraction;
      Value : Foreign_Value_Instance'Class)
      return Object
      is abstract;

   function To_Foreign_Value
     (This : Abstraction;
      Value : Object)
      return Foreign_Value_Instance'Class
   is abstract
     with Pre'Class => Raven.Objects.Is_Foreign_Value (Value);

   --  The value where it is, for reading without the copy that
   --  To_Foreign_Value makes: a string of a thousand characters is a
   --  thousand characters copied to reach one of them.  Process must
   --  not make anything while it runs, because the table is held.

   procedure Query_Foreign_Value
     (This    : Abstraction;
      Value   : Object;
      Process : not null access
        procedure (Item : Foreign_Value_Instance'Class))
   is abstract
     with Pre'Class => Raven.Objects.Is_Foreign_Value (Value);

   --  Giving up everything held.  Every foreign value still live is
   --  told, because Free is how one gives back whatever it stood for
   --  -- an open file, a host's memory -- and no collection happens
   --  at shutdown to tell it.
   --
   --  What is left afterwards is a memory that owns nothing, so that
   --  whoever holds the reference can give it back.

   procedure Close (This : in out Abstraction) is abstract;

   procedure Mark
     (This : in out Abstraction;
      Root : in out Object)
   is abstract;

end Raven.Memory;
