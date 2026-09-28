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
--  Two kinds so far.  A fixnum is an integer in an object's payload,
--  29 bits and a sign.  A bignum is an exact integer past that (#102),
--  held in the heap as a block of packed bytes and worked on as Ada's
--  Big_Integer: decoding one copies its digits out and encoding one
--  copies them back, which is the same order of work as adding two of
--  them and less than multiplying them.  Two fixnums never become a
--  Big_Integer at all; their answer is worked out in Long_Long_Integer,
--  where it cannot overflow, and only made a bignum if it does not fit.
--
--  Normalisation is the invariant: every Number an operation gives back
--  is in the smallest representation that holds it exactly.  An integer
--  that fits in a fixnum is a fixnum, however it was arrived at --
--  (- (expt 2 40) (expt 2 40)) is a fixnum zero and not a boxed one --
--  and a rational whose denominator is one will be an integer.  Encode
--  depends on it, and so does equality: a bignum and a fixnum are never
--  the same number, and two normal numbers that fit in a word are equal
--  when they are the same word.

private package Raven.Numbers is

   type Number is private;

   --  Whether arithmetic can take this object as an operand, which is
   --  whether Decode may be asked about it.

   function Is_Arithmetic (X : Object) return Boolean;

   --  Decoding a bignum reads its block, and encoding one makes a block,
   --  which may collect.  Nothing a Number holds is in the heap, so a
   --  collection while encoding moves nothing a Number needs; but an
   --  object the caller read before Encode is somewhere else afterwards.

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

   --  The operations.  Each gives back a normal Number, or raises
   --  Constraint_Error saying why there is none, which is now only a
   --  division by zero.

   function Add (Left, Right : Number) return Number;
   function Subtract (Left, Right : Number) return Number;
   function Multiply (Left, Right : Number) return Number;

   --  Integer division, throwing the remainder away, until there are
   --  rationals to answer with (#104).

   function Divide (Left, Right : Number) return Number;

   function Less_Or_Equal (Left, Right : Number) return Boolean;

   --  Two questions R7RS keeps apart.  Equal is =: the same number,
   --  whatever it is held as, so (= 2 2.0) will be true once there are
   --  floats to ask it of.  Eqv is eqv?, and asks more: equal, and both
   --  exact or both inexact, so (eqv? 2 2.0) is false.  Neither is
   --  identity: two equal bignums are two objects.

   function Equal (Left, Right : Number) return Boolean;
   function Eqv (Left, Right : Number) return Boolean;

   --  A number as it is written, in a radix from 2 to 16, without the
   --  prefix that would say which.

   subtype Radix is Positive range 2 .. 16;

   function Image
     (N    : Number;
      Base : Radix := 10)
      return String;

   --  An exact integer written as the reader takes one: an optional sign,
   --  an optional #b, #o, #d or #x that overrides Base, and at least one
   --  digit of the base.  Valid is false for anything else, and N is then
   --  nought.

   procedure Read
     (Text  : String;
      Base  : Radix;
      N     : out Number;
      Valid : out Boolean);

private

   use Ada.Numerics.Big_Numbers.Big_Integers;

   type Number_Kind is (Fixnum, Bignum);

   subtype Fixnum_Value is Integer
     range Raven.Objects.Min_Integer .. Raven.Objects.Max_Integer;

   --  A Bignum's Big is never in Fixnum_Value's range.

   type Number (Kind : Number_Kind := Fixnum) is
      record
         case Kind is
            when Fixnum =>
               Value : Fixnum_Value := 0;
            when Bignum =>
               Big   : Big_Integer;
         end case;
      end record;

end Raven.Numbers;
