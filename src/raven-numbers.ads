private with Ada.Numerics.Big_Numbers.Big_Integers;
private with Ada.Numerics.Big_Numbers.Big_Reals;

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
--  Four kinds, three exact and one not.
--
--  A fixnum is an integer in an object's payload, 29 bits and a sign.
--  A bignum is an exact integer past that (#102), held in the heap as a
--  block of packed bytes and worked on as Ada's Big_Integer.  A ratnum
--  is an exact rational that is not an integer (#104), held as one cell
--  of numerator and denominator and worked on as Ada's Big_Real.  Two
--  fixnums never become either; their answer is worked out in
--  Long_Long_Integer, where it cannot overflow, and made something else
--  only if it has to be.
--
--  A flonum is an inexact number, a double (#103).  It is worked on as
--  Long_Float, and kept as the immediate float when that holds it
--  exactly and as a boxed double otherwise -- see Raven.Objects.  An
--  operation with any inexact operand answers inexact, which is R7RS's
--  contagion: the answer can be no more exact than what it was worked
--  out from.
--
--  Normalisation is the invariant: every Number an operation gives back
--  is in the smallest representation that holds it exactly.  A rational
--  whose denominator is one is an integer, and an integer that fits in
--  a fixnum is a fixnum, however it was arrived at: (/ 6 2) is the
--  fixnum 3, and (- (expt 2 40) (expt 2 40)) a fixnum zero.  A double
--  the immediate float holds is an immediate.  Encode depends on it,
--  and so does equality: two exact numbers of different representations
--  are never the same number.

private package Raven.Numbers is

   type Number is private;

   --  Whether arithmetic can take this object as an operand, which is
   --  whether Decode may be asked about it.

   function Is_Arithmetic (X : Object) return Boolean;

   --  Decoding a bignum, a rational or a boxed double reads the heap, and
   --  encoding one makes something there, which may collect.  Nothing a
   --  Number holds is in the heap, so a collection while encoding moves
   --  nothing a Number needs; but an object the caller read before Encode
   --  is somewhere else afterwards.

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

   --  Division, which is exact for exact operands: (/ 7 2) is 7/2.  It
   --  truncated while there were no exact fractions to answer with.

   function Divide (Left, Right : Number) return Number;

   --  Integer division, throwing the remainder away, which is what
   --  truncate-quotient and so quotient, remainder and modulo are written
   --  on.  Both operands are integers, exact or not.

   function Quotient (Left, Right : Number) return Number
     with Pre => Is_Whole (Left) and then Is_Whole (Right);

   function Less_Or_Equal (Left, Right : Number) return Boolean;

   --  Two questions R7RS keeps apart.  Equal is =: the same number,
   --  whatever it is held as, so (= 2 2.0) is true.  Eqv is eqv?, and
   --  asks more: equal, and both exact or both inexact, so (eqv? 2 2.0)
   --  is false.  Neither is identity: two equal bignums are two objects.

   function Equal (Left, Right : Number) return Boolean;
   function Eqv (Left, Right : Number) return Boolean;

   --  Exactness, and changing it.  Every double is an exact rational, so
   --  To_Exact always has an answer: (exact 0.5) is 1/2, and (exact 0.1)
   --  is the fraction the double 0.1 is, which is not 1/10.

   function Is_Exact (N : Number) return Boolean;
   function Is_Whole (N : Number) return Boolean;
   function To_Exact (N : Number) return Number;
   function To_Inexact (N : Number) return Number;

   --  A rational's parts in lowest terms, with the denominator positive:
   --  an integer is itself over one, and an inexact number's parts are
   --  its exact parts made inexact again.

   function Numerator (N : Number) return Number;
   function Denominator (N : Number) return Number;

   --  floor, ceiling, truncate and round.  An exact rational rounds to an
   --  exact integer, an inexact number to a whole inexact one, and an
   --  integer is itself.  Round goes to the even one of two that are as
   --  near, as R7RS asks.

   type Rounding is (Floor, Ceiling, Truncate, Round);

   function Rounded (N : Number; How : Rounding) return Number;

   --  A number as it is written, in a radix from 2 to 16, without the
   --  prefix that would say which.  A rational is its numerator and its
   --  denominator with a slash between.  An inexact number is written in
   --  radix 10, as the shortest decimal that reads back as the same
   --  double: 1.5, 0.1, 1e+30.

   subtype Radix is Positive range 2 .. 16;

   function Image
     (N    : Number;
      Base : Radix := 10)
      return String
     with Pre => Base = 10 or else Is_Exact (N);

   --  An exact number written as the reader takes one: an optional sign,
   --  an optional #b, #o, #d or #x that overrides Base, digits of the
   --  base, and optionally a slash and more of them for a rational.
   --  Valid is false for anything else, including a denominator of
   --  nought, and N is then nought.

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
   use Ada.Numerics.Big_Numbers.Big_Reals;

   type Number_Kind is (Fixnum, Bignum, Ratnum, Flonum);

   subtype Fixnum_Value is Integer
     range Raven.Objects.Min_Integer .. Raven.Objects.Max_Integer;

   --  A Bignum's Big is never in Fixnum_Value's range, and a Ratnum's
   --  Ratio never has a denominator of one.

   type Number (Kind : Number_Kind := Fixnum) is
      record
         case Kind is
            when Fixnum =>
               Value   : Fixnum_Value := 0;
            when Bignum =>
               Big     : Big_Integer;
            when Ratnum =>
               Ratio   : Big_Real;
            when Flonum =>
               Inexact : Long_Float := 0.0;
         end case;
      end record;

end Raven.Numbers;
