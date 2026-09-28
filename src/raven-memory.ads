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

   --  A bignum's block: Length bytes of magnitude, nought, and the
   --  sign.  Its bytes are read and written as a bytevector's are, and
   --  its length is a vector's length.

   function New_Bignum
     (This     : in out Abstraction;
      Length   : Natural;
      Negative : Boolean)
      return Object
   is abstract;

   function Is_Negative
     (This : Abstraction;
      X    : Object)
      return Boolean
   is abstract;

   --  A boxed double, and the double in one.

   function New_Flonum
     (This  : in out Abstraction;
      Value : Long_Float)
      return Object
   is abstract;

   function Flonum_Value
     (This : Abstraction;
      X    : Object)
      return Long_Float
   is abstract
     with Pre'Class => Raven.Objects.Is_Flonum (X);

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

   --  Changing a value where it is (#158), for a value that a program
   --  may change, such as a string.  Update changes what it holds, and
   --  Process must not make anything, as Query's must not.  Replace
   --  puts another value of the same kind in its place, which is how
   --  one grows: every object that is the value is the new one after.

   procedure Update_Foreign_Value
     (This    : in out Abstraction;
      Value   : Object;
      Process : not null access
        procedure (Item : in out Foreign_Value_Instance'Class))
   is abstract
     with Pre'Class => Raven.Objects.Is_Foreign_Value (Value);

   procedure Replace_Foreign_Value
     (This      : in out Abstraction;
      Value     : Object;
      New_Value : Foreign_Value_Instance'Class)
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
