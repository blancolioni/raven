with Raven.Objects;

--  Numbers, as arithmetic sees them: decoded from an object, operated
--  on, and encoded again.
--
--  This is the seam the numeric tower goes behind (#45).  Every
--  arithmetic primitive raven has goes through it, and does nothing
--  else itself: decode each operand, ask this for the answer, encode
--  it.  So when there are floats, bignums and rationals, each is a kind
--  of Number here and a case in each operation, and the primitives and
--  the scheme library above them do not change.
--
--  There is one kind so far, the fixnum: an integer in an object's
--  payload.  Nothing a program can see is different; what is different
--  is that there is one place for the rest to go.
--
--  Normalisation is the invariant, and it is written down while there
--  is nothing yet to normalise so that what comes later inherits it
--  rather than having to be audited for it: every Number an operation
--  gives back is in the smallest representation that holds it exactly.
--  An integer that fits in a fixnum is a fixnum, however it was
--  arrived at -- (- (expt 2 40) (expt 2 40)) is a fixnum zero and not
--  a boxed one -- and a rational whose denominator is one will be an
--  integer.  Encode depends on it, and so does equality: two normal
--  numbers that are equal are the same word when they fit in one.

private package Raven.Numbers is

   type Number is private;

   --  Whether arithmetic can take this object as an operand, which is
   --  whether Decode may be asked about it.

   function Is_Arithmetic (X : Object) return Boolean;

   function Decode (X : Object) return Number
     with Pre => Is_Arithmetic (X);

   function Encode (N : Number) return Object
     with Post => Is_Arithmetic (Encode'Result);

   --  The operations.  Each gives back a normal Number, or raises
   --  Constraint_Error saying why there is none: an integer past what
   --  a fixnum holds, until there are bignums to hold it (#102), or a
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
   --  identity.  Two equal bignums will be two objects, and asking
   --  whether they are the same word would say they are not.
   --
   --  With fixnums alone the two agree, and agree with identity: that
   --  is why = could be eq? until now, and why it cannot stay so.

   function Equal (Left, Right : Number) return Boolean;
   function Eqv (Left, Right : Number) return Boolean;

   --  A number as it is written, for messages about one.

   function Image (N : Number) return String;

private

   type Number_Kind is (Fixnum);

   subtype Fixnum_Value is Integer
     range Raven.Objects.Min_Integer .. Raven.Objects.Max_Integer;

   type Number (Kind : Number_Kind := Fixnum) is
      record
         case Kind is
            when Fixnum =>
               Value : Fixnum_Value := 0;
         end case;
      end record;

end Raven.Numbers;
