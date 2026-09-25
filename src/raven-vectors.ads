with Raven.Evaluator;

private package Raven.Vectors is

   --  What a vector needs of the machine, which is the whole of what
   --  a vector is: how long one is, what is at an index, and putting
   --  something there.  Everything else R7RS asks for is written on
   --  these in the library, the way the string procedures are written
   --  on string->list.
   --
   --  Unlike those, these are not walks: a vector's elements are in
   --  the cells after its length, so an index is arithmetic.  That is
   --  what a vector is for and why it is not a tagged list.

   procedure Load_Vector_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class);

end Raven.Vectors;
