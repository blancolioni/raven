--  What this raven is, as R7RS lets a program ask: the feature
--  identifiers that (features) answers with and that cond-expand
--  chooses by.
--
--  They are here, in one list, because what a raven has is decided
--  where it is built.  The numeric tower is the case in view: a raven
--  without bignums or without rationals is a legal R7RS implementation,
--  and exact-closed, ratios, exact-complex and ieee-float are how a
--  program tells one from another and adapts, rather than failing
--  somewhere far from the cause.  Each is added by the change that
--  makes it true: exact-closed came with bignums (#102), ieee-float
--  with doubles (#103) and ratios with exact rationals (#104), and
--  exact-complex is not here because it is not.
--
--  r7rs is not here either.  Every R7RS implementation has it, and it
--  is a claim that the whole of the small language is present, which
--  it is not while continuations, exceptions and multiple values are
--  missing.

private package Raven.Features is

   function Count return Natural;

   function Feature (Index : Positive) return String
     with Pre => Index <= Count;

   --  Symbols are folded to lower case when they are read, so a feature
   --  is asked for in lower case and the list is kept that way.

   function Is_Feature (Name : String) return Boolean;

end Raven.Features;
