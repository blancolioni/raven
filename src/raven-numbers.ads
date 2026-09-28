private with Ada.Numerics.Big_Numbers.Big_Integers;

with Raven.Objects;

--  Numbers, as arithmetic sees them: decoded from an object, operated
--  on, and encoded again.
--
--  This is the seam the numeric tower goes behind (#45).  Every
--  arithmetic primitive raven has goes through it, and does nothing
--  else itself: decode each operand, ask this for the answer, encode
--  it.  So each kind of number is a kind of Number here and a case in
--  each operation, and the primitives and the scheme library above them
--  do not change when one is added.
--
--  Three kinds so far, two exact and one not.
--
--  A fixnum is an integer in an object's payload, 29 bits and a sign.
--  A bignum is an exact integer past that (#102), held in the heap as a
--  block of packed bytes and worked on as Ada's Big_Integer.  Two
--  fixnums never become a Big_Integer; their answer is worked out in
--  Long_Long_Integer, where it cannot overflow, and made a bignum only
--  if it does not fit.
--
--  A flonum is an inexact number, a double (#103).  It is worked on as
--  Long_Float, and kept as the immediate float when that holds it
--  exactly and as a boxed double otherwise -- see Raven.Objects.  An
--  operation with any inexact operand answers inexact, which is R7RS's
--  contagion: the answer can be no more exact than what it was worked
--  out from.
--
--  Normalisation is the invariant: every Number an operation gives back
--  is in the smallest representation that holds it exactly.  An exact
--  integer that fits in a fixnum is a fixnum, however it was arrived at
--  -- (- (expt 2 40) (expt 2 40)) is a fixnum zero and not a boxed one
--  -- and a double that the immediate float holds is an immediate.
--  Encode depends on it, and so does equality: two numbers of different
--  representations are never the same number unless one is exact and
--  the other not.

private package Raven.Numbers is

   type Number is private;

   --  Whether arithmetic can take this object as an operand, which is
   --  whether Decode may be asked about it.

   function Is_Arithmetic (X : Object) return Boolean;

   --  Decoding a bignum or a boxed double reads its block, and encoding
   --  one makes a block, which may collect.  Nothing a Number holds is in
   --  the heap, so a collection while encoding moves nothing a Number
   --  needs; but an object the caller read before Encode is somewhere
   --  else afterwards.

   function Decode
     (VM : Raven_VM'Class;
      X  : Object)
      return Number
     with Pre => Is_Arithmetic (X);

   function Encode
     (VM : Raven_VM'Class;
      N  : Number)
      return Object
     with Post => Is_Arithmetic (Encode'Result);

   --  An inexact number from a double, which is how the reader and
   --  string->number make one.

   function Inexact_Of (Value : Long_Float) return Number;

   --  The operations.  Each gives back a normal Number, or raises
   --  Constraint_Error saying why there is none: a division by zero, or
   --  a double past what a double holds.

   function Add (Left, Right : Number) return Number;
   function Subtract (Left, Right : Number) return Number;
   function Multiply (Left, Right : Number) return Number;

   --  An exact division throws the remainder away, until there are
   --  rationals to answer with (#104).  A division with an inexact
   --  operand is the double it comes to.

   function Divide (Left, Right : Number) return Number;

   function Less_Or_Equal (Left, Right : Number) return Boolean;

   --  Two questions R7RS keeps apart.  Equal is =: the same number,
   --  whatever it is held as, so (= 2 2.0) is true.  Eqv is eqv?, and
   --  asks more: equal, and both exact or both inexact, so (eqv? 2 2.0)
   --  is false.  Neither is identity: two equal bignums are two objects.

   function Equal (Left, Right : Number) return Boolean;
   function Eqv (Left, Right : Number) return Boolean;

   --  Exactness, and changing it.  To_Exact of a double that is not a
   --  whole number has nothing to answer with until there are rationals
   --  (#104), and raises saying so.

   function Is_Exact (N : Number) return Boolean;
   function Is_Whole (N : Number) return Boolean;
   function To_Exact (N : Number) return Number;
   function To_Inexact (N : Number) return Number;

   --  floor, ceiling, truncate and round, which give an exact number
   --  back as it is and round an inexact one to a whole inexact number.
   --  Round goes to the even one of two that are as near, as R7RS asks.

   type Rounding is (Floor, Ceiling, Truncate, Round);

   function Rounded (N : Number; How : Rounding) return Number;

   --  A number as it is written, in a radix from 2 to 16, without the
   --  prefix that would say which.  An inexact number is written in
   --  radix 10, as the shortest decimal that reads back as the same
   --  double: 1.5, 0.1, 1e+30.

   subtype Radix is Positive range 2 .. 16;

   function Image
     (N    : Number;
      Base : Radix := 10)
      return String
     with Pre => Base = 10 or else Is_Exact (N);

   --  An exact integer written as the reader takes one: an optional sign,
   --  an optional #b, #o, #d or #x that overrides Base, and at least one
   --  digit of the base.  Valid is false for anything else, and N is then
   --  nought.

   procedure Read
     (Text  : String;
      Base  : Radix;
      N     : out Number;
      Valid : out Boolean);

   --  A decimal with a point or an exponent, as an inexact number, or
   --  Valid false.  Ada's own reading of one wants a digit either side
   --  of the point and a point before the exponent, which R7RS does not.

   procedure Read_Decimal
     (Text  : String;
      N     : out Number;
      Valid : out Boolean);

private

   use Ada.Numerics.Big_Numbers.Big_Integers;

   type Number_Kind is (Fixnum, Bignum, Flonum);

   subtype Fixnum_Value is Integer
     range Raven.Objects.Min_Integer .. Raven.Objects.Max_Integer;

   --  A Bignum's Big is never in Fixnum_Value's range.

   type Number (Kind : Number_Kind := Fixnum) is
      record
         case Kind is
            when Fixnum =>
               Value   : Fixnum_Value := 0;
            when Bignum =>
               Big     : Big_Integer;
            when Flonum =>
               Inexact : Long_Float := 0.0;
         end case;
      end record;

end Raven.Numbers;
